import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createSuppressedOutbox } from '../../../src/notifications/outbox.js';
import {
  notificationEffectSha256,
  notificationIdFor,
  notificationReceiptId,
  parseNotificationEffect,
} from '../../../src/modules/notifications/domain/notification_effect.js';
import { bookingEffect } from '../../support/notifications_world.js';

void test('a Booking v2 record parses into the OD-09 effect with the subject as recipient', () => {
  const { id, data } = bookingEffect({
    effect: { kind: 'cancelled', cause: 'occurrenceCancelled' },
    revision: 2,
  });
  const parsed = parseNotificationEffect(id, data);
  assert.equal(parsed.kind, 'effect');
  if (parsed.kind !== 'effect') return;
  assert.equal(parsed.effect.eventId, '01JF1BOOKING00000000000001__r2');
  assert.equal(parsed.effect.eventType, 'booking.cancelled');
  assert.equal(parsed.effect.cause, 'occurrenceCancelled');
  assert.equal(parsed.effect.recipientId, 'recipient-1');
  assert.equal(parsed.effect.aggregateRevision, 2);
  assert.equal(parsed.effect.deliverUntilUtc, '2026-09-05T12:00:00.000Z');
});

void test('v1 suppressedPreActivation records are never activated', () => {
  const v1 = createSuppressedOutbox(
    'booking_confirmation',
    'booking',
    'actor',
    '2026-08-29T00:00:00Z',
  );
  assert.deepEqual(parseNotificationEffect('booking__r1', v1), { kind: 'not_dispatchable' });
  assert.deepEqual(
    parseNotificationEffect('booking__r1', { ...bookingEffect().data, dispatchable: false }),
    { kind: 'not_dispatchable' },
  );
});

void test('unknown versions or types are quarantined; malformed envelopes are invalid', () => {
  const { id, data } = bookingEffect();
  assert.deepEqual(parseNotificationEffect(id, { ...data, eventVersion: 2 }), {
    kind: 'invalid',
    code: 'unsupported_effect',
  });
  assert.deepEqual(parseNotificationEffect(id, { ...data, eventType: 'booking.teleported' }), {
    kind: 'invalid',
    code: 'unsupported_effect',
  });
  for (const broken of [
    { ...data, eventId: 'other__r1' },
    { ...data, producer: 'content' },
    { ...data, extra: true },
    { ...data, actorId: 'has space' },
    { ...data, payload: { ...(data.payload as object), recipientId: 'leak' } },
    { ...data, payload: { ...(data.payload as object), cause: 'userCancelled' } },
    { ...data, occurredAt: '2026-08-29' },
  ])
    assert.deepEqual(parseNotificationEffect(id, broken), {
      kind: 'invalid',
      code: 'invalid_effect',
    });
  assert.deepEqual(parseNotificationEffect(id, null), { kind: 'invalid', code: 'invalid_effect' });
});

void test('consumer identities are distinct, stable and free of person identifiers', () => {
  const eventId = '01JF1BOOKING00000000000001__r1';
  const receiptId = notificationReceiptId(eventId);
  assert.match(receiptId, /^nrc_[0-9a-f]{40}$/u);
  assert.equal(notificationReceiptId(eventId), receiptId);
  assert.notEqual(notificationReceiptId('01JF1BOOKING00000000000001__r2'), receiptId);
  const notificationId = notificationIdFor(receiptId);
  assert.match(notificationId, /^ntf_[0-9a-f]{32}$/u);
  assert.notEqual(notificationId.slice(4), receiptId.slice(4, 36));
  const first = parseNotificationEffect(eventId, bookingEffect().data);
  const second = parseNotificationEffect(
    eventId,
    bookingEffect({ recipientId: 'someone-else' }).data,
  );
  assert.ok(first.kind === 'effect' && second.kind === 'effect');
  assert.notEqual(notificationEffectSha256(first.effect), notificationEffectSha256(second.effect));
});
