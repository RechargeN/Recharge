import type {
  DeliveryAttempt,
  LiveReceipt,
  NotificationReceipt,
} from '../domain/delivery_attempt.js';
import type { InboxItemRecord } from '../domain/inbox_item.js';
import {
  parseStoredPreferences,
  type NotificationPreferences,
} from '../domain/notification_policy.js';
import type {
  CommandReceiptRecord,
  InboxPosition,
  InboxView,
  NotificationEffectSource,
  NotificationsStore,
  NotificationsTransaction,
  NotificationSubjectCounts,
  RecipientStatus,
  ReconcileCheckpoint,
  SourcePosition,
  SourceRecord,
} from '../domain/repositories.js';

interface State {
  receipts: Map<string, NotificationReceipt>;
  attempts: Map<string, DeliveryAttempt>;
  items: Map<string, InboxItemRecord | Record<string, unknown>>;
  preferences: Map<string, unknown>;
  commandReceipts: Map<string, CommandReceiptRecord>;
  accounts: Map<string, 'active' | 'restricted'>;
  checkpoint?: ReconcileCheckpoint;
}

function clone(state: State): State {
  return {
    receipts: new Map(state.receipts),
    attempts: new Map(state.attempts),
    items: new Map(state.items),
    preferences: new Map(state.preferences),
    commandReceipts: new Map(state.commandReceipts),
    accounts: new Map(state.accounts),
    ...(state.checkpoint === undefined ? {} : { checkpoint: state.checkpoint }),
  };
}

function isItem(value: unknown): value is InboxItemRecord {
  return (
    typeof value === 'object' &&
    value !== null &&
    (value as InboxItemRecord).schemaVersion === 1 &&
    typeof (value as InboxItemRecord).notificationId === 'string' &&
    typeof (value as InboxItemRecord).recipientId === 'string'
  );
}

class InMemoryTransaction implements NotificationsTransaction {
  #wrote = false;

  constructor(private readonly state: State) {}

  #read(): void {
    if (this.#wrote) throw new Error('in_memory_read_after_write');
  }

  #write(): void {
    this.#wrote = true;
  }

  receipt(receiptId: string): Promise<NotificationReceipt | undefined> {
    this.#read();
    return Promise.resolve(this.state.receipts.get(receiptId));
  }

  attempt(attemptId: string): Promise<DeliveryAttempt | undefined> {
    this.#read();
    return Promise.resolve(this.state.attempts.get(attemptId));
  }

  recipientStatus(userId: string): Promise<RecipientStatus> {
    this.#read();
    return Promise.resolve(this.state.accounts.get(userId) ?? 'not_found');
  }

  preferences(userId: string): Promise<NotificationPreferences | undefined> {
    this.#read();
    const stored = this.state.preferences.get(userId);
    return Promise.resolve(
      stored === undefined ? undefined : parseStoredPreferences(userId, stored),
    );
  }

  inboxItem(notificationId: string): Promise<InboxItemRecord | 'foreign' | undefined> {
    this.#read();
    const item = this.state.items.get(notificationId);
    return Promise.resolve(item === undefined ? undefined : isItem(item) ? item : 'foreign');
  }

  aggregateReceipts(aggregateId: string): Promise<readonly LiveReceipt[]> {
    this.#read();
    return Promise.resolve(
      [...this.state.receipts.values()].filter(
        (receipt): receipt is LiveReceipt =>
          receipt.shape === 'live' && receipt.aggregateId === aggregateId,
      ),
    );
  }

  commandReceipt(commandReceiptId: string): Promise<CommandReceiptRecord | undefined> {
    this.#read();
    return Promise.resolve(this.state.commandReceipts.get(commandReceiptId));
  }

  putReceipt(receipt: NotificationReceipt): void {
    this.#write();
    this.state.receipts.set(receipt.receiptId, receipt);
  }

  putAttempt(attempt: DeliveryAttempt): void {
    this.#write();
    this.state.attempts.set(attempt.attemptId, attempt);
  }

  createInboxItem(item: InboxItemRecord): void {
    this.#write();
    if (this.state.items.has(item.notificationId)) throw new Error('already_exists');
    this.state.items.set(item.notificationId, item);
  }

  putInboxItem(item: InboxItemRecord): void {
    this.#write();
    this.state.items.set(item.notificationId, item);
  }

  putPreferences(preferences: NotificationPreferences): void {
    this.#write();
    this.state.preferences.set(preferences.userId, preferences);
  }

  createCommandReceipt(receipt: CommandReceiptRecord): void {
    this.#write();
    if (this.state.commandReceipts.has(receipt.commandReceiptId)) throw new Error('already_exists');
    this.state.commandReceipts.set(receipt.commandReceiptId, receipt);
  }
}

/**
 * Deterministic in-memory Notifications store for unit tests: a transaction
 * works on a copy that replaces the state only when the work resolves, and it
 * enforces the Firestore reads-before-writes rule.
 */
export class InMemoryNotificationsStore implements NotificationsStore {
  #state: State = {
    receipts: new Map(),
    attempts: new Map(),
    items: new Map(),
    preferences: new Map(),
    commandReceipts: new Map(),
    accounts: new Map(),
  };

  setAccount(userId: string, status: 'active' | 'restricted' | undefined): void {
    if (status === undefined) this.#state.accounts.delete(userId);
    else this.#state.accounts.set(userId, status);
  }

  /** Writes a raw stored document, including unreadable ones, for tests. */
  setRawPreferences(userId: string, value: unknown): void {
    this.#state.preferences.set(userId, value);
  }

  setRawItem(notificationId: string, value: Record<string, unknown>): void {
    this.#state.items.set(notificationId, value);
  }

  snapshot(): Readonly<{
    receipts: ReadonlyMap<string, NotificationReceipt>;
    attempts: ReadonlyMap<string, DeliveryAttempt>;
    items: ReadonlyMap<string, unknown>;
    preferences: ReadonlyMap<string, unknown>;
    commandReceipts: ReadonlyMap<string, CommandReceiptRecord>;
  }> {
    return clone(this.#state);
  }

  async transact<T>(work: (transaction: NotificationsTransaction) => Promise<T>): Promise<T> {
    const working = clone(this.#state);
    const result = await work(new InMemoryTransaction(working));
    this.#state = working;
    return result;
  }

  receipt(receiptId: string): Promise<NotificationReceipt | undefined> {
    return Promise.resolve(this.#state.receipts.get(receiptId));
  }

  inboxItemExists(notificationId: string): Promise<boolean> {
    return Promise.resolve(this.#state.items.has(notificationId));
  }

  #live(): LiveReceipt[] {
    return [...this.#state.receipts.values()].filter(
      (receipt): receipt is LiveReceipt => receipt.shape === 'live',
    );
  }

  dueReceipts(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]> {
    return Promise.resolve(
      this.#live()
        .filter(
          (receipt) =>
            (receipt.status === 'claimed' || receipt.status === 'retry_scheduled') &&
            receipt.nextAttemptAtUtc !== null &&
            receipt.nextAttemptAtUtc <= nowUtc,
        )
        .sort((left, right) => left.nextAttemptAtUtc!.localeCompare(right.nextAttemptAtUtc!))
        .slice(0, limit),
    );
  }

  expiredDeadLetters(nowUtc: string, limit: number): Promise<readonly LiveReceipt[]> {
    return Promise.resolve(
      this.#live()
        .filter(
          (receipt) =>
            receipt.status === 'dead_lettered' &&
            receipt.deliverUntilUtc !== null &&
            receipt.deliverUntilUtc < nowUtc,
        )
        .slice(0, limit),
    );
  }

  deadLetters(limit: number): Promise<readonly LiveReceipt[]> {
    return Promise.resolve(
      this.#live()
        .filter((receipt) => receipt.status === 'dead_lettered')
        .slice(0, limit),
    );
  }

  hasOpenReceipts(): Promise<boolean> {
    return Promise.resolve(
      this.#live().some((receipt) =>
        ['claimed', 'retry_scheduled', 'dead_lettered'].includes(receipt.status),
      ),
    );
  }

  checkpoint(): Promise<ReconcileCheckpoint | undefined> {
    return Promise.resolve(this.#state.checkpoint);
  }

  saveCheckpoint(checkpoint: ReconcileCheckpoint): Promise<void> {
    this.#state.checkpoint = checkpoint;
    return Promise.resolve();
  }

  #items(): InboxItemRecord[] {
    return [...this.#state.items.values()].filter(isItem);
  }

  listInbox(
    recipientId: string,
    view: InboxView,
    after: InboxPosition | undefined,
    limit: number,
  ): Promise<readonly InboxItemRecord[]> {
    const statuses = view === 'active' ? ['unread', 'read'] : ['archived'];
    const sorted = this.#items()
      .filter((item) => item.recipientId === recipientId && statuses.includes(item.status))
      .sort(
        (left, right) =>
          right.createdAtUtc.localeCompare(left.createdAtUtc) ||
          right.notificationId.localeCompare(left.notificationId),
      );
    const start =
      after === undefined
        ? 0
        : sorted.findIndex(
            (item) =>
              item.createdAtUtc < after.createdAtUtc ||
              (item.createdAtUtc === after.createdAtUtc &&
                item.notificationId < after.notificationId),
          );
    return Promise.resolve(start < 0 ? [] : sorted.slice(start, start + limit));
  }

  unreadCount(recipientId: string): Promise<number> {
    return Promise.resolve(
      this.#items().filter((item) => item.recipientId === recipientId && item.status === 'unread')
        .length,
    );
  }

  unreadUpTo(recipientId: string, cutoffUtc: string, limit: number): Promise<readonly string[]> {
    return Promise.resolve(
      this.#items()
        .filter(
          (item) =>
            item.recipientId === recipientId &&
            item.status === 'unread' &&
            item.createdAtUtc <= cutoffUtc,
        )
        .sort((left, right) => left.createdAtUtc.localeCompare(right.createdAtUtc))
        .slice(0, limit)
        .map((item) => item.notificationId),
    );
  }

  subjectInboxItemIds(userId: string, limit: number): Promise<readonly string[]> {
    return Promise.resolve(
      this.#items()
        .filter((item) => item.recipientId === userId)
        .slice(0, limit)
        .map((item) => item.notificationId),
    );
  }

  subjectReceipts(userId: string, limit: number): Promise<readonly LiveReceipt[]> {
    return Promise.resolve(
      this.#live()
        .filter((receipt) => receipt.recipientId === userId)
        .slice(0, limit),
    );
  }

  subjectCommandReceiptIds(userId: string, limit: number): Promise<readonly string[]> {
    return Promise.resolve(
      [...this.#state.commandReceipts.values()]
        .filter((receipt) => receipt.userId === userId)
        .slice(0, limit)
        .map((receipt) => receipt.commandReceiptId),
    );
  }

  deleteInboxItems(notificationIds: readonly string[]): Promise<void> {
    for (const id of notificationIds) this.#state.items.delete(id);
    return Promise.resolve();
  }

  deleteAttempts(attemptIds: readonly string[]): Promise<void> {
    for (const id of attemptIds) this.#state.attempts.delete(id);
    return Promise.resolve();
  }

  deleteCommandReceipts(commandReceiptIds: readonly string[]): Promise<void> {
    for (const id of commandReceiptIds) this.#state.commandReceipts.delete(id);
    return Promise.resolve();
  }

  deletePreferences(userId: string): Promise<void> {
    this.#state.preferences.delete(userId);
    return Promise.resolve();
  }

  subjectCounts(userId: string): Promise<NotificationSubjectCounts> {
    return Promise.resolve({
      inboxItems: this.#items().filter((item) => item.recipientId === userId).length,
      receipts: this.#live().filter((receipt) => receipt.recipientId === userId).length,
      commandReceipts: [...this.#state.commandReceipts.values()].filter(
        (receipt) => receipt.userId === userId,
      ).length,
      preferences: this.#state.preferences.has(userId) ? 1 : 0,
    });
  }
}

/** In-memory Booking outbox source for unit tests. */
export class InMemoryNotificationEffectSource implements NotificationEffectSource {
  readonly #records = new Map<string, SourceRecord>();

  put(id: string, data: Record<string, unknown>): void {
    this.#records.set(id, {
      id,
      createdAt: typeof data.createdAt === 'string' ? data.createdAt : '',
      data,
    });
  }

  #sorted(): SourceRecord[] {
    return [...this.#records.values()].sort(
      (left, right) =>
        left.createdAt.localeCompare(right.createdAt) || left.id.localeCompare(right.id),
    );
  }

  page(after: SourcePosition | null, limit: number): Promise<readonly SourceRecord[]> {
    const sorted = this.#sorted();
    const start =
      after === null
        ? 0
        : sorted.findIndex(
            (record) =>
              record.createdAt > after.createdAt ||
              (record.createdAt === after.createdAt && record.id > after.id),
          );
    return Promise.resolve(start < 0 ? [] : sorted.slice(start, start + limit));
  }

  get(eventId: string): Promise<SourceRecord | undefined> {
    return Promise.resolve(this.#records.get(eventId));
  }
}
