import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from '../../../src/modules/notifications/application/notification_reconciler.js';
import type { LiveReceipt } from '../../../src/modules/notifications/domain/delivery_attempt.js';
import { notificationReceiptId } from '../../../src/modules/notifications/domain/notification_effect.js';
import type { NotificationsTransaction } from '../../../src/modules/notifications/domain/repositories.js';
import {
  InMemoryNotificationEffectSource,
  InMemoryNotificationsStore,
} from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { createSuppressedOutbox } from '../../../src/notifications/outbox.js';
import { FakeClock } from '../../support/fake_clock.js';
import {
  bookingEffect,
  FaultyNotificationsStore,
  unavailable,
} from '../../support/notifications_world.js';

function world(config: { pageSize?: number; maxPages?: number } = {}) {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const faulty = new FaultyNotificationsStore(store);
  const source = new InMemoryNotificationEffectSource();
  const clock = new FakeClock(new Date('2026-08-29T12:05:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store: faulty, clock });
  const reconciler = new NotificationReconciler(faulty, source, consumer, clock, config);
  return { store, faulty, source, clock, consumer, reconciler };
}

function effectAt(index: number) {
  const minute = String(index).padStart(2, '0');
  return bookingEffect({
    bookingId: `01JF1BOOKING0000000000${minute}`,
    occurredAt: `2026-08-29T12:${minute}:00.000Z`,
  });
}

/** Fails every transaction that touches one receipt id: a single failing record. */
class OneBadRecordStore extends FaultyNotificationsStore {
  constructor(
    inner: InMemoryNotificationsStore,
    private readonly badReceiptId: string,
  ) {
    super(inner);
  }

  override transact<T>(work: (transaction: NotificationsTransaction) => Promise<T>): Promise<T> {
    return super.transact((transaction) => {
      const guarded = Object.create(transaction) as NotificationsTransaction;
      guarded.receipt = (id) =>
        id === this.badReceiptId ? Promise.reject(unavailable('receipt')) : transaction.receipt(id);
      return work(guarded);
    });
  }

  override receipt(id: string) {
    return id === this.badReceiptId ? Promise.reject(unavailable('receipt')) : super.receipt(id);
  }
}

void test('reconciliation consumes missing effects once and reports complete', async () => {
  const { store, source, reconciler } = world();
  for (const index of [1, 2, 3]) {
    const effect = effectAt(index);
    source.put(effect.id, effect.data);
  }
  source.put('legacy__r1', {
    ...createSuppressedOutbox(
      'booking_confirmation',
      'legacy',
      'recipient-1',
      '2026-08-29T12:00:30.000Z',
    ),
  });
  const first = await reconciler.reconcile();
  assert.equal(first.outcomes.created, 3);
  assert.equal(first.complete, true);
  const second = await reconciler.reconcile();
  assert.equal(second.complete, true);
  assert.equal(second.outcomes.created, undefined);
  assert.equal([...store.snapshot().items.values()].length, 3);
  assert.equal(store.snapshot().receipts.size, 3);
});

void test('one failing record is kept for retry but never blocks the others', async () => {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const bad = effectAt(2);
  const faulty = new OneBadRecordStore(store, notificationReceiptId(bad.id));
  const source = new InMemoryNotificationEffectSource();
  const clock = new FakeClock(new Date('2026-08-29T12:30:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store: faulty, clock });
  const reconciler = new NotificationReconciler(faulty, source, consumer, clock, {
    pageSize: 2,
    maxPages: 1,
  });
  for (const index of [1, 2, 3, 4, 5]) {
    const effect = effectAt(index);
    source.put(effect.id, effect.data);
  }
  const passes = [];
  for (let pass = 0; pass < 4; pass += 1) passes.push(await reconciler.reconcile());
  // Every healthy record got its single inbox record although #2 always fails.
  assert.equal([...store.snapshot().items.values()].length, 4);
  assert.ok(passes.every((report) => !report.complete));
  assert.ok(
    passes.some((report) =>
      report.findings.some(
        (finding) =>
          finding.code === 'receipt_missing' && finding.ref === notificationReceiptId(bad.id),
      ),
    ),
  );
  const checkpoint = await store.checkpoint();
  // `safe` never passes the record without a receipt.
  assert.equal(checkpoint?.safe?.id, effectAt(1).id);
  // The failing record is processed once it heals.
  const healed = new NotificationReconciler(
    store,
    source,
    new NotificationEffectConsumer({ store, clock }),
    clock,
    { pageSize: 2, maxPages: 5 },
  );
  let report = await healed.reconcile();
  if (!report.complete) report = await healed.reconcile();
  assert.equal(report.complete, true);
  assert.equal([...store.snapshot().items.values()].length, 5);
});

void test('due retries run from the receipt index, and dead letters past the window expire', async () => {
  const { store, faulty, source, clock, reconciler } = world();
  const first = effectAt(1);
  source.put(first.id, first.data);
  faulty.faults.add('inbox_write');
  const failing = await reconciler.reconcile();
  assert.equal(failing.outcomes.retry_scheduled, 1);
  assert.equal(failing.complete, false);
  faulty.faults.clear();
  clock.set(new Date('2026-08-29T12:06:00.000Z'));
  const retried = await reconciler.reconcile();
  assert.equal(retried.outcomes.created, 1);
  assert.equal(retried.complete, true);

  const second = effectAt(2);
  source.put(second.id, second.data);
  store.setRawItem(
    (
      await import('../../../src/modules/notifications/domain/notification_effect.js')
    ).notificationIdFor(notificationReceiptId(second.id)),
    { foreign: true },
  );
  const dead = await reconciler.reconcile();
  assert.deepEqual(
    dead.findings.map((finding) => finding.code),
    ['dead_letter'],
  );
  clock.set(new Date('2026-09-06T00:00:00.000Z'));
  const expired = await reconciler.reconcile();
  assert.equal(expired.outcomes.expired_by_reconcile, 1);
  assert.equal(store.snapshot().receipts.get(notificationReceiptId(second.id))?.status, 'expired');
  assert.equal(expired.complete, true);
});

void test('replay is audited and limited to dead letters inside their window', async () => {
  const { store, source, clock, consumer, reconciler } = world();
  const effect = effectAt(1);
  source.put(effect.id, effect.data);
  const { notificationIdFor } =
    await import('../../../src/modules/notifications/domain/notification_effect.js');
  const receiptId = notificationReceiptId(effect.id);
  store.setRawItem(notificationIdFor(receiptId), { foreign: true });
  assert.equal(await consumer.consume(effect.id, effect.data), 'dead_lettered');
  assert.deepEqual(await reconciler.replay({ receiptId, reason: ' ', operator: 'ops' }), {
    kind: 'reason_invalid',
  });
  await store.deleteInboxItems([notificationIdFor(receiptId)]);
  assert.deepEqual(
    await reconciler.replay({ receiptId, reason: 'foreign document removed', operator: 'ops' }),
    { kind: 'replayed' },
  );
  const replayed = store.snapshot().receipts.get(receiptId) as LiveReceipt;
  assert.equal(replayed.status, 'retry_scheduled');
  assert.deepEqual(replayed.replays, [
    { atUtc: '2026-08-29T12:05:00.000Z', reason: 'foreign document removed', operator: 'ops' },
  ]);
  const report = await reconciler.reconcile();
  assert.equal(report.outcomes.created, 1);
  assert.deepEqual(await reconciler.replay({ receiptId, reason: 'again', operator: 'ops' }), {
    kind: 'refused',
    status: 'created',
  });
  const late = effectAt(2);
  const lateId = notificationReceiptId(late.id);
  store.setRawItem(notificationIdFor(lateId), { foreign: true });
  assert.equal(await consumer.consume(late.id, late.data), 'dead_lettered');
  clock.set(new Date('2026-09-06T00:00:00.000Z'));
  assert.deepEqual(
    await reconciler.replay({ receiptId: lateId, reason: 'late', operator: 'ops' }),
    {
      kind: 'expired',
    },
  );
  assert.deepEqual(
    await reconciler.replay({ receiptId: 'nrc_missing', reason: 'x', operator: 'ops' }),
    {
      kind: 'not_found',
    },
  );
});
