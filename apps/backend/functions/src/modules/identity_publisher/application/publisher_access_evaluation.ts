import type { PublisherEligibilityV1, PublisherRefV1 } from '../../../contracts/identity_v1.js';
import { assertCurrentSession } from '../domain/session.js';
import type { IdentityAuthorityTransaction } from '../domain/repositories.js';

export type PublisherAccessReason = PublisherEligibilityV1['reason'];

export interface PublisherAccessDecision {
  readonly eligible: boolean;
  readonly reason: PublisherAccessReason;
  readonly authorityRevision: number;
}

/**
 * Read-only backend-time evaluation of one actor for one exact Publisher:
 * current Session, active Account, verified Creator, and for a Page the exact
 * active membership, an active verified Page and the required capability. It
 * never creates or reads an AccessSnapshot, so a cached client snapshot is
 * never authority (BCK-14 §6, BCK-06).
 */
export async function evaluatePublisherAccess(
  transaction: IdentityAuthorityTransaction,
  input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly publisherRef: PublisherRefV1;
    readonly requiredCapability: string;
    readonly nowUtc: string;
  },
): Promise<PublisherAccessDecision> {
  const account = await transaction.account(input.userId);
  const session = await transaction.session(input.sessionId);
  if (account === null || session === null)
    return { eligible: false, reason: 'account_inactive', authorityRevision: 0 };
  try {
    assertCurrentSession(session, account, input.nowUtc);
  } catch {
    return {
      eligible: false,
      reason: 'snapshot_stale',
      authorityRevision: account.securityRevision,
    };
  }
  const revision = account.securityRevision;
  const deny = (reason: PublisherAccessReason): PublisherAccessDecision => ({
    eligible: false,
    reason,
    authorityRevision: revision,
  });
  if (account.status !== 'active') return deny('account_inactive');
  const verification = await transaction.verificationForUser(input.userId);
  if (verification?.status !== 'verified' || !account.systemRoles.includes('Creator'))
    return deny('creator_verification_required');
  if (input.publisherRef.type === 'user') {
    return input.publisherRef.id === input.userId
      ? { eligible: true, reason: 'eligible', authorityRevision: revision }
      : deny('publisher_not_accessible');
  }
  const membership = await transaction.membership(input.publisherRef.id, input.userId);
  if (membership?.status !== 'active') return deny('membership_inactive');
  const page = await transaction.page(input.publisherRef.id);
  if (page?.status !== 'active' || page.verificationStatus !== 'verified')
    return deny('publisher_not_accessible');
  if (!membership.capabilityIds.includes(input.requiredCapability))
    return deny('capability_denied');
  return { eligible: true, reason: 'eligible', authorityRevision: revision };
}
