import type { IdentityAuthorityRepository } from '../../identity_publisher/domain/repositories.js';
import { evaluatePublisherAccess } from '../../identity_publisher/application/publisher_access_evaluation.js';
import { assertCurrentSession } from '../../identity_publisher/domain/session.js';
import type {
  MediaActorAuthorityPort,
  MediaAuthorityRequest,
  MediaAuthorityResult,
} from '../application/ports/actor_authority_port.js';

/** The capability a Publisher needs to upload media for its own content. */
export const mediaUploadCapability = 'content.create';

/**
 * Media authority from the Identity owner records at backend time: Session and
 * revocation, enabled market, verified Creator and the exact Publisher
 * (personal, or an active verified Page with an active membership holding
 * `content.create`). Reading a Media status needs only a current Session; the
 * service itself restricts it to the owner.
 */
export class IdentityMediaActorAuthority implements MediaActorAuthorityPort {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly enabledMarkets: ReadonlySet<string>,
  ) {}

  async evaluate(request: MediaAuthorityRequest): Promise<MediaAuthorityResult> {
    if (!this.enabledMarkets.has(request.marketId))
      return { allowed: false, reason: 'market_disabled' };
    return this.repository.transact(async (transaction): Promise<MediaAuthorityResult> => {
      const account = await transaction.account(request.actor.userId);
      const session = await transaction.session(request.actor.sessionId);
      if (account === null || session === null)
        return { allowed: false, reason: 'session_invalid' };
      try {
        assertCurrentSession(session, account, request.nowUtc);
      } catch {
        return { allowed: false, reason: 'session_invalid' };
      }
      if (request.action === 'read')
        return { allowed: true, authorityRevision: account.securityRevision };
      // Upload and manage always name an exact Publisher; none is a refusal.
      if (request.publisherRef === undefined)
        return { allowed: false, reason: 'capability_denied' };
      const decision = await evaluatePublisherAccess(transaction, {
        userId: request.actor.userId,
        sessionId: request.actor.sessionId,
        publisherRef: request.publisherRef,
        requiredCapability: mediaUploadCapability,
        nowUtc: request.nowUtc,
      });
      if (decision.eligible)
        return { allowed: true, authorityRevision: decision.authorityRevision };
      return {
        allowed: false,
        reason:
          decision.reason === 'membership_inactive' ? 'membership_inactive' : 'capability_denied',
      };
    });
  }
}
