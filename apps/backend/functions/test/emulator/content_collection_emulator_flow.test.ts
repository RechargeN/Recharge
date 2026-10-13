// D3.4 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §2.3, §3, §4): the Collection
// lifecycle on the Firestore and Storage Emulators through the real Content,
// Media and C2 moderation services, with membership answered by the
// Catalog-owned evaluator over the Content owner's pointers and revisions; and
// the effects on Catalog (excluded as a disabled type, no Collection model),
// Discover (refused), Booking (nothing) and D2 (a restricted cover).
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, test } from 'node:test';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createCollectionWorld, expectData } from '../support/content_collection_world.js';

const switchName = 'RECHARGE_TEST_COLLECTION_MEMBERSHIP';
const previousSwitch = process.env[switchName];
process.env[switchName] = 'true';
after(() => {
  if (previousSwitch === undefined) delete process.env[switchName];
  else process.env[switchName] = previousSwitch;
});

const firestore = emulatorFirestore();
const world = createCollectionWorld(firestore, 'd34-flow');

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;
const stableKey = (contentId: string) => `place:${contentId}`;

void test('a Collection of published Places goes draft, cover, submit, approval and publish', async () => {
  const places = await world.members();
  const { pageId } = await world.actors;
  // A replayed create is the same draft (the body is always empty).
  const create = {
    commandType: 'createDraft',
    idempotencyKey: world.key('create-replay'),
    payload: {
      typeId: 'collection',
      publisherRef: { type: 'page', id: pageId },
      marketId: 'LV',
      body: {},
    },
  };
  const first = expectData<{ draftId: string }>(await world.execute(create), 'create');
  assert.deepEqual(expectData(await world.execute(create), 'create replay'), first);

  const collection = await world.publishCollection(await world.boundCollection(places));
  const pointer = await world.pointer(collection.contentId);
  assert.equal(pointer.visibility, 'visible');
  assert.equal(pointer.currentPublishedRevisionId, collection.publishedRevisionId);
  const revision = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(collection.publishedRevisionId),
  );
  assert.ok(revision);
  assert.equal(revision.typeId, 'collection');
  assert.deepEqual(revision.body, collection.body);
  assert.deepEqual(
    (revision.body.items as { ref: { objectId: string } }[]).map((item) => item.ref.objectId),
    places.map((place) => place.contentId),
  );
  assert.deepEqual(
    revision.mediaAttachments.map((item) => item.assetId),
    [collection.cover],
  );
});

void test('membership is the Catalog evaluator’s: hidden and restricted members need acknowledgement', async () => {
  const [hidden, restricted, ready] = await world.members();
  assert.ok(hidden && restricted && ready);
  assert.equal(code(await world.withdraw(hidden.contentId, 1)), 'succeeded');
  expectData(await world.decide('restrict', { contentId: restricted.contentId }), 'restrict');
  const members = [hidden, restricted, ready];

  const unacknowledged = await world.boundCollection(members);
  assert.equal(
    code(await world.submit(unacknowledged.draftId, unacknowledged.revision)),
    'rejected:validation_failed',
  );
  const partly = await world.boundCollection(members, {
    acknowledged: [stableKey(hidden.contentId)],
  });
  assert.equal(
    code(await world.submit(partly.draftId, partly.revision)),
    'rejected:validation_failed',
  );
  const acknowledged = await world.boundCollection(members, {
    acknowledged: [stableKey(hidden.contentId), stableKey(restricted.contentId)],
  });
  assert.equal(code(await world.submit(acknowledged.draftId, acknowledged.revision)), 'succeeded');
});

void test('unknown ids, drafts, other types and Collections are never allowed members', async () => {
  const [one, two] = await world.members(2);
  assert.ok(one && two);
  const draftPlace = await world.boundPlace();
  const otherCollection = await world.emptyCollectionDraft();
  const refused: ReadonlyArray<readonly [string, { contentId: string; objectType?: string }]> = [
    ['unknown id', { contentId: randomUUID() }],
    ['unpublished Place draft', { contentId: draftPlace.contentId }],
    ['a Place asked as Rental', { contentId: one.contentId, objectType: 'rental' }],
    ['a Place asked as Route', { contentId: one.contentId, objectType: 'route' }],
    ['a Collection as Place', { contentId: otherCollection.contentId }],
  ];
  for (const [label, third] of refused) {
    // Even when the author acknowledges it, it is refused.
    const collection = await world.boundCollection([one, two, third], {
      acknowledged: [`${third.objectType ?? 'place'}:${third.contentId}`],
    });
    assert.equal(
      code(await world.submit(collection.draftId, collection.revision)),
      'rejected:validation_failed',
      label,
    );
  }
});

void test('without the local membership switch Collection fails closed', async () => {
  const places = await world.members();
  const collection = await world.boundCollection(places);
  process.env[switchName] = 'false';
  const closed = eventAuthoringComposition(firestore, {
    media: world.media,
    enabledTypes: new Set(['collection'] as const),
  });
  process.env[switchName] = 'true';
  const { creator } = await world.actors;
  const refused = await closed.content.execute(creator.actor, {
    schemaVersion: 1,
    commandType: 'submitForPublication',
    idempotencyKey: world.key('closed-submit'),
    payload: { draftId: collection.draftId, expectedDraftRevision: collection.revision },
  });
  assert.equal(code(refused), 'rejected:validation_failed');
  // With the switch, the same draft is submitted.
  assert.equal(code(await world.submit(collection.draftId, collection.revision)), 'succeeded');
});

void test('publish re-reads membership; hide, decay-tolerant activation and a new revision', async () => {
  const places = await world.members();
  const [first] = places;
  assert.ok(first);
  const collection = await world.boundCollection(places);
  const submission = expectData<{ submissionId: string }>(
    await world.submit(collection.draftId, collection.revision),
    'submit',
  );
  expectData(
    await world.decide('approve', {
      contentId: collection.contentId,
      submissionId: submission.submissionId,
    }),
    'approve',
  );
  // A member hidden after approval: the review acknowledged nothing, publish refuses.
  assert.equal(code(await world.withdraw(first.contentId, 1)), 'succeeded');
  assert.equal(
    code(await world.publishApproved(submission.submissionId, 0)),
    'rejected:validation_failed',
  );
  assert.equal(
    await world.composition.contentRepository.transact((tx) => tx.pointer(collection.contentId)),
    null,
  );
  // Shown again by its owner, the same approved submission publishes.
  assert.equal(
    code(await world.activate(first.contentId, first.publishedRevisionId, 2)),
    'succeeded',
  );
  const published = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submission.submissionId, 0),
    'publish',
  );

  // The owner hides the Collection; a member decays meanwhile; activation still works.
  assert.equal(code(await world.withdraw(collection.contentId, 1)), 'succeeded');
  assert.equal(code(await world.withdraw(first.contentId, 3)), 'succeeded');
  assert.equal(
    code(await world.activate(collection.contentId, published.publishedRevisionId, 2)),
    'succeeded',
  );
  assert.equal((await world.pointer(collection.contentId)).visibility, 'visible');

  // A new revision (now acknowledging the hidden member) switches the pointer.
  const revisedBody = {
    ...collection.body,
    title: 'Quiet corners of central Riga, revised',
    compositionReview: {
      draftRevision: collection.revision + 1,
      reviewedAtUtc: '2026-10-12T09:00:00.000Z',
      acknowledgedUnavailableStableKeys: [stableKey(first.contentId)],
    },
  };
  const revised = expectData<{ revision: number }>(
    await world.update(collection.draftId, collection.revision, revisedBody),
    'revise',
  );
  const resubmitted = expectData<{ submissionId: string }>(
    await world.submit(collection.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: collection.contentId,
      submissionId: resubmitted.submissionId,
    }),
    'reapprove',
  );
  const current = await world.pointer(collection.contentId);
  const republished = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(resubmitted.submissionId, current.revision),
    'republish',
  );
  const switched = await world.pointer(collection.contentId);
  assert.equal(switched.currentPublishedRevisionId, republished.publishedRevisionId);
  assert.equal(switched.previousPublishedRevisionId, published.publishedRevisionId);
});

void test('effects: Catalog excludes the Collection as a disabled type, Discover refuses it, Booking ignores it', async () => {
  const collection = await world.publishCollection(
    await world.boundCollection(await world.members()),
  );
  const catalog = createEmulatorCatalogComposition(firestore);
  const versionsOf = async () =>
    (
      await firestore
        .collection(catalogCollections.versions)
        .where('contentId', '==', collection.contentId)
        .get()
    ).docs.map((doc) => doc.data() as { setId: string; state: string; reason: string });
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const delivered = (await versionsOf()).filter((item) => item.setId === active.setId);
  assert.ok(delivered.length > 0, 'Catalog recorded the Collection');
  for (const item of delivered)
    assert.deepEqual([item.state, item.reason], ['excluded', 'type_disabled']);
  const rebuilt = await catalog.sets.rebuild();
  const activated = await catalog.sets.activate(rebuilt.setId, active.setId);
  assert.equal(activated.ok, true, JSON.stringify(activated));
  const rebuiltVersions = (await versionsOf()).filter((item) => item.setId === rebuilt.setId);
  assert.ok(rebuiltVersions.length > 0);
  for (const item of rebuiltVersions)
    assert.deepEqual([item.state, item.reason], ['excluded', 'type_disabled']);
  const rolledBack = await catalog.sets.rollback(rebuilt.setId);
  assert.equal(rolledBack.ok, true, JSON.stringify(rolledBack));

  const discover = (await catalog.query.feed({
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['collection'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:collection', JSON.stringify(discover));
  // Collection is not itself a relation target either.
  assert.deepEqual(
    await catalog.query.publishedObject({
      typeId: 'place',
      contentId: collection.contentId,
      marketId: 'LV',
    }),
    { status: 'forbidden' },
  );

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', collection.contentId)
    .get();
  assert.ok(!effects.empty);
  for (const effect of effects.docs) {
    const receipt = await repository.transact((tx) => tx.receipt(String(effect.data().effectId)));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(collection.contentId)), null);
});

void test('the exact picker answer comes from the same evaluator: eligible members, withheld hidden ones', async () => {
  const [visible, hidden] = await world.members(2);
  assert.ok(visible && hidden);
  assert.equal(code(await world.withdraw(hidden.contentId, 1)), 'succeeded');
  const catalog = createEmulatorCatalogComposition(firestore);
  const exact = await catalog.query.publishedObject({
    typeId: 'place',
    contentId: visible.contentId,
    marketId: 'LV',
  });
  assert.equal(exact.status, 'eligible');
  assert.deepEqual(
    await catalog.query.publishedObject({
      typeId: 'place',
      contentId: hidden.contentId,
      marketId: 'LV',
    }),
    { status: 'withheld' },
  );
  // Candidate pages are covered by the unit tests: here the shared Emulator
  // holds pointers of every other test file.
});

void test('D2: a restricted Collection cover is suppressed in Content until the publisher activates', async () => {
  const collection = await world.publishCollection(
    await world.boundCollection(await world.members()),
  );
  const cover = collection.cover;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: collection.contentId, assetId: cover });
  assert.ok(await pinOf(), 'the published Collection pins its cover');
  const restricted = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_media', { assetId: cover }),
    'restrict_media',
  );
  const availability = contentMediaAvailability(firestore);
  assert.equal(await availability.reconcileContent(collection.contentId), 'suppressed');
  const suppressed = await world.pointer(collection.contentId);
  assert.deepEqual(
    (suppressed.mediaSuppression ?? []).map((item) => item.assetId),
    [cover],
  );
  assert.equal(await pinOf(), null);
  expectData(
    await world.decide(
      'restore_media',
      { assetId: cover },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'restore_media',
  );
  assert.equal(await pinOf(), null);
  const pointer = await world.pointer(collection.contentId);
  assert.equal(
    code(
      await world.activate(collection.contentId, collection.publishedRevisionId, pointer.revision),
    ),
    'succeeded',
  );
  assert.equal((await world.pointer(collection.contentId)).mediaSuppression, undefined);
  assert.ok(await pinOf());
});
