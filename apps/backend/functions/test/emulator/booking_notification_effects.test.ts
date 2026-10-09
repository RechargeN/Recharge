import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import {
  consumeEventForBookingProjection,
  type EventBookingProjectionEvent,
} from '../../src/booking/event_projection_consumer.js';
import {
  applyOccurrenceLifecycleEffects,
  cancelBookingForPrivacyErasure,
} from '../../src/booking/occurrence_lifecycle.js';
import { reconfirmInternalBooking } from '../../src/booking/reconfirm_internal_booking.js';
import { runReconfirmationDeadlineWorker } from '../../src/booking/reconfirmation_deadline_worker.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import { bookingNotificationFlagIds } from '../../src/shared/feature_flags.js';
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
import { setLocalFlag } from '../support/notifications_world.js';

/**
 * F1: the Booking producer. Off (default) every transition still writes the
 * unchanged v1 `suppressedPreActivation` record; on, the same transaction writes
 * the v2 OD-09 envelope with the explicit effect type and cause.
 */
const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);
const actorId = 'f1-producer-actor';

beforeEach(async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
});
after(async () => cleanupBookingEmulator(firestore));

function futureEvent(): BookingEventProjection {
  return finiteEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
}

async function outbox(): Promise<Record<string, Record<string, unknown>>> {
  const snapshot = await firestore.collection(bookingCollections.outbox).get();
  return Object.fromEntries(snapshot.docs.map((document) => [document.id, document.data()]));
}

async function create(bookingId: string, event = futureEvent()): Promise<void> {
  await seedEvent(event, firestore);
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand(),
  );
  assert.equal(created.kind, 'succeeded');
}

async function reschedule(event: BookingEventProjection, startsAt: string): Promise<void> {
  const change: EventBookingProjectionEvent = {
    kind: 'EventMateriallyRescheduled',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: 8,
    materialRevision: 8,
    occurredAt: '2026-08-29T11:00:00.000Z',
    projection: {
      ...event,
      materialRevision: 8,
      occurrenceStartsAt: startsAt,
      occurrenceEndsAt: new Date(Date.parse(startsAt) + 2 * 3_600_000).toISOString(),
    },
  };
  assert.equal((await consumeEventForBookingProjection(firestore, change)).kind, 'applied');
  assert.equal((await applyOccurrenceLifecycleEffects(firestore, change)).affected, 1);
}

void test('producer off: transitions write the unchanged v1 suppressedPreActivation record', async () => {
  await create('01JF1PRODUCEROFF0000000001');
  const cancelled = await cancelInternalBooking({ firestore, clock }, actorId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_f1_off',
    idempotencyKey: 'idem_f1_off',
    expectedBookingRevision: 1,
    payload: { bookingId: '01JF1PRODUCEROFF0000000001', reasonCode: 'user_request' },
  });
  assert.equal(cancelled.kind, 'succeeded');
  const records = await outbox();
  assert.deepEqual(Object.keys(records).sort(), [
    '01JF1PRODUCEROFF0000000001__r1',
    '01JF1PRODUCEROFF0000000001__r2',
  ]);
  for (const record of Object.values(records)) {
    assert.equal(record.schemaVersion, 1);
    assert.equal(record.effectDisposition, 'suppressedPreActivation');
    assert.equal(record.dispatchable, false);
  }
});

void test('producer on: create and user cancel write v2 envelopes atomically', async () => {
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  const bookingId = '01JF1PRODUCERON00000000001';
  await create(bookingId);
  const cancelled = await cancelInternalBooking({ firestore, clock }, actorId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_f1_on',
    idempotencyKey: 'idem_f1_on',
    expectedBookingRevision: 1,
    payload: { bookingId, reasonCode: 'user_request' },
  });
  assert.equal(cancelled.kind, 'succeeded');
  const records = await outbox();
  const confirmed = records[`${bookingId}__r1`]!;
  const cancellation = records[`${bookingId}__r2`]!;
  assert.equal(confirmed.schemaVersion, 2);
  assert.equal(confirmed.eventId, `${bookingId}__r1`);
  assert.equal(confirmed.eventType, 'booking.confirmed');
  assert.equal(confirmed.actorId, actorId);
  assert.match(String(confirmed.correlationId), /^m1_/u);
  assert.equal(cancellation.eventType, 'booking.cancelled');
  assert.equal((cancellation.payload as Record<string, unknown>).cause, 'userCancelled');
  assert.equal(cancellation.aggregateRevision, 2);
  assert.ok(cancellation.expiresAt !== undefined);
});

void test('producer on: reschedule requires reconfirmation, then the user reconfirms', async () => {
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  const bookingId = '01JF1PRODUCERRECONFIRM0001';
  const event = futureEvent();
  await create(bookingId, event);
  await reschedule(event, '2026-08-31T12:00:00.000Z');
  const reconfirmed = await reconfirmInternalBooking(
    { firestore, clock },
    actorId,
    reconfirmCommand(bookingId),
  );
  assert.equal(reconfirmed.kind, 'succeeded');
  const records = await outbox();
  const required = records[`${bookingId}__r2`]!;
  assert.equal(required.eventType, 'booking.reconfirmationRequired');
  const payload = required.payload as Record<string, unknown>;
  assert.equal(typeof payload.reconfirmationDeadlineUtc, 'string');
  assert.ok(
    Date.parse(String(payload.deliverUntilUtc)) <=
      Date.parse(String(payload.reconfirmationDeadlineUtc)),
  );
  assert.match(String(required.correlationId), /^occ_[0-9a-f]{32}$/u);
  assert.equal(records[`${bookingId}__r3`]!.eventType, 'booking.reconfirmed');
});

void test('producer on: an occurrence cancellation and a privacy erasure carry their causes', async () => {
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  const event = futureEvent();
  await create('01JF1PRODUCEROCCURRENCE001', event);
  const cancellation: EventBookingProjectionEvent = {
    kind: 'EventOccurrenceCancelled',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: 9,
    materialRevision: 1,
    occurredAt: '2026-08-29T11:30:00.000Z',
  };
  await consumeEventForBookingProjection(firestore, cancellation);
  assert.equal((await applyOccurrenceLifecycleEffects(firestore, cancellation)).affected, 1);
  const occurrence = (await outbox())['01JF1PRODUCEROCCURRENCE001__r2']!;
  assert.equal((occurrence.payload as Record<string, unknown>).cause, 'occurrenceCancelled');

  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  await create('01JF1PRODUCERPRIVACY000001');
  assert.equal(
    await cancelBookingForPrivacyErasure(
      firestore,
      '01JF1PRODUCERPRIVACY000001',
      fixedNow.toISOString(),
    ),
    true,
  );
  const privacy = (await outbox())['01JF1PRODUCERPRIVACY000001__r2']!;
  assert.equal((privacy.payload as Record<string, unknown>).cause, 'privacyErasure');
  assert.match(String(privacy.correlationId), /^prv_[0-9a-f]{32}$/u);
});

void test('producer on: the deadline worker cancellation carries missedReconfirmation', async () => {
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  const bookingId = '01JF1PRODUCERDEADLINE00001';
  const event = futureEvent();
  await create(bookingId, event);
  await reschedule(event, fixedNow.toISOString());
  await runReconfirmationDeadlineWorker(firestore, fixedNow.toISOString());
  const missed = (await outbox())[`${bookingId}__r3`]!;
  assert.equal(missed.eventType, 'booking.cancelled');
  assert.equal((missed.payload as Record<string, unknown>).cause, 'missedReconfirmation');
  assert.match(String(missed.correlationId), /^brd1_/u);
});
