import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';

import { getEventAvailability } from '../../src/booking/availability_query.js';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import {
  eventBookingDeliveryCollections,
  deliverEventBookingProjection,
} from '../../src/booking/event_projection_delivery.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import {
  catalogEffectConsumer,
  deliverContentEffects,
  type ContentEffectConsumer,
} from '../../src/content_effects_entry.js';
import type { HandoffSource } from '../../src/modules/content/application/event_booking_handoff.js';
import { internalPoolId } from '../../src/modules/content/domain/event_internal_registration.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import {
  createEmulatorEventBookingHandoff,
  eventBookingHandoffCollections,
} from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { catalogFlagIds, contentFlagIds } from '../../src/shared/feature_flags.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { createCommand } from '../support/booking_fixtures.js';
import { createContentEventWorld } from '../support/content_event_world.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();
/** Created after the cleanup below, which also clears Identity access data. */
let world!: ReturnType<typeof createContentEventWorld>;
/** Booking's clock sits inside the registration window of the 2035 Events. */
const clock = new FakeClock(new Date('2035-10-05T12:00:00.000Z'));
const bookingNow = () => clock.now().toISOString();

/** Test switches of the source the main handoff reads. */
const faults = { revisionDown: false };
const { handoff } = createEmulatorEventBookingHandoff(firestore, {
  source: (base) => ({
    ...base,
    publishedRevision: (id) =>
      faults.revisionDown ? Promise.reject(new Error('source_down')) : base.publishedRevision(id),
  }),
});

async function cleanup() {
  for (const name of [
    ...Object.values(contentCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
    ...Object.values(catalogCollections),
    eventBookingHandoffCollections.status,
    eventBookingHandoffCollections.receipts,
    eventBookingHandoffCollections.states,
  ]) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
  await cleanupBookingEmulator(firestore);
}
before(async () => {
  await cleanup();
  world = createContentEventWorld(firestore, 'e20-handoff');
});
after(cleanup);

type Body = Record<string, unknown>;
interface Shape {
  readonly a: string;
  readonly b: string;
  readonly withB: boolean;
  readonly startMinute: number;
  readonly capacity: number;
}

/** Internal registration v1 over one or two occurrences with stable ids. */
function shaped(shape: Shape) {
  const hour = String(shape.startMinute / 60 - 3).padStart(2, '0');
  const endHour = String(shape.startMinute / 60 - 1).padStart(2, '0');
  const slot = (id: string, date: string) => ({
    id,
    localDate: date,
    startAtUtc: `${date}T${hour}:00:00.000Z`,
    endAtUtc: `${date}T${endHour}:00:00.000Z`,
  });
  return (body: Body): Body => ({
    ...body,
    schedule: {
      ...(body.schedule as Body),
      scheduleMode: shape.withB ? 'multiDate' : 'oneTime',
      localStartDate: '2035-10-10',
      startMinute: shape.startMinute,
      ...(shape.withB ? { multiDateLocalDates: ['2035-10-10', '2035-10-17'] } : {}),
    },
    eventSlots: shape.withB
      ? [slot(shape.a, '2035-10-10'), slot(shape.b, '2035-10-17')]
      : [slot(shape.a, '2035-10-10')],
    participants: { capacityMode: 'known', capacity: shape.capacity },
    registration: {
      mode: 'internal',
      confirmationMode: 'instant',
      maxPartySize: 2,
      opensMinutesBeforeStart: 525_600,
      closesMinutesBeforeStart: 60,
      cancellationClosesMinutesBeforeStart: 120,
    },
  });
}

/** Booking delivers every outbox record with its own delivery records. */
async function deliverBooking(): Promise<void> {
  const outbox = await firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .orderBy('createdAt')
    .get();
  for (const document of outbox.docs)
    await deliverEventBookingProjection(firestore, document.id, bookingNow());
}

async function projection(occurrenceId: string): Promise<Record<string, unknown>> {
  const snapshot = await firestore
    .collection(bookingCollections.eventProjections)
    .doc(occurrenceId)
    .get();
  assert.ok(snapshot.exists, `projection of ${occurrenceId}`);
  return snapshot.data() as Record<string, unknown>;
}

const outboxCount = async () =>
  (await firestore.collection(eventBookingDeliveryCollections.sourceOutbox).get()).size;

let commandSequence = 0;
function book(actor: string, contentId: string, occurrenceId: string, key?: string) {
  commandSequence += 1;
  const idempotencyKey = key ?? `idem_e20_${commandSequence}`;
  const { occurredAgainstEventRevision, ...base } = createCommand({
    requestId: `req_e20_${commandSequence}`,
    idempotencyKey,
  });
  void occurredAgainstEventRevision;
  return createInternalBooking({ firestore, clock }, actor, {
    ...base,
    payload: {
      occurrenceId,
      inventoryPoolId: internalPoolId(contentId, occurrenceId),
      channel: 'onsite',
      participantUnits: 2,
      namedGuests: [],
    },
  });
}

const ids = { content: '', a: '', b: randomUUID(), bookingA: '', bookingB: '' };

void test('publication becomes one Booking projection per occurrence; repeats add nothing', async () => {
  ids.content = await world.publish({ title: 'Clay twice', date: '2035-10-10' });
  ids.a = world.slotIdOf(ids.content);
  const r1 = await world.revise(ids.content, {
    title: 'Clay twice',
    date: '2035-10-10',
    transform: shaped({ a: ids.a, b: ids.b, withB: true, startMinute: 1080, capacity: 20 }),
  });
  assert.deepEqual(r1, { stage: 'publish', kind: 'succeeded' });

  const report = await handoff.deliver();
  assert.equal(report.stoppedAt, null);
  assert.equal(report.synced, true);
  await deliverBooking();
  for (const occurrenceId of [ids.a, ids.b]) {
    const stored = await projection(occurrenceId);
    assert.equal(stored.lifecycle, 'published');
    assert.equal(stored.poolId, internalPoolId(ids.content, occurrenceId));
    assert.equal(stored.channel, 'onsite');
    assert.equal(stored.materialRevision, 1);
    assert.equal(stored.totalCapacity, 20);
  }

  const availability = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_e20_availability',
    payload: { eventId: ids.content, occurrenceId: ids.a, channel: 'onsite' },
  });
  assert.equal(availability.kind, 'succeeded', JSON.stringify(availability));
  assert.deepEqual(availability.kind === 'succeeded' ? availability.data.terms : null, {
    inventoryPoolId: internalPoolId(ids.content, ids.a),
    channel: 'onsite',
    partyMode: 'partyWithoutNames',
    maxParticipantUnits: 2,
    registrationOpensAt: '2034-10-10T15:00:00.000Z',
    registrationClosesAt: '2035-10-10T14:00:00.000Z',
    cancellationDeadline: '2035-10-10T13:00:00.000Z',
  });

  const before = await outboxCount();
  const again = await handoff.deliver();
  assert.equal(again.applied, 0);
  assert.equal(await outboxCount(), before, 'no duplicate outbox record');

  const booked = await book('viewer-a', ids.content, ids.a, 'idem_e20_same');
  assert.equal(booked.kind, 'succeeded', JSON.stringify(booked));
  const repeated = await book('viewer-a', ids.content, ids.a, 'idem_e20_same');
  assert.equal(
    repeated.kind === 'succeeded' && repeated.data.replayed,
    true,
    'replayed, no second Booking',
  );
  ids.bookingA = booked.kind === 'succeeded' ? booked.data.booking.id : '';
  const onB = await book('viewer-b', ids.content, ids.b);
  assert.equal(onB.kind, 'succeeded', JSON.stringify(onB));
  ids.bookingB = onB.kind === 'succeeded' ? onB.data.booking.id : '';
  const bookings = await firestore.collection(bookingCollections.bookings).get();
  assert.equal(bookings.size, 2);
});

void test('D07 reschedule, capacity change and removal before the start use the Booking lifecycle', async () => {
  // A moves three hours (material), B is removed, capacity becomes 30.
  const r2 = await world.revise(ids.content, {
    title: 'Clay twice',
    date: '2035-10-10',
    transform: shaped({ a: ids.a, b: ids.b, withB: false, startMinute: 1260, capacity: 30 }),
  });
  assert.deepEqual(r2, { stage: 'publish', kind: 'succeeded' });
  assert.equal((await handoff.deliver()).stoppedAt, null);
  await deliverBooking();

  const a = await projection(ids.a);
  assert.equal(a.materialRevision, 2);
  assert.equal(a.sourceEventKind, 'EventMateriallyRescheduled');
  assert.equal(a.totalCapacity, 30);
  const bookingA = await firestore.collection(bookingCollections.bookings).doc(ids.bookingA).get();
  assert.equal(bookingA.get('state'), 'confirmed');
  assert.equal(bookingA.get('reconfirmationState'), 'required');

  const b = await projection(ids.b);
  assert.equal(b.lifecycle, 'occurrenceCancelled');
  const bookingB = await firestore.collection(bookingCollections.bookings).doc(ids.bookingB).get();
  assert.equal(bookingB.get('state'), 'cancelled');
  assert.equal(bookingB.get('terminalReason'), 'occurrenceCancelled');

  // B comes back in a later revision: it stays cancelled (terminal marker).
  const r3 = await world.revise(ids.content, {
    title: 'Clay twice',
    date: '2035-10-10',
    transform: shaped({ a: ids.a, b: ids.b, withB: true, startMinute: 1260, capacity: 30 }),
  });
  assert.deepEqual(r3, { stage: 'publish', kind: 'succeeded' });
  assert.equal((await handoff.deliver()).stoppedAt, null);
  await deliverBooking();
  assert.equal((await projection(ids.b)).lifecycle, 'occurrenceCancelled');
  assert.equal((await projection(ids.a)).materialRevision, 2, 'same time: not material');
  const report = await handoff.reconcile();
  assert.deepEqual(report.notices, [{ contentId: ids.content, occurrenceId: ids.b }]);
});

void test('hide closes new Booking once applied in Booking; restore reopens it', async () => {
  await world.ownerWithdraw(ids.content);
  assert.equal((await handoff.deliver()).stoppedAt, null);
  // Eventual consistency: the guarantee starts when Booking applied the hide.
  await deliverBooking();
  assert.equal((await projection(ids.a)).lifecycle, 'unpublished');
  const refused = await book('viewer-c', ids.content, ids.a);
  assert.deepEqual(refused, { kind: 'rejected', code: 'event_unavailable' });

  // The existing Booking stays and can still be cancelled by its owner.
  const cancelled = await cancelInternalBooking({ firestore, clock }, 'viewer-a', {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_e20_cancel',
    idempotencyKey: 'idem_e20_cancel',
    expectedBookingRevision: 2,
    payload: { bookingId: ids.bookingA },
  });
  assert.equal(cancelled.kind, 'succeeded', JSON.stringify(cancelled));

  const current = (await world.pointer(ids.content)).currentPublishedRevisionId;
  assert.ok(current);
  assert.deepEqual(await world.activate(ids.content, current), {
    stage: 'activate',
    kind: 'succeeded',
  });
  assert.equal((await handoff.deliver()).stoppedAt, null);
  await deliverBooking();
  assert.equal((await projection(ids.a)).lifecycle, 'published');
  assert.equal((await book('viewer-c', ids.content, ids.a)).kind, 'succeeded');
});

void test('a failing handoff never marks the Catalog and is finished without a new Content effect', async () => {
  const contentId = await world.publish({ title: 'Glaze day', date: '2035-10-12' });
  faults.revisionDown = true;
  const own: ContentEffectConsumer = {
    name: 'bookingHandoff',
    flagId: contentFlagIds.eventBookingHandoff,
    async run() {
      const report = await handoff.deliver();
      return report.stoppedAt === null ? { status: 'completed' } : { status: 'stopped' };
    },
  };
  const outcomes = await deliverContentEffects(firestore, {
    flags: {
      isEnabled: (id) =>
        Promise.resolve(
          id === catalogFlagIds.delivery || id === contentFlagIds.eventBookingHandoff,
        ),
    },
    consumers: [own, catalogEffectConsumer()],
  });
  assert.deepEqual(outcomes, [
    { consumer: 'bookingHandoff', status: 'failed', detail: 'Error' },
    { consumer: 'catalog', status: 'completed' },
  ]);
  // The source is back, but no new Content effect will arrive.
  faults.revisionDown = false;
  const lagging = await handoff.reconcile();
  const codes = lagging.findings.map((finding) => finding.code);
  assert.ok(codes.includes('handoff_pending'), JSON.stringify(lagging));
  assert.ok(
    lagging.findings.some(
      (finding) => finding.code === 'handoff_gap' && finding.contentId === contentId,
    ),
  );

  // The stand command alone finishes the work.
  const resumed = await handoff.deliver();
  assert.equal(resumed.stoppedAt, null);
  assert.ok(resumed.processed >= 1);
  await deliverBooking();
  const healed = await handoff.reconcile();
  assert.equal(healed.complete, true, JSON.stringify(healed.findings));
});

void test('a reordered feed is caught up from stored history; a lost effect stops and is reported', async () => {
  const caughtUp = await world.publish({ title: 'Kiln talk', date: '2035-10-14' });
  const internal = shaped({
    a: world.slotIdOf(caughtUp),
    b: randomUUID(),
    withB: false,
    startMinute: 1080,
    capacity: 10,
  });
  await world.revise(caughtUp, { title: 'Kiln talk', date: '2035-10-14', transform: internal });
  await world.revise(caughtUp, {
    title: 'Kiln talk',
    date: '2035-10-14',
    transform: (body) => internal({ ...body, title: 'Kiln talk, again' }),
  });
  // The global feed misses revision 2 of this object: history fills it in.
  const hiding = (base: HandoffSource): HandoffSource => ({
    ...base,
    effectsAfter: async (position, limit) =>
      (await base.effectsAfter(position, limit)).filter(
        (effect) => !(effect.contentId === caughtUp && effect.pointerRevision === 2),
      ),
  });
  const reordered = createEmulatorEventBookingHandoff(firestore, { source: hiding }).handoff;
  const report = await reordered.deliver();
  assert.equal(report.stoppedAt, null, JSON.stringify(report));
  const state = await createEmulatorEventBookingHandoff(firestore).repository.transact((tx) =>
    tx.state(caughtUp),
  );
  assert.equal(state?.lastPointerRevision, 3);

  // Content lost revision 2 of another object: the handoff stops, never guesses.
  const lost = await world.publish({ title: 'Lost glaze', date: '2035-10-15' });
  const internalLost = shaped({
    a: world.slotIdOf(lost),
    b: randomUUID(),
    withB: false,
    startMinute: 1080,
    capacity: 10,
  });
  await world.revise(lost, { title: 'Lost glaze', date: '2035-10-15', transform: internalLost });
  await world.revise(lost, {
    title: 'Lost glaze',
    date: '2035-10-15',
    transform: (body) => internalLost({ ...body, title: 'Lost glaze, again' }),
  });
  const losing = (base: HandoffSource): HandoffSource => ({
    ...base,
    effectsAfter: async (position, limit) =>
      (await base.effectsAfter(position, limit)).filter(
        (effect) => !(effect.contentId === lost && effect.pointerRevision === 2),
      ),
    effectsForContent: async (contentId, cursor, limit) =>
      (await base.effectsForContent(contentId, cursor, limit)).filter(
        (effect) => !(effect.contentId === lost && effect.pointerRevision === 2),
      ),
  });
  const stopped = await createEmulatorEventBookingHandoff(firestore, {
    source: losing,
  }).handoff.deliver();
  assert.equal(stopped.stoppedAt?.code, 'source_effect_missing');
  const reported = await handoff.reconcile();
  assert.ok(
    reported.findings.some(
      (finding) => finding.code === 'handoff_gap' && finding.contentId === lost,
    ),
  );
  // With the full history the same handoff resumes from its own checkpoint.
  assert.equal((await handoff.deliver()).stoppedAt, null);
  await deliverBooking();
  assert.equal((await handoff.reconcile()).complete, true);
});

void test('a lost outbox record is found and recreated from the stored history', async () => {
  const state = await createEmulatorEventBookingHandoff(firestore).repository.transact((tx) =>
    tx.state(ids.content),
  );
  const lastOutboxId = state?.occurrences[ids.a]?.lastOutboxId;
  assert.ok(lastOutboxId);
  await firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(lastOutboxId)
    .delete();
  const report = await handoff.reconcile();
  assert.ok(
    report.findings.some(
      (finding) => finding.code === 'outbox_missing' && finding.detail === lastOutboxId,
    ),
    JSON.stringify(report.findings),
  );
  const repaired = await handoff.repairContent(ids.content);
  assert.ok(repaired.created >= 1);
  const outbox = await firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(lastOutboxId)
    .get();
  assert.ok(outbox.exists);
  await deliverBooking();
  assert.equal((await handoff.reconcile()).complete, true);
});
