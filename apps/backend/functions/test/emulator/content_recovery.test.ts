import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import type { ContentEffectV1 } from '../../src/contracts/content_v1.js';
import { ContentIntegrityRecovery } from '../../src/modules/content/application/content_integrity_recovery.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { serviceHarness } from '../support/content_repository_scenarios.js';

const firestore = emulatorFirestore();

async function cleanup(): Promise<void> {
  for (const collection of Object.values(contentCollections))
    for (;;) {
      const snapshot = await firestore.collection(collection).limit(200).get();
      if (snapshot.empty) break;
      const batch = firestore.batch();
      for (const document of snapshot.docs) batch.delete(document.ref);
      await batch.commit();
    }
}

before(cleanup);
after(cleanup);

async function published() {
  const repository = new FirestoreContentRepository(firestore);
  const { contentId } = await serviceHarness(repository).publishOne();
  return { recovery: new ContentIntegrityRecovery(repository), contentId };
}

const documentsOf = (collection: string, contentId: string) =>
  firestore.collection(collection).where('contentId', '==', contentId).get();

void test('intact stored records verify clean and stored effects replay in order, idempotently', async () => {
  const { recovery, contentId } = await published();
  assert.deepEqual((await recovery.verify(contentId)).findings, []);
  const seen: ContentEffectV1[] = [];
  const first = await recovery.replayEffects(contentId, (effect) => {
    seen.push(effect);
    return Promise.resolve();
  });
  assert.equal(first, 1);
  // Replaying again hands out the same stored effects and writes nothing.
  const again: string[] = [];
  await recovery.replayEffects(contentId, (effect) => {
    again.push(effect.effectId);
    return Promise.resolve();
  });
  assert.deepEqual(
    again,
    seen.map((item) => item.effectId),
  );
  assert.equal(await recovery.replayEffects(contentId, () => Promise.resolve(), 1), 0);
});

void test('a lost historical effect is reported as corruption and never invented', async () => {
  const { recovery, contentId } = await published();
  for (const document of (await documentsOf(contentCollections.effects, contentId)).docs)
    await document.ref.delete();
  const report = await recovery.verify(contentId);
  assert.equal(report.ok, false);
  assert.deepEqual(report.findings.map((item) => item.code).sort(), [
    'effect_missing_for_pointer_revision',
    'effect_missing_for_revision',
  ]);
  // Recovery creates nothing: the effect is still gone afterwards.
  assert.equal((await documentsOf(contentCollections.effects, contentId)).size, 0);
});

void test('a tampered revision body or a missing current revision is reported', async () => {
  const tampered = await published();
  const revisions = await documentsOf(contentCollections.publishedRevisions, tampered.contentId);
  await revisions.docs[0]?.ref.update({ bodyJson: JSON.stringify({ title: 'tampered' }) });
  assert.ok(
    (await tampered.recovery.verify(tampered.contentId)).findings.some(
      (item) => item.code === 'revision_body_hash_mismatch',
    ),
  );
  const missing = await published();
  const other = await documentsOf(contentCollections.publishedRevisions, missing.contentId);
  await other.docs[0]?.ref.delete();
  const codes = (await missing.recovery.verify(missing.contentId)).findings.map(
    (item) => item.code,
  );
  assert.ok(codes.includes('current_revision_missing'));
});
