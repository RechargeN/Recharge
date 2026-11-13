import assert from 'node:assert/strict';
import test from 'node:test';

import type { App } from 'firebase-admin/app';

import { FcmPushProvider } from '../../../src/modules/notifications/infrastructure/fcm_push_provider.js';

// N3c (2026-11-13, OD-07): the FCM message shape and the answer classes,
// against a stub of the Admin SDK (no network).

const message = {
  token: `fcm-token-${'b'.repeat(40)}`,
  notificationId: 'ntf_0123',
  category: 'booking.changes' as const,
  title: 'Recharge',
  body: 'You have a new notification.',
  ttlSeconds: 86_400,
};

void test('a generic hint with opaque ids, normal priority and the policy TTL', async () => {
  const sent: unknown[] = [];
  const provider = new FcmPushProvider({} as App, {
    send: (payload) => {
      sent.push(payload);
      return Promise.resolve('projects/p/messages/1');
    },
  });
  assert.deepEqual(await provider.send(message), {
    kind: 'accepted',
    providerMessageId: 'projects/p/messages/1',
  });
  assert.deepEqual(sent[0], {
    token: message.token,
    notification: { title: 'Recharge', body: 'You have a new notification.' },
    data: { notificationId: 'ntf_0123', category: 'booking.changes' },
    android: {
      priority: 'normal',
      ttl: 86_400_000,
      notification: { channelId: 'recharge_default' },
    },
  });
});

void test('provider errors become invalid_token, transient or rejected', async () => {
  const failing = (code: unknown) =>
    new FcmPushProvider({} as App, {
      send: () => Promise.reject(Object.assign(new Error('x'), { code })),
    });
  assert.equal(
    (await failing('messaging/registration-token-not-registered').send(message)).kind,
    'invalid_token',
  );
  assert.equal((await failing('messaging/server-unavailable').send(message)).kind, 'transient');
  assert.equal((await failing('messaging/invalid-argument').send(message)).kind, 'rejected');
  assert.deepEqual(await failing({ weird: true }).send(message), {
    kind: 'rejected',
    code: 'unknown',
  });
});
