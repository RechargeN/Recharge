import type { ContentTypeId } from '../../../../contracts/content_v1.js';
import type { PublisherEligibilityV1, PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { EntityId } from '../../../../shared/ids.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';
import type { ContentAction } from '../../domain/content_type_registry.js';

/** Server-resolved caller; never a client-supplied claim. */
export interface ContentActor {
  readonly userId: EntityId;
  readonly sessionId: EntityId;
}

export interface PublisherEligibilityRequest {
  readonly actor: ContentActor;
  readonly publisherRef: PublisherRefV1;
  readonly typeId: ContentTypeId;
  readonly action: ContentAction;
  readonly marketId: MarketId;
  readonly requiredCapability: string;
  readonly nowUtc: string;
}

/**
 * BCK-06 `identity.getPublisherEligibility` for the exact
 * `{PublisherRef, typeId, action, market}`. Cached mobile AccessSnapshot is
 * never transaction authority.
 */
export interface PublisherEligibilityPort {
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1>;

  /**
   * Eligibility for an approved server module acting for a Publisher without a
   * user Session. The Publisher itself (account, verification, page and
   * delegation) is still evaluated by BCK-06; the absence of a Session never
   * weakens authorization.
   */
  evaluateDelegated(request: DelegatedEligibilityRequest): Promise<PublisherEligibilityV1>;
}

/** An approved server module and the operation it performs (no user Session). */
export interface DelegatedActor {
  readonly moduleId: string;
  readonly operation: string;
  /** `module:<moduleId>/<operation>` */
  readonly actorRef: string;
}

export interface DelegatedEligibilityRequest {
  readonly delegatedActor: DelegatedActor;
  readonly publisherRef: PublisherRefV1;
  readonly typeId: ContentTypeId;
  readonly action: ContentAction;
  readonly marketId: MarketId;
  readonly requiredCapability: string;
  readonly nowUtc: string;
}
