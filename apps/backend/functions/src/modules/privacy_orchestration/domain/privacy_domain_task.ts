import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';

/**
 * `blocked` (L1): the domain did every step its accepted policy allows and the
 * rest waits for a named policy decision. It is visible and not terminal: the
 * request stays `partially_completed`, and a later run may continue the task.
 */
export type PrivacyDomainTaskStatus =
  'pending' | 'dispatched' | 'blocked' | 'succeeded' | 'failed' | 'cancelled';

export const privacyDomainTaskMaxAttempts = 5;

/** L1 policy blockers (PRIVACY_L1_DSR_RETENTION_HOLD_AMENDMENT.md §9). */
export const privacyPolicyBlockers = [
  'PB-01',
  'PB-02',
  'PB-03',
  'PB-04',
  'PB-05',
  'PB-06',
  'PB-07',
  'PB-08',
  'PB-09',
  'PB-10',
  'PB-11',
  'PB-12',
  'PB-13',
  'PB-14',
  'PB-15',
  'PB-16',
  'PB-17',
  'PB-18',
] as const;
export type PrivacyPolicyBlocker = (typeof privacyPolicyBlockers)[number];

export interface PrivacyDomainTask {
  readonly schemaVersion: 1;
  readonly taskId: EntityId;
  readonly requestId: EntityId;
  readonly subjectId: EntityId;
  readonly domainId: string;
  readonly marketId: MarketId | null;
  readonly targetRevision: number;
  readonly status: PrivacyDomainTaskStatus;
  readonly revision: number;
  readonly attempts: number;
  readonly evidenceId: EntityId | null;
  readonly completionOutcome: 'completed' | 'retained_legal_hold' | null;
  readonly retainedCount: number;
  readonly updatedAtUtc: UtcInstant;
  /** L1: the policy blockers a `blocked` task waits for; empty otherwise. */
  readonly blockedCodes?: readonly PrivacyPolicyBlocker[];
  /** L1: the privacy policy revision of the latest run. */
  readonly policyRevision?: string | null;
  /** L1: the runner holding the task; its effects are fenced by this lease. */
  readonly leaseOwner?: string | null;
  readonly leaseExpiresAtUtc?: UtcInstant | null;
}

export function createPrivacyDomainTask(input: {
  readonly taskId: string;
  readonly requestId: string;
  readonly subjectId: string;
  readonly domainId: string;
  readonly marketId: MarketId | null;
  readonly targetRevision: number;
  readonly occurredAtUtc: string;
}): DeepReadonly<PrivacyDomainTask> {
  if (
    !/^[a-z][a-z0-9._-]{0,63}$/.test(input.domainId) ||
    !Number.isSafeInteger(input.targetRevision) ||
    input.targetRevision < 0
  )
    throw new TypeError('privacy_task_scope_invalid');
  return deepFreeze({
    schemaVersion: 1,
    taskId: parseEntityId(input.taskId),
    requestId: parseEntityId(input.requestId),
    subjectId: parseEntityId(input.subjectId),
    domainId: input.domainId,
    marketId: input.marketId,
    targetRevision: input.targetRevision,
    status: 'pending',
    revision: 1,
    attempts: 0,
    evidenceId: null,
    completionOutcome: null,
    retainedCount: 0,
    updatedAtUtc: parseUtcInstant(input.occurredAtUtc),
  });
}

export function transitionPrivacyDomainTask(input: {
  readonly task: PrivacyDomainTask;
  readonly nextStatus: PrivacyDomainTaskStatus;
  readonly occurredAtUtc: string;
  readonly evidenceId?: string;
  readonly completionOutcome?: 'completed' | 'retained_legal_hold';
  readonly retainedCount?: number;
  readonly blockedCodes?: readonly PrivacyPolicyBlocker[];
}): DeepReadonly<PrivacyDomainTask> {
  const allowed: Readonly<Record<PrivacyDomainTaskStatus, readonly PrivacyDomainTaskStatus[]>> = {
    pending: ['dispatched', 'cancelled'],
    dispatched: ['dispatched', 'blocked', 'succeeded', 'failed', 'cancelled'],
    blocked: ['dispatched', 'cancelled'],
    succeeded: [],
    failed: [],
    cancelled: [],
  };
  if (!allowed[input.task.status].includes(input.nextStatus))
    throw new TypeError('privacy_task_transition_invalid');
  if (input.nextStatus === 'dispatched' && input.task.attempts >= privacyDomainTaskMaxAttempts) {
    throw new TypeError('privacy_task_retry_exhausted');
  }
  const blockedCodes = [...new Set(input.blockedCodes ?? [])].sort();
  if (
    (input.nextStatus === 'blocked') !== blockedCodes.length > 0 ||
    blockedCodes.some((code) => !privacyPolicyBlockers.includes(code))
  )
    throw new TypeError('privacy_task_blocked_codes_invalid');
  const evidenceId = input.evidenceId === undefined ? null : parseEntityId(input.evidenceId);
  if (input.nextStatus === 'succeeded' && evidenceId === null)
    throw new TypeError('privacy_task_evidence_missing');
  const completionOutcome =
    input.nextStatus === 'succeeded' ? (input.completionOutcome ?? 'completed') : null;
  const retainedCount = input.nextStatus === 'succeeded' ? (input.retainedCount ?? 0) : 0;
  if (
    !Number.isSafeInteger(retainedCount) ||
    retainedCount < 0 ||
    (completionOutcome === 'completed' && retainedCount !== 0) ||
    (completionOutcome === 'retained_legal_hold' && retainedCount < 1)
  ) {
    throw new TypeError('privacy_task_retention_evidence_invalid');
  }
  return deepFreeze({
    ...input.task,
    status: input.nextStatus,
    revision: input.task.revision + 1,
    attempts: input.nextStatus === 'dispatched' ? input.task.attempts + 1 : input.task.attempts,
    evidenceId,
    completionOutcome,
    retainedCount,
    blockedCodes,
    // Every recorded outcome ends the run that held the lease.
    leaseOwner: null,
    leaseExpiresAtUtc: null,
    updatedAtUtc: parseUtcInstant(input.occurredAtUtc),
  });
}

/**
 * L1: one runner takes the task for a bounded time. A live lease of another
 * owner is refused; an expired one may be taken over, and the revision bump
 * fences every later write of the previous owner. Taking a lease is not an
 * attempt: only a recorded retryable failure counts against the limit.
 */
export function leasePrivacyDomainTask(input: {
  readonly task: PrivacyDomainTask;
  readonly leaseOwner: string;
  readonly nowUtc: string;
  readonly leaseSeconds: number;
  readonly policyRevision: string;
}): DeepReadonly<PrivacyDomainTask> {
  if (input.task.status !== 'dispatched' && input.task.status !== 'blocked')
    throw new TypeError('privacy_task_transition_invalid');
  if (!/^[a-z0-9:._-]{1,128}$/.test(input.leaseOwner) || !(input.leaseSeconds > 0))
    throw new TypeError('privacy_task_lease_invalid');
  const now = Date.parse(parseUtcInstant(input.nowUtc));
  if (
    input.task.leaseOwner !== undefined &&
    input.task.leaseOwner !== null &&
    input.task.leaseOwner !== input.leaseOwner &&
    typeof input.task.leaseExpiresAtUtc === 'string' &&
    Date.parse(input.task.leaseExpiresAtUtc) > now
  )
    throw new TypeError('privacy_task_lease_held');
  return deepFreeze({
    ...input.task,
    status: 'dispatched',
    revision: input.task.revision + 1,
    blockedCodes: [],
    policyRevision: input.policyRevision,
    leaseOwner: input.leaseOwner,
    leaseExpiresAtUtc: parseUtcInstant(new Date(now + input.leaseSeconds * 1000).toISOString()),
    updatedAtUtc: parseUtcInstant(input.nowUtc),
  });
}

/** L1: a run that made bounded progress gives the task back without an outcome. */
export function releasePrivacyDomainTaskLease(input: {
  readonly task: PrivacyDomainTask;
  readonly nowUtc: string;
}): DeepReadonly<PrivacyDomainTask> {
  if (input.task.status !== 'dispatched') throw new TypeError('privacy_task_transition_invalid');
  return deepFreeze({
    ...input.task,
    revision: input.task.revision + 1,
    leaseOwner: null,
    leaseExpiresAtUtc: null,
    updatedAtUtc: parseUtcInstant(input.nowUtc),
  });
}
