import { RetentionRegistry, type RetentionPolicy } from '../security/retention_registry.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';

export const bookingRetentionPolicyIds = Object.freeze({
  core: 'booking.core.post-occurrence',
  idempotency: 'booking.idempotency.retry-window',
  outbox: 'booking.outbox.delivery-reconciliation',
  audit: 'booking.audit.legal-security',
});

export const bookingRetentionDecisionId = 'BCK09-RETENTION-DEC-01';
export const bookingRetentionBaselineMarkets = Object.freeze(['LV', 'EE', 'LT'] as const);
export const bookingRetentionDurationDays = Object.freeze({
  core: 90,
  idempotency: 7,
  outbox: 30,
  audit: 365,
});
export const bookingPhysicalDeletionTargetHours = 72;

export type BookingRetentionClass = keyof typeof bookingRetentionPolicyIds;

export interface BookingRetentionCandidate {
  readonly recordId: string;
  readonly retentionClass: BookingRetentionClass;
  readonly createdAtUtc: UtcInstant;
  readonly legalHold: boolean;
  readonly deliveredAtUtc?: UtcInstant;
  readonly reconciledAtUtc?: UtcInstant;
  /**
   * `core`: the Booking terminal time. `outbox`: any terminal Notifications
   * outcome (created, suppressed, expired, erased), so a suppressed or expired
   * obligation is not retained forever waiting for a delivery (F1 §8).
   */
  readonly terminalAtUtc?: UtcInstant;
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
  | Readonly<{
      action: 'dispatch_deletion';
      policyId: string;
      recordId: string;
      expiredAtUtc: UtcInstant;
      physicalDeletionDueByUtc: UtcInstant;
    }>;

export type BookingRestoreDecision =
  | Readonly<{ action: 'restore_allowed'; policyId: string; recordId: string }>
  | Readonly<{ action: 'restore_allowed_legal_hold'; policyId: string; recordId: string }>
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
    const outcomeAtUtc = candidate.deliveredAtUtc ?? candidate.terminalAtUtc;
    if (
      candidate.retentionClass === 'outbox' &&
      (outcomeAtUtc === undefined || candidate.reconciledAtUtc === undefined)
    ) {
      return { action: 'retain_delivery_pending', policyId, recordId: candidate.recordId };
    }
    const retentionAnchorUtc =
      candidate.retentionClass === 'outbox'
        ? laterInstant(outcomeAtUtc, candidate.reconciledAtUtc)
        : candidate.retentionClass === 'core' && candidate.terminalAtUtc !== undefined
          ? laterInstant(candidate.createdAtUtc, candidate.terminalAtUtc)
          : candidate.createdAtUtc;
    const decision = this.#registry.decide(policyId, retentionAnchorUtc, nowUtc, false);
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
      return {
        action: 'dispatch_deletion',
        policyId,
        recordId: candidate.recordId,
        expiredAtUtc: decision.deleteAfterUtc,
        physicalDeletionDueByUtc: addHoursUtc(
          decision.deleteAfterUtc,
          bookingPhysicalDeletionTargetHours,
        ),
      };
    }
    return { action: 'retain_legal_hold', policyId, recordId: candidate.recordId };
  }

  planRestore(candidate: BookingRetentionCandidate, nowUtc: UtcInstant): BookingRestoreDecision {
    const cleanup = this.plan(candidate, nowUtc);
    if (cleanup.action === 'retain_legal_hold') {
      return {
        action: 'restore_allowed_legal_hold',
        policyId: cleanup.policyId,
        recordId: cleanup.recordId,
      };
    }
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

export function acceptedBookingRetentionPolicies(): readonly RetentionPolicy[] {
  return Object.freeze(
    (Object.keys(bookingRetentionPolicyIds) as BookingRetentionClass[]).map((retentionClass) => ({
      policyId: bookingRetentionPolicyIds[retentionClass],
      status: 'accepted' as const,
      durationDays: bookingRetentionDurationDays[retentionClass],
      legalHoldSupported: true,
      evidenceRevision: bookingRetentionDecisionId,
    })),
  );
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
  readonly deliveredAtUtc?: string;
  readonly reconciledAtUtc?: string;
  readonly terminalAtUtc?: string;
}): BookingRetentionCandidate {
  return {
    recordId: input.recordId,
    retentionClass: input.retentionClass,
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
    legalHold: input.legalHold ?? false,
    ...(input.deliveredAtUtc === undefined
      ? {}
      : { deliveredAtUtc: parseUtcInstant(input.deliveredAtUtc) }),
    ...(input.reconciledAtUtc === undefined
      ? {}
      : { reconciledAtUtc: parseUtcInstant(input.reconciledAtUtc) }),
    ...(input.terminalAtUtc === undefined
      ? {}
      : { terminalAtUtc: parseUtcInstant(input.terminalAtUtc) }),
  };
}

export function idempotencyExpiresAt(createdAtUtc: string): Date {
  return new Date(retentionExpiryUtc('idempotency', parseUtcInstant(createdAtUtc)));
}

export function auditExpiresAt(occurredAtUtc: string): Date {
  return new Date(retentionExpiryUtc('audit', parseUtcInstant(occurredAtUtc)));
}

export function outboxExpiresAt(
  deliveredAtUtc: string | undefined,
  reconciledAtUtc: string | undefined,
  legalHold: boolean,
): Date | undefined {
  if (legalHold || deliveredAtUtc === undefined || reconciledAtUtc === undefined) return undefined;
  const anchor = laterInstant(parseUtcInstant(deliveredAtUtc), parseUtcInstant(reconciledAtUtc));
  return new Date(retentionExpiryUtc('outbox', anchor));
}

/**
 * F1: a v2 notification obligation expires a full outbox retention period after
 * the relevance deadline its producer declared. By then every Notifications
 * outcome is terminal (late work is `expired`), so no outcome waits forever.
 */
export function notificationOutboxExpiresAt(deliverUntilUtc: string): Date {
  return new Date(retentionExpiryUtc('outbox', parseUtcInstant(deliverUntilUtc)));
}

export function suppressedOutboxExpiresAt(
  suppressedAtUtc: string,
  legalHold: boolean,
): Date | undefined {
  if (legalHold) return undefined;
  return new Date(retentionExpiryUtc('outbox', parseUtcInstant(suppressedAtUtc)));
}

export function coreBookingExpiresAt(
  occurrenceEndUtc: string | undefined,
  terminalAtUtc: string,
  legalHold: boolean,
): Date | undefined {
  if (legalHold) return undefined;
  const terminal = parseUtcInstant(terminalAtUtc);
  const anchor =
    occurrenceEndUtc === undefined
      ? terminal
      : laterInstant(parseUtcInstant(occurrenceEndUtc), terminal);
  return new Date(retentionExpiryUtc('core', anchor));
}

function retentionExpiryUtc(
  retentionClass: BookingRetentionClass,
  anchorUtc: UtcInstant,
): UtcInstant {
  return addHoursUtc(anchorUtc, bookingRetentionDurationDays[retentionClass] * 24);
}

function addHoursUtc(value: UtcInstant, hours: number): UtcInstant {
  return new Date(Date.parse(value) + hours * 3_600_000).toISOString() as UtcInstant;
}

function laterInstant(first: UtcInstant | undefined, second: UtcInstant | undefined): UtcInstant {
  if (first === undefined || second === undefined) {
    throw new TypeError('outbox_completion_evidence_required');
  }
  return Date.parse(first) >= Date.parse(second) ? first : second;
}
