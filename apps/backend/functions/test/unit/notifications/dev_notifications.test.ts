import assert from 'node:assert/strict';
import test from 'node:test';

import {
  devNotificationsCallables,
  selfTestEffect,
} from '../../../src/dev_notifications_composition.js';
import { devNotificationsOpen } from '../../../src/dev_notifications_entry.js';
import { parseNotificationEffect } from '../../../src/modules/notifications/domain/notification_effect.js';

// N3c (2026-11-13): the dev-cloud Notifications runtime is closed unless every
// switch is set; the owner's self-test is an ordinary, strictly valid effect.

const uid = 'abcdefghijklmnopqrstuvwxyz012345';
const open = {
  GCLOUD_PROJECT: 'recharge-dev-n2a01',
  N3C_DEV_ENABLED: 'true',
  N3C_ALLOWED_FIREBASE_UIDS: uid,
};

void test('closed unless dev project, switch on, exact allowlist and no Emulator', () => {
  assert.deepEqual(devNotificationsOpen(open), [uid]);
  for (const broken of [
    { ...open, GCLOUD_PROJECT: 'recharge-prod' },
    { ...open, N3C_DEV_ENABLED: 'false' },
    { ...open, N3C_ALLOWED_FIREBASE_UIDS: '' },
    { ...open, N3C_ALLOWED_FIREBASE_UIDS: 'bad uid' },
    { ...open, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
  ])
    assert.equal(devNotificationsOpen(broken), null, JSON.stringify(broken));
  assert.deepEqual(
    [...devNotificationsCallables],
    [
      'notificationsQueryV1',
      'notificationsCommandV1',
      'pushDeviceCommandV1',
      'sendSelfTestNotificationV1',
    ],
  );
});

void test('the self-test is a strictly valid Booking v2 effect for the caller only', () => {
  const effect = selfTestEffect('user-1', '2026-11-13T10:00:00.000Z', 'fixed-id');
  const parsed = parseNotificationEffect(effect.eventId, effect.data);
  assert.equal(parsed.kind, 'effect');
  if (parsed.kind !== 'effect') return;
  assert.equal(parsed.effect.recipientId, 'user-1');
  assert.equal(parsed.effect.eventType, 'booking.confirmed');
  assert.equal(effect.eventId, 'devselftest_fixed-id');
});
