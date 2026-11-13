import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import type { Firestore } from 'firebase-admin/firestore';

import {
  closedModeration,
  devContentTypes,
  devOperations,
  handleDevContentMedia,
  type DevContentMedia,
} from '../../src/dev_content_media_composition.js';
import { devRuntimeOpen, failureShape } from '../../src/dev_content_media_entry.js';
import { createDevMediaComposition } from '../../src/modules/media/infrastructure/dev_media_composition.js';

const uid = 'abcdefghijklmnopqrstuvwxyz012345';
const session = {
  sessionId: 'session-1',
  sessionHandle: 'A'.repeat(43),
  installationId: 'install-1',
};
/** Firestore that fails the test if anything reads it. */
const untouchable = new Proxy(
  {},
  {
    get: () => {
      throw new Error('firestore must not be touched');
    },
  },
) as unknown as Firestore;
const neverCompose = (): DevContentMedia => {
  throw new Error('composition must not be built');
};

void test('only Place and the owner draft/media operations exist; publication paths are closed', async () => {
  assert.deepEqual([...devContentTypes], ['place']);
  for (const [callable, data] of [
    ['contentCommandV1', { commandType: 'submitForPublication' }],
    ['contentCommandV1', { commandType: 'publishApprovedRevision' }],
    ['contentCommandV1', { commandType: 'withdrawPublication' }],
    ['contentCommandV1', { commandType: 'activatePublishedRevision' }],
    ['contentCommandV1', { commandType: 'rollbackImportedDraft' }],
    ['contentCommandV1', { commandType: 'applyModerationDisposition' }],
    ['contentQueryV1', { queryType: 'getPublishedRevision' }],
    ['mediaCommandV1', { commandType: 'deleteAsset' }],
    ['mediaQueryV1', { queryType: 'deliver' }],
    ['contentCommandV1', {}],
    ['contentCommandV1', 'not an object'],
  ] as const) {
    const result = await handleDevContentMedia({
      callable,
      firebaseUid: uid,
      data,
      firestore: untouchable,
      compose: neverCompose,
    });
    assert.deepEqual(result, { schemaVersion: 1, kind: 'rejected', code: 'capability_denied' });
  }
  assert.deepEqual(devOperations.contentCommandV1, ['createDraft', 'updateDraft']);
});

void test('no Recharge Session in the payload: unauthenticated before any read', async () => {
  for (const sessionContext of [
    undefined,
    {},
    { ...session, extra: 'x' },
    { ...session, sessionHandle: 'short' },
  ]) {
    const result = await handleDevContentMedia({
      callable: 'contentCommandV1',
      firebaseUid: uid,
      data: { commandType: 'createDraft', sessionContext },
      firestore: untouchable,
      compose: neverCompose,
    });
    assert.equal(result.code, 'unauthenticated');
  }
});

void test('a Session Firestore does not know is unauthenticated and builds nothing', async () => {
  const empty = {
    collection: () => ({ doc: (id: string) => ({ id }) }),
    getAll: () => Promise.resolve([{ data: () => undefined }, { data: () => undefined }]),
  } as unknown as Firestore;
  const result = await handleDevContentMedia({
    callable: 'mediaCommandV1',
    firebaseUid: uid,
    data: { commandType: 'createUploadSession', sessionContext: session },
    firestore: empty,
    compose: neverCompose,
  });
  assert.equal(result.code, 'unauthenticated');
});

void test('runtime switch: exact project, every dev flag, no Emulator, a valid owner allowlist', () => {
  const env = {
    GCLOUD_PROJECT: 'recharge-dev-n2a01',
    N3A2_DEV_ENABLED: 'true',
    RECHARGE_DEV_RUNTIME: 'content-media',
    RECHARGE_MEDIA_STORAGE: 'dev-cloud',
    RECHARGE_MEDIA_TOOLS: 'dev-cloud',
    N3A2_ALLOWED_FIREBASE_UIDS: uid,
  };
  assert.deepEqual(devRuntimeOpen(env), [uid]);
  for (const broken of [
    { ...env, N3A2_DEV_ENABLED: 'false' },
    { ...env, GCLOUD_PROJECT: 'recharge-prod-x' },
    { ...env, RECHARGE_MEDIA_TOOLS: 'local-real' },
    { ...env, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
    { ...env, N3A2_ALLOWED_FIREBASE_UIDS: '' },
    { ...env, N3A2_ALLOWED_FIREBASE_UIDS: 'bad uid!' },
  ])
    assert.equal(devRuntimeOpen(broken), null);
});

void test('Media never starts without the dev-cloud tools (no fake or local fallback)', () => {
  assert.throws(
    () =>
      createDevMediaComposition({
        app: { options: { projectId: 'recharge-dev-n2a01' } } as never,
        firestore: untouchable,
        environment: { GCLOUD_PROJECT: 'recharge-dev-n2a01' },
      }),
    /dev_media_requires_dev_cloud_tools/u,
  );
});

void test('no moderation in dev: no profile, no verified disposition', async () => {
  assert.deepEqual(
    await closedModeration.profileFor({
      typeId: 'place',
      marketId: 'LV',
      publisherRef: { type: 'user', id: uid as never },
    }),
    { available: false },
  );
  assert.deepEqual(await closedModeration.verifyDisposition({ payload: {} as never, nowUtc: '' }), {
    verified: false,
  });
});

void test('static: the dev compositions use the real adapters only', () => {
  const src = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../src');
  for (const file of [
    'dev_content_media_composition.ts',
    'dev_content_media_entry.ts',
    'modules/media/infrastructure/dev_media_composition.ts',
  ]) {
    // Code only: the files' comments name what is deliberately absent.
    const text = readFileSync(path.join(src, file), 'utf8').replace(
      /\/\*[\s\S]*?\*\/|\/\/.*$/gmu,
      '',
    );
    assert.doesNotMatch(
      text,
      /fake_|Fake(Scanner|Processor|ObjectStore)|local_tools_client|storage_emulator|createEmulatorMediaComposition|eventAuthoringComposition/u,
      file,
    );
    assert.doesNotMatch(
      text,
      /getSignedUrl|delivery|orphan|MediaDeletionService|removeVariant/iu,
      file,
    );
  }
});

void test('a failure logs only its class and a short code, never the message', () => {
  const refused = Object.assign(new Error('secret detail /path?token=abc'), {
    name: 'ContentPersistenceEnvironmentError',
    reason: 'dev_cloud_override',
  });
  assert.deepEqual(failureShape(refused), {
    error: 'ContentPersistenceEnvironmentError',
    code: 'dev_cloud_override',
  });
  assert.deepEqual(failureShape(Object.assign(new Error('x'), { code: 7 })), {
    error: 'Error',
    code: '7',
  });
  assert.deepEqual(failureShape(Object.assign(new Error('x'), { code: 'has spaces and more' })), {
    error: 'Error',
    code: null,
  });
  assert.deepEqual(failureShape('boom'), { error: 'string', code: null });
  assert.ok(!JSON.stringify(failureShape(refused)).includes('secret'));
});
