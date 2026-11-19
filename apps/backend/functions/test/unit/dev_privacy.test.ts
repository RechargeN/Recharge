import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import {
  devPrivacyOpen,
  handlePrivacyOperator,
  handlePrivacyRequest,
  privacySwitchOpen,
  runPrivacyWork,
  syntheticPrivacySubjects,
  uuidV5,
} from '../../src/dev_privacy_entry.js';

/**
 * Step 2 (owner decisions 2026-11-20): the cloud DSR entry. The subject comes
 * only from the Session; the operator path serves synthetic subjects only;
 * everything stays contained while the privacy switch is missing.
 */

const dev = 'recharge-dev-n2a01';
const uid = 'a'.repeat(28);
const now = '2026-11-20T10:00:00.000Z';
const session = {
  sessionId: 'session_001',
  sessionHandle: 'A'.repeat(43),
  installationId: 'installation-001',
};

function emptyFirestore(): Firestore {
  return {
    collection: () => ({
      doc: () => ({ get: () => Promise.resolve({ data: () => undefined }) }),
    }),
  } as unknown as Firestore;
}

const untouched = {
  collection: () => {
    throw new Error('must not read');
  },
} as unknown as Firestore;

async function inDevCloud<T>(run: () => Promise<T>): Promise<T> {
  const names = [
    'FUNCTIONS_EMULATOR',
    'FIRESTORE_EMULATOR_HOST',
    'GCLOUD_PROJECT',
    'N5D_PRIVACY_ENABLED',
  ];
  const saved = names.map((name) => [name, process.env[name]] as const);
  for (const name of names) delete process.env[name];
  process.env.GCLOUD_PROJECT = dev;
  try {
    return await run();
  } finally {
    for (const [name, value] of saved) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

void test('UUIDv5 matches the RFC 9562 vector; synthetic subjects are stable UUIDs', () => {
  assert.equal(
    uuidV5('www.example.com', '6ba7b810-9dad-11d1-80b4-00c04fd430c8'),
    '2ed6657d-e927-568b-95e1-2665a8aea6a2',
  );
  assert.equal(syntheticPrivacySubjects.length, 20);
  assert.equal(new Set(syntheticPrivacySubjects).size, 20);
  for (const subject of syntheticPrivacySubjects) assert.match(subject, /^[0-9a-f-]{36}$/u);
});

void test('the runtime opens only in the reviewed project with the owner allowlist', () => {
  const open = { GCLOUD_PROJECT: dev, N4C_BOOKING_ENABLED: 'true', N4C_ALLOWED_FIREBASE_UIDS: uid };
  assert.deepEqual(devPrivacyOpen(open), [uid]);
  assert.equal(devPrivacyOpen({ ...open, N4C_BOOKING_ENABLED: 'false' }), null);
  assert.equal(devPrivacyOpen({ ...open, N4C_ALLOWED_FIREBASE_UIDS: '' }), null);
  assert.equal(devPrivacyOpen({ ...open, GCLOUD_PROJECT: 'recharge-prod' }), null);
  assert.equal(devPrivacyOpen({ ...open, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }), null);
});

void test('a closed privacy deploy switch contains intake and the worker', async () => {
  await inDevCloud(async () => {
    const submit = await handlePrivacyRequest({
      firestore: emptyFirestore(),
      firebaseUid: uid,
      nowUtc: now,
      data: {
        schemaVersion: 1,
        commandType: 'submitPrivacyRequest',
        sessionContext: session,
        payload: {
          requestId: '0b8f9a3e-1d2c-4e5f-8a6b-7c8d9e0f1a2b',
          requestType: 'access',
          idempotencyKey: 'privacy-access-0001',
        },
      },
    });
    assert.equal(submit.code, 'temporarily_unavailable');
    assert.deepEqual(await runPrivacyWork(untouched, now), { tasks: 0, requests: 0 });
  });
});

void test('only an explicit true opens the privacy switch', () => {
  assert.equal(privacySwitchOpen({ N5D_PRIVACY_ENABLED: 'true' }), true);
  for (const value of [undefined, 'false', 'TRUE', '1', ''])
    assert.equal(privacySwitchOpen({ N5D_PRIVACY_ENABLED: value }), false);
});

void test('without a Session context nothing is read', async () => {
  const result = await handlePrivacyRequest({
    firestore: untouched,
    firebaseUid: uid,
    nowUtc: now,
    data: { schemaVersion: 1, commandType: 'submitPrivacyRequest', payload: {} },
  });
  assert.equal(result.code, 'access_denied');
});

void test('the operator path refuses any non-synthetic subject before reading', async () => {
  for (const subjectId of [undefined, 'b399e3e7-950c-401a-9f7a-a75d32fb6f23', uid]) {
    const result = await handlePrivacyOperator({
      firestore: untouched,
      nowUtc: now,
      body: { operation: 'submit', subjectId, requestType: 'erasure' },
    });
    assert.equal(result.code, 'subject_not_synthetic');
  }
});
