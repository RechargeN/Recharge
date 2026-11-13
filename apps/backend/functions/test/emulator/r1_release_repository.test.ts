import assert from 'node:assert/strict';
import test from 'node:test';

import { getFirestore } from 'firebase-admin/firestore';

import { FirestoreConfigReader } from '../../src/platform/adapters/firestore_config_reader.js';
import { getOrCreateEmulatorAdminApp } from '../../src/platform/adapters/firebase_app.js';
import {
  activeReleasePointerCollection,
  releaseManifestCollection,
} from '../../src/platform/release/release_manifest_repository.js';

void test('immutable release and active pointer use separate exact collections', async () => {
  const app = getOrCreateEmulatorAdminApp(process.env);
  assert.ok(app);
  const firestore = getFirestore(app);
  const reader = new FirestoreConfigReader(firestore);
  const suffix = `release-${Date.now()}`;
  const manifest = firestore.collection(releaseManifestCollection).doc(suffix);
  const pointer = firestore.collection(activeReleasePointerCollection).doc(suffix);
  try {
    await manifest.create({ status: 'disabled', revision: 1 });
    await pointer.create({ activeManifestId: suffix, pointerRevision: 1 });
    assert.deepEqual(await reader.readReleaseManifest(suffix), { status: 'disabled', revision: 1 });
    assert.deepEqual(await reader.readActiveReleasePointer(suffix), {
      activeManifestId: suffix,
      pointerRevision: 1,
    });
    await assert.rejects(
      () => manifest.create({ status: 'disabled', revision: 2 }),
      /ALREADY_EXISTS|already exists|6/,
    );
  } finally {
    await Promise.all([manifest.delete(), pointer.delete()]);
  }
});
