import type { Firestore } from 'firebase-admin/firestore';

import {
  notificationEffectRecord,
  type BookingNotificationEffect,
} from '../../src/booking/notification_effects.js';

import { identityAuthorityCollections } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import type {
  NotificationsStore,
  NotificationsTransaction,
} from '../../src/modules/notifications/domain/repositories.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';

/**
 * Writes the next immutable flag revision and moves the pointer, so a test can
 * switch a flag off and on again (the stand bootstrap only ever writes rev 1).
 */
export async function setLocalFlag(
  firestore: Firestore,
  capabilityId: string,
  enabled: boolean,
): Promise<void> {
  const key = featureFlagKey('local', 'LV', capabilityId);
  const pointerRef = firestore.collection(featureFlagPointerCollection).doc(key);
  await firestore.runTransaction(async (transaction) => {
    const pointer = await transaction.get(pointerRef);
    const active = Number(pointer.get('activeRevision') ?? 0);
    const next = active + 1;
    transaction.create(
      firestore
        .collection(featureFlagRevisionCollection)
        .doc(featureFlagRevisionDocumentId(key, next)),
      {
        schemaVersion: 1,
        revision: next,
        environmentId: 'local',
        marketId: 'LV',
        capabilityId,
        enabled,
        createdAtUtc: '2026-08-29T00:00:00.000Z',
      },
    );
    transaction.set(pointerRef, { key, activeRevision: next, pointerRevision: next });
  });
}

/** Writes the Identity account a recipient check reads (`active` or other). */
export async function setRecipientAccount(
  firestore: Firestore,
  userId: string,
  status: 'active' | 'restricted' | 'blocked',
): Promise<void> {
  await firestore
    .collection(identityAuthorityCollections.accounts)
    .doc(userId)
    .set({
      schemaVersion: 1,
      userId,
      status,
      systemRoles: ['User'],
      revision: 1,
      securityRevision: 1,
      revokeBeforeSecurityRevision: 0,
      createdAtUtc: '2026-08-29T00:00:00.000Z',
      updatedAtUtc: '2026-08-29T00:00:00.000Z',
    });
}

export async function cleanupNotifications(firestore: Firestore): Promise<void> {
  for (const name of [
    ...Object.values(notificationCollections),
    identityAuthorityCollections.accounts,
    'privacyRequests',
    'privacyDomainTasks',
    'privacyEvidence',
    'bookingPrivacyProgress',
  ]) {
    for (;;) {
      const snapshot = await firestore.collection(name).limit(200).get();
      if (snapshot.empty) break;
      const batch = firestore.batch();
      for (const document of snapshot.docs) batch.delete(document.ref);
      await batch.commit();
    }
  }
}

export type NotificationsFault = 'inbox_write' | 'preferences_read' | 'store';

/** The gRPC UNAVAILABLE shape a Firestore client raises when the store is down. */
export function unavailable(operation: string): Error {
  return Object.assign(new Error(`14 UNAVAILABLE: notifications store down (${operation})`), {
    code: 14,
  });
}

/**
 * A real Firestore-backed Notifications store that fails the chosen operation
 * with UNAVAILABLE, the way an outage of the inbox would. Booking, Identity and
 * the privacy orchestrator never receive this store.
 */
export class FaultyNotificationsStore implements NotificationsStore {
  readonly faults = new Set<NotificationsFault>();

  constructor(private readonly inner: NotificationsStore) {}

  #guard(operation: string): void {
    if (this.faults.has('store')) throw unavailable(operation);
  }

  transact<T>(work: (transaction: NotificationsTransaction) => Promise<T>): Promise<T> {
    if (this.faults.has('store')) return Promise.reject(unavailable('transact'));
    return this.inner.transact((transaction) => {
      const faults = this.faults;
      const wrapped: NotificationsTransaction = Object.create(
        transaction,
      ) as NotificationsTransaction;
      wrapped.receipt = (id) => transaction.receipt(id);
      wrapped.attempt = (id) => transaction.attempt(id);
      wrapped.recipientStatus = (id) => transaction.recipientStatus(id);
      wrapped.preferences = (id) =>
        faults.has('preferences_read')
          ? Promise.reject(unavailable('preferences_read'))
          : transaction.preferences(id);
      wrapped.inboxItem = (id) => transaction.inboxItem(id);
      wrapped.aggregateReceipts = (id) => transaction.aggregateReceipts(id);
      wrapped.commandReceipt = (id) => transaction.commandReceipt(id);
      wrapped.putReceipt = (value) => transaction.putReceipt(value);
      wrapped.putAttempt = (value) => transaction.putAttempt(value);
      wrapped.createInboxItem = (value) => {
        if (faults.has('inbox_write')) throw unavailable('inbox_write');
        transaction.createInboxItem(value);
      };
      wrapped.putInboxItem = (value) => {
        if (faults.has('inbox_write')) throw unavailable('inbox_write');
        transaction.putInboxItem(value);
      };
      wrapped.putPreferences = (value) => transaction.putPreferences(value);
      wrapped.createCommandReceipt = (value) => transaction.createCommandReceipt(value);
      return work(wrapped);
    });
  }

  receipt(id: string) {
    this.#guard('receipt');
    return this.inner.receipt(id);
  }
  inboxItemExists(id: string) {
    this.#guard('inboxItemExists');
    return this.inner.inboxItemExists(id);
  }
  dueReceipts(now: string, limit: number) {
    this.#guard('dueReceipts');
    return this.inner.dueReceipts(now, limit);
  }
  expiredDeadLetters(now: string, limit: number) {
    this.#guard('expiredDeadLetters');
    return this.inner.expiredDeadLetters(now, limit);
  }
  deadLetters(limit: number) {
    this.#guard('deadLetters');
    return this.inner.deadLetters(limit);
  }
  hasOpenReceipts() {
    this.#guard('hasOpenReceipts');
    return this.inner.hasOpenReceipts();
  }
  checkpoint() {
    this.#guard('checkpoint');
    return this.inner.checkpoint();
  }
  saveCheckpoint(value: Parameters<NotificationsStore['saveCheckpoint']>[0]) {
    this.#guard('saveCheckpoint');
    return this.inner.saveCheckpoint(value);
  }
  listInbox(...args: Parameters<NotificationsStore['listInbox']>) {
    this.#guard('listInbox');
    return this.inner.listInbox(...args);
  }
  unreadCount(id: string) {
    this.#guard('unreadCount');
    return this.inner.unreadCount(id);
  }
  unreadUpTo(...args: Parameters<NotificationsStore['unreadUpTo']>) {
    this.#guard('unreadUpTo');
    return this.inner.unreadUpTo(...args);
  }
  subjectInboxItemIds(id: string, limit: number) {
    this.#guard('subjectInboxItemIds');
    return this.inner.subjectInboxItemIds(id, limit);
  }
  subjectReceipts(id: string, limit: number) {
    this.#guard('subjectReceipts');
    return this.inner.subjectReceipts(id, limit);
  }
  subjectCommandReceiptIds(id: string, limit: number) {
    this.#guard('subjectCommandReceiptIds');
    return this.inner.subjectCommandReceiptIds(id, limit);
  }
  deleteInboxItems(ids: readonly string[]) {
    this.#guard('deleteInboxItems');
    return this.inner.deleteInboxItems(ids);
  }
  deleteAttempts(ids: readonly string[]) {
    this.#guard('deleteAttempts');
    return this.inner.deleteAttempts(ids);
  }
  deleteCommandReceipts(ids: readonly string[]) {
    this.#guard('deleteCommandReceipts');
    return this.inner.deleteCommandReceipts(ids);
  }
  deletePreferences(id: string) {
    this.#guard('deletePreferences');
    return this.inner.deletePreferences(id);
  }
  subjectCounts(id: string) {
    this.#guard('subjectCounts');
    return this.inner.subjectCounts(id);
  }
}

/** A Booking outbox v2 record exactly as Booking writes it (F1 §2). */
export function bookingEffect(
  input: Readonly<{
    effect?: BookingNotificationEffect;
    bookingId?: string;
    revision?: number;
    recipientId?: string;
    occurredAt?: string;
    eventId?: string;
    occurrenceId?: string;
  }> = {},
): Readonly<{ id: string; data: Record<string, unknown> }> {
  const record = notificationEffectRecord({
    effect: input.effect ?? { kind: 'confirmed' },
    booking: {
      id: input.bookingId ?? '01JF1BOOKING00000000000001',
      userId: input.recipientId ?? 'recipient-1',
      marketId: 'LV',
      eventId: input.eventId ?? 'evt_01JF1EVENT000000000000000',
      occurrenceId: input.occurrenceId ?? 'occ_01JF1OCCURRENCE0000000000',
    },
    actorId: input.recipientId ?? 'recipient-1',
    revision: input.revision ?? 1,
    occurredAt: input.occurredAt ?? '2026-08-29T12:00:00.000Z',
    correlationId: 'm1_f1correlation',
  });
  return { id: record.eventId, data: { ...record } };
}
