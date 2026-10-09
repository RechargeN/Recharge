import { notificationConsumer } from './notification_effect.js';
import type { NotificationCategory } from './notification_policy.js';

/**
 * F1 delivery bookkeeping: one receipt per consumed effect (OD-09 consumer
 * key) and one attempt record per claim. Inbox state, receipt state and source
 * lifecycle are separate facts. All numbers are local stand constants.
 */
export const notificationDeliveryConfig = Object.freeze({
  leaseMs: 60_000,
  maxAttempts: 5,
  baseBackoffMs: 30_000,
  maxReplays: 3,
  attemptRetentionDays: 30,
  terminalRetentionDays: 30,
  itemRetentionDays: 90,
  commandReceiptRetentionDays: 7,
});

export type ReceiptStatus =
  'claimed' | 'retry_scheduled' | 'dead_lettered' | 'created' | 'suppressed' | 'expired' | 'erased';

export type SuppressionReason =
  | 'user_preference'
  | 'superseded'
  | 'recipient_restricted'
  | 'recipient_not_found'
  | 'recipient_erasure';

export type DeadLetterReason =
  | 'invalid_effect'
  | 'unsupported_effect'
  | 'retry_exhausted'
  | 'item_conflict'
  | 'template_unavailable'
  | 'policy_unavailable';

export interface PinnedRevisions {
  readonly policyRevision: number;
  readonly category: NotificationCategory;
  readonly templateKey: string;
  readonly templateRevision: number;
}

export interface ReplayAudit {
  readonly atUtc: string;
  readonly reason: string;
  readonly operator: string;
}

/**
 * A receipt that still carries effect data: while the effect is in flight
 * (claimed, retry, dead letter) or while its inbox record exists (created).
 */
export interface LiveReceipt {
  readonly schemaVersion: 1;
  readonly shape: 'live';
  readonly receiptId: string;
  readonly consumer: string;
  readonly consumerVersion: number;
  readonly status: 'claimed' | 'retry_scheduled' | 'dead_lettered' | 'created';
  readonly reason: DeadLetterReason | null;
  readonly eventId: string;
  readonly eventType: string | null;
  readonly aggregateId: string | null;
  readonly aggregateRevision: number | null;
  readonly recipientId: string | null;
  readonly payloadSha256: string | null;
  readonly occurredAtUtc: string | null;
  readonly deliverUntilUtc: string | null;
  readonly pinned: PinnedRevisions | null;
  readonly attemptCount: number;
  readonly attemptBudget: number;
  readonly replayCount: number;
  readonly replays: readonly ReplayAudit[];
  readonly leaseId: string | null;
  readonly leaseExpiresAtUtc: string | null;
  /** Due time for retry; for `claimed` it equals the lease expiry. */
  readonly nextAttemptAtUtc: string | null;
  readonly notificationId: string | null;
  readonly preferenceRevision: number | null;
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly terminalAtUtc: string | null;
  readonly expiresAt: Date | null;
}

/**
 * Every terminal outcome other than `created`: no recipient, event, aggregate,
 * payload hash, variables or references. The id is a hash of the event id only.
 */
export interface MinimalReceipt {
  readonly schemaVersion: 1;
  readonly shape: 'minimal';
  readonly receiptId: string;
  readonly consumer: string;
  readonly consumerVersion: number;
  readonly status: 'suppressed' | 'expired' | 'erased';
  readonly reason: SuppressionReason | null;
  readonly evidence: Readonly<{
    policyRevision?: number;
    templateRevision?: number;
    preferenceRevision?: number;
  }>;
  readonly terminalAtUtc: string;
  readonly expiresAt: Date;
}

export type NotificationReceipt = LiveReceipt | MinimalReceipt;

export function isTerminalStatus(status: ReceiptStatus): boolean {
  return (
    status === 'created' || status === 'suppressed' || status === 'expired' || status === 'erased'
  );
}

export function addDaysUtc(instant: string, days: number): string {
  return new Date(Date.parse(instant) + days * 86_400_000).toISOString();
}

export function addMsUtc(instant: string, ms: number): string {
  return new Date(Date.parse(instant) + ms).toISOString();
}

export function laterUtc(first: string, second: string | null): string {
  return second !== null && Date.parse(second) > Date.parse(first) ? second : first;
}

/** Never before the source outbox record (deliverUntil + 30 days) can be gone. */
export function terminalReceiptExpiresAt(
  terminalAtUtc: string,
  deliverUntilUtc: string | null,
): Date {
  return new Date(
    addDaysUtc(
      laterUtc(terminalAtUtc, deliverUntilUtc),
      notificationDeliveryConfig.terminalRetentionDays,
    ),
  );
}

export function retryBackoffMs(attemptNumber: number): number {
  return notificationDeliveryConfig.baseBackoffMs * 2 ** Math.max(0, attemptNumber - 1);
}

export function minimalReceipt(input: {
  readonly receiptId: string;
  readonly status: MinimalReceipt['status'];
  readonly reason: SuppressionReason | null;
  readonly terminalAtUtc: string;
  readonly deliverUntilUtc: string | null;
  readonly evidence?: MinimalReceipt['evidence'];
}): MinimalReceipt {
  return {
    schemaVersion: 1,
    shape: 'minimal',
    receiptId: input.receiptId,
    consumer: notificationConsumer.name,
    consumerVersion: notificationConsumer.version,
    status: input.status,
    reason: input.reason,
    evidence: input.evidence ?? {},
    terminalAtUtc: input.terminalAtUtc,
    expiresAt: terminalReceiptExpiresAt(input.terminalAtUtc, input.deliverUntilUtc),
  };
}

export type AttemptStatus = 'started' | 'succeeded' | 'failed' | 'abandoned';

export interface DeliveryAttempt {
  readonly schemaVersion: 1;
  readonly attemptId: string;
  readonly receiptId: string;
  readonly attemptNumber: number;
  readonly channel: 'inApp';
  readonly leaseId: string;
  readonly status: AttemptStatus;
  readonly outcome: ReceiptStatus | null;
  readonly failureClass: 'transient' | 'permanent' | null;
  readonly failureCode: string | null;
  readonly startedAtUtc: string;
  readonly finishedAtUtc: string | null;
  readonly expiresAt: Date;
}

export function attemptIdFor(receiptId: string, attemptNumber: number): string {
  return `${receiptId}_a${String(attemptNumber).padStart(2, '0')}`;
}

export function startedAttempt(input: {
  readonly receiptId: string;
  readonly attemptNumber: number;
  readonly leaseId: string;
  readonly startedAtUtc: string;
}): DeliveryAttempt {
  return {
    schemaVersion: 1,
    attemptId: attemptIdFor(input.receiptId, input.attemptNumber),
    receiptId: input.receiptId,
    attemptNumber: input.attemptNumber,
    channel: 'inApp',
    leaseId: input.leaseId,
    status: 'started',
    outcome: null,
    failureClass: null,
    failureCode: null,
    startedAtUtc: input.startedAtUtc,
    finishedAtUtc: null,
    expiresAt: new Date(
      addDaysUtc(input.startedAtUtc, notificationDeliveryConfig.attemptRetentionDays),
    ),
  };
}

export function finishedAttempt(
  attempt: DeliveryAttempt,
  input: {
    readonly status: Exclude<AttemptStatus, 'started'>;
    readonly outcome?: ReceiptStatus;
    readonly failureClass?: 'transient' | 'permanent';
    readonly failureCode?: string;
    readonly finishedAtUtc: string;
  },
): DeliveryAttempt {
  return {
    ...attempt,
    status: input.status,
    outcome: input.outcome ?? null,
    failureClass: input.failureClass ?? null,
    failureCode: input.failureCode ?? null,
    finishedAtUtc: input.finishedAtUtc,
  };
}
