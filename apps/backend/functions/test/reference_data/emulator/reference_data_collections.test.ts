import assert from 'node:assert/strict';
import test from 'node:test';

import { getFirestore } from 'firebase-admin/firestore';

import { getOrCreateEmulatorAdminApp } from '../../../src/platform/adapters/firebase_app.js';
import {
  marketConfigRevisionCollection,
  referenceActivationPointerCollection,
} from '../../../src/platform/config/market_config_repository.js';

void test('reference data reuses the exact approved R1 collections', () => {
  assert.equal(marketConfigRevisionCollection, 'referenceMarketConfigRevisions');
  assert.equal(referenceActivationPointerCollection, 'referenceActivationPointers');
});

void test('emulator stores synthetic disabled revisions and isolated pointers only', async () => {
  const app = getOrCreateEmulatorAdminApp({
    FUNCTIONS_EMULATOR: 'true',
    GCLOUD_PROJECT: 'demo-recharge',
    FIRESTORE_EMULATOR_HOST: process.env.FIRESTORE_EMULATOR_HOST,
  });
  assert.ok(app, 'Firebase Emulator must be available');
  const firestore = getFirestore(app);
  const suffix = `reference-data-${Date.now()}`;
  const config = firestore.collection(marketConfigRevisionCollection).doc(suffix);
  const lvPointer = firestore
    .collection(referenceActivationPointerCollection)
    .doc(`local-LV-${suffix}`);
  const eePointer = firestore
    .collection(referenceActivationPointerCollection)
    .doc(`local-EE-${suffix}`);
  try {
    await config.set({ schemaVersion: 1, marketId: 'LV', status: 'disabled', synthetic: true });
    await lvPointer.set({ activeRevisionId: suffix, pointerRevision: 1 });
    assert.equal((await config.get()).get('status'), 'disabled');
    assert.equal((await lvPointer.get()).get('activeRevisionId'), suffix);
    assert.equal((await eePointer.get()).exists, false);
  } finally {
    await Promise.all([config.delete(), lvPointer.delete(), eePointer.delete()]);
  }
});
