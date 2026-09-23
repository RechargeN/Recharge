import { RetentionRegistry, type RetentionPolicy } from '../security/retention_registry.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';

export const bookingRetentionPolicyIds = Object.freeze({
  idempotency: 'booking.idempotency.retry-window',
  outbox: 'booking.outbox.delivery-reconciliation',
  audit: 'booking.audit.legal-security',
});

export type BookingRetentionClass = keyof typeof bookingRetentionPolicyIds;

export interface BookingRetentionCandidate {
  readonly recordId: string;
  readonly retentionClass: BookingRetentionClass;
  readonly createdAtUtc: UtcInstant;
  readonly legalHold: boolean;
  readonly deliveryCompleted?: boolean;
  readonly reconciliationCompleted?: boolean;
}

export type BookingCleanupDecision =
  | Readonly<{ action: 'retain_legal_hold'; policyId: string; recordId: string }>
  | Readonly<{ action: 'retain_delivery_pending'; policyId: string; recordId: string }>
  | Readonly<{ action: 'policy_unavailable'; policyId: string; recordId: string }>
  | Readonly<{
      action: 'retain_until';
      policyId: string;
      recordId: string;
      expiresAtUtc: UtcInstant;
    }>
  | Readonly<{ action: 'dispatch_deletion'; policyId: string; recordId: string }>;

export type BookingRestoreDecision =
  | Readonly<{ action: 'restore_allowed'; policyId: string; recordId: string }>
  | Readonly<{ action: 'restore_blocked_policy_unavailable'; policyId: string; recordId: string }>
  | Readonly<{ action: 'restore_blocked_expired'; policyId: string; recordId: string }>;

export class BookingRetentionPlanner {
  readonly #registry: RetentionRegistry;

  constructor(policies: readonly RetentionPolicy[]) {
    this.#registry = new RetentionRegistry(policies);
  }

  plan(candidate: BookingRetentionCandidate, nowUtc: UtcInstant): BookingCleanupDecision {
    const policyId = bookingRetentionPolicyIds[candidate.retentionClass];
    if (candidate.legalHold)
      return { action: 'retain_legal_hold', policyId, recordId: candidate.recordId };
    if (
      candidate.retentionClass === 'outbox' &&
      (candidate.deliveryCompleted !== true || candidate.reconciliationCompleted !== true)
    ) {
      return { action: 'retain_delivery_pending', policyId, recordId: candidate.recordId };
    }
    const decision = this.#registry.decide(policyId, candidate.createdAtUtc, nowUtc, false);
    if (decision.action === 'policy_unavailable') {
      return { ...decision, recordId: candidate.recordId };
    }
    if (decision.action === 'retain_until') {
      return {
        action: 'retain_until',
        policyId,
        recordId: candidate.recordId,
        expiresAtUtc: decision.deleteAfterUtc,
      };
    }
    if (decision.action === 'dispatch_deletion') {
      return { action: 'dispatch_deletion', policyId, recordId: candidate.recordId };
    }
    return { action: 'retain_legal_hold', policyId, recordId: candidate.recordId };
  }

  planRestore(candidate: BookingRetentionCandidate, nowUtc: UtcInstant): BookingRestoreDecision {
    const cleanup = this.plan(candidate, nowUtc);
    if (cleanup.action === 'policy_unavailable') {
      return {
        action: 'restore_blocked_policy_unavailable',
        policyId: cleanup.policyId,
        recordId: cleanup.recordId,
      };
    }
    if (cleanup.action === 'dispatch_deletion') {
      return {
        action: 'restore_blocked_expired',
        policyId: cleanup.policyId,
        recordId: cleanup.recordId,
      };
    }
    return {
      action: 'restore_allowed',
      policyId: cleanup.policyId,
      recordId: cleanup.recordId,
    };
  }
}

export function unresolvedBookingRetentionPolicies(): readonly RetentionPolicy[] {
  return Object.freeze(
    Object.values(bookingRetentionPolicyIds).map((policyId) => ({
      policyId,
      status: 'unresolved' as const,
      legalHoldSupported: true,
    })),
  );
}

export function bookingRetentionCandidate(input: {
  readonly recordId: string;
  readonly retentionClass: BookingRetentionClass;
  readonly createdAtUtc: string;
  readonly legalHold?: boolean;
  readonly deliveryCompleted?: boolean;
  readonly reconciliationCompleted?: boolean;
}): BookingRetentionCandidate {
  return {
    recordId: input.recordId,
    retentionClass: input.retentionClass,
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
    legalHold: input.legalHold ?? false,
    ...(input.deliveryCompleted === undefined
      ? {}
      : { deliveryCompleted: input.deliveryCompleted }),
    ...(input.reconciliationCompleted === undefined
      ? {}
      : { reconciliationCompleted: input.reconciliationCompleted }),
  };
}
