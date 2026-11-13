import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import {
  consumeEventForBookingProjection,
  type EventBookingProjectionEvent,
} from '../../src/booking/event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from '../../src/booking/occurrence_lifecycle.js';
import { reconfirmInternalBooking } from '../../src/booking/reconfirm_internal_booking.js';
import { runReconfirmationDeadlineWorker } from '../../src/booking/reconfirmation_deadline_worker.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { NotificationEffectConsumer } from '../../src/modules/notifications/application/consume_notification_effect.js';
import { FirestoreNotificationsStore } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { bookingFlagIds, bookingNotificationFlagIds } from '../../src/shared/feature_flags.js';
import { bookingInvariantProblems } from '../support/booking_invariants.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import {
  createCommand,
  finiteEvent,
  fixedNow,
  reconfirmCommand,
} from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupNotifications,
  setLocalFlag,
  setRecipientAccount,
} from '../support/notifications_world.js';

/**
 * F2 §5: deadline boundaries with one controlled server clock shared by every
 * participant — Booking commands, the reschedule lifecycle, the 2B deadline
 * worker and the Notifications consumer. The deadline D of local 2A is the
 * rescheduled start. Before D, at D and after D are checked separately.
 */
const firestore = emulatorFirestore();
const actorId = 'f2-deadline-actor';
const bookingId = '01JF2DEADLINEBOOKING000001';
const start = fixedNow.getTime();
const deadline = new Date(start + 2 * 3_600_000);
const deadlineIso = deadline.toISOString();

beforeEach(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
  await setBookingFlags(true, firestore);
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  await setRecipientAccount(firestore, actorId, 'active');
});
after(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
});

function event(): BookingEventProjection {
  return finiteEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
}

/** Booked at T0, rescheduled at T0 + 1 min to start at D (material: date change). */
async function bookedAndRescheduled(clock: FakeClock): Promise<void> {
  const projection = event();
  await seedEvent(projection, firestore);
  clock.set(new Date(start));
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand(),
  );
  assert.equal(created.kind, 'succeeded');
  clock.set(new Date(start + 60_000));
  const change: EventBookingProjectionEvent = {
    kind: 'EventMateriallyRescheduled',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    publicationRevision: 8,
    materialRevision: 8,
    occurredAt: clock.now().toISOString(),
    projection: {
      ...projection,
      materialRevision: 8,
      occurrenceStartsAt: deadlineIso,
      occurrenceEndsAt: new Date(deadline.getTime() + 2 * 3_600_000).toISOString(),
    },
  };
  assert.equal((await consumeEventForBookingProjection(firestore, change)).kind, 'applied');
  assert.equal((await applyOccurrenceLifecycleEffects(firestore, change)).affected, 1);
  const booking = await bookingData();
  assert.equal(booking.reconfirmationState, 'required');
  assert.equal(booking.reconfirmationDeadlineUtc, deadlineIso);
}

async function bookingData(): Promise<Record<string, unknown>> {
  return (await firestore.collection(bookingCollections.bookings).doc(bookingId).get()).data()!;
}

async function ledgerUnits(): Promise<number> {
  const ledgers = await firestore.collection(bookingCollections.poolLedgers).get();
  return ledgers.docs.reduce((sum, document) => sum + Number(document.get('confirmedUnits')), 0);
}

async function reconfirm(clock: FakeClock, key = 'idem_f2_reconfirm') {
  return reconfirmInternalBooking(
    { firestore, clock },
    actorId,
    reconfirmCommand(bookingId, { requestId: `req_${key}`, idempotencyKey: key }),
  );
}

async function cancel(clock: FakeClock) {
  return cancelInternalBooking({ firestore, clock }, actorId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_f2_cancel',
    idempotencyKey: 'idem_f2_cancel',
    expectedBookingRevision: 2,
    payload: { bookingId, reasonCode: 'user_request' },
  });
}

async function consume(clock: FakeClock, revision: number) {
  const record = await firestore
    .collection(bookingCollections.outbox)
    .doc(`${bookingId}__r${String(revision)}`)
    .get();
  return new NotificationEffectConsumer({
    store: new FirestoreNotificationsStore(firestore),
    clock,
  }).consume(record.id, record.data());
}

void test('one millisecond before D: reconfirm accepted, worker idle, notice created', async () => {
  const clock = new FakeClock(fixedNow);
  await bookedAndRescheduled(clock);
  clock.set(new Date(deadline.getTime() - 1));
  assert.equal(await consume(clock, 2), 'created');
  const result = await reconfirm(clock);
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  assert.equal((await bookingData()).reconfirmationState, 'confirmed');
  assert.equal(
    (await runReconfirmationDeadlineWorker(firestore, clock.now().toISOString())).attempted,
    0,
  );
  assert.equal((await bookingData()).state, 'confirmed');
  assert.equal(await ledgerUnits(), 1);
  assert.deepEqual(await bookingInvariantProblems(firestore), []);
});

void test('exactly at D (2A): late reconfirm refused, seat not released, cancellation still allowed', async () => {
  const clock = new FakeClock(fixedNow);
  await bookingFlagOff(bookingFlagIds.reconfirmationDeadlineWorker);
  await bookedAndRescheduled(clock);
  clock.set(deadline);
  const late = await reconfirm(clock);
  assert.equal(late.kind, 'rejected');
  assert.equal((late as { code?: string }).code, 'reconfirmation_deadline_passed');
  // 2A alone never frees the seat: still confirmed, still required, still held.
  assert.equal((await bookingData()).state, 'confirmed');
  assert.equal((await bookingData()).reconfirmationState, 'required');
  assert.equal(await ledgerUnits(), 1);
  // The notice is still deliverable exactly at its deadline.
  assert.equal(await consume(clock, 2), 'created');
  const cancelled = await cancel(clock);
  assert.equal(cancelled.kind, 'succeeded', JSON.stringify(cancelled));
  assert.equal(await ledgerUnits(), 0);
  assert.deepEqual(await bookingInvariantProblems(firestore), []);
});

void test('exactly at D (local 2B): the worker cancels once and releases once', async () => {
  const clock = new FakeClock(fixedNow);
  await bookedAndRescheduled(clock);
  clock.set(deadline);
  await runReconfirmationDeadlineWorker(firestore, clock.now().toISOString());
  const booking = await bookingData();
  assert.equal(booking.state, 'cancelled');
  assert.equal(booking.terminalReason, 'missedReconfirmation');
  assert.equal(booking.reconfirmationState, 'missed');
  await runReconfirmationDeadlineWorker(firestore, clock.now().toISOString());
  assert.equal(await ledgerUnits(), 0);
  assert.deepEqual(await bookingInvariantProblems(firestore), []);
});

void test('one millisecond after D: reconfirm refused, the notice expired, the cancellation notice is new', async () => {
  const clock = new FakeClock(fixedNow);
  await bookedAndRescheduled(clock);
  clock.set(new Date(deadline.getTime() + 1));
  const late = await reconfirm(clock);
  assert.equal((late as { code?: string }).code, 'reconfirmation_deadline_passed');
  assert.equal(await consume(clock, 2), 'expired');
  await runReconfirmationDeadlineWorker(firestore, clock.now().toISOString());
  assert.equal((await bookingData()).terminalReason, 'missedReconfirmation');
  assert.equal(await consume(clock, 3), 'created');
  assert.equal(await consume(clock, 3), 'duplicate');
  // A manual cancellation after the worker is an idempotent no-op: the stored
  // Booking, its reason and the released allocation do not change.
  const before = await bookingData();
  await cancel(clock);
  const afterCancel = await bookingData();
  assert.equal(afterCancel.revision, before.revision);
  assert.equal(afterCancel.terminalReason, 'missedReconfirmation');
  assert.equal(await ledgerUnits(), 0);
  assert.deepEqual(await bookingInvariantProblems(firestore), []);
});

async function bookingFlagOff(flagId: string): Promise<void> {
  await setLocalFlag(firestore, flagId, false);
}
