import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';

export interface PrivacyEvidence {
  readonly evidenceId: EntityId;
  readonly requestId: EntityId;
  readonly taskId: EntityId;
  readonly outcome: 'completed' | 'not_found' | 'retained_legal_hold' | 'failed';
  readonly evidenceSha256: string;
  readonly occurredAtUtc: UtcInstant;
}

export function createPrivacyEvidence(
  input: Omit<PrivacyEvidence, 'evidenceId' | 'requestId' | 'taskId' | 'occurredAtUtc'> & {
    readonly evidenceId: string;
    readonly requestId: string;
    readonly taskId: string;
    readonly occurredAtUtc: string;
  },
): DeepReadonly<PrivacyEvidence> {
  if (!/^[0-9a-f]{64}$/.test(input.evidenceSha256))
    throw new TypeError('privacy_evidence_hash_invalid');
  return deepFreeze({
    ...input,
    evidenceId: parseEntityId(input.evidenceId),
    requestId: parseEntityId(input.requestId),
    taskId: parseEntityId(input.taskId),
    occurredAtUtc: parseUtcInstant(input.occurredAtUtc),
  });
}
