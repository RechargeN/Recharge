import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import { handleNotificationsQueryRequest } from '../../../src/modules/notifications/application/notifications_query_handler.js';
import { InMemoryNotificationsStore } from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { FakeClock } from '../../support/fake_clock.js';
import { bookingEffect } from '../../support/notifications_world.js';

async function world() {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  store.setAccount('recipient-2', 'active');
  const clock = new FakeClock(new Date('2026-08-29T12:00:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store, clock });
  for (let index = 1; index <= 5; index += 1) {
    clock.set(new Date(`2026-08-29T12:0${String(index)}:00.000Z`));
    const effect = bookingEffect({
      bookingId: `B${String(index)}`,
      occurredAt: clock.now().toISOString(),
    });
    assert.equal(await consumer.consume(effect.id, effect.data), 'created');
  }
  const other = bookingEffect({ bookingId: 'OTHER', recipientId: 'recipient-2' });
  assert.equal(await consumer.consume(other.id, other.data), 'created');
  const query = (
    userId: string,
    body: Record<string, unknown>,
    features = { inbox: true, preferences: true },
  ) => handleNotificationsQueryRequest({ store, clock, features }, userId, body);
  return { store, clock, query };
}

const request = (queryType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  requestId: 'req-1',
  queryType,
  payload,
});

void test('listInbox pages the caller own records newest first with a bound cursor', async () => {
  const { query } = await world();
  const first = await query('recipient-1', request('listInbox', { locale: 'ru', pageSize: 2 }));
  assert.equal(first.kind, 'succeeded');
  const items = first.items as {
    createdAtUtc: string;
    content: { title: string };
    contentStatus: string;
  }[];
  assert.deepEqual(
    items.map((item) => item.createdAtUtc),
    ['2026-08-29T12:05:00.000Z', '2026-08-29T12:04:00.000Z'],
  );
  assert.equal(items[0]!.content.title, 'Бронь подтверждена');
  assert.equal(items[0]!.contentStatus, 'rendered');
  const cursor = first.nextCursor as string;
  const second = await query(
    'recipient-1',
    request('listInbox', { locale: 'en', pageSize: 2, cursor }),
  );
  assert.deepEqual(
    (second.items as { createdAtUtc: string }[]).map((item) => item.createdAtUtc),
    ['2026-08-29T12:03:00.000Z', '2026-08-29T12:02:00.000Z'],
  );
  const third = await query(
    'recipient-1',
    request('listInbox', { locale: 'lv-LV', pageSize: 2, cursor: second.nextCursor }),
  );
  assert.equal((third.items as unknown[]).length, 1);
  assert.equal(third.nextCursor, null);
  // A cursor from another account or view is refused, not reinterpreted.
  assert.equal(
    (await query('recipient-2', request('listInbox', { locale: 'ru', cursor }))).code,
    'cursor_invalid',
  );
  assert.equal(
    (await query('recipient-1', request('listInbox', { locale: 'ru', view: 'archived', cursor })))
      .code,
    'cursor_invalid',
  );
  const otherList = await query('recipient-2', request('listInbox', { locale: 'ru' }));
  assert.equal((otherList.items as unknown[]).length, 1);
});

void test('unsupported locale, unknown fields, versions and disabled features fail typed', async () => {
  const { query } = await world();
  assert.equal(
    (await query('recipient-1', request('listInbox', { locale: 'de' }))).code,
    'unsupported_locale',
  );
  assert.equal(
    (await query('recipient-1', request('listInbox', { locale: 'ru', userId: 'recipient-2' })))
      .code,
    'unknown_field:userId',
  );
  assert.equal(
    (await query('recipient-1', { ...request('unreadSummary', {}), schemaVersion: 2 })).code,
    'unsupported_version',
  );
  assert.equal(
    (await query('recipient-1', request('listInbox', { locale: 'ru', pageSize: 51 }))).code,
    'page_size_invalid',
  );
  assert.equal(
    (
      await query('recipient-1', request('listInbox', { locale: 'ru' }), {
        inbox: false,
        preferences: true,
      })
    ).code,
    'feature_disabled',
  );
  assert.equal(
    (await query('recipient-1', request('getPreferences', {}), { inbox: true, preferences: false }))
      .code,
    'feature_disabled',
  );
  assert.equal(
    (await query('recipient-1', request('pushTokens', {}))).code,
    'query_type_unsupported',
  );
});

void test('unread summary counts only the caller unread records', async () => {
  const { query } = await world();
  const summary = await query('recipient-1', request('unreadSummary', {}));
  assert.equal(summary.unreadCount, 5);
  assert.equal(summary.asOfUtc, '2026-08-29T12:05:00.000Z');
});

void test('getPreferences shows the explicit category policy and locks', async () => {
  const { query } = await world();
  const preferences = await query('recipient-1', request('getPreferences', {}));
  assert.equal(preferences.revision, 0);
  assert.deepEqual(preferences.channels, ['inApp']);
  assert.deepEqual(preferences.categories, [
    { category: 'booking.receipts', inApp: { enabled: true, locked: false } },
    { category: 'booking.changes', inApp: { enabled: true, locked: true } },
  ]);
});
