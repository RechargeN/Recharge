import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { PublishedObjectLinkService } from '../../src/modules/catalog/application/published_object_link_service.js';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createClassWorkshopWorld, expectData } from '../support/content_class_workshop_world.js';

const firestore = emulatorFirestore();
const world = createClassWorkshopWorld(firestore, 'd36-flow');
after(() => world.cleanup());

const effectIds = async (contentId: string) =>
  (
    await firestore.collection(contentCollections.effects).where('contentId', '==', contentId).get()
  ).docs
    .map((doc) => String(doc.data().effectId))
    .sort();

void test('Class C3 through real Media, C2 review, publish, owner hide, restrict/restore and immutable activate', async () => {
  const d = await world.boundClass();
  const sub = expectData<{ submissionId: string }>(
    await world.submit(d.draftId, d.revision),
    'submit',
  );
  // Without a staff approval the owner cannot publish.
  assert.notEqual((await world.publishApproved(sub.submissionId, 0)).kind, 'succeeded');
  expectData(
    await world.decide('approve', { contentId: d.contentId, submissionId: sub.submissionId }),
    'review',
  );
  const published = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(sub.submissionId, 0),
    'publish',
  );
  const pointer = await world.pointer(d.contentId);
  assert.equal(pointer.visibility, 'visible');
  const original = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(published.publishedRevisionId),
  );
  assert.ok(original);
  assert.equal(original.typeId, 'class_workshop');
  assert.deepEqual(original.body, d.body);
  assert.equal(original.mediaAttachments.length, 3);
  const afterPublish = await effectIds(d.contentId);
  assert.ok(afterPublish.length > 0, 'publication produced Content effects');

  expectData(await world.withdraw(d.contentId, pointer.revision), 'hide');
  const hidden = await world.pointer(d.contentId);
  assert.equal(hidden.visibility, 'withdrawn');
  const stale = await world.activate(d.contentId, published.publishedRevisionId, pointer.revision);
  assert.equal(stale.code, 'revision_conflict');
  expectData(
    await world.activate(d.contentId, published.publishedRevisionId, hidden.revision),
    'activate',
  );
  assert.equal((await world.pointer(d.contentId)).visibility, 'visible');
  const restricted = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict', { contentId: d.contentId }),
    'content restrict',
  );
  assert.equal((await world.pointer(d.contentId)).visibility, 'restricted');
  expectData(
    await world.decide(
      'restore',
      { contentId: d.contentId },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'content restore',
  );
  assert.equal((await world.pointer(d.contentId)).visibility, 'visible');
  // The immutable revision and its draft are untouched by the whole lifecycle.
  assert.deepEqual(
    await world.composition.contentRepository.transact((tx) =>
      tx.publishedRevision(published.publishedRevisionId),
    ),
    original,
  );
  const revisions = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevisionsForContent(d.contentId as never),
  );
  assert.equal(revisions.length, 1, 'no duplicate revision');
});

void test('a new authored revision then a rollback to the older immutable revision under CAS', async () => {
  const first = await world.publishedClass();
  const revised = structuredClone(first.body);
  revised.title = 'Riga pottery course, second edition';
  const updated = expectData<{ revision: number }>(
    await world.update(first.draftId, first.revision, revised),
    'update',
  );
  const sub = expectData<{ submissionId: string }>(
    await world.submit(first.draftId, updated.revision),
    'submit v2',
  );
  expectData(
    await world.decide('approve', { contentId: first.contentId, submissionId: sub.submissionId }),
    'review v2',
  );
  const pointer = await world.pointer(first.contentId);
  const second = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(sub.submissionId, pointer.revision),
    'publish v2',
  );
  const v2 = await world.pointer(first.contentId);
  assert.equal(v2.currentPublishedRevisionId, second.publishedRevisionId);
  assert.equal(
    (await world.activate(first.contentId, first.publishedRevisionId, v2.revision - 1)).code,
    'revision_conflict',
  );
  expectData(
    await world.activate(first.contentId, first.publishedRevisionId, v2.revision),
    'rollback',
  );
  const rolled = await world.pointer(first.contentId);
  assert.equal(rolled.currentPublishedRevisionId, first.publishedRevisionId);
  const target = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(first.publishedRevisionId),
  );
  assert.equal(target?.body.title, 'Riga pottery course');
});

void test('raw forbidden legacy, Booking and Event fields refuse submission without publication', async () => {
  for (const field of [
    'eventSlots',
    'capacity',
    'confirmed',
    'hold',
    'availability',
    'archetype',
  ]) {
    const d = await world.boundClass((body) => ({ ...body, [field]: [] }));
    const result = await world.submit(d.draftId, d.revision);
    assert.equal(result.code, 'validation_failed', field);
    assert.equal(
      await world.composition.contentRepository.transact((tx) => tx.pointer(d.contentId)),
      null,
    );
  }
});

void test('Collection evaluator returns only allowlisted Class facts; area-only address and private fields never leak', async () => {
  const d = await world.publishedClass((body) => {
    const data = body.class_workshop as Record<string, unknown>;
    return {
      ...body,
      class_workshop: {
        ...data,
        public_location_mode: 'area_only',
        safe_area_label: 'Riga centre',
      },
    };
  });
  const catalog = createEmulatorCatalogComposition(firestore);
  const evaluator = new PublishedObjectLinkService(catalog.source, true);
  const input = { typeId: 'class_workshop' as const, contentId: d.contentId, marketId: 'LV' };
  const result = await evaluator.status(input, true);
  assert.equal(result.status, 'eligible');
  for (const forbidden of [
    'Riga studio 1',
    'addressLine1',
    '56.9496',
    'rightsConfirmed',
    'timezone_confirmed',
    'external_url',
    'studio.example.org',
    'createdByUserId',
  ])
    assert.ok(!JSON.stringify(result).includes(forbidden), forbidden);
  const pointer = await world.pointer(d.contentId);
  expectData(await world.withdraw(d.contentId, pointer.revision), 'hide');
  assert.equal((await evaluator.status(input, true)).status, 'withheld');
  assert.equal(
    (await evaluator.status({ ...input, contentId: randomUUID() }, true)).status,
    'unknown',
  );
});

void test('Class stays excluded from Discover and creates no Booking authority through owner delivery', async () => {
  const value = await world.publishedClass();
  const catalog = createEmulatorCatalogComposition(firestore);
  const discover = (await catalog.query.feed({
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['class_workshop'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:class_workshop', JSON.stringify(discover));
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const versions = await firestore
    .collection(catalogCollections.versions)
    .where('contentId', '==', value.contentId)
    .get();
  for (const version of versions.docs) {
    assert.equal(version.data().state, 'excluded');
    assert.equal(version.data().reason, 'type_disabled');
  }
  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await effectIds(value.contentId);
  assert.ok(effects.length > 0);
  for (const effectId of effects) {
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(value.contentId)), null);
});
