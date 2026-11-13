import type { ManagedPageV1 } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { parseMarketId } from '../../reference_data/domain/identifiers.js';
import { IdentityFailure } from './failures.js';

export type ManagedPage = ManagedPageV1;

export function createManagedPage(input: {
  readonly pageId: string;
  readonly ownerUserId: string;
  readonly marketId: string;
  readonly nowUtc: string;
}): ManagedPage {
  const now = parseUtcInstant(input.nowUtc);
  return deepFreeze({
    schemaVersion: 1,
    pageId: parseEntityId(input.pageId),
    ownerUserId: parseEntityId(input.ownerUserId),
    marketId: parseMarketId(input.marketId),
    status: 'pendingReview',
    verificationStatus: 'pendingReview',
    revision: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
  });
}

export function decideManagedPage(
  page: ManagedPage,
  decision: 'verified' | 'rejected' | 'suspended' | 'revoked',
  nowUtc: string,
): ManagedPage {
  const allowed =
    page.verificationStatus === 'unverified' || page.verificationStatus === 'pendingReview'
      ? new Set(['verified', 'rejected'])
      : page.verificationStatus === 'verified'
        ? new Set(['suspended', 'revoked'])
        : page.verificationStatus === 'suspended'
          ? new Set(['verified', 'revoked'])
          : new Set<string>();
  if (!allowed.has(decision)) throw new IdentityFailure('invalid_transition');
  return deepFreeze({
    ...page,
    status: decision === 'verified' ? 'active' : 'restricted',
    verificationStatus: decision,
    revision: page.revision + 1,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}
