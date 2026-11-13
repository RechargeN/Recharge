import type { Firestore } from 'firebase-admin/firestore';

import { notificationReceiptId } from '../../src/modules/notifications/domain/notification_effect.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { FirestorePrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { createEmulatorNotifications } from '../../src/notifications_entry.js';
import {
  bookingNotificationFlagIds,
  notificationsFlagIds,
} from '../../src/shared/feature_flags.js';
import { setLocalFlag } from '../support/notifications_world.js';
import { standLinkedUserId } from './stand_session_fixture.js';

/**
 * Stand commands for the F1 Notifications inbox. Reconciliation, replay and
 * privacy run through the Notifications application layer in the trusted
 * backend context of the local stand; this file never writes an inbox record.
 * The only direct writes are flag revisions and the two stored-data fault
 * fixtures (`prefs-corrupt` / `prefs-repair`) the F1 gate uses to prove that
 * an unreadable Notifications state never blocks Booking.
 */
const flagGroups: Readonly<Record<string, readonly string[]>> = {
  producer: [bookingNotificationFlagIds.effects],
  consume: [notificationsFlagIds.consumeBooking],
  inbox: [notificationsFlagIds.inbox],
  preferences: [notificationsFlagIds.preferences],
  all: [
    bookingNotificationFlagIds.effects,
    notificationsFlagIds.consumeBooking,
    notificationsFlagIds.inbox,
    notificationsFlagIds.preferences,
  ],
};

const usage =
  'usage: notifications flags on|off <producer|consume|inbox|preferences|all> | reconcile | ' +
  'replay <receiptId> --reason <text> | status | inbox <userLabel> | receipt <eventId> | ' +
  'prefs-corrupt <userLabel> | prefs-repair <userLabel> | privacy-erase <userLabel> <requestId>';

export async function runNotifications(
  firestore: Firestore,
  args: readonly string[],
): Promise<unknown> {
  const [action, first, second, ...rest] = args;
  const notifications = createEmulatorNotifications(firestore);
  if (action === 'flags' && (first === 'on' || first === 'off') && second !== undefined) {
    const ids = flagGroups[second];
    if (ids === undefined) throw new Error(usage);
    for (const id of ids) await setLocalFlag(firestore, id, first === 'on');
    return { flags: ids, enabled: first === 'on' };
  }
  if (action === 'reconcile') return notifications.reconciler.reconcile();
  if (action === 'replay' && first !== undefined && second === '--reason') {
    const reason = rest.join(' ');
    return notifications.reconciler.replay({ receiptId: first, reason, operator: 'stand' });
  }
  if (action === 'status') return status(firestore);
  if (action === 'inbox' && first !== undefined) {
    const userId = await standLinkedUserId(firestore, first);
    const snapshot = await firestore
      .collection(notificationCollections.inboxItems)
      .where('recipientId', '==', userId)
      .get();
    const items = snapshot.docs
      .map((document) => ({
        notificationId: document.id,
        templateKey: document.get('templateKey') as unknown,
        status: document.get('status') as unknown,
        createdAtUtc: document.get('createdAtUtc') as unknown,
      }))
      .sort((left, right) => String(left.createdAtUtc).localeCompare(String(right.createdAtUtc)));
    return { items };
  }
  if (action === 'receipt' && first !== undefined) {
    const receipt = await notifications.store.receipt(notificationReceiptId(first));
    return receipt === undefined
      ? { found: false }
      : {
          found: true,
          receiptId: receipt.receiptId,
          status: receipt.status,
          reason: receipt.reason,
          ...(receipt.shape === 'live' ? { attemptCount: receipt.attemptCount } : {}),
        };
  }
  if (action === 'prefs-corrupt' && first !== undefined) {
    const userId = await standLinkedUserId(firestore, first);
    await firestore
      .collection(notificationCollections.preferences)
      .doc(userId)
      .set({ schemaVersion: 1, corruptedByStandFixture: true });
    return { corrupted: true };
  }
  if (action === 'prefs-repair' && first !== undefined) {
    const userId = await standLinkedUserId(firestore, first);
    await firestore.collection(notificationCollections.preferences).doc(userId).delete();
    return { repaired: true };
  }
  if (action === 'privacy-erase' && first !== undefined && second !== undefined) {
    return privacyErase(firestore, await standLinkedUserId(firestore, first), second);
  }
  throw new Error(usage);
}

async function status(firestore: Firestore): Promise<unknown> {
  const count = async (collection: string, field?: string, value?: string) => {
    const base = firestore.collection(collection);
    const query = field === undefined ? base : base.where(field, '==', value);
    return (await query.count().get()).data().count;
  };
  const receipts: Record<string, number> = {};
  for (const state of [
    'claimed',
    'retry_scheduled',
    'dead_lettered',
    'created',
    'suppressed',
    'expired',
    'erased',
  ])
    receipts[state] = await count(notificationCollections.receipts, 'status', state);
  return {
    inboxItems: await count(notificationCollections.inboxItems),
    receipts,
    attempts: await count(notificationCollections.attempts),
  };
}

/** One erasure DSR over Booking and Notifications, run to completion on the stand. */
async function privacyErase(firestore: Firestore, subjectId: string, requestId: string) {
  const repository = new FirestorePrivacyOrchestrationRepository(firestore);
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  const now = () => new Date().toISOString();
  const submitted = await service.submit({
    requestId,
    subjectId,
    requestType: 'erasure',
    idempotencyKey: `stand-erasure-${requestId.slice(0, 18)}`,
    semanticHash: `sha256:${'e'.repeat(64)}`,
    requiredDomainIds: ['booking', 'notifications'],
    occurredAtUtc: now(),
  });
  if (!submitted.ok) return { submitted };
  await service.verify(requestId, 1, now());
  await service.dispatch(
    requestId,
    2,
    [
      { domainId: 'booking', marketId: 'LV', targetRevision: 1 },
      { domainId: 'notifications', marketId: 'LV', targetRevision: 1 },
    ],
    now(),
  );
  const runner = new PrivacyDomainTaskRunner(firestore, repository, service);
  const notifications = await runner.runNotificationsTask({
    requestId,
    taskId: privacyDomainTaskId(requestId, 'notifications', 'LV', 1),
    nowUtc: now(),
  });
  const booking = await runner.runBookingTask({
    requestId,
    taskId: privacyDomainTaskId(requestId, 'booking', 'LV', 1),
    nowUtc: now(),
  });
  const reconciled = await service.reconcile(requestId, 3, now());
  return {
    booking,
    notifications,
    requestStatus: reconciled.ok ? reconciled.request.status : reconciled.code,
  };
}
