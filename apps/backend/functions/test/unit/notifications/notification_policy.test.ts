import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  applyPreferenceUpdate,
  defaultNotificationPolicies,
  inAppDecision,
  parseStoredPreferences,
  PreferencesUnreadable,
  type NotificationPreferences,
} from '../../../src/modules/notifications/domain/notification_policy.js';
import { parseNotificationEffect } from '../../../src/modules/notifications/domain/notification_effect.js';
import type { BookingNotificationEffect } from '../../../src/booking/notification_effects.js';
import { bookingEffect } from '../../support/notifications_world.js';

const policy = defaultNotificationPolicies.active();

function route(effect: BookingNotificationEffect) {
  const { id, data } = bookingEffect({ effect });
  const parsed = parseNotificationEffect(id, data);
  assert.equal(parsed.kind, 'effect');
  return policy.route((parsed as { effect: Parameters<typeof policy.route>[0] }).effect);
}

void test('local policy rev 1 maps every allowed effect to an explicit category and template', () => {
  assert.deepEqual(route({ kind: 'confirmed' }), {
    kind: 'deliver',
    category: 'booking.receipts',
    templateKey: 'booking.confirmed',
  });
  assert.deepEqual(route({ kind: 'cancelled', cause: 'userCancelled' }), {
    kind: 'deliver',
    category: 'booking.receipts',
    templateKey: 'booking.cancelled.byUser',
  });
  assert.deepEqual(route({ kind: 'reconfirmed' }), {
    kind: 'deliver',
    category: 'booking.receipts',
    templateKey: 'booking.reconfirmed',
  });
  assert.deepEqual(route({ kind: 'cancelled', cause: 'occurrenceCancelled' }), {
    kind: 'deliver',
    category: 'booking.changes',
    templateKey: 'booking.cancelled.occurrence',
  });
  assert.deepEqual(route({ kind: 'cancelled', cause: 'missedReconfirmation' }), {
    kind: 'deliver',
    category: 'booking.changes',
    templateKey: 'booking.cancelled.missedReconfirmation',
  });
  assert.deepEqual(
    route({
      kind: 'reconfirmationRequired',
      reconfirmationDeadlineUtc: '2026-08-30T12:00:00.000Z',
    }),
    { kind: 'deliver', category: 'booking.changes', templateKey: 'booking.reconfirmationRequired' },
  );
  assert.deepEqual(route({ kind: 'cancelled', cause: 'privacyErasure' }), {
    kind: 'suppress',
    reason: 'recipient_erasure',
  });
});

void test('Booking notifications are not all mandatory: only booking.changes is locked', () => {
  assert.deepEqual(policy.categories['booking.receipts'], { inAppDefault: true, locked: false });
  assert.deepEqual(policy.categories['booking.changes'], { inAppDefault: true, locked: true });
  assert.deepEqual([...policy.channels], ['inApp']);
});

function preferences(categories: NotificationPreferences['categories']): NotificationPreferences {
  return {
    schemaVersion: 1,
    userId: 'user-1',
    revision: 1,
    policyRevision: 1,
    categories,
    processingRestricted: false,
    updatedAtUtc: '2026-08-29T12:00:00.000Z',
  };
}

void test('a preference switches booking.receipts off but never a locked category', () => {
  const off = preferences({ 'booking.receipts': { inApp: false } });
  assert.deepEqual(inAppDecision(policy, off, 'booking.receipts'), {
    enabled: false,
    locked: false,
  });
  assert.deepEqual(inAppDecision(policy, undefined, 'booking.receipts'), {
    enabled: true,
    locked: false,
  });
  assert.deepEqual(inAppDecision(policy, off, 'booking.changes'), { enabled: true, locked: true });
});

void test('updates are versioned and refuse locked, unknown and out-of-policy channels', () => {
  const base = {
    policy,
    current: undefined,
    userId: 'user-1',
    expectedRevision: 0,
    nowUtc: '2026-08-29T12:00:00.000Z',
  } as const;
  const updated = applyPreferenceUpdate({
    ...base,
    categories: { 'booking.receipts': { inApp: false } },
  });
  assert.equal(updated.kind, 'updated');
  if (updated.kind !== 'updated') return;
  assert.equal(updated.preferences.revision, 1);
  assert.deepEqual(updated.preferences.categories, { 'booking.receipts': { inApp: false } });
  const refusals: [unknown, string][] = [
    [{ 'booking.changes': { inApp: false } }, 'category_locked'],
    [{ 'booking.marketing': { inApp: true } }, 'category_unknown'],
    [{ 'booking.receipts': { push: true } }, 'channel_unknown'],
    [{ 'booking.receipts': { email: true } }, 'channel_unknown'],
    [{ 'booking.receipts': { sms: true } }, 'channel_unknown'],
    [{ 'booking.receipts': { inApp: 'no' } }, 'channel_value_invalid'],
    [{ 'booking.receipts': {} }, 'channels_invalid'],
    [{}, 'categories_empty'],
    [[], 'categories_invalid'],
  ];
  for (const [categories, detail] of refusals)
    assert.deepEqual(applyPreferenceUpdate({ ...base, categories }), {
      kind: 'invalid_preference',
      detail,
    });
  assert.deepEqual(
    applyPreferenceUpdate({
      ...base,
      current: updated.preferences,
      expectedRevision: 0,
      categories: { 'booking.receipts': { inApp: true } },
    }),
    { kind: 'stale_revision' },
  );
  const restricted = { ...updated.preferences, processingRestricted: true };
  const next = applyPreferenceUpdate({
    ...base,
    current: restricted,
    expectedRevision: 1,
    categories: { 'booking.receipts': { inApp: true } },
  });
  assert.equal(next.kind === 'updated' && next.preferences.processingRestricted, true);
});

void test('stored preferences parse strictly and fail closed', () => {
  const stored = preferences({ 'booking.receipts': { inApp: false } });
  assert.deepEqual(parseStoredPreferences('user-1', stored), stored);
  for (const broken of [
    null,
    { ...stored, userId: 'user-2' },
    { ...stored, categories: { 'booking.changes': { inApp: true, push: true } } },
    { ...stored, categories: { unknown: { inApp: true } } },
    { ...stored, processingRestricted: 'no' },
  ])
    assert.throws(() => parseStoredPreferences('user-1', broken), PreferencesUnreadable);
});
