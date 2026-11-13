import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import {
  establishEmulatorIdentitySession,
  recoverEmulatorIdentitySessions,
} from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { NotificationEffectConsumer } from '../../src/modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from '../../src/modules/notifications/application/notification_reconciler.js';
import {
  notificationIdFor,
  notificationReceiptId,
} from '../../src/modules/notifications/domain/notification_effect.js';
import { FirestoreBookingOutboxSource } from '../../src/modules/notifications/infrastructure/firestore_notification_sources.js';
import {
  FirestoreNotificationsStore,
  notificationCollections,
} from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { FirestorePrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { bookingNotificationFlagIds } from '../../src/shared/feature_flags.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent, fixedNow } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupNotifications,
  FaultyNotificationsStore,
  setLocalFlag,
} from '../support/notifications_world.js';

/**
 * F1 §10: an unavailable inbox never blocks booking cancellation, access
 * recovery or independent privacy tasks. Failures are real: the Firestore-backed
 * Notifications store answers UNAVAILABLE on the inbox write or the preference
 * read, or stored Notifications data cannot be read. The trigger consumer flag
 * stays off, so only this test drives consumption.
 */
const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);
const store = new FirestoreNotificationsStore(firestore);
const faulty = new FaultyNotificationsStore(store);
const consumer = new NotificationEffectConsumer({ store: faulty, clock });
const reconciler = new NotificationReconciler(
  faulty,
  new FirestoreBookingOutboxSource(firestore),
  consumer,
  clock,
);

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

function futureEvent(occurrence: string): BookingEventProjection {
  return finiteEvent({
    occurrenceId: occurrence,
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
}

async function newUser(firebaseUid: string): Promise<string> {
  const session = await establishEmulatorIdentitySession({
    firestore,
    firebaseUid,
    installationId: `install-${firebaseUid}`,
    attemptRequestId: `req-${firebaseUid}`,
    now: new Date(),
  });
  return session.userId;
}

async function book(userId: string, bookingId: string, occurrence: string): Promise<void> {
  const event = futureEvent(occurrence);
  await seedEvent(event, firestore);
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    userId,
    createCommand({
      requestId: `req_${bookingId}`,
      idempotencyKey: `idem_${bookingId}`,
      payload: {
        occurrenceId: occurrence,
        inventoryPoolId: 'pool_general',
        channel: 'onsite',
        participantUnits: 1,
        namedGuests: [],
      },
    }),
  );
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
}

async function cancel(userId: string, bookingId: string): Promise<string> {
  const result = await cancelInternalBooking({ firestore, clock }, userId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: `req_cancel_${bookingId}`,
    idempotencyKey: `idem_cancel_${bookingId}`,
    expectedBookingRevision: 1,
    payload: { bookingId, reasonCode: 'user_request' },
  });
  return result.kind;
}

async function outboxRecord(eventId: string) {
  const snapshot = await firestore.collection(bookingCollections.outbox).doc(eventId).get();
  assert.equal(snapshot.exists, true, eventId);
  return { id: snapshot.id, data: snapshot.data()! };
}

async function itemsOf(userId: string) {
  const snapshot = await firestore
    .collection(notificationCollections.inboxItems)
    .where('recipientId', '==', userId)
    .get();
  return snapshot.docs.map((document) => document.data());
}

void test('inbox write and preference read outages: cancellation and recovery still complete', async () => {
  const firebaseUid = 'f1-unavailable-user';
  const userId = await newUser(firebaseUid);
  const bookingId = '01JF1UNAVAILABLE0000000001';
  await book(userId, bookingId, 'occ_01JF1UNAVAILABLE00000001');

  faulty.faults.add('inbox_write');
  const confirmation = await outboxRecord(`${bookingId}__r1`);
  assert.equal(await consumer.consume(confirmation.id, confirmation.data), 'retry_scheduled');

  // Cancellation is a Booking transaction only; the inbox outage cannot block it.
  faulty.faults.clear();
  faulty.faults.add('preferences_read');
  assert.equal(await cancel(userId, bookingId), 'succeeded');
  assert.equal(
    (await firestore.collection(bookingCollections.bookings).doc(bookingId).get()).get('state'),
    'cancelled',
  );
  const cancellation = await outboxRecord(`${bookingId}__r2`);
  assert.equal(await consumer.consume(cancellation.id, cancellation.data), 'retry_scheduled');

  // Access recovery does not touch Notifications at all.
  const recovered = await recoverEmulatorIdentitySessions({
    firestore,
    firebaseUid,
    installationId: `install-${firebaseUid}-2`,
    attemptRequestId: 'req-f1-recover',
    now: new Date(),
  });
  assert.equal(recovered.userId, userId);

  // The attempts are recorded although no inbox write ever committed.
  const failures = await firestore
    .collection(notificationCollections.attempts)
    .where('status', '==', 'failed')
    .get();
  assert.deepEqual(failures.docs.map((document) => String(document.get('failureCode'))).sort(), [
    'store_unavailable',
    'store_unavailable',
  ]);
  assert.equal((await itemsOf(userId)).length, 0);

  // Recovery: one logical record per effect, or a justified suppression.
  faulty.faults.clear();
  clock.set(new Date(fixedNow.getTime() + 60_000));
  const report = await reconciler.reconcile();
  assert.deepEqual(report.findings, []);
  const statuses = await Promise.all(
    [confirmation.id, cancellation.id].map(
      async (eventId) => (await store.receipt(notificationReceiptId(eventId)))?.status,
    ),
  );
  assert.ok(
    statuses.every((status) => status === 'created' || status === 'suppressed'),
    String(statuses),
  );
  const items = await itemsOf(userId);
  assert.equal(items.length, statuses.filter((status) => status === 'created').length);
  assert.ok(items.some((item) => item.templateKey === 'booking.cancelled.byUser'));
  assert.equal((await reconciler.reconcile()).complete, true);
  assert.equal((await itemsOf(userId)).length, items.length);
});

void test('stored Notifications data that cannot be read fails only Notifications', async () => {
  const userId = await newUser('f1-unreadable-user');
  const bookingId = '01JF1UNREADABLE00000000001';
  // An unreadable preference document and a foreign document on the record id.
  await firestore
    .collection(notificationCollections.preferences)
    .doc(userId)
    .set({ schemaVersion: 1, corrupted: true });
  await book(userId, bookingId, 'occ_01JF1UNREADABLE000000001');
  const confirmation = await outboxRecord(`${bookingId}__r1`);
  assert.equal(await consumer.consume(confirmation.id, confirmation.data), 'retry_scheduled');
  assert.equal(await cancel(userId, bookingId), 'succeeded');
  const cancellation = await outboxRecord(`${bookingId}__r2`);
  await firestore
    .collection(notificationCollections.inboxItems)
    .doc(notificationIdFor(notificationReceiptId(cancellation.id)))
    .set({ foreign: true });
  await firestore.collection(notificationCollections.preferences).doc(userId).delete();
  assert.equal(await consumer.consume(cancellation.id, cancellation.data), 'dead_lettered');

  // Repair the foreign document, replay the dead letter with a reason.
  await firestore
    .collection(notificationCollections.inboxItems)
    .doc(notificationIdFor(notificationReceiptId(cancellation.id)))
    .delete();
  assert.deepEqual(
    await reconciler.replay({
      receiptId: notificationReceiptId(cancellation.id),
      reason: 'foreign document removed after review',
      operator: 'f1-test',
    }),
    { kind: 'replayed' },
  );
  clock.set(new Date(fixedNow.getTime() + 120_000));
  await reconciler.reconcile();
  const items = await itemsOf(userId);
  assert.equal(items.filter((item) => item.templateKey === 'booking.cancelled.byUser').length, 1);
  assert.ok(items.length <= 2);
});

void test('a Notifications outage delays only its own privacy task; the DSR completes after it', async () => {
  const userId = await newUser('f1-privacy-outage-user');
  const bookingId = '01JF1PRIVACYOUTAGE00000001';
  await book(userId, bookingId, 'occ_01JF1PRIVACYOUTAGE000001');
  const repository = new FirestorePrivacyOrchestrationRepository(firestore);
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  const requestId = '6f0d1d5e-3c2b-4a5f-9a61-0f1f1e2d3c4b';
  const submitted = await service.submit({
    requestId,
    subjectId: userId,
    requestType: 'erasure',
    idempotencyKey: 'f1-privacy-outage-0001',
    semanticHash: `sha256:${'c'.repeat(64)}`,
    requiredDomainIds: ['booking', 'notifications'],
    occurredAtUtc: '2026-08-29T12:10:00.000Z',
  });
  assert.equal(submitted.ok, true, JSON.stringify(submitted));
  await service.verify(requestId, 1, '2026-08-29T12:11:00.000Z');
  await service.dispatch(
    requestId,
    2,
    [
      { domainId: 'booking', marketId: 'LV', targetRevision: 1 },
      { domainId: 'notifications', marketId: 'LV', targetRevision: 1 },
    ],
    '2026-08-29T12:12:00.000Z',
  );
  const runner = new PrivacyDomainTaskRunner(firestore, repository, service);
  faulty.faults.add('store');
  const notificationsTask = privacyDomainTaskId(requestId, 'notifications', 'LV', 1);
  assert.equal(
    await runner.runNotificationsTask(
      { requestId, taskId: notificationsTask, nowUtc: '2026-08-29T12:13:00.000Z' },
      { store: faulty },
    ),
    'retry_scheduled',
  );
  // Account restriction and the Booking task proceed regardless.
  assert.equal(
    (await firestore.collection('identityAccounts').doc(userId).get()).get('status'),
    'restricted',
  );
  assert.equal(
    await runner.runBookingTask({
      requestId,
      taskId: privacyDomainTaskId(requestId, 'booking', 'LV', 1),
      nowUtc: '2026-08-29T12:14:00.000Z',
    }),
    'succeeded',
  );
  const pending = await service.reconcile(requestId, 3, '2026-08-29T12:15:00.000Z');
  assert.ok(pending.ok && pending.request.status !== 'completed');

  // A running consumer cannot create a record for the restricted subject.
  faulty.faults.clear();
  const effects = await firestore
    .collection(bookingCollections.outbox)
    .where('aggregateId', '==', bookingId)
    .get();
  for (const document of effects.docs)
    assert.notEqual(await consumer.consume(document.id, document.data()), 'created');

  assert.equal(
    await runner.runNotificationsTask(
      { requestId, taskId: notificationsTask, nowUtc: '2026-08-29T12:16:00.000Z' },
      { store },
    ),
    'succeeded',
  );
  const completed = await service.reconcile(requestId, 3, '2026-08-29T12:17:00.000Z');
  assert.ok(completed.ok && completed.request.status === 'completed', JSON.stringify(completed));
  assert.equal((await itemsOf(userId)).length, 0);
});
