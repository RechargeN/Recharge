import assert from 'node:assert/strict';
import test from 'node:test';

import { getFirestore } from 'firebase-admin/firestore';

import { FirestoreConfigReader } from '../../src/platform/adapters/firestore_config_reader.js';
import { getOrCreateEmulatorAdminApp } from '../../src/platform/adapters/firebase_app.js';
import { featureFlagRevisionCollection } from '../../src/platform/config/feature_flag_repository.js';
import {
  marketConfigRevisionCollection,
  referenceActivationPointerCollection,
} from '../../src/platform/config/market_config_repository.js';

void test('R1 config reader uses exact collections and reads pointers without writes', async () => {
  const app = getOrCreateEmulatorAdminApp(process.env);
  assert.ok(app, 'emulator Admin app must be available');
  const firestore = getFirestore(app);
  const reader = new FirestoreConfigReader(firestore);
  const suffix = `test-${Date.now()}`;
  const references = [
    firestore.collection(featureFlagRevisionCollection).doc(suffix),
    firestore.collection(marketConfigRevisionCollection).doc(suffix),
    firestore.collection(referenceActivationPointerCollection).doc(suffix),
  ];
  try {
    await references[0]!.set({ enabled: false });
    await references[1]!.set({ status: 'disabled' });
    await references[2]!.set({ activeRevisionId: suffix, pointerRevision: 1 });
    assert.deepEqual(await reader.readFeatureFlagRevision(suffix), { enabled: false });
    assert.deepEqual(await reader.readMarketConfigRevision(suffix), { status: 'disabled' });
    assert.deepEqual(await reader.readActiveReferencePointer(suffix), {
      activeRevisionId: suffix,
      pointerRevision: 1,
    });
  } finally {
    await Promise.all(references.map((reference) => reference.delete()));
  }
});

void test('Firestore transaction permits only one expected-revision pointer swap', async () => {
  const app = getOrCreateEmulatorAdminApp(process.env);
  assert.ok(app);
  const firestore = getFirestore(app);
  const pointer = firestore
    .collection(referenceActivationPointerCollection)
    .doc(`cas-${Date.now()}`);
  await pointer.set({ activeRevisionId: 'initial', pointerRevision: 0 });
  const swap = async (target: string) =>
    firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(pointer);
      if (snapshot.get('pointerRevision') !== 0) return false;
      transaction.update(pointer, { activeRevisionId: target, pointerRevision: 1 });
      return true;
    });
  try {
    const results = await Promise.all([swap('one'), swap('two')]);
    assert.equal(results.filter(Boolean).length, 1);
  } finally {
    await pointer.delete();
  }
});
