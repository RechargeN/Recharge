import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import { handleNotificationsCommandRequest } from '../../../src/modules/notifications/application/notifications_command_handler.js';
import { NotificationsPrivacyTaskHandler } from '../../../src/modules/notifications/application/notifications_privacy_task_handler.js';
import { notificationReceiptId } from '../../../src/modules/notifications/domain/notification_effect.js';
import { InMemoryNotificationsStore } from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { FakeClock } from '../../support/fake_clock.js';
import { bookingEffect, FaultyNotificationsStore } from '../../support/notifications_world.js';

async function world() {
  const store = new InMemoryNotificationsStore();
  store.setAccount('subject-1', 'active');
  store.setAccount('bystander', 'active');
  const clock = new FakeClock(new Date('2026-08-29T12:00:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store, clock });
  const subject = bookingEffect({ bookingId: 'SUBJ', recipientId: 'subject-1' });
  const bystander = bookingEffect({ bookingId: 'BYST', recipientId: 'bystander' });
  assert.equal(await consumer.consume(subject.id, subject.data), 'created');
  assert.equal(await consumer.consume(bystander.id, bystander.data), 'created');
  await handleNotificationsCommandRequest(
    { store, clock, features: { inbox: true, preferences: true } },
    'subject-1',
    {
      schemaVersion: 1,
      requestId: 'r',
      idempotencyKey: 'idem-pref-1',
      commandType: 'updatePreferences',
      payload: { expectedRevision: 0, categories: { 'booking.receipts': { inApp: true } } },
    },
  );
  return { store, clock, consumer, subject, bystander };
}

void test('erasure removes the subject data and leaves tombstones with nothing personal', async () => {
  const { store, clock, consumer, subject } = await world();
  const handler = new NotificationsPrivacyTaskHandler(store, clock);
  const result = await handler.handle({ taskType: 'erasure', subjectId: 'subject-1' });
  assert.equal(result.kind, 'succeeded');
  const snapshot = store.snapshot();
  assert.equal([...snapshot.items.values()].length, 1);
  assert.equal(snapshot.preferences.has('subject-1'), false);
  assert.equal(
    [...snapshot.commandReceipts.values()].some((receipt) => receipt.userId === 'subject-1'),
    false,
  );
  const tombstone = snapshot.receipts.get(notificationReceiptId(subject.id))!;
  assert.equal(tombstone.status, 'erased');
  assert.equal(tombstone.shape, 'minimal');
  const serialized = JSON.stringify(tombstone);
  for (const leak of [
    'subject-1',
    'SUBJ',
    'evt_',
    'occ_',
    'payload',
    'aggregate',
    'ntf_',
    'deadline',
  ])
    assert.equal(serialized.includes(leak), false, leak);
  assert.equal(tombstone.expiresAt.toISOString(), '2026-10-05T12:00:00.000Z');
  assert.equal(
    [...snapshot.attempts.values()].some((attempt) => attempt.receiptId === tombstone.receiptId),
    false,
  );
  // Redelivery after erasure does not bring anything back.
  assert.equal(await consumer.consume(subject.id, subject.data), 'duplicate');
  assert.equal([...store.snapshot().items.values()].length, 1);
});

void test('restriction suppresses new effects without touching existing records', async () => {
  const { store, clock, consumer } = await world();
  const handler = new NotificationsPrivacyTaskHandler(store, clock);
  assert.equal(
    (await handler.handle({ taskType: 'restriction', subjectId: 'subject-1' })).kind,
    'succeeded',
  );
  const next = bookingEffect({
    bookingId: 'SUBJ',
    recipientId: 'subject-1',
    revision: 2,
    effect: { kind: 'cancelled', cause: 'occurrenceCancelled' },
  });
  assert.equal(await consumer.consume(next.id, next.data), 'suppressed');
  const receipt = store.snapshot().receipts.get(notificationReceiptId(next.id))!;
  assert.equal(receipt.shape === 'minimal' && receipt.reason, 'recipient_restricted');
  assert.equal([...store.snapshot().items.values()].length, 2);
});

void test('access counts records; an outage fails only this task, retryably', async () => {
  const { store, clock } = await world();
  const access = await new NotificationsPrivacyTaskHandler(store, clock).handle({
    taskType: 'access',
    subjectId: 'subject-1',
  });
  assert.equal(access.kind === 'succeeded' && access.evidence.recordCount, 4);
  const faulty = new FaultyNotificationsStore(store);
  faulty.faults.add('store');
  assert.deepEqual(
    await new NotificationsPrivacyTaskHandler(faulty, clock).handle({
      taskType: 'erasure',
      subjectId: 'subject-1',
    }),
    { kind: 'retryableFailure', code: 'temporarily_unavailable' },
  );
});
