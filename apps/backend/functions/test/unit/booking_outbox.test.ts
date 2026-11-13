import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createSuppressedOutbox, suppressedOutboxId } from '../../src/notifications/outbox.js';

void test('pre-activation outbox is explicitly suppressed and non-replayable', () => {
  const record = createSuppressedOutbox(
    'booking_confirmation',
    'booking',
    'actor',
    '2026-08-29T00:00:00Z',
  );
  assert.deepEqual(record, {
    schemaVersion: 1,
    effectDisposition: 'suppressedPreActivation',
    policyRevision: 1,
    dispatchable: false,
    replayable: false,
    obligationType: 'booking_confirmation',
    bookingId: 'booking',
    actorId: 'actor',
    createdAt: '2026-08-29T00:00:00Z',
    suppressedAt: '2026-08-29T00:00:00Z',
    retentionClass: 'bookingOutbox',
    legalHold: false,
    expiresAt: new Date('2026-09-28T00:00:00.000Z'),
  });
  assert.equal(record.expiresAt.toISOString(), '2026-09-28T00:00:00.000Z');
  assert.equal(suppressedOutboxId('booking', 2), 'booking__r2');
});
