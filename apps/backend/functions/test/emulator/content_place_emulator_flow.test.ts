// D3.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md §3, §4, §2.3): the Place lifecycle
// on the Firestore and Storage Emulators through the real Content, Media and C2
// moderation services, the Emulator Place reference data, and the effects on
// Catalog (excluded as a disabled type), Discover (refused), Booking (nothing)
// and D2 (a restricted gallery photo).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { revocationEpochOf } from '../../src/modules/media/domain/media_asset.js';
import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { standPlaceBody, standSeedPlace } from '../stand/stand_content_place.js';
import { createPlaceWorld, expectData } from '../support/content_place_world.js';

const firestore = emulatorFirestore();
const world = createPlaceWorld(firestore, 'd31-flow');

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

void test('a Place goes draft, media, submit, approval and publish; a repeated create is the same draft', async () => {
  const { pageId } = await world.actors;
  const create = {
    commandType: 'createDraft',
    idempotencyKey: world.key('create-replay'),
    payload: {
      typeId: 'place',
      publisherRef: { type: 'page', id: pageId },
      marketId: 'LV',
      body: {},
    },
  };
  const first = expectData<{ draftId: string; contentId: string }>(
    await world.execute(create),
    'create',
  );
  const again = expectData<{ draftId: string; contentId: string }>(
    await world.execute(create),
    'create replay',
  );
  assert.deepEqual(again, first);
  const drafts = await firestore
    .collection(contentCollections.drafts)
    .where('contentId', '==', first.contentId)
    .get();
  assert.equal(drafts.size, 1);

  const published = await world.publishedPlace();
  const pointer = await world.pointer(published.contentId);
  assert.equal(pointer.visibility, 'visible');
  assert.equal(pointer.currentPublishedRevisionId, published.publishedRevisionId);
  const revision = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(published.publishedRevisionId),
  );
  assert.ok(revision);
  assert.equal(revision.typeId, 'place');
  assert.deepEqual(
    revision.mediaAttachments.map((item) => item.assetId).sort(),
    [published.cover, ...published.gallery].sort(),
  );
  assert.equal(
    (revision.body.provenance as { submittedByUserId: string }).submittedByUserId,
    published.createdByUserId,
  );
  assert.deepEqual(revision.body, published.body);
});

void test('submit waits until every photo is ready', async () => {
  const { creator, pageId } = await world.actors;
  const draft = await world.emptyDraft();
  const cover = await world.upload(draft.contentId, standSeedPlace.images.cover);
  // An upload session without bytes: the asset is reserved, not ready.
  const reserved = expectData<{ assetId: string }>(
    await world.media.service.execute(creator.actor, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: world.key('reserved'),
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: 70,
        publisherRef: { type: 'page', id: pageId },
        entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
      },
    }),
    'reserve',
  );
  const bound = expectData<{ revision: number }>(
    await world.update(
      draft.draftId,
      draft.revision,
      standPlaceBody({
        submittedByUserId: draft.createdByUserId,
        coverMediaId: cover,
        galleryMediaIds: [reserved.assetId],
      }),
    ),
    'bind',
  );
  assert.equal(code(await world.submit(draft.draftId, bound.revision)), 'rejected:media_not_ready');
});

void test('§2.3: an inapplicable subcategory or a missing required criterion is refused', async () => {
  const inapplicable = await world.boundPlace((body) => ({
    ...body,
    categoryId: 'art_culture_museums',
    subcategoryId: 'artist_talk',
  }));
  assert.equal(
    code(await world.submit(inapplicable.draftId, inapplicable.revision)),
    'rejected:validation_failed',
  );
  const missing = await world.boundPlace((body) => {
    const { criteria, ...rest } = body;
    void criteria;
    return rest;
  });
  assert.equal(
    code(await world.submit(missing.draftId, missing.revision)),
    'rejected:validation_failed',
  );
  // A museum needs no criteria; the park with its criterion is the published case above.
  const museum = await world.boundPlace((body) => {
    const { criteria, ...rest } = body;
    void criteria;
    return { ...rest, categoryId: 'art_culture_museums', subcategoryId: 'museum' };
  });
  assert.equal(code(await world.submit(museum.draftId, museum.revision)), 'succeeded');
});

void test('a rejected revision cannot be published', async () => {
  const place = await world.boundPlace();
  const submission = expectData<{ submissionId: string }>(
    await world.submit(place.draftId, place.revision),
    'submit',
  );
  expectData(
    await world.decide('reject', {
      contentId: place.contentId,
      submissionId: submission.submissionId,
    }),
    'reject',
  );
  const result = await world.publishApproved(submission.submissionId, 0);
  assert.equal(result.kind, 'rejected', JSON.stringify(result));
  // Nothing was ever published: there is no pointer.
  assert.equal(
    await world.composition.contentRepository.transact((tx) => tx.pointer(place.contentId)),
    null,
  );
});

void test('owner hide, re-activation, a new revision, staff restriction and stale revisions', async () => {
  const place = await world.publishedPlace();
  assert.equal(code(await world.withdraw(place.contentId, 1)), 'succeeded');
  assert.equal((await world.pointer(place.contentId)).visibility, 'withdrawn');
  assert.equal(
    code(await world.activate(place.contentId, place.publishedRevisionId, 2)),
    'succeeded',
  );
  assert.equal((await world.pointer(place.contentId)).visibility, 'visible');

  // A new revision through the whole path switches the pointer.
  const revised = expectData<{ revision: number }>(
    await world.update(place.draftId, place.revision, {
      ...place.body,
      title: 'Kronvalda park and pond',
    }),
    'revise',
  );
  // A stale draft revision is refused.
  assert.equal(
    code(await world.update(place.draftId, place.revision, place.body)),
    'rejected:revision_conflict',
  );
  const submission = expectData<{ submissionId: string }>(
    await world.submit(place.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: place.contentId,
      submissionId: submission.submissionId,
    }),
    'reapprove',
  );
  const current = await world.pointer(place.contentId);
  assert.equal(
    code(await world.publishApproved(submission.submissionId, current.revision - 1)),
    'rejected:revision_conflict',
  );
  const republished = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submission.submissionId, current.revision),
    'republish',
  );
  const switched = await world.pointer(place.contentId);
  assert.equal(switched.currentPublishedRevisionId, republished.publishedRevisionId);
  assert.equal(switched.previousPublishedRevisionId, place.publishedRevisionId);

  // Staff restriction takes the Place down.
  expectData(await world.decide('restrict', { contentId: place.contentId }), 'restrict');
  assert.equal((await world.pointer(place.contentId)).visibility, 'restricted');
});

void test('effects: Catalog excludes the Place as a disabled type, Discover refuses it, Booking ignores it', async () => {
  const place = await world.publishedPlace();
  const catalog = createEmulatorCatalogComposition(firestore);
  const versionsOf = async () =>
    (
      await firestore
        .collection(catalogCollections.versions)
        .where('contentId', '==', place.contentId)
        .get()
    ).docs.map((doc) => doc.data() as { setId: string; state: string; reason: string });
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const delivered = (await versionsOf()).filter((item) => item.setId === active.setId);
  assert.ok(delivered.length > 0, 'Catalog recorded the Place');
  for (const item of delivered)
    assert.deepEqual([item.state, item.reason], ['excluded', 'type_disabled']);

  // Rebuild, activation and rollback keep the exclusion.
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
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['place'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:place', JSON.stringify(discover));

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', place.contentId)
    .get();
  assert.ok(!effects.empty);
  for (const effect of effects.docs) {
    const receipt = await repository.transact((tx) => tx.receipt(String(effect.data().effectId)));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(place.contentId)), null);
});

void test('D2: a restricted gallery photo is refused at once and suppressed only in Content', async () => {
  const place = await world.publishedPlace();
  const photo = place.gallery[0] as string;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: place.contentId, assetId: photo });
  const assetOf = async () => {
    const asset = await world.media.repository.transact((tx) => tx.asset(photo));
    assert.ok(asset);
    return asset;
  };
  const before = await pinOf();
  assert.ok(before, 'the published Place pins its gallery photo');
  assert.equal(revocationEpochOf(await assetOf()), before.revocationEpoch);

  const restricted = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_media', { assetId: photo }),
    'restrict_media',
  );
  // Content has not reacted yet: its pin is unchanged, Media's own record refuses.
  const stale = await pinOf();
  assert.ok(stale);
  const asset = await assetOf();
  assert.ok(asset.deliveryDisabled || revocationEpochOf(asset) !== stale.revocationEpoch);
  const wire = await world.media.delivery.deliver({
    contentId: place.contentId,
    assetId: photo,
    profile: 'display',
  });
  assert.equal(code(wire), 'rejected:not_found');

  const availability = contentMediaAvailability(firestore);
  assert.equal(await availability.reconcileContent(place.contentId), 'suppressed');
  const suppressed = await world.pointer(place.contentId);
  assert.deepEqual(
    (suppressed.mediaSuppression ?? []).map((item) => item.assetId),
    [photo],
  );
  assert.equal(suppressed.visibility, 'visible');
  assert.equal(await pinOf(), null);

  // Lifting the restriction does not lift the suppression; the publisher's activation does.
  expectData(
    await world.decide(
      'restore_media',
      { assetId: photo },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'restore_media',
  );
  assert.equal(await pinOf(), null);
  const pointer = await world.pointer(place.contentId);
  assert.equal(
    code(await world.activate(place.contentId, place.publishedRevisionId, pointer.revision)),
    'succeeded',
  );
  assert.equal((await world.pointer(place.contentId)).mediaSuppression, undefined);
  assert.ok(await pinOf());
});
