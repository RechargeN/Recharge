import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
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
import { cleanupNotifications, setLocalFlag } from '../support/notifications_world.js';

/**
 * F1 §9: erasure against a consumer that is already running, in both orders,
 * then redelivery and replay. Nothing erased may come back, and a tombstone
 * keeps no recipient, event, aggregate, payload, variable or reference.
 */
const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);
const store = new FirestoreNotificationsStore(firestore);
const consumer = new NotificationEffectConsumer({ store, clock });
const reconciler = new NotificationReconciler(
  store,
  new FirestoreBookingOutboxSource(firestore),
  consumer,
  clock,
);
const repository = new FirestorePrivacyOrchestrationRepository(firestore);
const service = new PrivacyOrchestrationService(repository, repository, repository);
const runner = new PrivacyDomainTaskRunner(firestore, repository, service);

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

async function subjectWithBooking(name: string, bookingId: string) {
  const session = await establishEmulatorIdentitySession({
    firestore,
    firebaseUid: `f1-privacy-${name}`,
    installationId: `install-f1-privacy-${name}`,
    attemptRequestId: `req-f1-privacy-${name}`,
    now: new Date(),
  });
  const occurrenceId = `occ_01JF1PRIVACY${name.toUpperCase().padEnd(13, '0')}`;
  const event: BookingEventProjection = finiteEvent({ occurrenceId });
  await seedEvent(event, firestore);
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    session.userId,
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
  const effect = await firestore
    .collection(bookingCollections.outbox)
    .doc(`${bookingId}__r1`)
    .get();
  return { userId: session.userId, effect: { id: effect.id, data: effect.data()! } };
}

async function erase(subjectId: string, requestId: string): Promise<void> {
  assert.equal(
    (
      await service.submit({
        requestId,
        subjectId,
        requestType: 'erasure',
        idempotencyKey: `f1-erasure-${requestId.slice(0, 8)}`,
        semanticHash: `sha256:${'d'.repeat(64)}`,
        requiredDomainIds: ['notifications'],
        occurredAtUtc: '2026-08-29T12:20:00.000Z',
      })
    ).ok,
    true,
  );
  await service.verify(requestId, 1, '2026-08-29T12:21:00.000Z');
  await service.dispatch(
    requestId,
    2,
    [{ domainId: 'notifications', marketId: 'LV', targetRevision: 1 }],
    '2026-08-29T12:22:00.000Z',
  );
  assert.equal(
    await runner.runNotificationsTask({
      requestId,
      taskId: privacyDomainTaskId(requestId, 'notifications', 'LV', 1),
      nowUtc: '2026-08-29T12:23:00.000Z',
    }),
    'succeeded',
  );
  const reconciled = await service.reconcile(requestId, 3, '2026-08-29T12:24:00.000Z');
  assert.ok(reconciled.ok && reconciled.request.status === 'completed');
}

async function assertNothingPersonal(receiptId: string, userId: string, bookingId: string) {
  const snapshot = await firestore
    .collection(notificationCollections.receipts)
    .doc(receiptId)
    .get();
  assert.equal(snapshot.get('status'), 'erased');
  const serialized = JSON.stringify(snapshot.data());
  for (const leak of [userId, bookingId, 'evt_', 'occ_', 'payload', 'aggregate', 'ntf_', 'eventId'])
    assert.equal(serialized.includes(leak), false, leak);
  const attempts = await firestore
    .collection(notificationCollections.attempts)
    .where('receiptId', '==', receiptId)
    .get();
  assert.equal(attempts.empty, true);
}

void test('claim before erasure, completion after: the stale completion writes nothing', async () => {
  const bookingId = '01JF1PRIVACYRACECLAIM00001';
  const { userId, effect } = await subjectWithBooking('claimfirst', bookingId);
  const claimed = await consumer.claim(effect.id, effect.data);
  assert.equal(claimed.kind, 'claimed');
  if (claimed.kind !== 'claimed') return;
  await erase(userId, '0d6b4f2a-1c3e-4b5d-8e7f-9a0b1c2d3e4f');
  assert.deepEqual(await consumer.complete(claimed.claim), { kind: 'stale' });
  assert.equal(
    (
      await firestore
        .collection(notificationCollections.inboxItems)
        .doc(notificationIdFor(claimed.claim.receiptId))
        .get()
    ).exists,
    false,
  );
  await assertNothingPersonal(claimed.claim.receiptId, userId, bookingId);
  // Redelivery and replay after erasure bring nothing back.
  assert.equal(await consumer.consume(effect.id, effect.data), 'duplicate');
  assert.deepEqual(
    await reconciler.replay({ receiptId: claimed.claim.receiptId, reason: 'try', operator: 'ops' }),
    { kind: 'refused', status: 'erased' },
  );
  await reconciler.reconcile();
  assert.equal(
    (
      await firestore
        .collection(notificationCollections.inboxItems)
        .where('recipientId', '==', userId)
        .get()
    ).empty,
    true,
  );
});

void test('completion before erasure: the record is erased and cannot be resurrected', async () => {
  const bookingId = '01JF1PRIVACYRACEDONE000001';
  const { userId, effect } = await subjectWithBooking('donefirst', bookingId);
  assert.equal(await consumer.consume(effect.id, effect.data), 'created');
  const receiptId = notificationReceiptId(effect.id);
  await erase(userId, '1e7c5a3b-2d4f-4c6e-9f80-ab1c2d3e4f50');
  assert.equal(
    (
      await firestore
        .collection(notificationCollections.inboxItems)
        .doc(notificationIdFor(receiptId))
        .get()
    ).exists,
    false,
  );
  await assertNothingPersonal(receiptId, userId, bookingId);
  assert.equal(await consumer.consume(effect.id, effect.data), 'duplicate');
  assert.deepEqual(await reconciler.replay({ receiptId, reason: 'try', operator: 'ops' }), {
    kind: 'refused',
    status: 'erased',
  });
});

void test('a claim after the restriction writes only a minimal suppression', async () => {
  const bookingId = '01JF1PRIVACYAFTER000000001';
  const { userId, effect } = await subjectWithBooking('afterward', bookingId);
  await erase(userId, '2f8d6b4c-3e50-4d7f-a091-bc2d3e4f5061');
  assert.equal(await consumer.consume(effect.id, effect.data), 'suppressed');
  const snapshot = await firestore
    .collection(notificationCollections.receipts)
    .doc(notificationReceiptId(effect.id))
    .get();
  assert.equal(snapshot.get('reason'), 'recipient_restricted');
  assert.equal(snapshot.get('shape'), 'minimal');
  assert.equal(JSON.stringify(snapshot.data()).includes(userId), false);
});
