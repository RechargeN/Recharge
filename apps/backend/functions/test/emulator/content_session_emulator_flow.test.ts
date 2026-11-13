import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { PublishedObjectLinkService } from '../../src/modules/catalog/application/published_object_link_service.js';
import { randomUUID } from 'node:crypto';
import { revocationEpochOf } from '../../src/modules/media/domain/media_asset.js';
import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createSessionWorld, expectData } from '../support/content_session_world.js';
const code = (r: { kind: string; code?: string }) =>
  r.kind === 'succeeded' ? 'succeeded' : `${r.kind}:${String(r.code)}`;
const firestore = emulatorFirestore();
const world = createSessionWorld(firestore, 'd35-flow', { enabledTypes: new Set(['session']) });
after(() => world.cleanup());
void test('Session through real Media, C2 review, publish, owner hide and immutable activate', async () => {
  const d = await world.boundSession();
  const sub = expectData<{ submissionId: string }>(
    await world.submit(d.draftId, d.revision),
    'submit',
  );
  const denied = await world.publishApproved(sub.submissionId, 0);
  assert.notEqual(denied.kind, 'succeeded');
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
  assert.equal(original.typeId, 'session');
  assert.deepEqual(original.body, d.body);
  assert.equal(original.mediaAttachments.length, 3);
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

  assert.deepEqual(
    await world.composition.contentRepository.transact((tx) =>
      tx.publishedRevision(published.publishedRevisionId),
    ),
    original,
  );
});
void test('Session raw forbidden legacy/Booking payload refuses submission without publication', async () => {
  for (const field of ['eventSlots', 'capacity', 'confirmed', 'hold', 'availability', 'offers']) {
    const d = await world.boundSession((body) => ({ ...body, [field]: [] }));
    const result = await world.submit(d.draftId, d.revision);
    assert.equal(result.code, 'validation_failed', field);
    assert.equal(
      await world.composition.contentRepository.transact((tx) => tx.pointer(d.contentId)),
      null,
    );
  }
});

void test('new Session schedule sequence stays monotonic after activating an older immutable revision', async () => {
  const first = await world.publishedSession();
  const revised = structuredClone(first.body);
  const data = revised.session as Record<string, unknown>;
  data.schedule = {
    ...(data.schedule as Record<string, unknown>),
    slot_duration_minutes: 90,
    schedule_revision: 2,
  };
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
  expectData(
    await world.activate(first.contentId, first.publishedRevisionId, v2.revision),
    'rollback',
  );
  const target = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(first.publishedRevisionId),
  );
  assert.equal(
    ((target!.body.session as Record<string, unknown>).schedule as Record<string, unknown>)
      .schedule_revision,
    1,
  );
  const stale = structuredClone(revised);
  const sd = stale.session as Record<string, unknown>;
  sd.schedule = { ...(sd.schedule as Record<string, unknown>), slot_duration_minutes: 120 };
  const bad = expectData<{ revision: number }>(
    await world.update(first.draftId, updated.revision, stale),
    'candidate',
  );
  assert.equal((await world.submit(first.draftId, bad.revision)).code, 'source_revision_stale');
  sd.schedule = { ...(sd.schedule as Record<string, unknown>), schedule_revision: 3 };
  const good = expectData<{ revision: number }>(
    await world.update(first.draftId, bad.revision, stale),
    'candidate v3',
  );
  expectData(await world.submit(first.draftId, good.revision), 'submit v3');
});
void test('Collection evaluator returns only allowlisted Session facts and refuses hidden targets', async () => {
  const { creator } = await world.actors;
  const d = await world.boundSession((body) => {
    const session = body.session as Record<string, unknown>;
    return {
      ...body,
      session: {
        ...session,
        exceptions: [
          {
            id: randomUUID(),
            start_date_local: '2026-10-25',
            end_date_local: '2026-10-25',
            all_day: true,
            private_note: 'private operational reason',
            created_by_user_id: creator.actor.userId,
            created_at_utc: '2026-10-18T00:00:00.000Z',
          },
        ],
      },
    };
  });
  const sub = expectData<{ submissionId: string }>(
    await world.submit(d.draftId, d.revision),
    'submit',
  );
  expectData(
    await world.decide('approve', { contentId: d.contentId, submissionId: sub.submissionId }),
    'approve',
  );
  expectData(await world.publishApproved(sub.submissionId, 0), 'publish');
  const catalog = createEmulatorCatalogComposition(firestore);
  const evaluator = new PublishedObjectLinkService(catalog.source, true);
  const input = { typeId: 'session' as const, contentId: d.contentId, marketId: 'LV' };
  const result = await evaluator.status(input, true);
  assert.equal(result.status, 'eligible');
  for (const forbidden of [
    'private operational reason',
    'private_note',
    'created_by_user_id',
    'created_at_utc',
    'exceptions',
    'external_booking_url',
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

void test('D2: a restricted gallery photo is refused at once and suppressed only in Content', async () => {
  const session = await world.publishedSession();
  const photo = session.gallery[0] as string;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: session.contentId, assetId: photo });
  const assetOf = async () => {
    const asset = await world.media.repository.transact((tx) => tx.asset(photo));
    assert.ok(asset);
    return asset;
  };
  const before = await pinOf();
  assert.ok(before, 'the published Session pins its gallery photo');
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
    contentId: session.contentId,
    assetId: photo,
    profile: 'display',
  });
  assert.equal(code(wire), 'rejected:not_found');

  const availability = contentMediaAvailability(firestore);
  assert.equal(await availability.reconcileContent(session.contentId), 'suppressed');
  const suppressed = await world.pointer(session.contentId);
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
  const pointer = await world.pointer(session.contentId);
  assert.equal(
    code(await world.activate(session.contentId, session.publishedRevisionId, pointer.revision)),
    'succeeded',
  );
  assert.equal((await world.pointer(session.contentId)).mediaSuppression, undefined);
  assert.ok(await pinOf());
});

void test('Session stays excluded from Discover and creates no Booking authority through owner delivery', async () => {
  const session = await world.publishedSession();
  const catalog = createEmulatorCatalogComposition(firestore);
  const discover = (await catalog.query.feed({
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['session'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:session', JSON.stringify(discover));
  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', session.contentId)
    .get();
  assert.ok(!effects.empty);
  for (const effect of effects.docs) {
    const receipt = await repository.transact((tx) => tx.receipt(String(effect.data().effectId)));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(session.contentId)), null);
});
