import type { UtcInstant } from '../../../shared/utc_instant.js';
import type { RetentionDecision, RetentionRegistry } from '../../../security/retention_registry.js';

export interface RetentionDeletionTarget {
  readonly domainId: string;
  readonly recordId: string;
  readonly policyId: string;
  readonly createdAtUtc: UtcInstant;
  readonly legalHold: boolean;
}

export interface RetentionDeletionDispatch {
  readonly domainId: string;
  readonly recordId: string;
  readonly decision: RetentionDecision;
}

export function planRetentionDeletionDispatch(
  registry: RetentionRegistry,
  targets: readonly RetentionDeletionTarget[],
  nowUtc: UtcInstant,
): readonly RetentionDeletionDispatch[] {
  return Object.freeze(
    targets.map((target) =>
      Object.freeze({
        domainId: target.domainId,
        recordId: target.recordId,
        decision: registry.decide(target.policyId, target.createdAtUtc, nowUtc, target.legalHold),
      }),
    ),
  );
}
