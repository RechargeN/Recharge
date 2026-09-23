import type { AccessSnapshotV1 } from '../../../contracts/identity_v1.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import type { Account } from './account.js';
import type { PageMembership } from './page_membership.js';
import type { IdentitySession } from './session.js';

export type AccessSnapshot = AccessSnapshotV1;

export function createAccessSnapshot(input: {
  readonly account: Account;
  readonly session: IdentitySession;
  readonly membership?: PageMembership;
  readonly personalCapabilityIds: readonly string[];
  readonly capabilityPolicyRevision: number;
  readonly evaluatedAtUtc: string;
  readonly expiresAtUtc: string;
}): AccessSnapshot {
  const base = {
    schemaVersion: 1 as const,
    userId: input.account.userId,
    sessionId: input.session.sessionId,
    accountRevision: input.account.revision,
    sessionRevision: input.session.revision,
    authzRevision: input.session.authzRevision,
    capabilityPolicyRevision: input.capabilityPolicyRevision,
    capabilityIds: [
      ...new Set(
        input.membership?.status === 'active'
          ? input.membership.capabilityIds
          : input.personalCapabilityIds,
      ),
    ].sort(),
    evaluatedAtUtc: parseUtcInstant(input.evaluatedAtUtc),
    expiresAtUtc: parseUtcInstant(input.expiresAtUtc),
  };
  return input.membership === undefined
    ? deepFreeze(base)
    : deepFreeze({
        ...base,
        pageId: input.membership.pageId,
        membershipRevision: input.membership.revision,
      });
}

export function isAccessSnapshotFresh(snapshot: AccessSnapshot, nowUtc: string): boolean {
  return Date.parse(nowUtc) <= Date.parse(snapshot.expiresAtUtc);
}
