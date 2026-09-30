import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import {
  createContentDraft,
  directProvenance,
  importProvenance,
} from '../../src/modules/content/domain/content_draft.js';
import { ContentRepositoryConflict } from '../../src/modules/content/domain/failures.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { newId } from '../support/content_repository_scenarios.js';

const firestore = emulatorFirestore();
const now = parseUtcInstant('2026-09-30T10:00:00.000Z');
const references = {
  marketConfigRevisionId: 'mc-lv-1',
  taxonomyRevisionId: 'tx-1',
  localizationRevisionId: 'loc-1',
};

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

function draft(binding?: string) {
  const owner = newId();
  return createContentDraft({
    draftId: newId(),
    contentId: newId(),
    typeId: 'place',
    publisherRef: { type: 'user', id: owner },
    marketId: 'LV',
    body: { title: 'x' },
    referenceRevisions: references,
    createdByUserId: binding === undefined ? owner : null,
    provenance:
      binding === undefined
        ? directProvenance(owner)
        : importProvenance({
            kind: 'delegatedImport',
            delegatedActorRef: 'module:event-ingestion/syncSource',
            externalBindingRef: binding,
            sourceId: 'src-1',
            sourceRevision: '1',
            acquiredAtUtc: now,
            correctionRemovalPolicyRef: 'removal-policy-1',
          }),
    nowUtc: now,
  });
}

void test('concurrent imports of one external source record leave exactly one bound draft', async () => {
  const repository = new FirestoreContentRepository(firestore);
  const binding = `src-1|${newId()}|`;
  const results = await Promise.allSettled(
    Array.from({ length: 6 }, () =>
      repository.transact(async (tx) => {
        // Every attempt starts from "no draft bound yet", like concurrent importers.
        if ((await tx.draftByExternalBinding(binding)) === null) tx.putDraft(draft(binding));
      }),
    ),
  );
  assert.ok(results.some((item) => item.status === 'fulfilled'));
  for (const item of results)
    if (item.status === 'rejected')
      assert.ok(item.reason instanceof ContentRepositoryConflict, String(item.reason));
  const stored = await firestore
    .collection(contentCollections.drafts)
    .where('provenance.originBinding.externalBindingRef', '==', binding)
    .get();
  assert.equal(stored.size, 1);
});

void test('concurrent independent transactions on different Content do not interfere', async () => {
  const repository = new FirestoreContentRepository(firestore);
  const drafts = Array.from({ length: 12 }, () => draft());
  await Promise.all(
    drafts.map((item) =>
      repository.transact((tx) => {
        tx.putDraft(item);
      }),
    ),
  );
  for (const item of drafts)
    assert.equal(
      (await repository.transact((tx) => tx.draft(item.draftId)))?.draftId,
      item.draftId,
    );
});
