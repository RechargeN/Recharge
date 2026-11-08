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
 * current Session and active Account; for a Page the exact active membership,
 * an active verified Page and the required capability. It never creates or
 * reads an AccessSnapshot, so a cached client snapshot is never authority
 * (BCK-14 §6, BCK-06).
 *
 * ADR 0023 (User = Creator; owner decision 2026-11-08, marketplace rule, DSA
 * Art. 30): no Creator role. For the personal publisher the caller passes the
 * commerce of the publication: `none` publishes freely; `external` (paid, or a
 * booking outside Recharge) needs the seller declaration; `inApp` needs it too,
 * and a trader also needs the identity verification fact. On suspected fraud
 * (`stepUpRequired`) any paid or bookable publication needs verification.
 * Page publishing keeps the verification fact as before.
 */
export async function evaluatePublisherAccess(
  transaction: IdentityAuthorityTransaction,
  input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly publisherRef: PublisherRefV1;
    readonly requiredCapability: string;
    readonly nowUtc: string;
    /** Explicit at every call site (ADR 0023): what the publication sells or books. */
    readonly commerce: 'none' | 'external' | 'inApp';
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
  const verified = async () =>
    (await transaction.verificationForUser(input.userId))?.status === 'verified';
  if (input.publisherRef.type === 'user') {
    if (input.publisherRef.id !== input.userId) return deny('publisher_not_accessible');
    if (input.commerce !== 'none') {
      const declaration = await transaction.sellerDeclaration(input.userId);
      if (declaration === null) return deny('seller_declaration_required');
      const stepUp =
        account.stepUpRequired === true ||
        (input.commerce === 'inApp' && declaration.declaration.status === 'trader');
      if (stepUp && !(await verified())) return deny('identity_verification_required');
    }
    return { eligible: true, reason: 'eligible', authorityRevision: revision };
  }
  if (!(await verified())) return deny('identity_verification_required');
  const membership = await transaction.membership(input.publisherRef.id, input.userId);
  if (membership?.status !== 'active') return deny('membership_inactive');
  const page = await transaction.page(input.publisherRef.id);
  if (page?.status !== 'active' || page.verificationStatus !== 'verified')
    return deny('publisher_not_accessible');
  if (!membership.capabilityIds.includes(input.requiredCapability))
    return deny('capability_denied');
  return { eligible: true, reason: 'eligible', authorityRevision: revision };
}
