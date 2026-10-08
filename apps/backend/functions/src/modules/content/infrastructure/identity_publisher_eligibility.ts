import type { PublisherEligibilityV1 } from '../../../contracts/identity_v1.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { evaluatePublisherAccess } from '../../identity_publisher/application/publisher_access_evaluation.js';
import type { IdentityAuthorityRepository } from '../../identity_publisher/domain/repositories.js';
import type {
  DelegatedEligibilityRequest,
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../application/ports/publisher_eligibility_port.js';

/**
 * Content's `PublisherEligibilityPort` answered from the Identity owner records
 * at backend time (BCK-06). Delegated modules have no Session and no approved
 * grant in this slice, so they are never eligible.
 */
export class IdentityPublisherEligibility implements PublisherEligibilityPort {
  constructor(private readonly repository: IdentityAuthorityRepository) {}

  async evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    const decision = await this.repository.transact((transaction) =>
      evaluatePublisherAccess(transaction, {
        userId: request.actor.userId,
        sessionId: request.actor.sessionId,
        publisherRef: request.publisherRef,
        requiredCapability: request.requiredCapability,
        nowUtc: request.nowUtc,
      }),
    );
    return {
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: decision.eligible,
      reason: decision.reason,
      authorityRevision: decision.authorityRevision,
      evaluatedAtUtc: parseUtcInstant(request.nowUtc),
    };
  }

  evaluateDelegated(request: DelegatedEligibilityRequest): Promise<PublisherEligibilityV1> {
    return Promise.resolve({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: false,
      reason: 'capability_denied',
      authorityRevision: 0,
      evaluatedAtUtc: parseUtcInstant(request.nowUtc),
    });
  }
}
