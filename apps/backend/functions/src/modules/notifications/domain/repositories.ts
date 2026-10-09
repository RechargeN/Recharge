import type { DeliveryAttempt, LiveReceipt, NotificationReceipt } from './delivery_attempt.js';
import type { InboxItemRecord } from './inbox_item.js';
import type { NotificationPreferences } from './notification_policy.js';

/** Recipient eligibility read from Identity; Notifications never decides it. */
export type RecipientStatus = 'active' | 'restricted' | 'not_found';

export interface CommandReceiptRecord {
  readonly schemaVersion: 1;
  readonly commandReceiptId: string;
  readonly userId: string;
  readonly commandType: string;
  readonly semanticSha256: string;
  readonly result: Readonly<Record<string, unknown>>;
  readonly createdAtUtc: string;
  readonly expiresAt: Date;
}

/**
 * One atomic unit over Notifications state. All reads happen before the first
 * write (Firestore transaction rule); a thrown error aborts every write.
 */
export interface NotificationsTransaction {
  receipt(receiptId: string): Promise<NotificationReceipt | undefined>;
  attempt(attemptId: string): Promise<DeliveryAttempt | undefined>;
  recipientStatus(userId: string): Promise<RecipientStatus>;
  /** Throws `PreferencesUnreadable` for a stored document that does not parse. */
  preferences(userId: string): Promise<NotificationPreferences | undefined>;
  /** `foreign`: a document exists under the id but is not a readable inbox record. */
  inboxItem(notificationId: string): Promise<InboxItemRecord | 'foreign' | undefined>;
  aggregateReceipts(aggregateId: string): Promise<readonly LiveReceipt[]>;
  commandReceipt(commandReceiptId: string): Promise<CommandReceiptRecord | undefined>;
  putReceipt(receipt: NotificationReceipt): void;
  putAttempt(attempt: DeliveryAttempt): void;
  createInboxItem(item: InboxItemRecord): void;
  putInboxItem(item: InboxItemRecord): void;
  putPreferences(preferences: NotificationPreferences): void;
  createCommandReceipt(receipt: CommandReceiptRecord): void;
}

export interface InboxPosition {
  readonly createdAtUtc: string;
  readonly notificationId: string;
}

export type InboxView = 'active' | 'archived';

export interface NotificationSubjectCounts {
  readonly inboxItems: number;
  readonly receipts: number;
  readonly commandReceipts: number;
  readonly preferences: number;
}

export interface NotificationsStore {
  transact<T>(work: (transaction: NotificationsTransaction) => Promise<T>): Promise<T>;
  receipt(receiptId: string): Promise<NotificationReceipt | undefined>;
  inboxItemExists(notificationId: string): Promise<boolean>;
  /** `claimed` with an expired lease and `retry_scheduled` that is due. */
  dueReceipts(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]>;
  /** Dead letters whose relevance window has passed (become `expired`). */
  expiredDeadLetters(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]>;
  deadLetters(limit: number): Promise<readonly LiveReceipt[]>;
  /** Whether any receipt is still claimed, scheduled for retry or dead-lettered. */
  hasOpenReceipts(): Promise<boolean>;
  checkpoint(): Promise<ReconcileCheckpoint | undefined>;
  saveCheckpoint(checkpoint: ReconcileCheckpoint): Promise<void>;
  listInbox(
    recipientId: string,
    view: InboxView,
    after: InboxPosition | undefined,
    limit: number,
  ): Promise<readonly InboxItemRecord[]>;
  unreadCount(recipientId: string): Promise<number>;
  unreadUpTo(recipientId: string, cutoffUtc: string, limit: number): Promise<readonly string[]>;
  subjectInboxItemIds(userId: string, limit: number): Promise<readonly string[]>;
  subjectReceipts(userId: string, limit: number): Promise<readonly LiveReceipt[]>;
  subjectCommandReceiptIds(userId: string, limit: number): Promise<readonly string[]>;
  deleteInboxItems(notificationIds: readonly string[]): Promise<void>;
  deleteAttempts(attemptIds: readonly string[]): Promise<void>;
  deleteCommandReceipts(commandReceiptIds: readonly string[]): Promise<void>;
  deletePreferences(userId: string): Promise<void>;
  subjectCounts(userId: string): Promise<NotificationSubjectCounts>;
}

export interface SourcePosition {
  readonly createdAt: string;
  readonly id: string;
}

export interface SourceRecord extends SourcePosition {
  readonly data: unknown;
}

/** Read-only port over the producer-owned Booking outbox. */
export interface NotificationEffectSource {
  page(after: SourcePosition | null, limit: number): Promise<readonly SourceRecord[]>;
  get(eventId: string): Promise<SourceRecord | undefined>;
}

/**
 * `safe`: every v2 record up to here has a receipt — it never passes a record
 * without one. `scan`: where the next pass resumes, ahead of `safe`, so one
 * failing record never blocks the rest.
 */
export interface ReconcileCheckpoint {
  readonly safe: SourcePosition | null;
  readonly scan: SourcePosition | null;
  readonly updatedAtUtc: string;
}
