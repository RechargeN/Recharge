import {
  FieldPath,
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';

import { identityAuthorityCollections } from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import type {
  DeliveryAttempt,
  LiveReceipt,
  NotificationReceipt,
} from '../domain/delivery_attempt.js';
import type { InboxItemRecord } from '../domain/inbox_item.js';
import {
  notificationCategories,
  parseStoredPreferences,
  type NotificationPreferences,
} from '../domain/notification_policy.js';
import type {
  CommandReceiptRecord,
  InboxPosition,
  InboxView,
  NotificationsStore,
  NotificationsTransaction,
  NotificationSubjectCounts,
  RecipientStatus,
  ReconcileCheckpoint,
} from '../domain/repositories.js';

/** F1 Notifications collections; every one is denied to clients by Rules. */
export const notificationCollections = Object.freeze({
  inboxItems: 'notificationInboxItems',
  receipts: 'notificationEffectReceipts',
  attempts: 'notificationDeliveryAttempts',
  preferences: 'notificationPreferences',
  commandReceipts: 'notificationCommandReceipts',
  checkpoints: 'notificationReconcileCheckpoints',
});

const checkpointDocument = 'booking-outbox-v1';
const openStatuses = ['claimed', 'retry_scheduled', 'dead_lettered'];

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function parseReceipt(data: DocumentData | undefined): NotificationReceipt | undefined {
  if (data === undefined) return undefined;
  if (data.shape === 'minimal')
    return { ...(data as NotificationReceipt), expiresAt: toDate(data.expiresAt)! };
  return { ...(data as LiveReceipt), expiresAt: toDate(data.expiresAt) };
}

function parseAttempt(data: DocumentData | undefined): DeliveryAttempt | undefined {
  if (data === undefined) return undefined;
  return { ...(data as DeliveryAttempt), expiresAt: toDate(data.expiresAt)! };
}

const itemStatuses = ['unread', 'read', 'archived'];

function parseItem(data: DocumentData | undefined): InboxItemRecord | 'foreign' | undefined {
  if (data === undefined) return undefined;
  const expiresAt = toDate(data.expiresAt);
  if (
    data.schemaVersion !== 1 ||
    typeof data.notificationId !== 'string' ||
    typeof data.recipientId !== 'string' ||
    typeof data.receiptId !== 'string' ||
    !notificationCategories.includes(data.category as never) ||
    typeof data.templateKey !== 'string' ||
    !Number.isSafeInteger(data.templateRevision) ||
    !itemStatuses.includes(data.status as string) ||
    !Number.isSafeInteger(data.revision) ||
    typeof data.createdAtUtc !== 'string' ||
    expiresAt === null
  )
    return 'foreign';
  return { ...(data as InboxItemRecord), expiresAt };
}

function parseCommandReceipt(data: DocumentData | undefined): CommandReceiptRecord | undefined {
  if (data === undefined) return undefined;
  return { ...(data as CommandReceiptRecord), expiresAt: toDate(data.expiresAt)! };
}

function plain<T extends object>(value: T): DocumentData {
  return { ...value };
}

class FirestoreNotificationsTransaction implements NotificationsTransaction {
  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  #doc(collection: string, id: string) {
    return this.firestore.collection(collection).doc(id);
  }

  async receipt(receiptId: string): Promise<NotificationReceipt | undefined> {
    const snapshot = await this.transaction.get(
      this.#doc(notificationCollections.receipts, receiptId),
    );
    return parseReceipt(snapshot.data());
  }

  async attempt(attemptId: string): Promise<DeliveryAttempt | undefined> {
    const snapshot = await this.transaction.get(
      this.#doc(notificationCollections.attempts, attemptId),
    );
    return parseAttempt(snapshot.data());
  }

  async recipientStatus(userId: string): Promise<RecipientStatus> {
    const snapshot = await this.transaction.get(
      this.#doc(identityAuthorityCollections.accounts, userId),
    );
    if (!snapshot.exists) return 'not_found';
    return snapshot.get('status') === 'active' ? 'active' : 'restricted';
  }

  async preferences(userId: string): Promise<NotificationPreferences | undefined> {
    const snapshot = await this.transaction.get(
      this.#doc(notificationCollections.preferences, userId),
    );
    return snapshot.exists ? parseStoredPreferences(userId, snapshot.data()) : undefined;
  }

  async inboxItem(notificationId: string): Promise<InboxItemRecord | 'foreign' | undefined> {
    const snapshot = await this.transaction.get(
      this.#doc(notificationCollections.inboxItems, notificationId),
    );
    return parseItem(snapshot.data());
  }

  async aggregateReceipts(aggregateId: string): Promise<readonly LiveReceipt[]> {
    const snapshot = await this.transaction.get(
      this.firestore
        .collection(notificationCollections.receipts)
        .where('aggregateId', '==', aggregateId)
        .limit(100),
    );
    return snapshot.docs
      .map((document) => parseReceipt(document.data()))
      .filter((receipt): receipt is LiveReceipt => receipt?.shape === 'live');
  }

  async commandReceipt(commandReceiptId: string): Promise<CommandReceiptRecord | undefined> {
    const snapshot = await this.transaction.get(
      this.#doc(notificationCollections.commandReceipts, commandReceiptId),
    );
    return parseCommandReceipt(snapshot.data());
  }

  putReceipt(receipt: NotificationReceipt): void {
    this.transaction.set(
      this.#doc(notificationCollections.receipts, receipt.receiptId),
      plain(receipt),
    );
  }

  putAttempt(attempt: DeliveryAttempt): void {
    this.transaction.set(
      this.#doc(notificationCollections.attempts, attempt.attemptId),
      plain(attempt),
    );
  }

  createInboxItem(item: InboxItemRecord): void {
    this.transaction.create(
      this.#doc(notificationCollections.inboxItems, item.notificationId),
      plain(item),
    );
  }

  putInboxItem(item: InboxItemRecord): void {
    this.transaction.set(
      this.#doc(notificationCollections.inboxItems, item.notificationId),
      plain(item),
    );
  }

  putPreferences(preferences: NotificationPreferences): void {
    this.transaction.set(
      this.#doc(notificationCollections.preferences, preferences.userId),
      plain(preferences),
    );
  }

  createCommandReceipt(receipt: CommandReceiptRecord): void {
    this.transaction.create(
      this.#doc(notificationCollections.commandReceipts, receipt.commandReceiptId),
      plain(receipt),
    );
  }
}

export class FirestoreNotificationsStore implements NotificationsStore {
  constructor(private readonly firestore: Firestore) {}

  #collection(name: string) {
    return this.firestore.collection(name);
  }

  transact<T>(work: (transaction: NotificationsTransaction) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction((transaction) =>
      work(new FirestoreNotificationsTransaction(this.firestore, transaction)),
    );
  }

  async receipt(receiptId: string): Promise<NotificationReceipt | undefined> {
    return parseReceipt(
      (await this.#collection(notificationCollections.receipts).doc(receiptId).get()).data(),
    );
  }

  async inboxItemExists(notificationId: string): Promise<boolean> {
    return (await this.#collection(notificationCollections.inboxItems).doc(notificationId).get())
      .exists;
  }

  async dueReceipts(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]> {
    const snapshot = await this.#collection(notificationCollections.receipts)
      .where('status', 'in', ['claimed', 'retry_scheduled'])
      .where('nextAttemptAtUtc', '<=', nowUtc)
      .orderBy('nextAttemptAtUtc')
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => parseReceipt(document.data()) as LiveReceipt);
  }

  async expiredDeadLetters(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]> {
    const snapshot = await this.#collection(notificationCollections.receipts)
      .where('status', '==', 'dead_lettered')
      .where('deliverUntilUtc', '<', nowUtc)
      .orderBy('deliverUntilUtc')
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => parseReceipt(document.data()) as LiveReceipt);
  }

  async deadLetters(limit: number): Promise<readonly LiveReceipt[]> {
    const snapshot = await this.#collection(notificationCollections.receipts)
      .where('status', '==', 'dead_lettered')
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => parseReceipt(document.data()) as LiveReceipt);
  }

  async hasOpenReceipts(): Promise<boolean> {
    const snapshot = await this.#collection(notificationCollections.receipts)
      .where('status', 'in', openStatuses)
      .limit(1)
      .get();
    return !snapshot.empty;
  }

  async checkpoint(): Promise<ReconcileCheckpoint | undefined> {
    const data = (
      await this.#collection(notificationCollections.checkpoints).doc(checkpointDocument).get()
    ).data();
    return data === undefined ? undefined : (data as ReconcileCheckpoint);
  }

  async saveCheckpoint(checkpoint: ReconcileCheckpoint): Promise<void> {
    await this.#collection(notificationCollections.checkpoints)
      .doc(checkpointDocument)
      .set({ ...checkpoint });
  }

  async listInbox(
    recipientId: string,
    view: InboxView,
    after: InboxPosition | undefined,
    limit: number,
  ): Promise<readonly InboxItemRecord[]> {
    let query = this.#collection(notificationCollections.inboxItems)
      .where('recipientId', '==', recipientId)
      .where('status', 'in', view === 'active' ? ['unread', 'read'] : ['archived'])
      .orderBy('createdAtUtc', 'desc')
      .orderBy(FieldPath.documentId(), 'desc');
    if (after !== undefined) query = query.startAfter(after.createdAtUtc, after.notificationId);
    const snapshot = await query.limit(limit).get();
    return snapshot.docs
      .map((document) => parseItem(document.data()))
      .filter((item): item is InboxItemRecord => item !== undefined && item !== 'foreign');
  }

  async unreadCount(recipientId: string): Promise<number> {
    const snapshot = await this.#collection(notificationCollections.inboxItems)
      .where('recipientId', '==', recipientId)
      .where('status', '==', 'unread')
      .count()
      .get();
    return snapshot.data().count;
  }

  async unreadUpTo(
    recipientId: string,
    cutoffUtc: string,
    limit: number,
  ): Promise<readonly string[]> {
    const snapshot = await this.#collection(notificationCollections.inboxItems)
      .where('recipientId', '==', recipientId)
      .where('status', '==', 'unread')
      .where('createdAtUtc', '<=', cutoffUtc)
      .orderBy('createdAtUtc')
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => document.id);
  }

  async subjectInboxItemIds(userId: string, limit: number): Promise<readonly string[]> {
    const snapshot = await this.#collection(notificationCollections.inboxItems)
      .where('recipientId', '==', userId)
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => document.id);
  }

  async subjectReceipts(userId: string, limit: number): Promise<readonly LiveReceipt[]> {
    const snapshot = await this.#collection(notificationCollections.receipts)
      .where('recipientId', '==', userId)
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => parseReceipt(document.data()) as LiveReceipt);
  }

  async subjectCommandReceiptIds(userId: string, limit: number): Promise<readonly string[]> {
    const snapshot = await this.#collection(notificationCollections.commandReceipts)
      .where('userId', '==', userId)
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => document.id);
  }

  deleteInboxItems(notificationIds: readonly string[]): Promise<void> {
    return this.#deleteAll(notificationCollections.inboxItems, notificationIds);
  }

  deleteAttempts(attemptIds: readonly string[]): Promise<void> {
    return this.#deleteAll(notificationCollections.attempts, attemptIds);
  }

  deleteCommandReceipts(commandReceiptIds: readonly string[]): Promise<void> {
    return this.#deleteAll(notificationCollections.commandReceipts, commandReceiptIds);
  }

  async deletePreferences(userId: string): Promise<void> {
    await this.#collection(notificationCollections.preferences).doc(userId).delete();
  }

  async subjectCounts(userId: string): Promise<NotificationSubjectCounts> {
    const count = async (collection: string, field: string) =>
      (await this.#collection(collection).where(field, '==', userId).count().get()).data().count;
    const preferences = await this.#collection(notificationCollections.preferences)
      .doc(userId)
      .get();
    return {
      inboxItems: await count(notificationCollections.inboxItems, 'recipientId'),
      receipts: await count(notificationCollections.receipts, 'recipientId'),
      commandReceipts: await count(notificationCollections.commandReceipts, 'userId'),
      preferences: preferences.exists ? 1 : 0,
    };
  }

  async #deleteAll(collection: string, ids: readonly string[]): Promise<void> {
    for (let start = 0; start < ids.length; start += 400) {
      const batch = this.firestore.batch();
      for (const id of ids.slice(start, start + 400))
        batch.delete(this.#collection(collection).doc(id));
      await batch.commit();
    }
  }
}
