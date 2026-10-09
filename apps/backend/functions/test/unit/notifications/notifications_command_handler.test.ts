import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import { handleNotificationsCommandRequest } from '../../../src/modules/notifications/application/notifications_command_handler.js';
import {
  notificationIdFor,
  notificationReceiptId,
} from '../../../src/modules/notifications/domain/notification_effect.js';
import { InMemoryNotificationsStore } from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { FakeClock } from '../../support/fake_clock.js';
import { bookingEffect } from '../../support/notifications_world.js';

async function world() {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const clock = new FakeClock(new Date('2026-08-29T12:00:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store, clock });
  const ids: string[] = [];
  for (let index = 1; index <= 3; index += 1) {
    const effect = bookingEffect({ bookingId: `B${String(index)}` });
    assert.equal(await consumer.consume(effect.id, effect.data), 'created');
    ids.push(notificationIdFor(notificationReceiptId(effect.id)));
  }
  clock.set(new Date('2026-08-29T13:00:00.000Z'));
  let keys = 0;
  const command = (
    userId: string,
    commandType: string,
    payload: Record<string, unknown>,
    idempotencyKey = `idem-key-${String((keys += 1))}`,
  ) =>
    handleNotificationsCommandRequest(
      { store, clock, features: { inbox: true, preferences: true } },
      userId,
      { schemaVersion: 1, requestId: 'req-1', idempotencyKey, commandType, payload },
    );
  return { store, clock, ids, command };
}

void test('markRead is idempotent and another recipient cannot see the record', async () => {
  const { ids, command } = await world();
  const read = await command('recipient-1', 'markRead', { notificationId: ids[0] }, 'idem-read-1');
  assert.equal(read.kind, 'succeeded');
  assert.equal(read.status, 'read');
  assert.equal(read.readAtUtc, '2026-08-29T13:00:00.000Z');
  const repeat = await command(
    'recipient-1',
    'markRead',
    { notificationId: ids[0] },
    'idem-read-1',
  );
  assert.equal(repeat.replayed, true);
  assert.equal(repeat.revision, read.revision);
  const conflict = await command(
    'recipient-1',
    'markRead',
    { notificationId: ids[1] },
    'idem-read-1',
  );
  assert.equal(conflict.code, 'idempotency_conflict');
  const foreign = await command('intruder', 'markRead', { notificationId: ids[1] });
  assert.equal(foreign.code, 'notification_not_found');
});

void test('archive needs the current revision', async () => {
  const { ids, command } = await world();
  assert.equal(
    (await command('recipient-1', 'archive', { notificationId: ids[0], expectedRevision: 2 })).code,
    'stale_revision',
  );
  const archived = await command('recipient-1', 'archive', {
    notificationId: ids[0],
    expectedRevision: 1,
  });
  assert.equal(archived.status, 'archived');
});

void test('markAllRead is bounded by its cutoff and maximum and reports what remains', async () => {
  const { store, command } = await world();
  const partial = await command('recipient-1', 'markAllRead', {
    cutoffUtc: '2026-08-29T12:30:00.000Z',
    maxItems: 2,
  });
  assert.deepEqual([partial.updated, partial.remaining], [2, true]);
  assert.equal(await store.unreadCount('recipient-1'), 1);
  assert.equal(
    (
      await command('recipient-1', 'markAllRead', {
        cutoffUtc: '2026-08-29T14:00:00.000Z',
        maxItems: 2,
      })
    ).code,
    'cutoff_in_future',
  );
  assert.equal(
    (
      await command('recipient-1', 'markAllRead', {
        cutoffUtc: '2026-08-29T12:30:00.000Z',
        maxItems: 101,
      })
    ).code,
    'max_items_invalid',
  );
  const rest = await command('recipient-1', 'markAllRead', {
    cutoffUtc: '2026-08-29T12:30:00.000Z',
    maxItems: 100,
  });
  assert.deepEqual([rest.updated, rest.remaining], [1, false]);
});

void test('updatePreferences changes only unlocked categories and refuses push, email and SMS', async () => {
  const { command } = await world();
  const updated = await command('recipient-1', 'updatePreferences', {
    expectedRevision: 0,
    categories: { 'booking.receipts': { inApp: false } },
  });
  assert.equal(updated.kind, 'succeeded');
  assert.equal(updated.revision, 1);
  for (const [categories, detail] of [
    [{ 'booking.changes': { inApp: false } }, 'category_locked'],
    [{ 'booking.receipts': { push: true } }, 'channel_unknown'],
  ] as const) {
    const refused = await command('recipient-1', 'updatePreferences', {
      expectedRevision: 1,
      categories,
    });
    assert.deepEqual([refused.code, refused.detail], ['invalid_preference', detail]);
  }
  const stale = await command('recipient-1', 'updatePreferences', {
    expectedRevision: 0,
    categories: { 'booking.receipts': { inApp: true } },
  });
  assert.deepEqual([stale.code, stale.currentRevision], ['stale_revision', 1]);
});

void test('envelope validation and feature flags are enforced before any work', async () => {
  const { store, clock } = await world();
  const run = (body: unknown, features = { inbox: true, preferences: true }) =>
    handleNotificationsCommandRequest({ store, clock, features }, 'recipient-1', body);
  assert.equal(
    (
      await run({
        schemaVersion: 1,
        requestId: 'r',
        idempotencyKey: 'short',
        commandType: 'markRead',
        payload: {},
      })
    ).code,
    'idempotency_key_invalid',
  );
  assert.equal(
    (
      await run({
        schemaVersion: 1,
        requestId: 'r',
        idempotencyKey: 'long-enough',
        commandType: 'registerPush',
        payload: {},
      })
    ).code,
    'command_type_unsupported',
  );
  assert.equal(
    (
      await run(
        {
          schemaVersion: 1,
          requestId: 'r',
          idempotencyKey: 'long-enough',
          commandType: 'markRead',
          payload: { notificationId: 'ntf_0123456789abcdef0123456789abcdef' },
        },
        { inbox: false, preferences: true },
      )
    ).code,
    'feature_disabled',
  );
  assert.equal(
    (
      await run({
        schemaVersion: 1,
        requestId: 'r',
        idempotencyKey: 'long-enough',
        commandType: 'markRead',
        payload: { notificationId: 'x' },
      })
    ).code,
    'notification_id_invalid',
  );
});
