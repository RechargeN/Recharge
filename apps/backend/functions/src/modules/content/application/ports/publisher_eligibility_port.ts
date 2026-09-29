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
}
