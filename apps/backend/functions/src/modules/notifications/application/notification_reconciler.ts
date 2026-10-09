import type { ServerClock } from '../../../shared/server_clock.js';
import { minimalReceipt, notificationDeliveryConfig } from '../domain/delivery_attempt.js';
import {
  notificationEffectSha256,
  notificationReceiptId,
  parseNotificationEffect,
} from '../domain/notification_effect.js';
import type {
  NotificationEffectSource,
  NotificationsStore,
  SourcePosition,
  SourceRecord,
} from '../domain/repositories.js';
import type { ConsumeOutcome, NotificationEffectConsumer } from './consume_notification_effect.js';

export type ReconcileFindingCode =
  | 'receipt_missing'
  | 'consume_failed'
  | 'dead_letter'
  | 'inbox_item_missing'
  | 'payload_conflict'
  | 'source_missing';

export interface ReconcileFinding {
  readonly code: ReconcileFindingCode;
  readonly ref: string;
}

export interface ReconcileReport {
  readonly complete: boolean;
  readonly scanned: number;
  readonly reachedEnd: boolean;
  readonly startedAtSafe: boolean;
  readonly outcomes: Readonly<Partial<Record<ConsumeOutcome | 'expired_by_reconcile', number>>>;
  readonly findings: readonly ReconcileFinding[];
}

export type ReplayResult =
  | Readonly<{ kind: 'replayed' }>
  | Readonly<{ kind: 'not_found' }>
  | Readonly<{ kind: 'refused'; status: string }>
  | Readonly<{ kind: 'expired' }>
  | Readonly<{ kind: 'replay_exhausted' }>
  | Readonly<{ kind: 'reason_invalid' }>;

export interface NotificationReconcileConfig {
  readonly pageSize: number;
  readonly maxPages: number;
  readonly dueLimit: number;
}

/** F1 local bounds; not production values. */
export const notificationReconcileConfig: NotificationReconcileConfig = Object.freeze({
  pageSize: 100,
  maxPages: 50,
  dueLimit: 200,
});

function position(record: SourceRecord): SourcePosition {
  return { createdAt: record.createdAt, id: record.id };
}

/**
 * F1 reconciliation over the Booking outbox (F1 §7). A failing record is kept
 * for retry and reported, but never stops the pass: `scan` moves past it while
 * `safe` stays behind the first record without a receipt.
 */
export class NotificationReconciler {
  readonly #config: NotificationReconcileConfig;

  constructor(
    private readonly store: NotificationsStore,
    private readonly source: NotificationEffectSource,
    private readonly consumer: NotificationEffectConsumer,
    private readonly clock: ServerClock,
    config: Partial<NotificationReconcileConfig> = {},
  ) {
    this.#config = { ...notificationReconcileConfig, ...config };
  }

  async reconcile(): Promise<ReconcileReport> {
    const findings: ReconcileFinding[] = [];
    const outcomes: Partial<Record<ConsumeOutcome | 'expired_by_reconcile', number>> = {};
    const count = (key: ConsumeOutcome | 'expired_by_reconcile') => {
      outcomes[key] = (outcomes[key] ?? 0) + 1;
    };
    const checkpoint = (await this.store.checkpoint()) ?? { safe: null, scan: null };
    const startedAtSafe = checkpoint.scan === null;
    let cursor = checkpoint.scan ?? checkpoint.safe;
    let safe = checkpoint.safe;
    let contiguous = startedAtSafe;
    let reachedEnd = false;
    let scanned = 0;
    for (let page = 0; page < this.#config.maxPages; page += 1) {
      const records = await this.source.page(cursor, this.#config.pageSize);
      for (const record of records) {
        scanned += 1;
        const resolved = await this.#visit(record, findings, count);
        if (contiguous && resolved) safe = position(record);
        else contiguous = false;
        cursor = position(record);
      }
      if (records.length < this.#config.pageSize) {
        reachedEnd = true;
        break;
      }
    }
    await this.store.saveCheckpoint({
      safe,
      scan: reachedEnd ? null : cursor,
      updatedAtUtc: this.clock.now().toISOString(),
    });

    const now = this.clock.now().toISOString();
    for (const receipt of await this.store.dueReceipts(now, this.#config.dueLimit)) {
      try {
        if (
          receipt.deliverUntilUtc !== null &&
          Date.parse(now) > Date.parse(receipt.deliverUntilUtc)
        ) {
          if ((await this.consumer.expire(receipt.receiptId)) === 'expired')
            count('expired_by_reconcile');
          continue;
        }
        const record = await this.source.get(receipt.eventId);
        if (record === undefined) {
          findings.push({ code: 'source_missing', ref: receipt.receiptId });
          continue;
        }
        const outcome = await this.consumer.consume(record.id, record.data);
        count(outcome);
        if (outcome === 'failed_unrecorded')
          findings.push({ code: 'consume_failed', ref: receipt.receiptId });
      } catch {
        findings.push({ code: 'consume_failed', ref: receipt.receiptId });
      }
    }
    for (const receipt of await this.store.expiredDeadLetters(now, this.#config.dueLimit)) {
      try {
        if ((await this.consumer.expire(receipt.receiptId)) === 'expired')
          count('expired_by_reconcile');
      } catch {
        findings.push({ code: 'consume_failed', ref: receipt.receiptId });
      }
    }
    for (const receipt of await this.store.deadLetters(this.#config.dueLimit))
      findings.push({ code: 'dead_letter', ref: receipt.receiptId });
    const open = await this.store.hasOpenReceipts();
    return {
      complete: findings.length === 0 && startedAtSafe && reachedEnd && contiguous && !open,
      scanned,
      reachedEnd,
      startedAtSafe,
      outcomes,
      findings,
    };
  }

  /** `true` when the record needs nothing more from this pass's scan. */
  async #visit(
    record: SourceRecord,
    findings: ReconcileFinding[],
    count: (key: ConsumeOutcome) => void,
  ): Promise<boolean> {
    const parsed = parseNotificationEffect(record.id, record.data);
    if (parsed.kind === 'not_dispatchable') return true;
    const receiptId = notificationReceiptId(record.id);
    let receipt;
    try {
      receipt = await this.store.receipt(receiptId);
      if (receipt === undefined) {
        const outcome = await this.consumer.consume(record.id, record.data);
        count(outcome);
        if (outcome === 'failed_unrecorded')
          findings.push({ code: 'consume_failed', ref: receiptId });
        receipt = await this.store.receipt(receiptId);
      }
    } catch {
      findings.push({ code: 'consume_failed', ref: receiptId });
      receipt = undefined;
    }
    if (receipt === undefined) {
      findings.push({ code: 'receipt_missing', ref: receiptId });
      return false;
    }
    if (receipt.shape === 'live') {
      if (
        parsed.kind === 'effect' &&
        receipt.payloadSha256 !== null &&
        receipt.payloadSha256 !== notificationEffectSha256(parsed.effect)
      )
        findings.push({ code: 'payload_conflict', ref: receiptId });
      if (
        receipt.status === 'created' &&
        receipt.notificationId !== null &&
        !(await this.store.inboxItemExists(receipt.notificationId))
      )
        findings.push({ code: 'inbox_item_missing', ref: receiptId });
    }
    return true;
  }

  /**
   * Audited operator replay of one dead letter inside its relevance window.
   * Created, suppressed, expired and erased receipts are refused.
   */
  replay(input: {
    readonly receiptId: string;
    readonly reason: string;
    readonly operator: string;
  }): Promise<ReplayResult> {
    const reason = input.reason.trim();
    if (reason.length === 0 || reason.length > 200 || input.operator.trim().length === 0)
      return Promise.resolve({ kind: 'reason_invalid' });
    const now = this.clock.now().toISOString();
    return this.store.transact(async (tx) => {
      const receipt = await tx.receipt(input.receiptId);
      if (receipt === undefined) return { kind: 'not_found' };
      if (receipt.shape === 'minimal' || receipt.status !== 'dead_lettered')
        return { kind: 'refused', status: receipt.status };
      if (
        receipt.deliverUntilUtc !== null &&
        Date.parse(now) > Date.parse(receipt.deliverUntilUtc)
      ) {
        tx.putReceipt(
          minimalReceipt({
            receiptId: receipt.receiptId,
            status: 'expired',
            reason: null,
            terminalAtUtc: now,
            deliverUntilUtc: receipt.deliverUntilUtc,
          }),
        );
        return { kind: 'expired' };
      }
      if (receipt.replayCount >= notificationDeliveryConfig.maxReplays)
        return { kind: 'replay_exhausted' };
      tx.putReceipt({
        ...receipt,
        status: 'retry_scheduled',
        reason: null,
        nextAttemptAtUtc: now,
        attemptBudget: receipt.attemptCount + notificationDeliveryConfig.maxAttempts,
        replayCount: receipt.replayCount + 1,
        replays: [...receipt.replays, { atUtc: now, reason, operator: input.operator.trim() }],
        updatedAtUtc: now,
      });
      return { kind: 'replayed' };
    });
  }
}
