import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import type { UtcInstant } from '../shared/utc_instant.js';

export type RetentionPolicy =
  | {
      readonly policyId: string;
      readonly status: 'unresolved';
      readonly legalHoldSupported: boolean;
    }
  | {
      readonly policyId: string;
      readonly status: 'accepted';
      readonly durationDays: number;
      readonly legalHoldSupported: boolean;
      readonly evidenceRevision: string;
    };

export type RetentionDecision =
  | { readonly action: 'policy_unavailable'; readonly policyId: string }
  | { readonly action: 'retain_legal_hold'; readonly policyId: string }
  | {
      readonly action: 'retain_until';
      readonly policyId: string;
      readonly deleteAfterUtc: UtcInstant;
    }
  | {
      readonly action: 'dispatch_deletion';
      readonly policyId: string;
      readonly deleteAfterUtc: UtcInstant;
    };

export class RetentionRegistry {
  readonly #policies: ReadonlyMap<string, DeepReadonly<RetentionPolicy>>;

  constructor(policies: readonly RetentionPolicy[]) {
    const map = new Map<string, DeepReadonly<RetentionPolicy>>();
    for (const policy of policies) {
      if (
        !/^[a-z][a-z0-9._-]{0,95}$/.test(policy.policyId) ||
        map.has(policy.policyId) ||
        (policy.status === 'accepted' &&
          (!Number.isSafeInteger(policy.durationDays) ||
            policy.durationDays < 0 ||
            policy.durationDays > 36_600 ||
            policy.evidenceRevision.trim().length === 0))
      )
        throw new TypeError('retention_policy_invalid');
      map.set(policy.policyId, deepFreeze({ ...policy }));
    }
    this.#policies = map;
  }

  decide(
    policyId: string,
    createdAtUtc: UtcInstant,
    nowUtc: UtcInstant,
    legalHold: boolean,
  ): RetentionDecision {
    const policy = this.#policies.get(policyId);
    if (policy === undefined || policy.status === 'unresolved')
      return { action: 'policy_unavailable', policyId };
    if (legalHold) return { action: 'retain_legal_hold', policyId };
    const deleteAfterEpoch = Date.parse(createdAtUtc) + policy.durationDays * 86_400_000;
    const deleteAfterUtc = new Date(deleteAfterEpoch).toISOString() as UtcInstant;
    return Date.parse(nowUtc) >= deleteAfterEpoch
      ? { action: 'dispatch_deletion', policyId, deleteAfterUtc }
      : { action: 'retain_until', policyId, deleteAfterUtc };
  }
}
