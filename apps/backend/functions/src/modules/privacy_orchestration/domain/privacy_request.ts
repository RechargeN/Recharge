import {
  parseEntityId,
  parseIdempotencyKey,
  type EntityId,
  type IdempotencyKey,
} from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';

export type PrivacyRequestType =
  'access' | 'erasure' | 'restriction' | 'rectification' | 'objection';
export type PrivacyRequestStatus =
  | 'submitted'
  | 'verified'
  | 'dispatched'
  | 'partially_completed'
  | 'completed'
  | 'failed'
  | 'cancelled';

export interface PrivacyRequest {
  readonly schemaVersion: 1;
  readonly requestId: EntityId;
  readonly subjectId: EntityId;
  readonly requestType: PrivacyRequestType;
  readonly status: PrivacyRequestStatus;
  readonly revision: number;
  readonly idempotencyKey: IdempotencyKey;
  readonly semanticHash: `sha256:${string}`;
  readonly requiredDomainIds: readonly string[];
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
  readonly terminalEvidenceIds: readonly EntityId[];
}

export function createPrivacyRequest(input: {
  readonly requestId: string;
  readonly subjectId: string;
  readonly requestType: PrivacyRequestType;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly requiredDomainIds: readonly string[];
  readonly occurredAtUtc: string;
}): DeepReadonly<PrivacyRequest> {
  if (!/^sha256:[0-9a-f]{64}$/.test(input.semanticHash))
    throw new TypeError('privacy_semantic_hash_invalid');
  const requiredDomainIds = validateDomains(input.requiredDomainIds);
  const occurredAtUtc = parseUtcInstant(input.occurredAtUtc);
  return deepFreeze({
    schemaVersion: 1,
    requestId: parseEntityId(input.requestId),
    subjectId: parseEntityId(input.subjectId),
    requestType: input.requestType,
    status: 'submitted',
    revision: 1,
    idempotencyKey: parseIdempotencyKey(input.idempotencyKey),
    semanticHash: input.semanticHash as `sha256:${string}`,
    requiredDomainIds,
    createdAtUtc: occurredAtUtc,
    updatedAtUtc: occurredAtUtc,
    terminalEvidenceIds: [],
  });
}

export function transitionPrivacyRequest(input: {
  readonly request: PrivacyRequest;
  readonly nextStatus: PrivacyRequestStatus;
  readonly occurredAtUtc: string;
  readonly terminalEvidenceIds?: readonly string[];
}): DeepReadonly<PrivacyRequest> {
  const allowed: Readonly<Record<PrivacyRequestStatus, readonly PrivacyRequestStatus[]>> = {
    submitted: ['verified', 'cancelled', 'failed'],
    verified: ['dispatched', 'cancelled', 'failed'],
    dispatched: ['partially_completed', 'completed', 'failed', 'cancelled'],
    partially_completed: ['partially_completed', 'completed', 'failed', 'cancelled'],
    completed: [],
    failed: [],
    cancelled: [],
  };
  if (!allowed[input.request.status].includes(input.nextStatus))
    throw new TypeError('privacy_request_transition_invalid');
  const evidence = (input.terminalEvidenceIds ?? []).map(parseEntityId);
  if (input.nextStatus === 'completed' && evidence.length < input.request.requiredDomainIds.length)
    throw new TypeError('privacy_request_terminal_evidence_missing');
  return deepFreeze({
    ...input.request,
    status: input.nextStatus,
    revision: input.request.revision + 1,
    updatedAtUtc: parseUtcInstant(input.occurredAtUtc),
    terminalEvidenceIds: evidence,
  });
}

function validateDomains(values: readonly string[]): readonly string[] {
  if (
    values.length < 1 ||
    values.length > 32 ||
    values.some((value) => !/^[a-z][a-z0-9._-]{0,63}$/.test(value)) ||
    new Set(values).size !== values.length
  )
    throw new TypeError('privacy_request_domains_invalid');
  return Object.freeze([...values].sort());
}
