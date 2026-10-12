import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { CatalogQueryService } from '../../src/modules/catalog/application/catalog_query_service.js';
import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createPlaceWorld } from '../support/content_place_world.js';
import { createActivityWorld, expectData } from '../support/content_activity_world.js';
const firestore = emulatorFirestore();
const world = createActivityWorld(firestore, 'activity-catalog');
const environment = { ...process.env, RECHARGE_TEST_ACTIVITY_CATALOG: 'true' };
const catalog = createEmulatorCatalogComposition(firestore, { environment });
const query = { schemaVersion: 1, marketId: 'LV', typeIds: ['activity'] };
void test('Activity Catalog real lifecycle, D2, replay/rebuild/rollback and kill switch', async () => {
  const activity = await world.publishedActivity((body) => ({
    ...body,
    optionalContribution: {
      kind: 'donation',
      note: 'Optional donation to the local group',
      amountHint: { amountMinor: 250, currencyCode: 'EUR' },
    },
  }));
  const active = await catalog.sets.ensureActive();
  assert.equal((await catalog.projector.deliverFromContent(active.setId)).synced, true);
  const initial = await catalog.query.feed({ query });
  assert.equal(initial.kind, 'succeeded');
  if (initial.kind !== 'succeeded') throw new Error('feed refused');
  const card = initial.items.find((i) => i.ref.contentId === activity.contentId);
  assert.ok(card && 'typeId' in card && card.typeId === 'activity');
  assert.equal(card.publishedRevisionId, activity.publishedRevisionId);
  assert.deepEqual(card.typicalDurationMinutes, { min: 60, max: 120 });
  const map = await catalog.query.map({ query, snapshotToken: initial.snapshotToken });
  assert.ok(map.kind === 'succeeded');
  assert.ok(
    map.leaves.some((i) => i.ref.contentId === activity.contentId && i.ref.typeId === 'activity'),
  );
  const search = await catalog.query.feed({ query: { ...query, literalText: 'Ķemeri' } });
  assert.ok(search.kind === 'succeeded');
  assert.ok(search.items.some((i) => i.ref.contentId === activity.contentId));
  const original = await catalog.query.details({ contentId: activity.contentId });
  assert.ok(original.kind === 'succeeded' && original.item?.typeId === 'activity');
  const photo = activity.gallery[0]!;
  const restriction = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_media', { assetId: photo }),
    'restrict',
  );
  await contentMediaAvailability(firestore).reconcileContent(activity.contentId);
  await catalog.projector.deliverFromContent(active.setId);
  const check = async () => {
    const details = await catalog.query.details({ contentId: activity.contentId });
    assert.ok(details.kind === 'succeeded' && details.item?.typeId === 'activity');
    assert.equal(details.item.galleryMediaIds.includes(photo), false);
  };
  await check();
  const oldSnapshot = await catalog.query.feed({ query, snapshotToken: initial.snapshotToken });
  assert.ok(oldSnapshot.kind === 'succeeded');
  const oldCard = oldSnapshot.items.find((i) => i.ref.contentId === activity.contentId);
  assert.ok(oldCard && 'galleryMediaIds' in oldCard);
  assert.equal(oldCard.galleryMediaIds.includes(photo), false);
  const facts = await catalog.source.effectsForContent(activity.contentId, null, 100);
  assert.ok(facts.length >= 2);
  assert.equal(
    (await catalog.projector.consumeContentFact(active.setId, facts.at(-1)!)).outcome,
    'deduped',
  );
  assert.equal(
    (
      await catalog.projector.consumeContentFact(active.setId, {
        ...facts[0]!,
        effectId: 'old-replay-' + activity.contentId,
      })
    ).outcome,
    'stale',
  );
  await check();
  const rebuild = await catalog.sets.rebuild();
  assert.equal(rebuild.report.complete, true);
  assert.equal((await catalog.sets.activate(rebuild.setId, active.setId)).ok, true);
  await check();
  expectData(
    await world.decide(
      'restore_media',
      { assetId: photo },
      { restoresDecisionId: restriction.decision.decisionId },
    ),
    'restore',
  );
  await contentMediaAvailability(firestore).reconcileContent(activity.contentId);
  await catalog.projector.deliverFromContent(rebuild.setId);
  await check();
  assert.equal((await catalog.sets.rollback(rebuild.setId)).ok, true);
  await check();
  const pointer = await world.pointer(activity.contentId);
  expectData(
    await world.activate(activity.contentId, activity.publishedRevisionId, pointer.revision),
    'activate',
  );
  await catalog.projector.deliverFromContent(active.setId);
  const restored = await catalog.query.details({ contentId: activity.contentId });
  assert.ok(restored.kind === 'succeeded' && restored.item?.typeId === 'activity');
  assert.equal(restored.item.galleryMediaIds.includes(photo), true);
  const disabled = createEmulatorCatalogComposition(firestore, {
    environment: { ...environment, RECHARGE_TEST_ACTIVITY_CATALOG: 'false' },
  });
  assert.deepEqual(await disabled.query.details({ contentId: activity.contentId }), {
    kind: 'unsupported',
    code: 'type_disabled:activity',
  });
  const noTaxonomy = new CatalogQueryService(
    catalog.repository,
    { current: () => Promise.resolve(null) },
    { now: () => new Date() },
    true,
  );
  assert.deepEqual(await noTaxonomy.details({ contentId: activity.contentId }), {
    kind: 'unavailable',
    code: 'taxonomy_revision_unavailable',
  });
  const now = await world.pointer(activity.contentId);
  expectData(await world.withdraw(activity.contentId, now.revision), 'withdraw');
  await catalog.projector.deliverFromContent(active.setId);
  const hidden = await catalog.query.details({ contentId: activity.contentId });
  assert.ok(hidden.kind === 'succeeded');
  assert.equal(hidden.item, null);
});

void test('linked Place uses Catalog authority and fresh reads omit hidden relations across snapshots and rebuild', async () => {
  const previous = process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE;
  process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE = 'true';
  try {
    const places = createPlaceWorld(firestore, 'linked-catalog-place');
    const activities = createActivityWorld(firestore, 'linked-catalog-activity');
    const linkedCatalog = createEmulatorCatalogComposition(firestore, {
      environment: { ...environment, RECHARGE_TEST_ACTIVITY_LINKED_PLACE: 'true' },
    });
    const place = await places.publishedPlace();
    const activity = await activities.publishedActivity((body) => ({
      ...body,
      location: { ...(body.location as Record<string, unknown>), linkedPlaceId: place.contentId },
    }));
    const active = await linkedCatalog.sets.ensureActive();
    await linkedCatalog.projector.deliverFromContent(active.setId);
    const initial = await linkedCatalog.query.feed({ query });
    assert.ok(initial.kind === 'succeeded');
    let snapshotToken = initial.snapshotToken;
    const check = async (visible: boolean) => {
      const details = await linkedCatalog.query.details({ contentId: activity.contentId });
      assert.ok(details.kind === 'succeeded' && details.item?.typeId === 'activity');
      assert.equal(details.item.linkedPlace?.contentId, visible ? place.contentId : undefined);
      assert.equal('linkedPlaceId' in details.item, false);
      assert.equal(
        details.item.point.latitude,
        (activity.body.location as Record<string, unknown>).latitude,
      );
      assert.equal(
        details.item.point.longitude,
        (activity.body.location as Record<string, unknown>).longitude,
      );
      const feed = await linkedCatalog.query.feed({ query, snapshotToken });
      assert.ok(feed.kind === 'succeeded');
      const card = feed.items.find((i) => i.ref.contentId === activity.contentId);
      assert.ok(card && 'typeId' in card && card.typeId === 'activity');
      assert.equal(card.linkedPlace?.contentId, visible ? place.contentId : undefined);
      assert.equal('linkedPlaceId' in card, false);
    };
    await check(true);
    const before = await places.pointer(place.contentId);
    expectData(await places.withdraw(place.contentId, before.revision), 'hide Place');
    await check(false);
    const activityPointer = await activities.pointer(activity.contentId);
    const refused = await activities.activate(
      activity.contentId,
      activity.publishedRevisionId,
      activityPointer.revision,
    );
    assert.equal(refused.kind, 'rejected');
    assert.deepEqual(await activities.pointer(activity.contentId), activityPointer);
    const rebuilt = await linkedCatalog.sets.rebuild();
    assert.equal(rebuilt.report.complete, true);
    assert.equal((await linkedCatalog.sets.activate(rebuilt.setId, active.setId)).ok, true);
    assert.deepEqual(await linkedCatalog.query.feed({ query, snapshotToken }), {
      kind: 'stale',
      code: 'snapshot_superseded',
    });
    const refreshed = await linkedCatalog.query.feed({ query });
    assert.ok(refreshed.kind === 'succeeded');
    snapshotToken = refreshed.snapshotToken;
    await check(false);
    assert.equal((await linkedCatalog.sets.rollback(rebuilt.setId)).ok, true);
    const rolledBack = await linkedCatalog.query.feed({ query });
    assert.ok(rolledBack.kind === 'succeeded');
    snapshotToken = rolledBack.snapshotToken;
    await check(false);
    const hidden = await places.pointer(place.contentId);
    expectData(
      await places.activate(place.contentId, place.publishedRevisionId, hidden.revision),
      'restore Place',
    );
    await check(true);
    assert.deepEqual(await activities.pointer(activity.contentId), activityPointer);
  } finally {
    if (previous === undefined) delete process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE;
    else process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE = previous;
  }
});
