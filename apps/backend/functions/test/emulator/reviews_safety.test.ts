import { eventAuthoringComposition } from '../../src/content_entry.js';
import { standEventBody } from '../stand/stand_content.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { seedEvent } from '../support/booking_emulator.js';
import { createContentEventWorld } from '../support/content_event_world.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { deliverContentEffects, catalogEffectConsumer } from '../../src/content_effects_entry.js';
import { catalogFlagIds } from '../../src/shared/feature_flags.js';
import type { Transaction } from 'firebase-admin/firestore';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { before, after, test } from 'node:test';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { cleanupContentEmulatorState } from '../support/content_emulator_cleanup.js';
import { k1Collections } from '../../src/modules/moderation/application/k1_workflows.js';
import { createPublishingActors, type PublishingActor } from '../support/content_event_world.js';
import { setLocalFlag } from '../support/notifications_world.js';
import { createK1 } from '../../src/moderation_entry.js';
import { handleK2 } from '../../src/safety_entry.js';
import { FirestoreReviewService } from '../../src/modules/reviews/firestore_review_service.js';
import { reviewCollections as rc } from '../../src/modules/reviews/review_policy.js';
import { FirestoreSafetyService } from '../../src/modules/trust_safety/firestore_safety_service.js';
import {
  safetyCollections as sc,
  safetyPolicyRevision,
} from '../../src/modules/trust_safety/safety_policy.js';
import { applyBookingSafety } from '../../src/booking/booking_safety_commands.js';
import { safetyRestricted, type SafetyInstruction } from '../../src/shared/safety_instruction.js';
import { relationEffects, interactionAllowed } from '../../src/shared/safety_visibility.js';
import { contentCollections as cc } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { reviewBookingEvidence } from '../../src/booking/review_eligibility.js';
const db = emulatorFirestore();
const now = new Date();
const clock = { now: () => new Date(now) };
const h = new FirestoreReviewService(db, clock),
  k1 = createK1(db, clock);
const k2 = new FirestoreSafetyService(db, clock, k1.workflows);
let a: Awaited<ReturnType<typeof createPublishingActors>>,
  b: Awaited<ReturnType<typeof createPublishingActors>>;
const place = randomUUID(),
  event = randomUUID(),
  activity = randomUUID();
let reviewId: string = randomUUID();
const hint = (p: PublishingActor) => ({
  firebaseUid: p.firebaseUid,
  sessionId: p.actor.sessionId,
  sessionHandle: p.sessionHandle,
  installationId: p.installationId,
});
const command = (contentId = place, extra: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  requestId: randomUUID(),
  operation: 'submit',
  reviewId: randomUUID(),
  contentId,
  expectedRevision: 0,
  idempotencyKey: randomUUID(),
  rating: 5,
  text: 'Synthetic review',
  ...extra,
});
async function source(contentId: string, typeId: string) {
  const id = randomUUID(),
    body = { title: 'Synthetic ' + typeId, visibility: 'public' };
  // Synthetic source-owner snapshots only. Clients remain default-denied.
  await db
    .collection(cc.pointers)
    .doc(contentId)
    .set({ contentId, revision: 1, visibility: 'visible', currentPublishedRevisionId: id });
  await db
    .collection(cc.publishedRevisions)
    .doc(id)
    .set({
      publishedRevisionId: id,
      contentId,
      typeId,
      marketId: 'LV',
      publisherRef: { type: 'page', id: a.pageId },
      body,
      bodyHash: sha256Hex(canonicalJson(body)),
    });
}
const ownedCollections = [
  ...Object.values(rc),
  ...Object.values(sc),
  ...Object.values(k1Collections),
  'contentSafetyHolds',
  'catalogSafetyHolds',
  'bookingSafetyHolds',
];
before(async () => {
  await cleanupContentEmulatorState(db, ownedCollections);
  for (const flag of [
    'reviews.runtime',
    'trustSafety.runtime',
    'moderation.staff',
    'trustSafety.reports',
  ])
    await setLocalFlag(db, flag, true);
  a = await createPublishingActors(db, 'hk-a-' + randomUUID());
  b = await createPublishingActors(db, 'hk-b-' + randomUUID());
  const expiry = new Date(now.getTime() + 3600000).toISOString();
  for (const actor of [a.staff, b.staff])
    await k1.staff.grantScoped(
      actor.actor.userId,
      ['event', 'place', 'activity', 'user'].map((typeId) => ({
        marketId: 'LV',
        typeId,
        actions: ['sanction', 'appeal', 'moderateReview', 'triage'],
      })),
      expiry,
      now.toISOString(),
    );
  await db.collection(sc.authority).doc('owner').set({ userId: a.staff.actor.userId });
  await db
    .collection(sc.authority)
    .doc('abusePolicy')
    .set({ policyRevision: safetyPolicyRevision, maxPerMinute: 30 });
  await source(place, 'place');
  await source(event, 'event');
  await source(activity, 'activity');
});
// Published Content, Catalog projections and handoff facts must not leak into later groups.
after(() => cleanupContentEmulatorState(db, ownedCollections));
void test('H default-off, ownership and unsupported evidence are denied', async () => {
  await setLocalFlag(db, 'reviews.runtime', false);
  assert.equal((await h.command(hint(b.creator), command())).kind, 'rejected');
  await setLocalFlag(db, 'reviews.runtime', true);
  assert.equal((await h.command(hint(a.creator), command())).kind, 'rejected');
  for (const id of [event, activity])
    assert.equal((await h.command(hint(b.creator), command(id))).kind, 'rejected');
  // Self-reported visits are not consulted as evidence.
  await db
    .collection('libraryEntries')
    .doc(randomUUID())
    .set({ ownerId: b.creator.actor.userId, objectId: event, evidence: 'selfReported' });
  assert.equal((await h.command(hint(b.creator), command(event))).kind, 'rejected');
});
void test('H Booking owner grants eligibility only after start with a live noncancelled booking', async () => {
  const bookingId = randomUUID(),
    occurrenceId = randomUUID();
  await db.collection('bookings').doc(bookingId).set({
    userId: b.creator.actor.userId,
    eventId: event,
    occurrenceId,
    state: 'confirmed',
    reconfirmationState: 'notRequired',
  });
  const ref = db.collection('bookingEventProjections').doc(occurrenceId);
  await ref.set({
    eventId: event,
    occurrenceId,
    marketId: 'LV',
    lifecycle: 'published',
    occurrenceStartsAt: new Date(now.getTime() + 60000).toISOString(),
  });
  assert.equal((await h.command(hint(b.creator), command(event))).kind, 'rejected');
  await ref.update({ occurrenceStartsAt: new Date(now.getTime() - 60000).toISOString() });
  const result = await h.command(hint(b.creator), command(event));
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  if (result.kind === 'succeeded')
    assert.equal((result.data.review as Record<string, unknown>).verified, false);
  await db.collection('bookings').doc(bookingId).update({ state: 'cancelled' });
  assert.equal(
    await db.runTransaction((tx) =>
      reviewBookingEvidence(db, tx, b.creator.actor.userId, event, 'event', now),
    ),
    null,
  );
});
void test('H concurrent one-per-target, retry semantics, edit/delete and deterministic rebuild', async () => {
  const c = command(place, { reviewId }),
    d = command();
  const results = await Promise.all([h.command(hint(b.creator), c), h.command(hint(b.creator), d)]);
  assert.equal(results.filter((r) => r.kind === 'succeeded').length, 1);
  const winner = results[0].kind === 'succeeded' ? c : d;
  reviewId = winner.reviewId;
  assert.deepEqual(
    await h.command(hint(b.creator), { ...winner, requestId: randomUUID() }),
    results.find((r) => r.kind === 'succeeded'),
  );
  assert.equal((await h.command(hint(b.creator), { ...winner, rating: 1 })).kind, 'rejected');
  const edit = await h.command(
    hint(b.creator),
    command(place, { operation: 'edit', reviewId, expectedRevision: 1, rating: 2 }),
  );
  assert.equal(edit.kind, 'succeeded', JSON.stringify(edit));
  assert.equal(
    (
      await h.command(
        hint(a.creator),
        command(place, {
          operation: 'delete',
          reviewId,
          expectedRevision: 2,
          rating: undefined,
          text: undefined,
        }),
      )
    ).kind,
    'rejected',
  );
  const first = await h.rebuild(place),
    second = await h.rebuild(place);
  assert.deepEqual(first, second);
  const deleted = await h.command(hint(b.creator), {
    schemaVersion: 1,
    requestId: randomUUID(),
    operation: 'delete',
    reviewId,
    contentId: place,
    expectedRevision: 2,
    idempotencyKey: randomUUID(),
  });
  assert.equal(deleted.kind, 'succeeded', JSON.stringify(deleted));
  assert.equal((await h.command(hint(b.creator), command())).kind, 'rejected');
  assert.equal(
    (await h.command(hint(b.creator), command(place, { reviewId, expectedRevision: 3 }))).kind,
    'succeeded',
  );
});
void test('H threshold, exact-revision moderation, report routing and restore preserve projection', async () => {
  for (const actor of [a.staff, b.staff])
    assert.equal((await h.command(hint(actor), command())).kind, 'succeeded');
  const projection = (await db.collection(rc.projections).doc(place).get()).data()!;
  assert.equal(projection.count, 3);
  assert.equal(projection.averageScaled, 5000);
  const row = (await db.collection(rc.reviews).doc(reviewId).get()).data() as { revision: number };
  const report = {
    schemaVersion: 1,
    requestId: randomUUID(),
    reportId: randomUUID(),
    idempotencyKey: randomUUID(),
    target: { reviewId, reviewRevision: row.revision },
    reasonCode: 'spam',
  };
  assert.equal((await k1.reports.submit(hint(a.staff), report)).kind, 'succeeded');
  assert.equal((await db.collection(rc.projections).doc(place).get()).get('count'), 3);
  const hide = {
    reviewId,
    expectedRevision: row.revision,
    decisionId: randomUUID(),
    action: 'hide',
    reason: 'Synthetic review moderation',
    idempotencyKey: randomUUID(),
  };
  assert.equal(
    (await h.moderate(a.staff.actor, k1.workflows, { ...hide, expectedRevision: 1 })).kind,
    'rejected',
  );
  assert.equal((await h.moderate(a.staff.actor, k1.workflows, hide)).kind, 'succeeded');
  assert.equal((await db.collection(rc.projections).doc(place).get()).get('averageScaled'), null);
  assert.equal(
    (
      await k1.reports.submit(hint(a.staff), {
        ...report,
        reportId: randomUUID(),
        idempotencyKey: randomUUID(),
      })
    ).kind,
    'rejected',
  );
  assert.equal(
    (
      await h.moderate(a.staff.actor, k1.workflows, {
        ...hide,
        expectedRevision: row.revision + 1,
        action: 'restore',
        idempotencyKey: randomUUID(),
      })
    ).kind,
    'succeeded',
  );
  const before: unknown = (await db.collection(rc.projections).doc(place).get()).data();
  await h.rebuild(place);
  assert.deepEqual((await db.collection(rc.projections).doc(place).get()).data(), before);
});
void test('H query hides author ids, keeps multi-line text and filters a muted author', async () => {
  const read = async (viewer: PublishingActor) => {
    const result = await h.query(hint(viewer), {
      schemaVersion: 1,
      requestId: randomUUID(),
      contentId: place,
    });
    assert.equal(result.kind, 'succeeded', JSON.stringify(result));
    return (result as unknown as { data: { reviews: Record<string, unknown>[] } }).data.reviews;
  };
  const rows = await read(a.staff);
  for (const row of rows) {
    assert.equal('authorId' in row, false);
    assert.equal('evidence' in row, false);
    assert.equal(typeof row.own, 'boolean');
  }
  const mine = rows.filter((row) => row.own === true);
  assert.equal(mine.length, 1);
  const edit = (text: string) =>
    h.command(hint(a.staff), {
      ...command(place, { operation: 'edit', rating: 4, text }),
      reviewId: mine[0]!.reviewId,
      expectedRevision: mine[0]!.revision,
    });
  const bell = await edit('Synthetic \u0007 bell');
  assert.equal(bell.kind === 'rejected' && bell.code, 'invalid_contract');
  assert.equal((await edit('Line one\nLine two')).kind, 'succeeded');
  const edited = (await read(a.staff)).find((row) => row.own === true)!;
  assert.equal(edited.text, 'Line one\nLine two');
  const mute = (active: boolean, expectedRevision: number) =>
    k2.relation(hint(a.creator), {
      schemaVersion: 1,
      requestId: randomUUID(),
      targetUserId: a.staff.actor.userId,
      kind: 'mute',
      active,
      expectedRevision,
      idempotencyKey: randomUUID(),
    });
  // a.creator: test 13 later spends b.staff's one-per-minute relation budget.
  const before = await read(a.creator);
  assert.equal((await mute(true, 0)).kind, 'succeeded');
  const muted = await read(a.creator);
  assert.equal(muted.length, before.length - 1);
  assert.equal(
    muted.some((row) => row.reviewId === edited.reviewId),
    false,
  );
  assert.equal((await mute(false, 1)).kind, 'succeeded');
  assert.equal((await read(a.creator)).length, before.length);
});
void test('K2 block is bilateral, mute directional; relation retries and revisions are fenced', async () => {
  const raw = {
    schemaVersion: 1,
    requestId: randomUUID(),
    targetUserId: b.creator.actor.userId,
    kind: 'block',
    active: true,
    expectedRevision: 0,
    idempotencyKey: randomUUID(),
  };
  const before = await db.collection('bookings').get();
  const result = await k2.relation(hint(a.creator), raw);
  assert.equal(result.kind, 'succeeded');
  assert.deepEqual(await k2.relation(hint(a.creator), { ...raw, requestId: randomUUID() }), result);
  assert.equal(await interactionAllowed(db, b.creator.actor.userId, a.creator.actor.userId), false);
  assert.equal((await k2.relation(hint(a.creator), { ...raw, active: false })).kind, 'rejected');
  assert.equal(
    (
      await k2.relation(hint(a.creator), {
        ...raw,
        active: false,
        expectedRevision: 1,
        idempotencyKey: randomUUID(),
      })
    ).kind,
    'succeeded',
  );
  assert.equal(
    (await k2.relation(hint(a.creator), { ...raw, kind: 'mute', idempotencyKey: randomUUID() }))
      .kind,
    'succeeded',
  );
  assert.equal(
    (await relationEffects(db, a.creator.actor.userId, b.creator.actor.userId)).muted,
    true,
  );
  assert.equal(
    (await relationEffects(db, b.creator.actor.userId, a.creator.actor.userId)).muted,
    false,
  );
  assert.deepEqual(
    (await db.collection('bookings').get()).docs.map((d) => d.data()),
    before.docs.map((d) => d.data()),
  );
});
const sanction = (extra: Record<string, unknown> = {}) => ({
  sanctionId: randomUUID(),
  subjectUserId: b.creator.actor.userId,
  family: 'temporarySuspend',
  durationDays: 7,
  reasonCode: 'safety',
  reason: 'Synthetic owner-authorized restriction',
  idempotencyKey: randomUUID(),
  ...extra,
});
void test('K2 scoped sanctions, owner-only permanent ban, three domain acks and replay', async () => {
  const p = sanction();
  assert.equal((await k2.issue(b.creator.actor, p)).kind, 'rejected');
  assert.equal(
    (await k2.issue(b.staff.actor, sanction({ family: 'permanentBan', durationDays: undefined })))
      .kind,
    'rejected',
  );
  const issued = await k2.issue(a.staff.actor, p);
  assert.equal(issued.kind, 'succeeded', JSON.stringify(issued));
  const notice = await db.collection(sc.notices).doc(p.sanctionId).get();
  assert.equal(notice.get('reasonCode'), 'safety');
  assert.notEqual(notice.get('reason'), p.reason);
  assert.deepEqual(await k2.issue(a.staff.actor, p), issued);
  assert.equal((await k2.reconcile(p.sanctionId)).kind, 'succeeded');
  for (const owner of ['content', 'catalog', 'booking'] as const)
    assert.equal(await safetyRestricted(db, owner, b.creator.actor.userId, now), true);
  const s = await db.collection(sc.sanctions).doc(p.sanctionId).get();
  assert.deepEqual(s.get('acks'), { content: 1, catalog: 1, booking: 1 });
  assert.equal((await h.command(hint(b.creator), command(event))).kind, 'rejected');
  const revoke = {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic correction',
    idempotencyKey: randomUUID(),
  };
  assert.equal((await k2.change(a.staff.actor, revoke)).kind, 'succeeded');
  assert.equal((await k2.reconcile(p.sanctionId)).kind, 'succeeded');
  for (const owner of ['content', 'catalog', 'booking'] as const)
    assert.equal(await safetyRestricted(db, owner, b.creator.actor.userId, now), false);
  const old: SafetyInstruction = {
    sanctionId: p.sanctionId,
    revision: 1,
    policyRevision: safetyPolicyRevision,
    subjectUserId: p.subjectUserId,
    contentId: null,
    family: 'temporarySuspend',
    desired: 'active',
    untilUtc: s.get('untilUtc') as string,
    reason: p.reason,
  };
  assert.equal((await applyBookingSafety(db, k2, old)).kind, 'rejected');
  const permanent = sanction({ family: 'permanentBan', durationDays: undefined });
  assert.equal((await k2.issue(a.staff.actor, permanent)).kind, 'succeeded');
  await k2.reconcile(permanent.sanctionId);
  assert.equal(
    await safetyRestricted(
      db,
      'booking',
      b.creator.actor.userId,
      new Date('2050-01-01T00:00:00.000Z'),
    ),
    true,
  );
  const lift = (actor: PublishingActor) =>
    k2.change(actor.actor, {
      sanctionId: permanent.sanctionId,
      expectedRevision: 1,
      operation: 'revoke',
      reason: 'Synthetic',
      idempotencyKey: randomUUID(),
    });
  // Ordinary scoped staff cannot lift an owner-only ban, directly or through an appeal.
  const denied = await lift(b.staff);
  assert.equal(denied.kind === 'rejected' && denied.code, 'owner_required');
  await k2.appeal(hint(b.creator), {
    sanctionId: permanent.sanctionId,
    appealId: randomUUID(),
    reason: 'Synthetic ban appeal',
    idempotencyKey: randomUUID(),
  });
  const appealDenied = await k2.decideAppeal(b.staff.actor, {
    sanctionId: permanent.sanctionId,
    expectedRevision: 1,
    outcome: 'revoked',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  assert.equal(appealDenied.kind === 'rejected' && appealDenied.code, 'owner_required');
  assert.equal((await lift(a.staff)).kind, 'succeeded');
  await k2.reconcile(permanent.sanctionId);
});
void test('K2 appeal is confidential, unique, independent and compensates all owner holds', async () => {
  const p = sanction();
  await k2.issue(a.staff.actor, p);
  await k2.reconcile(p.sanctionId);
  const appeal = {
    sanctionId: p.sanctionId,
    appealId: randomUUID(),
    reason: 'Synthetic appeal',
    idempotencyKey: randomUUID(),
  };
  assert.equal((await k2.appeal(hint(a.creator), appeal)).kind, 'rejected');
  assert.equal((await k2.appeal(hint(b.creator), appeal)).kind, 'succeeded');
  assert.equal(
    (await k2.appeal(hint(b.creator), { ...appeal, appealId: randomUUID() })).kind,
    'rejected',
  );
  const decision = {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    outcome: 'revoked',
    reason: 'Synthetic independent correction',
    idempotencyKey: randomUUID(),
  };
  assert.equal((await k2.decideAppeal(a.staff.actor, decision)).kind, 'rejected');
  assert.equal((await k2.decideAppeal(b.staff.actor, decision)).kind, 'succeeded');
  // The appellant's statement survives the decision; the staff narrative is stored apart.
  const stored = await db.collection(sc.appeals).doc(p.sanctionId).get();
  assert.equal(stored.get('reason'), 'Synthetic appeal');
  assert.equal(stored.get('decisionReason'), 'Synthetic independent correction');
  const submitted = await db
    .collection(sc.audit)
    .where('operation', '==', 'appealSubmitted')
    .where('appealId', '==', appeal.appealId)
    .get();
  assert.equal(submitted.size, 1);
  assert.equal(submitted.docs[0]!.get('reason'), 'Synthetic appeal');
  const own = await k2.query(hint(b.creator));
  assert.equal(own.kind, 'succeeded');
  assert.doesNotMatch(JSON.stringify(own), /Synthetic independent correction/);
  await k2.reconcile(p.sanctionId);
  assert.equal(await safetyRestricted(db, 'booking', b.creator.actor.userId, now), false);
});
void test('K2 overlapping sanctions remain effective after one is revoked; expiry is bounded', async () => {
  const p = sanction(),
    q = sanction({ durationDays: 30 });
  await k2.issue(a.staff.actor, p);
  await k2.issue(a.staff.actor, q);
  await k2.reconcile(p.sanctionId);
  await k2.reconcile(q.sanctionId);
  await k2.change(a.staff.actor, {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  await k2.reconcile(p.sanctionId);
  assert.equal(await safetyRestricted(db, 'booking', b.creator.actor.userId, now), true);
  assert.equal(
    await safetyRestricted(
      db,
      'booking',
      b.creator.actor.userId,
      new Date(now.getTime() + 31 * 86400000),
    ),
    false,
  );
  const future = new FirestoreSafetyService(
    db,
    { now: () => new Date(now.getTime() + 31 * 86400000) },
    k1.workflows,
  );
  assert.equal((await future.reconcile(q.sanctionId)).kind, 'succeeded');
  assert.equal(
    (await db.collection(sc.sanctions).doc(q.sanctionId).get()).get('status'),
    'expired',
  );
});

void test('K2 partial owner outage remains pending and retries finish all acknowledgements', async () => {
  const p = sanction();
  await k2.issue(a.staff.actor, p);
  class Flaky extends FirestoreSafetyService {
    calls = 0;
    override async verify(tx: Transaction, i: SafetyInstruction) {
      if (++this.calls === 3) throw new Error('synthetic_booking_outage');
      return super.verify(tx, i);
    }
  }
  await assert.rejects(
    () => new Flaky(db, clock, k1.workflows).reconcile(p.sanctionId),
    /synthetic_booking_outage/,
  );
  const partial = (await db.collection(sc.sanctions).doc(p.sanctionId).get()).data()!;
  assert.equal(partial.status, 'pending');
  assert.deepEqual(partial.acks, { content: 1, catalog: 1 });
  assert.equal((await k2.reconcile(p.sanctionId)).kind, 'succeeded');
  await k2.change(a.staff.actor, {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  await k2.reconcile(p.sanctionId);
});
void test('K2 actual Content authoring and Booking create enforce holds, existing bookings survive', async () => {
  const content = eventAuthoringComposition(db, { clock });
  const create = () =>
    content.content.execute(b.creator.actor, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: randomUUID(),
      payload: {
        typeId: 'event',
        publisherRef: { type: 'page', id: b.pageId },
        marketId: 'LV',
        body: standEventBody(randomUUID()),
      },
    });
  assert.equal((await create()).kind, 'succeeded');
  const occurrenceId = randomUUID(),
    eventId = randomUUID();
  await seedEvent(
    finiteEvent({
      eventId,
      occurrenceId,
      occurrenceStartsAt: new Date(now.getTime() - 60000).toISOString(),
      occurrenceEndsAt: new Date(now.getTime() + 3600000).toISOString(),
      registrationWindow: {
        opensAt: new Date(now.getTime() - 86400000).toISOString(),
        closesAt: new Date(now.getTime() + 3600000).toISOString(),
      },
      cancellationDeadline: new Date(now.getTime() + 3600000).toISOString(),
    }),
    db,
  );
  const booking = () =>
    createInternalBooking(
      { firestore: db, clock },
      b.creator.actor.userId,
      createCommand({
        requestId: randomUUID(),
        idempotencyKey: randomUUID(),
        payload: {
          occurrenceId,
          inventoryPoolId: 'pool_general',
          channel: 'onsite',
          participantUnits: 1,
        },
      }),
    );
  const first = await booking();
  assert.equal(first.kind, 'succeeded', JSON.stringify(first));
  await source(eventId, 'event');
  assert.equal((await h.command(hint(b.creator), command(eventId))).kind, 'succeeded');
  const p = sanction();
  await k2.issue(a.staff.actor, p);
  await k2.reconcile(p.sanctionId);
  assert.equal((await create()).kind, 'rejected');
  assert.equal((await booking()).kind, 'rejected');
  if (first.kind === 'succeeded') {
    const existing = await db.collection('bookings').doc(first.data.booking.id).get();
    assert.equal(existing.get('state'), 'confirmed');
    assert.equal(
      (
        await cancelInternalBooking({ firestore: db, clock }, b.creator.actor.userId, {
          schemaVersion: 1,
          commandType: 'cancelBooking',
          requestId: randomUUID(),
          idempotencyKey: randomUUID(),
          expectedBookingRevision: 1,
          payload: { bookingId: first.data.booking.id },
        })
      ).kind,
      'succeeded',
    );
  }
  await k2.change(a.staff.actor, {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  await k2.reconcile(p.sanctionId);
  assert.equal((await create()).kind, 'succeeded');
});
void test('K2 real Catalog feed honors block, public event direct link survives, sanction removes both', async () => {
  const world = createContentEventWorld(db, 'k2-real');
  const contentId = await world.publish({ title: 'K2 synthetic public event', date: '2035-10-10' });
  const owner = (await world.actors).creator.userId;
  assert.deepEqual(
    await deliverContentEffects(db, {
      flags: { isEnabled: (id) => Promise.resolve(id === catalogFlagIds.delivery) },
      consumers: [catalogEffectConsumer()],
    }),
    [{ consumer: 'catalog', status: 'completed' }],
  );
  const catalog = createEmulatorCatalogComposition(db, { clock, viewerId: b.creator.actor.userId });
  const query = { schemaVersion: 1, marketId: 'LV', subcategoryIds: [world.subcategory] };
  const visible = await catalog.query.feed({ query });
  assert.equal(visible.kind, 'succeeded', JSON.stringify(visible));
  if (visible.kind === 'succeeded')
    assert.ok(visible.items.some((i) => i.ref.contentId === contentId));
  const block = {
    schemaVersion: 1,
    requestId: randomUUID(),
    targetUserId: owner,
    kind: 'block',
    active: true,
    expectedRevision: 0,
    idempotencyKey: randomUUID(),
  };
  await k2.relation(hint(b.creator), block);
  const filtered = await catalog.query.feed({ query });
  assert.equal(filtered.kind, 'succeeded');
  if (filtered.kind === 'succeeded')
    assert.equal(
      filtered.items.some((i) => i.ref.contentId === contentId),
      false,
    );
  const direct = await catalog.query.details({ contentId });
  assert.equal(direct.kind, 'succeeded');
  if (direct.kind === 'succeeded') assert.ok(direct.item);
  const p = sanction({
    subjectUserId: owner,
    contentId,
    typeId: 'event',
    family: 'contentHide',
    durationDays: undefined,
  });
  assert.equal((await k2.issue(a.staff.actor, p)).kind, 'succeeded');
  await k2.reconcile(p.sanctionId);
  const hidden = await catalog.query.details({ contentId });
  assert.equal(hidden.kind, 'succeeded');
  if (hidden.kind === 'succeeded') assert.equal(hidden.item, null);
  await k2.change(a.staff.actor, {
    sanctionId: p.sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  await k2.reconcile(p.sanctionId);
  const restored = await catalog.query.details({ contentId });
  assert.equal(restored.kind, 'succeeded');
  if (restored.kind === 'succeeded') assert.ok(restored.item);
});

void test('K2 missing abuse policy, default-off and injected client age/role claims fail closed', async () => {
  await db
    .collection(sc.authority)
    .doc('abusePolicy')
    .set({ policyRevision: safetyPolicyRevision, maxPerMinute: 1 });
  const limited = {
    schemaVersion: 1,
    requestId: randomUUID(),
    targetUserId: a.creator.actor.userId,
    kind: 'mute',
    active: true,
    expectedRevision: 0,
    idempotencyKey: randomUUID(),
  };
  const first = await k2.relation(hint(b.staff), limited);
  assert.equal(first.kind, 'succeeded');
  assert.deepEqual(
    await k2.relation(hint(b.staff), { ...limited, requestId: randomUUID() }),
    first,
  );
  assert.equal(
    (
      await k2.relation(hint(b.staff), {
        ...limited,
        active: false,
        expectedRevision: 1,
        idempotencyKey: randomUUID(),
      })
    ).kind,
    'rejected',
  );
  assert.equal(
    (await h.command(hint(b.creator), { ...command(), operation: { toString: null } })).kind,
    'rejected',
  );
  await db.collection(sc.authority).doc('abusePolicy').delete();
  const p = {
    schemaVersion: 1,
    requestId: randomUUID(),
    targetUserId: b.creator.actor.userId,
    kind: 'block',
    active: true,
    expectedRevision: 2,
    idempotencyKey: randomUUID(),
  };
  assert.equal((await k2.relation(hint(a.creator), p)).kind, 'rejected');
  await setLocalFlag(db, 'trustSafety.runtime', false);
  assert.equal(
    (
      await handleK2(
        db,
        hint(a.creator),
        'safetyCommandV1',
        {
          schemaVersion: 1,
          requestId: randomUUID(),
          operation: 'issueSanction',
          payload: sanction(),
        },
        clock,
      )
    ).kind,
    'rejected',
  );
  await setLocalFlag(db, 'trustSafety.runtime', true);
  assert.equal(
    (
      await handleK2(
        db,
        hint(a.creator),
        'safetyQueryV1',
        {
          schemaVersion: 1,
          requestId: randomUUID(),
          queryType: 'own',
          verifiedAge: 18,
          role: 'owner',
        },
        clock,
      )
    ).kind,
    'rejected',
  );
});
