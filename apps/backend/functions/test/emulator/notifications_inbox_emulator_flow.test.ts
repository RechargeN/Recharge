import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import type { DocumentData } from 'firebase-admin/firestore';

import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { NotificationEffectConsumer } from '../../src/modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from '../../src/modules/notifications/application/notification_reconciler.js';
import { notificationReceiptId } from '../../src/modules/notifications/domain/notification_effect.js';
import { FirestoreBookingOutboxSource } from '../../src/modules/notifications/infrastructure/firestore_notification_sources.js';
import {
  FirestoreNotificationsStore,
  notificationCollections,
} from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import {
  bookingNotificationFlagIds,
  notificationsFlagIds,
} from '../../src/shared/feature_flags.js';
import {
  callBookingFunction,
  cleanupBookingEmulator,
  createAuthorizedActor,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import { cleanupNotifications, setLocalFlag } from '../support/notifications_world.js';

/**
 * F1 end to end on the Emulator: Booking commits a v2 obligation, the
 * `consumeNotificationEffectV1` trigger creates exactly one inbox record, and
 * the Session-checked callables read and change only the caller's records.
 */
const firestore = emulatorFirestore();
const now = new Date();
const clock = new FakeClock(now);

before(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
  await setBookingFlags(true, firestore);
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
});
after(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
});

async function book(userId: string, bookingId: string, occurrenceId: string): Promise<string> {
  await seedEvent(
    finiteEvent({
      occurrenceId,
      occurrenceStartsAt: new Date(now.getTime() + 86_400_000).toISOString(),
      occurrenceEndsAt: new Date(now.getTime() + 90_000_000).toISOString(),
      registrationWindow: {
        opensAt: new Date(now.getTime() - 86_400_000).toISOString(),
        closesAt: new Date(now.getTime() + 43_200_000).toISOString(),
      },
      cancellationDeadline: new Date(now.getTime() + 43_200_000).toISOString(),
    }),
    firestore,
  );
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    userId,
    createCommand({
      requestId: `req_${bookingId}`,
      idempotencyKey: `idem_${bookingId}`,
      payload: {
        occurrenceId,
        inventoryPoolId: 'pool_general',
        channel: 'onsite',
        participantUnits: 1,
        namedGuests: [],
      },
    }),
  );
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
  return `${bookingId}__r1`;
}

async function waitForItems(userId: string, count: number): Promise<DocumentData[]> {
  const deadline = Date.now() + 30_000;
  for (;;) {
    const snapshot = await firestore
      .collection(notificationCollections.inboxItems)
      .where('recipientId', '==', userId)
      .get();
    if (snapshot.size >= count || Date.now() > deadline)
      return snapshot.docs.map((document) => document.data());
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

const query = (queryType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  requestId: `req-${queryType}`,
  queryType,
  payload,
});
const command = (
  commandType: string,
  idempotencyKey: string,
  payload: Record<string, unknown>,
) => ({
  schemaVersion: 1,
  requestId: `req-${commandType}`,
  idempotencyKey,
  commandType,
  payload,
});

void test('the trigger creates one inbox record and the callables serve only its recipient', async () => {
  const owner = 'f1-inbox-owner';
  const other = 'f1-inbox-other';
  const ownerToken = await createAuthorizedActor(owner);
  const otherToken = await createAuthorizedActor(other);

  // Callables are refused while their flags are off.
  const disabled = await callBookingFunction(
    'notificationsQueryV1',
    query('unreadSummary', {}),
    ownerToken,
  );
  assert.equal(
    disabled.body.result && (disabled.body.result as Record<string, unknown>).code,
    'feature_disabled',
  );

  await setLocalFlag(firestore, notificationsFlagIds.consumeBooking, true);
  await setLocalFlag(firestore, notificationsFlagIds.inbox, true);
  await setLocalFlag(firestore, notificationsFlagIds.preferences, true);
  const eventId = await book(owner, '01JF1INBOXTRIGGER000000001', 'occ_01JF1INBOXTRIGGER0000001');
  const items = await waitForItems(owner, 1);
  assert.equal(items.length, 1, 'the trigger did not create the record');
  assert.equal(items[0]!.templateKey, 'booking.confirmed');
  const receipt = await firestore
    .collection(notificationCollections.receipts)
    .doc(notificationReceiptId(eventId))
    .get();
  assert.equal(receipt.get('status'), 'created');

  const unauthenticated = await callBookingFunction(
    'notificationsQueryV1',
    query('unreadSummary', {}),
  );
  assert.equal((unauthenticated.body.result as Record<string, unknown>).code, 'unauthenticated');

  const listed = (
    await callBookingFunction(
      'notificationsQueryV1',
      query('listInbox', { locale: 'ru' }),
      ownerToken,
    )
  ).body.result as Record<string, unknown>;
  assert.equal(listed.kind, 'succeeded', JSON.stringify(listed));
  const [item] = listed.items as Record<string, unknown>[];
  assert.deepEqual(item!.content, {
    title: 'Бронь подтверждена',
    body: 'Ваше место на событии забронировано.',
  });
  const notificationId = String(item!.notificationId);

  const foreignList = (
    await callBookingFunction(
      'notificationsQueryV1',
      query('listInbox', { locale: 'en' }),
      otherToken,
    )
  ).body.result as Record<string, unknown>;
  assert.deepEqual(foreignList.items, []);
  const foreignRead = (
    await callBookingFunction(
      'notificationsCommandV1',
      command('markRead', 'f1-foreign-read-1', { notificationId }),
      otherToken,
    )
  ).body.result as Record<string, unknown>;
  assert.equal(foreignRead.code, 'notification_not_found');

  const read = (
    await callBookingFunction(
      'notificationsCommandV1',
      command('markRead', 'f1-owner-read-01', { notificationId }),
      ownerToken,
    )
  ).body.result as Record<string, unknown>;
  assert.equal(read.status, 'read');
  const summary = (
    await callBookingFunction('notificationsQueryV1', query('unreadSummary', {}), ownerToken)
  ).body.result as Record<string, unknown>;
  assert.equal(summary.unreadCount, 0);

  const preference = (
    await callBookingFunction(
      'notificationsCommandV1',
      command('updatePreferences', 'f1-owner-prefs-01', {
        expectedRevision: 0,
        categories: { 'booking.receipts': { push: true } },
      }),
      ownerToken,
    )
  ).body.result as Record<string, unknown>;
  assert.deepEqual([preference.code, preference.detail], ['invalid_preference', 'channel_unknown']);
});

void test('concurrent consumers and reconciliation overlapping in time create one record', async () => {
  await setLocalFlag(firestore, notificationsFlagIds.consumeBooking, false);
  const owner = 'f1-concurrent-owner';
  await createAuthorizedActor(owner);
  const eventId = await book(owner, '01JF1INBOXCONCURRENT000001', 'occ_01JF1INBOXCONCURRENT0001');
  const record = await firestore.collection(bookingCollections.outbox).doc(eventId).get();
  const store = new FirestoreNotificationsStore(firestore);
  const consumers = Array.from(
    { length: 6 },
    () => new NotificationEffectConsumer({ store, clock }),
  );
  const reconciler = new NotificationReconciler(
    store,
    new FirestoreBookingOutboxSource(firestore),
    consumers[0]!,
    clock,
  );
  const outcomes = await Promise.all([
    ...consumers.map((consumer) => consumer.consume(record.id, record.data())),
    reconciler.reconcile().then(() => 'reconciled'),
  ]);
  assert.ok(outcomes.filter((outcome) => outcome === 'created').length <= 1, String(outcomes));
  // Anything still in flight finishes on the next pass, never as a duplicate.
  clock.set(new Date(now.getTime() + 120_000));
  await reconciler.reconcile();
  const items = await firestore
    .collection(notificationCollections.inboxItems)
    .where('recipientId', '==', owner)
    .get();
  assert.equal(items.size, 1);
  const receipt = await firestore
    .collection(notificationCollections.receipts)
    .doc(notificationReceiptId(eventId))
    .get();
  assert.equal(receipt.get('status'), 'created');
});
