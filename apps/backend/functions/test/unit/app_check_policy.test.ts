import assert from 'node:assert/strict';
import test from 'node:test';

import { decideAppCheck } from '../../src/security/app_check_policy.js';

void test('App Check bypass is possible only for the exact local demo Emulator triple', () => {
  assert.deepEqual(
    decideAppCheck({
      environmentId: 'local',
      projectId: 'demo-recharge',
      functionsEmulator: 'true',
      firestoreEmulatorHost: '127.0.0.1:8080',
      evidenceState: 'missing',
    }),
    { allowed: true, mode: 'emulatorBypass' },
  );
  for (const changed of [
    { projectId: 'recharge-prod' },
    { functionsEmulator: 'false' },
    { firestoreEmulatorHost: 'firestore.googleapis.com:443' },
  ]) {
    assert.deepEqual(
      decideAppCheck({
        environmentId: 'local',
        projectId: 'demo-recharge',
        functionsEmulator: 'true',
        firestoreEmulatorHost: 'localhost:8080',
        evidenceState: 'missing',
        ...changed,
      }),
      { allowed: false, code: 'policy_unavailable' },
    );
  }
});

void test('dev, stage and prod require valid App Check evidence', () => {
  for (const environmentId of ['dev', 'stage', 'prod'] as const) {
    assert.equal(
      decideAppCheck({
        environmentId,
        projectId: 'any',
        functionsEmulator: undefined,
        firestoreEmulatorHost: undefined,
        evidenceState: 'missing',
      }).allowed,
      false,
    );
    assert.deepEqual(
      decideAppCheck({
        environmentId,
        projectId: 'any',
        functionsEmulator: undefined,
        firestoreEmulatorHost: undefined,
        evidenceState: 'valid',
      }),
      { allowed: true, mode: 'verified' },
    );
  }
});
