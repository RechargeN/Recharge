import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import type { LiveReceipt } from '../../../src/modules/notifications/domain/delivery_attempt.js';
import {
  notificationIdFor,
  notificationReceiptId,
} from '../../../src/modules/notifications/domain/notification_effect.js';
import { defaultNotificationPolicies } from '../../../src/modules/notifications/domain/notification_policy.js';
import {
  NotificationTemplateRegistry,
  notificationTemplateRevisionsOne,
} from '../../../src/modules/notifications/domain/notification_templates.js';
import { InMemoryNotificationsStore } from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { createSuppressedOutbox } from '../../../src/notifications/outbox.js';
import { FakeClock } from '../../support/fake_clock.js';
import { bookingEffect, FaultyNotificationsStore } from '../../support/notifications_world.js';

const start = new Date('2026-08-29T12:00:00.000Z');

function world(templates?: NotificationTemplateRegistry) {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const faulty = new FaultyNotificationsStore(store);
  const clock = new FakeClock(start);
  let leases = 0;
  const consumer = new NotificationEffectConsumer({
    store: faulty,
    clock,
    ...(templates === undefined ? {} : { templates }),
    newLeaseId: () => `lease-${String((leases += 1))}`,
  });
  const advance = (ms: number) => clock.set(new Date(clock.now().getTime() + ms));
  return { store, faulty, clock, consumer, advance };
}

function items(store: InMemoryNotificationsStore) {
  return [...store.snapshot().items.values()];
}

function attempts(store: InMemoryNotificationsStore) {
  return [...store.snapshot().attempts.values()].sort((a, b) =>
    a.attemptId.localeCompare(b.attemptId),
  );
}

const confirmed = bookingEffect();
const receiptId = notificationReceiptId(confirmed.id);

void test('one allowed effect and recipient create exactly one logical record; repeats do not', async () => {
  const { store, consumer } = world();
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'created');
  for (let index = 0; index < 3; index += 1)
    assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'duplicate');
  assert.equal(items(store).length, 1);
  const [item] = items(store) as {
    notificationId: string;
    status: string;
    templateRevision: number;
  }[];
  assert.equal(item!.notificationId, notificationIdFor(receiptId));
  assert.equal(item!.status, 'unread');
  assert.deepEqual(
    attempts(store).map((attempt) => [attempt.attemptNumber, attempt.status, attempt.outcome]),
    [[1, 'succeeded', 'created']],
  );
  const receipt = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(receipt.status, 'created');
  assert.deepEqual(receipt.pinned, {
    policyRevision: 1,
    category: 'booking.receipts',
    templateKey: 'booking.confirmed',
    templateRevision: 1,
  });
});

void test('v1 records are not consumed and write nothing', async () => {
  const { store, consumer } = world();
  const v1 = createSuppressedOutbox(
    'booking_confirmation',
    'b',
    'recipient-1',
    '2026-08-29T12:00:00Z',
  );
  assert.equal(await consumer.consume('b__r1', v1), 'not_dispatchable');
  assert.equal(store.snapshot().receipts.size, 0);
});

void test('preferences change behaviour: receipts can be switched off, booking.changes cannot', async () => {
  const { store, consumer } = world();
  store.setRawPreferences('recipient-1', {
    schemaVersion: 1,
    userId: 'recipient-1',
    revision: 3,
    policyRevision: 1,
    categories: { 'booking.receipts': { inApp: false } },
    processingRestricted: false,
    updatedAtUtc: '2026-08-29T11:00:00.000Z',
  });
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'suppressed');
  const minimal = store.snapshot().receipts.get(receiptId)!;
  assert.equal(minimal.shape, 'minimal');
  assert.equal(minimal.shape === 'minimal' && minimal.reason, 'user_preference');
  assert.deepEqual(minimal.shape === 'minimal' && minimal.evidence, {
    policyRevision: 1,
    templateRevision: 1,
    preferenceRevision: 3,
  });
  const cancelled = bookingEffect({
    effect: { kind: 'cancelled', cause: 'occurrenceCancelled' },
    revision: 2,
  });
  assert.equal(await consumer.consume(cancelled.id, cancelled.data), 'created');
  assert.equal(items(store).length, 1);
});

void test('ineligible recipients and privacy-erasure cancellations leave only minimal receipts', async () => {
  const { store, consumer } = world();
  store.setAccount('restricted-user', 'restricted');
  const cases = [
    [bookingEffect({ recipientId: 'restricted-user', bookingId: 'B1' }), 'recipient_restricted'],
    [bookingEffect({ recipientId: 'missing-user', bookingId: 'B2' }), 'recipient_not_found'],
    [
      bookingEffect({ effect: { kind: 'cancelled', cause: 'privacyErasure' }, bookingId: 'B3' }),
      'recipient_erasure',
    ],
  ] as const;
  for (const [effect, reason] of cases) {
    assert.equal(await consumer.consume(effect.id, effect.data), 'suppressed');
    const receipt = store.snapshot().receipts.get(notificationReceiptId(effect.id))!;
    assert.equal(receipt.shape === 'minimal' && receipt.reason, reason);
  }
  assert.equal(items(store).length, 0);
  const serialized = JSON.stringify([...store.snapshot().receipts.values()]);
  for (const leak of ['restricted-user', 'missing-user', 'recipient-1', 'B1', 'B2', 'B3'])
    assert.equal(serialized.includes(leak), false, leak);
});

void test('an effect past its relevance window expires instead of appearing late', async () => {
  const { store, consumer, clock } = world();
  clock.set(new Date('2026-09-06T00:00:00.000Z'));
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'expired');
  assert.equal(store.snapshot().receipts.get(receiptId)?.status, 'expired');
  assert.equal(items(store).length, 0);
});

void test('crash after claim: the lease blocks, then a new attempt marks the old one abandoned', async () => {
  const { store, consumer, advance } = world();
  const claimed = await consumer.claim(confirmed.id, confirmed.data);
  assert.equal(claimed.kind, 'claimed');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'busy');
  advance(60_001);
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'created');
  assert.deepEqual(
    attempts(store).map((attempt) => [attempt.attemptNumber, attempt.status, attempt.failureCode]),
    [
      [1, 'abandoned', 'lease_expired'],
      [2, 'succeeded', null],
    ],
  );
  assert.equal(items(store).length, 1);
});

void test('a failed inbox write rolls back the record but the attempt stays recorded and retries', async () => {
  const { store, faulty, consumer, advance } = world();
  faulty.faults.add('inbox_write');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'retry_scheduled');
  assert.equal(items(store).length, 0);
  const receipt = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(receipt.status, 'retry_scheduled');
  assert.equal(receipt.nextAttemptAtUtc, '2026-08-29T12:00:30.000Z');
  assert.deepEqual(
    attempts(store).map((attempt) => [attempt.status, attempt.failureClass, attempt.failureCode]),
    [['failed', 'transient', 'store_unavailable']],
  );
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'not_due');
  faulty.faults.clear();
  advance(30_000);
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'created');
  assert.equal(items(store).length, 1);
  assert.deepEqual(
    attempts(store).map((attempt) => attempt.status),
    ['failed', 'succeeded'],
  );
});

void test('an unreadable preference document is a transient failure, then delivery succeeds once', async () => {
  const { store, consumer, advance } = world();
  store.setRawPreferences('recipient-1', { schemaVersion: 1, garbage: true });
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'retry_scheduled');
  assert.equal(attempts(store)[0]!.failureCode, 'preferences_unreadable');
  store.setRawPreferences('recipient-1', {
    schemaVersion: 1,
    userId: 'recipient-1',
    revision: 1,
    policyRevision: 1,
    categories: {},
    processingRestricted: false,
    updatedAtUtc: '2026-08-29T12:00:00.000Z',
  });
  advance(30_000);
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'created');
  assert.equal(items(store).length, 1);
});

void test('when both completion and failure recording fail, the lease hands the effect on', async () => {
  const { store, faulty, consumer, advance } = world();
  const claimed = await consumer.claim(confirmed.id, confirmed.data);
  assert.equal(claimed.kind, 'claimed');
  if (claimed.kind !== 'claimed') return;
  faulty.faults.add('inbox_write');
  await assert.rejects(consumer.complete(claimed.claim), /UNAVAILABLE/u);
  faulty.faults.add('store');
  await assert.rejects(consumer.fail(claimed.claim, new Error('x')), /UNAVAILABLE/u);
  faulty.faults.clear();
  assert.equal((store.snapshot().receipts.get(receiptId) as LiveReceipt).status, 'claimed');
  assert.equal(attempts(store)[0]!.status, 'started');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'busy');
  advance(60_001);
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'created');
  assert.deepEqual(
    attempts(store).map((attempt) => attempt.status),
    ['abandoned', 'succeeded'],
  );
});

void test('a crash after commit but before acknowledgement does not duplicate on redelivery', async () => {
  const { store, consumer } = world();
  const claimed = await consumer.claim(confirmed.id, confirmed.data);
  if (claimed.kind !== 'claimed') throw new Error('claim expected');
  assert.equal((await consumer.complete(claimed.claim)).kind, 'created');
  // The worker dies here; the trigger and the reconciliation redeliver.
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'duplicate');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'duplicate');
  assert.equal(items(store).length, 1);
  assert.equal(attempts(store).length, 1);
  assert.equal((store.snapshot().receipts.get(receiptId) as LiveReceipt).attemptCount, 1);
});

void test('a stale worker cannot complete or fail after another worker took the lease', async () => {
  const { store, consumer, advance } = world();
  const first = await consumer.claim(confirmed.id, confirmed.data);
  if (first.kind !== 'claimed') throw new Error('claim expected');
  advance(60_001);
  const second = await consumer.claim(confirmed.id, confirmed.data);
  if (second.kind !== 'claimed') throw new Error('takeover expected');
  assert.deepEqual(await consumer.complete(first.claim), { kind: 'stale' });
  assert.deepEqual(await consumer.fail(first.claim, new Error('late')), { kind: 'stale' });
  assert.equal(items(store).length, 0);
  assert.equal((await consumer.complete(second.claim)).kind, 'created');
  assert.equal(items(store).length, 1);
});

void test('a foreign document under the record id is a permanent failure: dead letter at once', async () => {
  const { store, consumer } = world();
  store.setRawItem(notificationIdFor(receiptId), { foreign: true });
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'dead_lettered');
  const receipt = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(receipt.reason, 'item_conflict');
  assert.equal(attempts(store).length, 1);
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'dead_lettered');
  assert.equal(attempts(store).length, 1);
});

void test('the attempt budget is bounded: the fifth transient failure dead-letters', async () => {
  const { store, faulty, consumer, advance } = world();
  faulty.faults.add('inbox_write');
  const outcomes = [];
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    outcomes.push(await consumer.consume(confirmed.id, confirmed.data));
    advance(30_000 * 2 ** (attempt - 1));
  }
  assert.deepEqual(outcomes, [
    'retry_scheduled',
    'retry_scheduled',
    'retry_scheduled',
    'retry_scheduled',
    'dead_lettered',
  ]);
  const receipt = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(receipt.reason, 'retry_exhausted');
  assert.equal(attempts(store).length, 5);
});

void test('template and policy revisions are pinned at the first claim and survive retries', async () => {
  const revisionTwo = notificationTemplateRevisionsOne.map((template) => ({
    ...template,
    revision: 2,
    locales: { ...template.locales, en: { title: `${template.locales.en!.title} v2`, body: 'v2' } },
  }));
  const both = new NotificationTemplateRegistry(
    [...notificationTemplateRevisionsOne, ...revisionTwo],
    Object.fromEntries(revisionTwo.map((template) => [template.templateKey, 2])),
  );
  const { store, faulty, consumer, advance, clock } = world();
  faulty.faults.add('inbox_write');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'retry_scheduled');
  faulty.faults.clear();
  advance(30_000);
  const upgraded = new NotificationEffectConsumer({ store, clock, templates: both });
  assert.equal(await upgraded.consume(confirmed.id, confirmed.data), 'created');
  const [item] = items(store) as { templateRevision: number }[];
  assert.equal(item!.templateRevision, 1);
  const fresh = bookingEffect({ bookingId: 'FRESH' });
  assert.equal(await upgraded.consume(fresh.id, fresh.data), 'created');
  const pinned = (store.snapshot().receipts.get(notificationReceiptId(fresh.id)) as LiveReceipt)
    .pinned;
  assert.equal(pinned?.templateRevision, 2);
  assert.equal(pinned?.policyRevision, defaultNotificationPolicies.active().revision);
});

void test('an older effect arriving after a newer record of the same booking is superseded', async () => {
  const { store, consumer } = world();
  const cancelled = bookingEffect({
    effect: { kind: 'cancelled', cause: 'userCancelled' },
    revision: 2,
  });
  assert.equal(await consumer.consume(cancelled.id, cancelled.data), 'created');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'suppressed');
  const receipt = store.snapshot().receipts.get(receiptId)!;
  assert.equal(receipt.shape === 'minimal' && receipt.reason, 'superseded');
  assert.equal(items(store).length, 1);
});

void test('a changed redelivery of an in-flight effect is a payload conflict and mutates nothing', async () => {
  const { store, faulty, consumer, advance } = world();
  faulty.faults.add('inbox_write');
  assert.equal(await consumer.consume(confirmed.id, confirmed.data), 'retry_scheduled');
  faulty.faults.clear();
  advance(30_000);
  const before = JSON.stringify(store.snapshot().receipts.get(receiptId));
  const altered = bookingEffect({ recipientId: 'someone-else' });
  assert.equal(await consumer.consume(altered.id, altered.data), 'payload_conflict');
  assert.equal(JSON.stringify(store.snapshot().receipts.get(receiptId)), before);
});

void test('a poison envelope is quarantined with one permanent attempt', async () => {
  const { store, consumer } = world();
  const { id, data } = bookingEffect();
  assert.equal(await consumer.consume(id, { ...data, eventVersion: 9 }), 'dead_lettered');
  const receipt = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(receipt.reason, 'unsupported_effect');
  assert.equal(receipt.recipientId, null);
  assert.deepEqual(
    attempts(store).map((attempt) => [attempt.status, attempt.failureClass]),
    [['failed', 'permanent']],
  );
});
