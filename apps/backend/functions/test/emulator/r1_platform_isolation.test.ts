import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveEmulatorFirebaseContext } from '../../src/platform/adapters/firebase_app.js';

void test('platform adapter accepts only loopback demo-recharge emulator context', () => {
  assert.deepEqual(
    resolveEmulatorFirebaseContext({
      FUNCTIONS_EMULATOR: 'true',
      GCLOUD_PROJECT: 'demo-recharge',
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    }),
    { projectId: 'demo-recharge', firestoreHost: '127.0.0.1:8080' },
  );
  assert.equal(resolveEmulatorFirebaseContext({ GCLOUD_PROJECT: 'production-project' }), null);
  assert.equal(
    resolveEmulatorFirebaseContext({
      FUNCTIONS_EMULATOR: 'true',
      GCLOUD_PROJECT: 'demo-recharge',
      FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443',
    }),
    null,
  );
});
