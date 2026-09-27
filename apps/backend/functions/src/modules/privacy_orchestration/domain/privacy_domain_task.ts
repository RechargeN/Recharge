import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';

export type PrivacyDomainTaskStatus =
  'pending' | 'dispatched' | 'succeeded' | 'failed' | 'cancelled';

export const privacyDomainTaskMaxAttempts = 5;

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
}): DeepReadonly<PrivacyDomainTask> {
  const allowed: Readonly<Record<PrivacyDomainTaskStatus, readonly PrivacyDomainTaskStatus[]>> = {
    pending: ['dispatched', 'cancelled'],
    dispatched: ['dispatched', 'succeeded', 'failed', 'cancelled'],
    succeeded: [],
    failed: [],
    cancelled: [],
  };
  if (!allowed[input.task.status].includes(input.nextStatus))
    throw new TypeError('privacy_task_transition_invalid');
  if (input.nextStatus === 'dispatched' && input.task.attempts >= privacyDomainTaskMaxAttempts) {
    throw new TypeError('privacy_task_retry_exhausted');
  }
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
    updatedAtUtc: parseUtcInstant(input.occurredAtUtc),
  });
}
