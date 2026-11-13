import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import { consumeEventForBookingProjection } from '../../src/booking/event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from '../../src/booking/occurrence_lifecycle.js';
import { reconfirmInternalBooking } from '../../src/booking/reconfirm_internal_booking.js';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
} from '../../src/booking/transactions.js';
import { bookingIdentityCollections } from '../../src/booking/firestore_booking_access_authority.js';
import {
  bookingSessionContextFor,
  callBookingFunction,
  cleanupBookingEmulator,
  createAuthorizedActor,
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

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

beforeEach(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test('material reschedule requires exact-revision reconfirmation without touching allocation', async () => {
  const event = futureEvent();
  await seedEvent(event, firestore);
  const bookingId = '01JRECONFIRMBOOKING00000000';
  const actorId = 'actor-reconfirm';
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand(),
  );
  assert.equal(created.kind, 'succeeded');
  await applyMaterialReschedule(event, 8, '2026-08-31T12:00:00.000Z');

  const required = await bookingData(bookingId);
  assert.equal(required.revision, 2);
  assert.equal(required.reconfirmationState, 'required');
  assert.equal(required.reconfirmationRequiredForRevision, 8);
  assert.equal(required.reconfirmationDeadlineUtc, '2026-08-31T12:00:00.000Z');
  const ledgerBefore = await ledgerUnits(event);
  const usageBefore = await usageCounts(actorId);

  const command = reconfirmCommand(bookingId);
  const result = await reconfirmInternalBooking({ firestore, clock }, actorId, command);
  assert.equal(result.kind, 'succeeded');
  if (result.kind !== 'succeeded') return;
  assert.equal(result.data.outcome, 'reconfirmed');
  assert.equal(result.data.booking.reconfirmationState, 'confirmed');
  assert.equal(result.data.booking.revision, 3);
  assert.deepEqual(await ledgerUnits(event), ledgerBefore);
  assert.deepEqual(await usageCounts(actorId), usageBefore);

  const replay = await reconfirmInternalBooking({ firestore, clock }, actorId, {
    ...command,
    requestId: 'req_reconfirm_retry',
  });
  assert.equal(replay.kind, 'succeeded');
  if (replay.kind === 'succeeded') assert.equal(replay.data.replayed, true);
  assert.equal((await firestore.collection(bookingCollections.audit).get()).size, 3);
  assert.deepEqual(
    (await firestore.collection(bookingCollections.outbox).get()).docs
      .map((document) => readString(document.data(), 'obligationType'))
      .sort(),
    ['booking_confirmation', 'booking_reconfirmation', 'booking_reconfirmation'],
  );
});

void test('reconfirm exposes typed stale, material, deadline and not-required outcomes', async () => {
  const event = futureEvent();
  await seedEvent(event, firestore);
  const actorId = 'actor-reconfirm-outcomes';
  const bookingId = '01JRECONFIRMFAILURES0000000';
  await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand({ requestId: 'req_outcomes_create', idempotencyKey: 'idem_outcomes_create' }),
  );
  assert.deepEqual(
    await reconfirmInternalBooking(
      { firestore, clock },
      actorId,
      reconfirmCommand(bookingId, {
        expectedBookingRevision: 1,
        payload: { bookingId, materialRevision: 7 },
      }),
    ),
    { kind: 'rejected', code: 'reconfirmation_not_required' },
  );
  await applyMaterialReschedule(event, 8, '2026-08-31T12:00:00.000Z');
  assert.deepEqual(
    await reconfirmInternalBooking(
      { firestore, clock },
      actorId,
      reconfirmCommand(bookingId, { expectedBookingRevision: 1 }),
    ),
    { kind: 'rejected', code: 'revision_conflict' },
  );
  assert.deepEqual(
    await reconfirmInternalBooking(
      { firestore, clock },
      actorId,
      reconfirmCommand(bookingId, {
        requestId: 'req_material_mismatch',
        idempotencyKey: 'idem_material_mismatch',
        payload: { bookingId, materialRevision: 7 },
      }),
    ),
    { kind: 'rejected', code: 'material_revision_mismatch' },
  );
  assert.deepEqual(
    await reconfirmInternalBooking(
      { firestore, clock },
      'other-actor',
      reconfirmCommand(bookingId, {
        requestId: 'req_wrong_owner_reconfirm',
        idempotencyKey: 'idem_wrong_owner_reconfirm',
      }),
    ),
    { kind: 'rejected', code: 'permission_denied' },
  );

  await applyMaterialReschedule(event, 9, fixedNow.toISOString());
  const expired = await bookingData(bookingId);
  assert.equal(expired.reconfirmationRequiredForRevision, 9);
  assert.deepEqual(
    await reconfirmInternalBooking(
      { firestore, clock },
      actorId,
      reconfirmCommand(bookingId, {
        requestId: 'req_deadline_reconfirm',
        idempotencyKey: 'idem_deadline_reconfirm',
        expectedBookingRevision: Number(expired.revision),
        payload: { bookingId, materialRevision: 9 },
      }),
    ),
    { kind: 'rejected', code: 'reconfirmation_deadline_passed' },
  );
});

void test('later material reschedule invalidates the prior response and non-material event does not', async () => {
  const event = futureEvent();
  await seedEvent(event, firestore);
  const actorId = 'actor-reconfirm-twice';
  const bookingId = '01JRECONFIRMTWICE000000000';
  await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand({ requestId: 'req_twice_create', idempotencyKey: 'idem_twice_create' }),
  );
  await applyMaterialReschedule(event, 8, '2026-08-31T12:00:00.000Z');
  const first = await reconfirmInternalBooking(
    { firestore, clock },
    actorId,
    reconfirmCommand(bookingId),
  );
  assert.equal(first.kind, 'succeeded');
  await applyMaterialReschedule(event, 9, '2026-09-01T12:00:00.000Z');
  const secondRequired = await bookingData(bookingId);
  assert.equal(secondRequired.reconfirmationState, 'required');
  assert.equal(secondRequired.reconfirmationRequiredForRevision, 9);
  assert.equal(secondRequired.revision, 4);

  const nonMaterial: EventBookingProjectionEvent = {
    kind: 'EventRevisionPublished',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: 10,
    materialRevision: 9,
    occurredAt: '2026-08-29T11:30:00.000Z',
    projection: { ...event, materialRevision: 9, occurrenceStartsAt: '2026-09-01T12:00:00.000Z' },
  };
  assert.deepEqual(await applyOccurrenceLifecycleEffects(firestore, nonMaterial), {
    affected: 0,
    processed: 0,
  });
  assert.deepEqual(await bookingData(bookingId), secondRequired);
});

void test('required reconfirmation keeps owner cancellation available after the normal deadline', async () => {
  const event = futureEvent({ cancellationDeadline: fixedNow.toISOString() });
  await seedEvent(event, firestore);
  const actorId = 'actor-reconfirm-cancel';
  const bookingId = '01JRECONFIRMCANCEL00000000';
  await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand({ requestId: 'req_rc_create', idempotencyKey: 'idem_rc_create' }),
  );
  await applyMaterialReschedule(event, 8, '2026-08-31T12:00:00.000Z');
  const cancelled = await cancelInternalBooking({ firestore, clock }, actorId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_rc_cancel',
    idempotencyKey: 'idem_rc_cancel',
    expectedBookingRevision: 2,
    payload: { bookingId },
  });
  assert.equal(cancelled.kind, 'succeeded');
  assert.equal((await bookingData(bookingId)).state, 'cancelled');
});

void test('callable reconfirm fails closed for a revoked Session', async () => {
  const event = futureEvent({
    occurrenceStartsAt: '2099-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2099-08-30T14:00:00.000Z',
    registrationWindow: {
      opensAt: '2020-01-01T00:00:00.000Z',
      closesAt: '2099-08-30T11:00:00.000Z',
    },
  });
  await seedEvent(event, firestore);
  await setBookingFlags(true, firestore);
  const uid = 'reconfirm-revoked-session';
  const token = await createAuthorizedActor(uid);
  const createdResponse = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({
      requestId: 'req_callable_reconfirm_create',
      idempotencyKey: 'idem_callable_reconfirm_create',
    }),
    token,
  );
  const created = createdResponse.body.result as Record<string, unknown>;
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
  const booking = created.booking as Record<string, unknown>;
  await applyMaterialReschedule(event, 8, '2099-09-01T12:00:00.000Z');
  const sessionId = bookingSessionContextFor(uid).sessionId;
  await firestore
    .collection(bookingIdentityCollections.sessions)
    .doc(sessionId)
    .update({ status: 'revoked', revision: 2 });
  const response = await callBookingFunction(
    'reconfirmInternalBookingV1',
    reconfirmCommand(String(booking.id)),
    token,
  );
  const result = response.body.result as Record<string, unknown>;
  assert.equal(result.kind, 'rejected');
  assert.equal((result.error as Record<string, unknown>).code, 'session_revoked');
});

function futureEvent(overrides: Partial<ReturnType<typeof finiteEvent>> = {}) {
  return finiteEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
    ...overrides,
  });
}

async function applyMaterialReschedule(
  event: ReturnType<typeof futureEvent>,
  materialRevision: number,
  occurrenceStartsAt: string,
): Promise<void> {
  const projection = {
    ...event,
    materialRevision,
    occurrenceStartsAt,
    occurrenceEndsAt: new Date(Date.parse(occurrenceStartsAt) + 2 * 60 * 60_000).toISOString(),
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
  const projectionResult = await consumeEventForBookingProjection(firestore, change);
  assert.equal(projectionResult.kind, 'applied');
  const lifecycle = await applyOccurrenceLifecycleEffects(firestore, change);
  assert.equal(lifecycle.affected, 1);
}

async function bookingData(bookingId: string): Promise<Record<string, unknown>> {
  const snapshot = await firestore.collection(bookingCollections.bookings).doc(bookingId).get();
  assert.equal(snapshot.exists, true);
  return snapshot.data()!;
}

async function ledgerUnits(event: ReturnType<typeof futureEvent>) {
  const snapshot = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(event.occurrenceId, event.poolId!, event.channel!))
    .get();
  return {
    confirmedUnits: readNumber(snapshot.data(), 'confirmedUnits'),
    totalCapacity: readNumber(snapshot.data(), 'totalCapacity'),
  };
}

async function usageCounts(actorId: string) {
  const snapshot = await firestore
    .collection(bookingCollections.userUsage)
    .doc(bookingUserUsageId(actorId, 'LV'))
    .get();
  return {
    activeFiniteBookings: readNumber(snapshot.data(), 'activeFiniteBookings'),
    activeUnlimitedBookings: readNumber(snapshot.data(), 'activeUnlimitedBookings'),
  };
}

function readString(data: Record<string, unknown> | undefined, field: string): string {
  const value = data?.[field];
  if (typeof value !== 'string') throw new TypeError(`${field} must be a string`);
  return value;
}

function readNumber(data: Record<string, unknown> | undefined, field: string): number {
  const value = data?.[field];
  if (typeof value !== 'number') throw new TypeError(`${field} must be a number`);
  return value;
}
