import type { PageMembershipV1 } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { parseLocalIdentityCapability } from './capability.js';

export type PageMembership = PageMembershipV1;

export function createOwnerMembership(input: {
  readonly membershipId: string;
  readonly pageId: string;
  readonly userId: string;
  readonly nowUtc: string;
}): PageMembership {
  const now = parseUtcInstant(input.nowUtc);
  return deepFreeze({
    schemaVersion: 1,
    membershipId: parseEntityId(input.membershipId),
    pageId: parseEntityId(input.pageId),
    userId: parseEntityId(input.userId),
    role: 'owner',
    status: 'active',
    capabilityIds: ['content.create', 'content.submit', 'content.publish', 'manage_page'],
    revision: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
  });
}

export function setMembershipCapabilities(
  membership: PageMembership,
  capabilities: readonly string[],
  nowUtc: string,
): PageMembership {
  return deepFreeze({
    ...membership,
    capabilityIds: [...new Set(capabilities.map(parseLocalIdentityCapability))].sort(),
    revision: membership.revision + 1,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}

export function revokeMembership(membership: PageMembership, nowUtc: string): PageMembership {
  return deepFreeze({
    ...membership,
    status: 'revoked',
    capabilityIds: [],
    revision: membership.revision + 1,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}
