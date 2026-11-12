import assert from 'node:assert/strict';
import test from 'node:test';

import { PushDispatcher } from '../../../src/modules/notifications/application/push_dispatcher.js';
import type { NotificationPreferences } from '../../../src/modules/notifications/domain/notification_policy.js';
import {
  applyPreferenceUpdate,
  defaultNotificationPolicies,
  notificationPolicyRevisionOne,
  parseStoredPreferences,
} from '../../../src/modules/notifications/domain/notification_policy.js';
import {
  classifyProviderError,
  pushAttemptId,
  pushConfig,
} from '../../../src/modules/notifications/domain/push.js';
import { FakePushProvider } from '../../../src/modules/notifications/infrastructure/fake_push_provider.js';
import { InMemoryPushStore } from '../../../src/modules/notifications/infrastructure/in_memory_push_store.js';

// N3c (owner-approved 2026-11-13): FCM push after the inbox item, server-only
// tokens, one token one user, preferences, daily limit, idempotency, retry ->
// dead letter, invalid-token revocation, reconciliation and DSR erasure.

const user = 'user-1';
const other = 'user-2';
const token = `fcm-token-${'a'.repeat(40)}`;

function world(options?: {
  readonly sessions?: Set<string>;
  readonly prefs?: NotificationPreferences;
}) {
  let now = Date.parse('2026-11-13T10:00:00.000Z');
  const store = new InMemoryPushStore();
  const provider = new FakePushProvider();
  const sessions =
    options?.sessions ?? new Set([`${user}|inst-1`, `${other}|inst-2`, `${user}|inst-3`]);
  const logs: Record<string, unknown>[] = [];
  const dispatcher = new PushDispatcher({
    store,
    provider,
    sessions: {
      activeSession: (userId, installationId) =>
        Promise.resolve(sessions.has(`${userId}|${installationId}`)),
    },
    preferences: () => Promise.resolve(options?.prefs),
    clock: { now: () => new Date(now) },
    log: (event, fields) => logs.push({ event, ...fields }),
  });
  return {
    store,
    provider,
    dispatcher,
    sessions,
    logs,
    advance: (ms: number) => {
      now += ms;
    },
  };
}

const item = (n: number) => ({
  notificationId: `ntf_${String(n).padStart(32, '0')}`,
  recipientId: user,
  category: 'booking.changes' as const,
});

void test('push only to the signed-in installation; idempotent per notification', async () => {
  const w = world();
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  const first = await w.dispatcher.dispatch(item(1));
  assert.equal(first.length, 1);
  assert.equal(first[0]?.state, 'sent');
  assert.equal(w.provider.sent.length, 1);
  // A replayed effect or a second worker sends nothing more.
  assert.deepEqual(await w.dispatcher.dispatch(item(1)), []);
  assert.equal(w.provider.sent.length, 1);
  // Logs carry the fingerprint, never the token.
  assert.ok(!JSON.stringify(w.logs).includes(token));
});

void test('one token, one active user: a new account on the device revokes the old one', async () => {
  const w = world({ sessions: new Set([`${user}|inst-1`, `${other}|inst-1`]) });
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  await w.dispatcher.register({
    userId: other,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  assert.deepEqual(await w.store.activeRegistrationsForUser(user), []);
  assert.equal((await w.store.activeRegistrationsForUser(other)).length, 1);
  // The same token on another installation of another user is rebound too.
  const v = world();
  await v.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  await v.dispatcher.register({
    userId: other,
    installationId: 'inst-2',
    platform: 'android',
    token,
  });
  assert.equal((await v.store.registration('inst-1'))?.revokeReason, 'rebound');
});

void test('signed out (no Session) revokes the registration; nothing is sent', async () => {
  const w = world({ sessions: new Set() });
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  assert.deepEqual(await w.dispatcher.dispatch(item(2)), []);
  assert.equal(w.provider.sent.length, 0);
  assert.equal((await w.store.registration('inst-1'))?.revokeReason, 'session_ended');
  assert.equal(await w.dispatcher.unregister(other, 'inst-1'), false);
});

void test('a switched-off category and the daily limit suppress push, never the inbox', async () => {
  const prefs: NotificationPreferences = {
    schemaVersion: 1,
    userId: user,
    revision: 1,
    policyRevision: 2,
    categories: { 'booking.changes': { push: false } },
    processingRestricted: false,
    updatedAtUtc: '2026-11-13T09:00:00.000Z',
  };
  const off = world({ prefs });
  await off.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  const [suppressed] = await off.dispatcher.dispatch(item(3));
  assert.equal(suppressed?.suppressReason, 'user_preference');
  assert.equal(off.provider.sent.length, 0);

  const busy = world();
  await busy.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  for (let n = 0; n < pushConfig.maxPerUserPerDay; n += 1)
    await busy.dispatcher.dispatch(item(100 + n));
  const [limited] = await busy.dispatcher.dispatch(item(999));
  assert.equal(limited?.suppressReason, 'rate_limited');
  assert.equal(busy.provider.sent.length, pushConfig.maxPerUserPerDay);
});

void test('transient failures back off, then reconcile retries, then dead-letter', async () => {
  const w = world();
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  for (let n = 0; n < pushConfig.maxAttempts; n += 1)
    w.provider.script.push({ kind: 'transient', code: 'messaging/server-unavailable' });
  const [first] = await w.dispatcher.dispatch(item(4));
  assert.equal(first?.state, 'retry_scheduled');
  // Not due yet: nothing is retried.
  assert.equal((await w.dispatcher.reconcile()).retried, 0);
  for (let n = 1; n < pushConfig.maxAttempts; n += 1) {
    w.advance(pushConfig.baseBackoffMs * 2 ** (n - 1));
    assert.equal((await w.dispatcher.reconcile()).retried, 1);
  }
  const last = await w.store.attempt(pushAttemptId(item(4).notificationId, 'inst-1'));
  assert.equal(last?.state, 'dead_lettered');
  assert.equal(last?.attemptCount, pushConfig.maxAttempts);
});

void test('an invalid token revokes the registration at once, without retries', async () => {
  const w = world();
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  w.provider.script.push({
    kind: 'invalid_token',
    code: 'messaging/registration-token-not-registered',
  });
  const [attempt] = await w.dispatcher.dispatch(item(5));
  assert.equal(attempt?.state, 'invalid_token');
  assert.equal((await w.store.registration('inst-1'))?.revokeReason, 'invalid_token');
  assert.equal(classifyProviderError('messaging/invalid-registration-token'), 'invalid_token');
  assert.equal(classifyProviderError('messaging/internal-error'), 'transient');
  assert.equal(classifyProviderError('messaging/invalid-argument'), 'rejected');
});

void test('reconcile revokes registrations unseen for 270 days; DSR erases everything', async () => {
  const w = world();
  await w.dispatcher.register({
    userId: user,
    installationId: 'inst-1',
    platform: 'android',
    token,
  });
  await w.dispatcher.dispatch(item(6));
  w.advance((pushConfig.staleAfterDays + 1) * 86_400_000);
  assert.equal((await w.dispatcher.reconcile()).revoked, 1);
  assert.ok((await w.dispatcher.eraseSubject(user)) >= 2);
  assert.equal(w.store.registrations.size, 0);
  assert.equal(w.store.attempts.size, 0);
});

void test('preferences: push is a channel of revision 2; a locked category switches push only', () => {
  const policy = defaultNotificationPolicies.active();
  assert.equal(policy.revision, 2);
  assert.deepEqual(notificationPolicyRevisionOne.channels, ['inApp']);
  const base = {
    policy,
    current: undefined,
    userId: user,
    expectedRevision: 0,
    nowUtc: '2026-11-13T10:00:00.000Z',
  };
  const pushOff = applyPreferenceUpdate({
    ...base,
    categories: { 'booking.changes': { push: false } },
  });
  assert.equal(pushOff.kind, 'updated');
  assert.equal(
    applyPreferenceUpdate({ ...base, categories: { 'booking.changes': { inApp: false } } }).kind,
    'invalid_preference',
  );
  // Revision 1 knows no push channel.
  assert.equal(
    applyPreferenceUpdate({
      ...base,
      policy: notificationPolicyRevisionOne,
      categories: { 'booking.receipts': { push: false } },
    }).kind,
    'invalid_preference',
  );
  // Stored documents of both shapes read back; anything else fails closed.
  const stored = parseStoredPreferences(user, {
    schemaVersion: 1,
    userId: user,
    revision: 1,
    policyRevision: 2,
    categories: {
      'booking.receipts': { inApp: true, push: false },
      'booking.changes': { push: true },
    },
    processingRestricted: false,
    updatedAtUtc: '2026-11-13T10:00:00.000Z',
  });
  assert.equal(stored.categories['booking.receipts']?.push, false);
  assert.throws(() =>
    parseStoredPreferences(user, {
      ...stored,
      categories: { 'booking.receipts': { email: true } },
    }),
  );
});
