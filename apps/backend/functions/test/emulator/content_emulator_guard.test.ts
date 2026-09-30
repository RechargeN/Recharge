import assert from 'node:assert/strict';
import { test } from 'node:test';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import {
  ContentPersistenceDisabledError,
  createEmulatorContentService,
} from '../../src/modules/content/infrastructure/emulator_content_composition.js';
import {
  ContentPersistenceEnvironmentError,
  FirestoreContentRepository,
  type ContentPersistenceRefusal,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { serviceHarness } from '../support/content_repository_scenarios.js';

const firestore = emulatorFirestore();
const good: NodeJS.ProcessEnv = {
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  GCLOUD_PROJECT: 'demo-recharge',
};

function refusalOf(action: () => unknown): ContentPersistenceRefusal | undefined {
  try {
    action();
  } catch (error) {
    if (error instanceof ContentPersistenceEnvironmentError) return error.reason;
    throw error;
  }
  return undefined;
}

const construct = (environment: NodeJS.ProcessEnv, target = firestore) =>
  refusalOf(() => new FirestoreContentRepository(target, { environment }));

void test('the repository constructor accepts only the demo-recharge loopback Emulator', () => {
  assert.equal(construct(good), undefined);
  for (const host of ['127.0.0.1:8080', 'localhost:8080', '[::1]:8080'])
    assert.equal(construct({ ...good, FIRESTORE_EMULATOR_HOST: host }), undefined, host);
  // The live process environment set up by emulators:exec is accepted too.
  assert.doesNotThrow(() => new FirestoreContentRepository(firestore));
});

void test('a missing or non-loopback endpoint is refused, with no cloud fallback', () => {
  assert.equal(construct({ GCLOUD_PROJECT: 'demo-recharge' }), 'emulator_host_missing');
  assert.equal(construct({ ...good, FIRESTORE_EMULATOR_HOST: '' }), 'emulator_host_missing');
  for (const host of [
    'firestore.googleapis.com:443',
    '10.0.0.5:8080',
    '0.0.0.0:8080',
    '127.0.0.1.evil.example:8080',
    'localhost',
    'http://127.0.0.1:8080',
  ])
    assert.equal(
      construct({ ...good, FIRESTORE_EMULATOR_HOST: host }),
      'emulator_host_not_loopback',
      host,
    );
});

void test('any project other than the exact demo project is refused', () => {
  assert.equal(construct({ ...good, GCLOUD_PROJECT: 'recharge-prod' }), 'project_not_demo');
  assert.equal(construct({ ...good, GOOGLE_CLOUD_PROJECT: 'demo-recharge-2' }), 'project_not_demo');
  // A Firestore client bound to another project is refused even with a clean environment.
  const other = getFirestore(initializeApp({ projectId: 'some-real-project' }, 'guard-other'));
  assert.equal(construct(good, other), 'project_not_demo');
});

void test('cloud credentials and endpoint overrides are refused', () => {
  assert.equal(
    construct({ ...good, GOOGLE_APPLICATION_CREDENTIALS: 'C:\\keys\\service-account.json' }),
    'cloud_credentials_present',
  );
  assert.equal(construct({ ...good, FIREBASE_SERVICE_ACCOUNT: '{}' }), 'cloud_credentials_present');
  assert.equal(
    construct({ ...good, FIRESTORE_HOST: 'firestore.googleapis.com' }),
    'cloud_endpoint_override',
  );
});

void test('the composition needs its default-off flag and inherits every guard of the repository', () => {
  const { ports } = serviceHarness(new FirestoreContentRepository(firestore));
  assert.throws(
    () => createEmulatorContentService({ firestore, ports }),
    ContentPersistenceDisabledError,
  );
  assert.throws(
    () => createEmulatorContentService({ firestore, ports, contentPersistenceEnabled: false }),
    ContentPersistenceDisabledError,
  );
  assert.throws(
    () =>
      createEmulatorContentService({
        firestore,
        ports,
        contentPersistenceEnabled: true,
        environment: { ...good, FIRESTORE_EMULATOR_HOST: '10.0.0.5:8080' },
      }),
    ContentPersistenceEnvironmentError,
  );
  const composed = createEmulatorContentService({
    firestore,
    ports,
    contentPersistenceEnabled: true,
  });
  assert.ok(composed.service);
  assert.ok(composed.repository instanceof FirestoreContentRepository);
});
