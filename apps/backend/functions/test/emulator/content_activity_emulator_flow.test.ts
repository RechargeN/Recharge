// D3.2 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md §3, §4, §2.3, §2.4): the Recharge
// Activity lifecycle on the Firestore and Storage Emulators through the real
// Content, Media and C2 moderation services, the Emulator Activity reference
// data and composition rules, and the effects on Catalog (excluded as a
// disabled type), Discover (refused), Booking (nothing) and D2 (a restricted
// gallery photo).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { revocationEpochOf } from '../../src/modules/media/domain/media_asset.js';
import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { standActivityBody, standSeedActivity } from '../stand/stand_content_activity.js';
import { createActivityWorld, expectData } from '../support/content_activity_world.js';

const firestore = emulatorFirestore();
const world = createActivityWorld(firestore, 'd32-flow');

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

void test('an Activity goes draft, media, submit, approval and publish; a repeated create is the same draft', async () => {
  const { pageId } = await world.actors;
  const create = {
    commandType: 'createDraft',
    idempotencyKey: world.key('create-replay'),
    payload: {
      typeId: 'activity',
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

  const published = await world.publishedActivity();
  const pointer = await world.pointer(published.contentId);
  assert.equal(pointer.visibility, 'visible');
  assert.equal(pointer.currentPublishedRevisionId, published.publishedRevisionId);
  const revision = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(published.publishedRevisionId),
  );
  assert.ok(revision);
  assert.equal(revision.typeId, 'activity');
  assert.deepEqual(
    revision.mediaAttachments.map((item) => item.assetId).sort(),
    [published.cover, ...published.gallery].sort(),
  );
  assert.deepEqual(revision.body, published.body);
});

void test('submit waits until every photo is ready', async () => {
  const { creator, pageId } = await world.actors;
  const draft = await world.emptyDraft();
  const cover = await world.upload(draft.contentId, standSeedActivity.images.cover);
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
      standActivityBody({ coverMediaId: cover, galleryMediaIds: [reserved.assetId] }),
    ),
    'bind',
  );
  assert.equal(code(await world.submit(draft.draftId, bound.revision)), 'rejected:media_not_ready');
});

void test('§2.3: an inapplicable subcategory or a missing required criterion is refused', async () => {
  const inapplicable = await world.boundActivity((body) => ({
    ...body,
    categoryId: 'wellness_recharge',
    subcategoryId: 'sauna',
    criteria: {},
  }));
  assert.equal(
    code(await world.submit(inapplicable.draftId, inapplicable.revision)),
    'rejected:validation_failed',
  );
  const missing = await world.boundActivity((body) => ({
    ...body,
    subcategoryId: 'sunset_walk',
    criteria: {},
  }));
  assert.equal(
    code(await world.submit(missing.draftId, missing.revision)),
    'rejected:validation_failed',
  );
  // Meditation needs no criteria; the forest walk with its criterion is the published case.
  const meditation = await world.boundActivity((body) => {
    const { criteria, ...rest } = body;
    void criteria;
    return { ...rest, categoryId: 'wellness_recharge', subcategoryId: 'meditation' };
  });
  assert.equal(code(await world.submit(meditation.draftId, meditation.revision)), 'succeeded');
});

void test('§2.4: a linked Place fails closed; the same Activity without it is accepted', async () => {
  const linked = await world.boundActivity((body) => ({
    ...body,
    location: {
      ...(body.location as Record<string, unknown>),
      linkedPlaceId: '01HZZZZZZZZZZZZZZZZZZZZZZZ',
    },
  }));
  assert.equal(
    code(await world.submit(linked.draftId, linked.revision)),
    'rejected:validation_failed',
  );
  const unlinked = expectData<{ revision: number }>(
    await world.update(
      linked.draftId,
      linked.revision,
      standActivityBody({ coverMediaId: linked.cover, galleryMediaIds: linked.gallery }),
    ),
    'unlink',
  );
  assert.equal(code(await world.submit(linked.draftId, unlinked.revision)), 'succeeded');
});

void test('a rejected revision cannot be published', async () => {
  const activity = await world.boundActivity();
  const submission = expectData<{ submissionId: string }>(
    await world.submit(activity.draftId, activity.revision),
    'submit',
  );
  expectData(
    await world.decide('reject', {
      contentId: activity.contentId,
      submissionId: submission.submissionId,
    }),
    'reject',
  );
  const result = await world.publishApproved(submission.submissionId, 0);
  assert.equal(result.kind, 'rejected', JSON.stringify(result));
  // Nothing was ever published: there is no pointer.
  assert.equal(
    await world.composition.contentRepository.transact((tx) => tx.pointer(activity.contentId)),
    null,
  );
});

void test('owner hide, re-activation, a new revision, staff restriction and stale revisions', async () => {
  const activity = await world.publishedActivity();
  assert.equal(code(await world.withdraw(activity.contentId, 1)), 'succeeded');
  assert.equal((await world.pointer(activity.contentId)).visibility, 'withdrawn');
  assert.equal(
    code(await world.activate(activity.contentId, activity.publishedRevisionId, 2)),
    'succeeded',
  );
  assert.equal((await world.pointer(activity.contentId)).visibility, 'visible');

  // A new revision through the whole path switches the pointer.
  const revised = expectData<{ revision: number }>(
    await world.update(activity.draftId, activity.revision, {
      ...activity.body,
      title: 'Ķemeri bog boardwalk long loop',
    }),
    'revise',
  );
  // A stale draft revision is refused.
  assert.equal(
    code(await world.update(activity.draftId, activity.revision, activity.body)),
    'rejected:revision_conflict',
  );
  const submission = expectData<{ submissionId: string }>(
    await world.submit(activity.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: activity.contentId,
      submissionId: submission.submissionId,
    }),
    'reapprove',
  );
  const current = await world.pointer(activity.contentId);
  assert.equal(
    code(await world.publishApproved(submission.submissionId, current.revision - 1)),
    'rejected:revision_conflict',
  );
  const republished = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submission.submissionId, current.revision),
    'republish',
  );
  const switched = await world.pointer(activity.contentId);
  assert.equal(switched.currentPublishedRevisionId, republished.publishedRevisionId);
  assert.equal(switched.previousPublishedRevisionId, activity.publishedRevisionId);

  // Staff restriction takes the Activity down.
  expectData(await world.decide('restrict', { contentId: activity.contentId }), 'restrict');
  assert.equal((await world.pointer(activity.contentId)).visibility, 'restricted');
});

void test('effects: Catalog excludes the Activity as a disabled type, Discover refuses it, Booking ignores it', async () => {
  const activity = await world.publishedActivity();
  const catalog = createEmulatorCatalogComposition(firestore);
  const versionsOf = async () =>
    (
      await firestore
        .collection(catalogCollections.versions)
        .where('contentId', '==', activity.contentId)
        .get()
    ).docs.map((doc) => doc.data() as { setId: string; state: string; reason: string });
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const delivered = (await versionsOf()).filter((item) => item.setId === active.setId);
  assert.ok(delivered.length > 0, 'Catalog recorded the Activity');
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
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['activity'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:activity', JSON.stringify(discover));

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', activity.contentId)
    .get();
  assert.ok(!effects.empty);
  for (const effect of effects.docs) {
    const receipt = await repository.transact((tx) => tx.receipt(String(effect.data().effectId)));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(activity.contentId)), null);
});

void test('D2: a restricted gallery photo is refused at once and suppressed only in Content', async () => {
  const activity = await world.publishedActivity();
  const photo = activity.gallery[0] as string;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: activity.contentId, assetId: photo });
  const assetOf = async () => {
    const asset = await world.media.repository.transact((tx) => tx.asset(photo));
    assert.ok(asset);
    return asset;
  };
  const before = await pinOf();
  assert.ok(before, 'the published Activity pins its gallery photo');
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
    contentId: activity.contentId,
    assetId: photo,
    profile: 'display',
  });
  assert.equal(code(wire), 'rejected:not_found');

  const availability = contentMediaAvailability(firestore);
  assert.equal(await availability.reconcileContent(activity.contentId), 'suppressed');
  const suppressed = await world.pointer(activity.contentId);
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
  const pointer = await world.pointer(activity.contentId);
  assert.equal(
    code(await world.activate(activity.contentId, activity.publishedRevisionId, pointer.revision)),
    'succeeded',
  );
  assert.equal((await world.pointer(activity.contentId)).mediaSuppression, undefined);
  assert.ok(await pinOf());
});
