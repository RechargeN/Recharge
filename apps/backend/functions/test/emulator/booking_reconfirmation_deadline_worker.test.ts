import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import { consumeEventForBookingProjection } from '../../src/booking/event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from '../../src/booking/occurrence_lifecycle.js';
import { reconfirmInternalBooking } from '../../src/booking/reconfirm_internal_booking.js';
import {
  discoverReconfirmationDeadlineJobs,
  ensureReconfirmationDeadlineJob,
  processReconfirmationDeadlineJob,
  reconfirmationDeadlineJobId,
  replayDeadLetterReconfirmationDeadline,
  runReconfirmationDeadlineWorker,
} from '../../src/booking/reconfirmation_deadline_worker.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
} from '../../src/booking/transactions.js';
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
  unlimitedEvent,
} from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

beforeEach(async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
});
after(async () => cleanupBookingEmulator(firestore));

void test('deadline worker cancels finite Booking and releases allocation exactly once', async () => {
  const event = futureFiniteEvent();
  const bookingId = '01JDEADLINEFINITE000000000';
  const actorId = 'deadline-finite-user';
  await createRequiredBooking(event, bookingId, actorId, 8, fixedNow.toISOString());

  assert.deepEqual(await runReconfirmationDeadlineWorker(firestore, fixedNow.toISOString()), {
    discovered: 1,
    examined: 1,
    attempted: 1,
  });
  const booking = await bookingData(bookingId);
  assert.equal(booking.state, 'cancelled');
  assert.equal(booking.reconfirmationState, 'missed');
  assert.equal(booking.terminalReason, 'missedReconfirmation');
  assert.equal(booking.reconfirmationRequiredForRevision, undefined);
  assert.equal(booking.reconfirmationDeadlineUtc, undefined);
  assert.equal(await activeKeyExists(actorId, event.occurrenceId), false);
  assert.equal(await finiteLedgerUnits(event), 0);
  assert.deepEqual(await usageCounts(actorId), { finite: 0, unlimited: 0 });

  const jobId = reconfirmationDeadlineJobId(bookingId, 8);
  assert.equal(
    await processReconfirmationDeadlineJob(firestore, jobId, fixedNow.toISOString()),
    'replayed',
  );
  assert.equal(await finiteLedgerUnits(event), 0);
  assert.deepEqual(await usageCounts(actorId), { finite: 0, unlimited: 0 });
  assert.equal((await firestore.collection(bookingCollections.audit).get()).size, 3);
  assert.equal((await firestore.collection(bookingCollections.outbox).get()).size, 3);
});

void test('deadline worker releases unlimited usage without creating a ledger', async () => {
  const event = unlimitedEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
  const bookingId = '01JDEADLINEUNLIMITED000000';
  const actorId = 'deadline-unlimited-user';
  await createRequiredBooking(event, bookingId, actorId, 8, fixedNow.toISOString(), {
    payload: {
      occurrenceId: event.occurrenceId,
      participantUnits: 1,
      namedGuests: [],
    },
  });
  await runReconfirmationDeadlineWorker(firestore, fixedNow.toISOString());
  assert.deepEqual(await usageCounts(actorId), { finite: 0, unlimited: 0 });
  assert.equal((await firestore.collection(bookingCollections.poolLedgers).get()).empty, true);
});

void test('reconfirmation and deadline worker race has exactly one terminal winner', async () => {
  const event = futureFiniteEvent();
  const bookingId = '01JDEADLINERACERECONFIRM00';
  const actorId = 'deadline-race-reconfirm';
  const deadline = '2026-08-29T12:01:00.000Z';
  await createRequiredBooking(event, bookingId, actorId, 8, deadline);
  await ensureReconfirmationDeadlineJob(firestore, bookingId, deadline);
  const reconfirmClock = new FakeClock(new Date('2026-08-29T12:00:59.999Z'));
  const [reconfirmation, worker] = await Promise.all([
    reconfirmInternalBooking(
      { firestore, clock: reconfirmClock },
      actorId,
      reconfirmCommand(bookingId),
    ),
    processReconfirmationDeadlineJob(
      firestore,
      reconfirmationDeadlineJobId(bookingId, 8),
      deadline,
      'race-worker',
    ),
  ]);
  const booking = await bookingData(bookingId);
  if (booking.state === 'cancelled') {
    assert.equal(worker, 'auto_cancelled');
    assert.equal(reconfirmation.kind, 'rejected');
  } else {
    assert.equal(booking.reconfirmationState, 'confirmed');
    assert.equal(reconfirmation.kind, 'succeeded');
    assert.ok(worker === 'superseded' || worker === 'replayed');
  }
  assert.ok((await finiteLedgerUnits(event)) === 0 || (await finiteLedgerUnits(event)) === 1);
});

void test('manual cancellation racing the worker releases ledger and usage once', async () => {
  const event = futureFiniteEvent();
  const bookingId = '01JDEADLINERACECANCEL00000';
  const actorId = 'deadline-race-cancel';
  const deadline = fixedNow.toISOString();
  await createRequiredBooking(event, bookingId, actorId, 8, deadline);
  await ensureReconfirmationDeadlineJob(firestore, bookingId, deadline);
  const [cancellation, worker] = await Promise.all([
    cancelInternalBooking({ firestore, clock }, actorId, {
      schemaVersion: 1,
      commandType: 'cancelBooking',
      requestId: 'req_deadline_race_cancel',
      idempotencyKey: 'idem_deadline_race_cancel',
      expectedBookingRevision: 2,
      payload: { bookingId },
    }),
    processReconfirmationDeadlineJob(
      firestore,
      reconfirmationDeadlineJobId(bookingId, 8),
      deadline,
      'cancel-race-worker',
    ),
  ]);
  assert.equal((await bookingData(bookingId)).state, 'cancelled');
  assert.ok(cancellation.kind === 'succeeded' || cancellation.kind === 'rejected');
  assert.ok(worker === 'auto_cancelled' || worker === 'superseded' || worker === 'replayed');
  assert.equal(await finiteLedgerUnits(event), 0);
  assert.deepEqual(await usageCounts(actorId), { finite: 0, unlimited: 0 });
});

void test('discovery resumes after a page crash without duplicate jobs', async () => {
  const event = futureFiniteEvent();
  await seedEvent(event, firestore);
  for (const [bookingId, actorId, suffix] of [
    ['01JDEADLINEPAGEA0000000000', 'deadline-page-a', 'a'],
    ['01JDEADLINEPAGEB0000000000', 'deadline-page-b', 'b'],
  ] as const) {
    await createInternalBooking(
      { firestore, clock, newBookingId: () => bookingId },
      actorId,
      createCommand({ requestId: `req_page_${suffix}`, idempotencyKey: `idem_page_${suffix}` }),
    );
  }
  await applyMaterialReschedule(event, 8, fixedNow.toISOString(), 2);
  await assert.rejects(
    discoverReconfirmationDeadlineJobs(firestore, fixedNow.toISOString(), 1, () =>
      Promise.reject(new Error('simulated_page_crash')),
    ),
    /simulated_page_crash/u,
  );
  await discoverReconfirmationDeadlineJobs(firestore, fixedNow.toISOString(), 1);
  await discoverReconfirmationDeadlineJobs(firestore, fixedNow.toISOString(), 1);
  assert.equal(
    (await firestore.collection(bookingCollections.reconfirmationDeadlineJobs).get()).size,
    2,
  );
});

void test('dead letter requires audited replay and a newer material revision supersedes stale work', async () => {
  const event = futureFiniteEvent();
  const bookingId = '01JDEADLINEDEADLETTER000000';
  const actorId = 'deadline-dead-letter';
  await createRequiredBooking(event, bookingId, actorId, 8, fixedNow.toISOString());
  const jobId = reconfirmationDeadlineJobId(bookingId, 8);
  await ensureReconfirmationDeadlineJob(firestore, bookingId, fixedNow.toISOString());
  const usageRef = firestore
    .collection(bookingCollections.userUsage)
    .doc(bookingUserUsageId(actorId, 'LV'));
  const savedUsage = (await usageRef.get()).data();
  assert.ok(savedUsage !== undefined);
  await usageRef.delete();
  for (const offset of [0, 60_000, 6 * 60_000, 21 * 60_000, 81 * 60_000]) {
    await processReconfirmationDeadlineJob(
      firestore,
      jobId,
      new Date(fixedNow.getTime() + offset).toISOString(),
      `failure-${offset}`,
    );
  }
  assert.equal(
    (
      await firestore.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId).get()
    ).get('status'),
    'deadLetter',
  );
  await usageRef.set(savedUsage);
  assert.equal(
    await replayDeadLetterReconfirmationDeadline(
      firestore,
      jobId,
      new Date(fixedNow.getTime() + 82 * 60_000).toISOString(),
      {
        decisionId: 'decision-deadline-replay-1',
        actorId: 'operator-local',
        reason: 'fixture repaired',
        correlationId: 'correlation-deadline-replay-1',
      },
    ),
    'requeued',
  );
  assert.equal(
    await processReconfirmationDeadlineJob(
      firestore,
      jobId,
      new Date(fixedNow.getTime() + 82 * 60_000).toISOString(),
    ),
    'auto_cancelled',
  );

  const secondBookingId = '01JDEADLINESUPERSEDED000000';
  const secondActor = 'deadline-superseded';
  const secondEvent = finiteEvent({
    eventId: 'evt_01JDEADLINESECOND0000000',
    occurrenceId: 'occ_01JDEADLINESECOND0000000',
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
  await createRequiredBooking(
    secondEvent,
    secondBookingId,
    secondActor,
    8,
    fixedNow.toISOString(),
    {
      requestId: 'req_superseded_create',
      idempotencyKey: 'idem_superseded_create',
      payload: {
        occurrenceId: secondEvent.occurrenceId,
        inventoryPoolId: 'pool_general',
        channel: 'onsite',
        participantUnits: 1,
        namedGuests: [],
      },
    },
  );
  const staleJobId = reconfirmationDeadlineJobId(secondBookingId, 8);
  await ensureReconfirmationDeadlineJob(firestore, secondBookingId, fixedNow.toISOString());
  await applyMaterialReschedule(secondEvent, 9, '2026-08-29T13:00:00.000Z', 1);
  assert.equal(
    await processReconfirmationDeadlineJob(firestore, staleJobId, fixedNow.toISOString()),
    'superseded',
  );
  assert.equal((await bookingData(secondBookingId)).reconfirmationRequiredForRevision, 9);
});

function futureFiniteEvent(): BookingEventProjection {
  return finiteEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
}

async function createRequiredBooking(
  event: BookingEventProjection,
  bookingId: string,
  actorId: string,
  materialRevision: number,
  deadlineUtc: string,
  commandOverrides: Partial<ReturnType<typeof createCommand>> = {},
): Promise<void> {
  await seedEvent(event, firestore);
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand(commandOverrides),
  );
  assert.equal(created.kind, 'succeeded');
  await applyMaterialReschedule(event, materialRevision, deadlineUtc, 1);
}

async function applyMaterialReschedule(
  event: BookingEventProjection,
  materialRevision: number,
  deadlineUtc: string,
  expectedAffected: number,
): Promise<void> {
  const projection = {
    ...event,
    materialRevision,
    occurrenceStartsAt: deadlineUtc,
    occurrenceEndsAt: new Date(Date.parse(deadlineUtc) + 2 * 60 * 60_000).toISOString(),
  };
  const change: EventBookingProjectionEvent = {
    kind: 'EventMateriallyRescheduled',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: materialRevision,
    materialRevision,
    occurredAt: '2026-08-29T11:00:00.000Z',
    projection,
  };
  assert.equal((await consumeEventForBookingProjection(firestore, change)).kind, 'applied');
  assert.equal(
    (await applyOccurrenceLifecycleEffects(firestore, change)).affected,
    expectedAffected,
  );
}

async function bookingData(bookingId: string): Promise<Record<string, unknown>> {
  const snapshot = await firestore.collection(bookingCollections.bookings).doc(bookingId).get();
  assert.equal(snapshot.exists, true);
  return snapshot.data()!;
}

async function activeKeyExists(actorId: string, occurrenceId: string): Promise<boolean> {
  const snapshot = await firestore
    .collection(bookingCollections.activeKeys)
    .where('actorId', '==', actorId)
    .where('occurrenceId', '==', occurrenceId)
    .limit(1)
    .get();
  return !snapshot.empty;
}

async function finiteLedgerUnits(event: BookingEventProjection): Promise<number> {
  const snapshot = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(event.occurrenceId, event.poolId!, event.channel!))
    .get();
  const value: unknown = snapshot.get('confirmedUnits');
  if (typeof value !== 'number') throw new TypeError('confirmedUnits must be numeric');
  return value;
}

async function usageCounts(
  actorId: string,
): Promise<Readonly<{ finite: number; unlimited: number }>> {
  const snapshot = await firestore
    .collection(bookingCollections.userUsage)
    .doc(bookingUserUsageId(actorId, 'LV'))
    .get();
  return {
    finite: Number(snapshot.get('activeFiniteBookings')),
    unlimited: Number(snapshot.get('activeUnlimitedBookings')),
  };
}
