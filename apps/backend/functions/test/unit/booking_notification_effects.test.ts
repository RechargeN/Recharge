import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  bookingOutboxRecord,
  systemCorrelationId,
  type BookingNotificationEffect,
} from '../../src/booking/notification_effects.js';
import { createSuppressedOutbox } from '../../src/notifications/outbox.js';

const booking = {
  id: '01JF1BOOKING00000000000001',
  userId: 'actor-1',
  marketId: 'LV' as const,
  eventId: 'evt-1',
  occurrenceId: 'occ-1',
};
const input = (effect: BookingNotificationEffect) => ({
  effect,
  booking,
  actorId: 'actor-1',
  revision: 2,
  occurredAt: '2026-08-29T12:00:00.000Z',
  correlationId: 'm1_abc',
});

void test('an inactive producer writes exactly the previous v1 record', () => {
  const cases: [
    BookingNotificationEffect,
    'booking_confirmation' | 'booking_cancellation' | 'booking_reconfirmation',
  ][] = [
    [{ kind: 'confirmed' }, 'booking_confirmation'],
    [{ kind: 'cancelled', cause: 'userCancelled' }, 'booking_cancellation'],
    [{ kind: 'cancelled', cause: 'privacyErasure' }, 'booking_cancellation'],
    [{ kind: 'reconfirmed' }, 'booking_reconfirmation'],
    [
      { kind: 'reconfirmationRequired', reconfirmationDeadlineUtc: '2026-08-30T00:00:00.000Z' },
      'booking_reconfirmation',
    ],
  ];
  for (const [effect, obligation] of cases)
    assert.deepEqual(
      bookingOutboxRecord(false, input(effect)),
      createSuppressedOutbox(obligation, booking.id, 'actor-1', '2026-08-29T12:00:00.000Z'),
    );
});

void test('an active producer writes the OD-09 envelope with a minimal payload', () => {
  const record = bookingOutboxRecord(
    true,
    input({ kind: 'cancelled', cause: 'occurrenceCancelled' }),
  );
  assert.deepEqual(record, {
    schemaVersion: 2,
    effectDisposition: 'pending',
    dispatchable: true,
    replayable: true,
    eventId: '01JF1BOOKING00000000000001__r2',
    eventType: 'booking.cancelled',
    eventVersion: 1,
    producer: 'booking',
    aggregateType: 'booking',
    aggregateId: booking.id,
    aggregateRevision: 2,
    occurredAt: '2026-08-29T12:00:00.000Z',
    correlationId: 'm1_abc',
    marketId: 'LV',
    dataClass: 'personal',
    payload: {
      schemaVersion: 1,
      eventContentId: 'evt-1',
      occurrenceId: 'occ-1',
      cause: 'occurrenceCancelled',
      deliverUntilUtc: '2026-09-05T12:00:00.000Z',
    },
    actorId: 'actor-1',
    createdAt: '2026-08-29T12:00:00.000Z',
    retentionClass: 'bookingOutbox',
    legalHold: false,
    expiresAt: new Date('2026-10-05T12:00:00.000Z'),
  });
});

void test('reconfirmation relevance ends at the earlier of the window and the deadline', () => {
  const record = bookingOutboxRecord(
    true,
    input({
      kind: 'reconfirmationRequired',
      reconfirmationDeadlineUtc: '2026-08-30T00:00:00.000Z',
    }),
  );
  assert.equal(record.schemaVersion, 2);
  if (record.schemaVersion !== 2) return;
  assert.equal(record.eventType, 'booking.reconfirmationRequired');
  assert.equal(record.payload.reconfirmationDeadlineUtc, '2026-08-30T00:00:00.000Z');
  assert.equal(record.payload.deliverUntilUtc, '2026-08-30T00:00:00.000Z');
  assert.equal(record.expiresAt.toISOString(), '2026-09-29T00:00:00.000Z');
});

void test('system correlations are deterministic and prefixed', () => {
  const first = systemCorrelationId('occ', [
    'EventOccurrenceCancelled',
    'evt-1',
    'occ-1',
    '2',
    '1',
  ]);
  assert.match(first, /^occ_[0-9a-f]{32}$/u);
  assert.equal(
    first,
    systemCorrelationId('occ', ['EventOccurrenceCancelled', 'evt-1', 'occ-1', '2', '1']),
  );
  assert.notEqual(
    first,
    systemCorrelationId('occ', ['EventOccurrenceCancelled', 'evt-1', 'occ-1', '3', '1']),
  );
});
