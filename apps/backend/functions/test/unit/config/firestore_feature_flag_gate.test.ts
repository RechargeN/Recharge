import assert from 'node:assert/strict';
import test from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';
import { FirestoreFeatureFlagGate } from '../../../src/platform/config/firestore_feature_flag_gate.js';

void test('feature flag storage failure propagates instead of becoming disabled', async () => {
  const previousEmulator = process.env.FUNCTIONS_EMULATOR;
  const previousProject = process.env.GCLOUD_PROJECT;
  process.env.FUNCTIONS_EMULATOR = 'true';
  process.env.GCLOUD_PROJECT = 'demo-recharge';
  const unavailable = Object.assign(new Error('unavailable'), { code: 14 });
  const firestore = {
    collection() {
      return {
        doc() {
          return { get: () => Promise.reject(unavailable) };
        },
      };
    },
  } as unknown as Firestore;
  try {
    await assert.rejects(
      new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled('booking.create'),
      unavailable,
    );
  } finally {
    if (previousEmulator === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = previousEmulator;
    if (previousProject === undefined) delete process.env.GCLOUD_PROJECT;
    else process.env.GCLOUD_PROJECT = previousProject;
  }
});
