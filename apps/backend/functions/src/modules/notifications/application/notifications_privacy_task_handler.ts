import type { ServerClock } from '../../../shared/server_clock.js';
import { attemptIdFor, minimalReceipt } from '../domain/delivery_attempt.js';
import { defaultNotificationPolicies } from '../domain/notification_policy.js';
import type { NotificationsStore } from '../domain/repositories.js';

export type NotificationsPrivacyTaskType = 'access' | 'erasure' | 'restriction';

export type NotificationsPrivacyTaskResult =
  | Readonly<{
      kind: 'succeeded';
      evidence: Readonly<{
        recordCount: number;
        erasedCount: number;
        retainedCount: 0;
        outcome: 'completed';
      }>;
    }>
  | Readonly<{ kind: 'retryableFailure'; code: 'temporarily_unavailable' }>;

const pageSize = 200;

/**
 * F1 privacy domain `notifications` (F1 §9). Erasure runs only after the
 * orchestrator restricted the account, so a consumer that is already running
 * either sees the restriction inside its transaction or has committed a record
 * this pass removes. Receipts become tombstones without recipient, event,
 * aggregate, payload hash, template variables or references; attempts, inbox
 * records, command receipts and preferences are deleted.
 */
export class NotificationsPrivacyTaskHandler {
  constructor(
    private readonly store: NotificationsStore,
    private readonly clock: ServerClock,
  ) {}

  async handle(input: {
    readonly taskType: NotificationsPrivacyTaskType;
    readonly subjectId: string;
  }): Promise<NotificationsPrivacyTaskResult> {
    try {
      if (input.taskType === 'access') {
        const counts = await this.store.subjectCounts(input.subjectId);
        return succeeded(
          counts.inboxItems + counts.receipts + counts.commandReceipts + counts.preferences,
          0,
        );
      }
      if (input.taskType === 'restriction') return await this.#restrict(input.subjectId);
      return await this.#erase(input.subjectId);
    } catch {
      return { kind: 'retryableFailure', code: 'temporarily_unavailable' };
    }
  }

  async #restrict(subjectId: string): Promise<NotificationsPrivacyTaskResult> {
    const now = this.clock.now().toISOString();
    const policy = defaultNotificationPolicies.active();
    await this.store.transact(async (tx) => {
      let current;
      try {
        current = await tx.preferences(subjectId);
      } catch {
        // An unreadable document is replaced by a restricted default one.
        current = undefined;
      }
      if (current?.processingRestricted === true) return;
      tx.putPreferences({
        schemaVersion: 1,
        userId: subjectId,
        revision: (current?.revision ?? 0) + 1,
        policyRevision: current?.policyRevision ?? policy.revision,
        categories: current?.categories ?? {},
        processingRestricted: true,
        updatedAtUtc: now,
      });
    });
    return succeeded(1, 0);
  }

  async #erase(subjectId: string): Promise<NotificationsPrivacyTaskResult> {
    let recordCount = 0;
    let erasedCount = 0;
    const visited = new Set<string>();
    for (;;) {
      const receipts = (await this.store.subjectReceipts(subjectId, pageSize)).filter(
        (receipt) => !visited.has(receipt.receiptId),
      );
      if (receipts.length === 0) break;
      for (const receipt of receipts) {
        visited.add(receipt.receiptId);
        const now = this.clock.now().toISOString();
        const attempts = await this.store.transact(async (tx) => {
          const current = await tx.receipt(receipt.receiptId);
          if (current?.shape !== 'live' || current.recipientId !== subjectId) return [];
          tx.putReceipt(
            minimalReceipt({
              receiptId: current.receiptId,
              status: 'erased',
              reason: null,
              terminalAtUtc: now,
              deliverUntilUtc: current.deliverUntilUtc,
            }),
          );
          return Array.from({ length: current.attemptCount }, (_, index) =>
            attemptIdFor(current.receiptId, index + 1),
          );
        });
        if (attempts.length > 0) await this.store.deleteAttempts(attempts);
        recordCount += 1;
        erasedCount += 1;
      }
    }
    for (;;) {
      const ids = await this.store.subjectInboxItemIds(subjectId, pageSize);
      if (ids.length === 0) break;
      await this.store.deleteInboxItems(ids);
      recordCount += ids.length;
      erasedCount += ids.length;
    }
    for (;;) {
      const ids = await this.store.subjectCommandReceiptIds(subjectId, pageSize);
      if (ids.length === 0) break;
      await this.store.deleteCommandReceipts(ids);
      recordCount += ids.length;
      erasedCount += ids.length;
    }
    await this.store.deletePreferences(subjectId);
    return succeeded(recordCount, erasedCount);
  }
}

function succeeded(recordCount: number, erasedCount: number): NotificationsPrivacyTaskResult {
  return {
    kind: 'succeeded',
    evidence: { recordCount, erasedCount, retainedCount: 0, outcome: 'completed' },
  };
}
