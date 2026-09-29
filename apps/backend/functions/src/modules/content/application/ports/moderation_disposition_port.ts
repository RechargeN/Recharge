import type { ContentTypeId } from '../../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';

export type ModerationProfileResolution =
  | {
      readonly available: true;
      readonly profileId: string;
      readonly requiresPrePublicationModeration: boolean;
      readonly policyRevision: string;
      /** Recorded policy decision; required when no pre-publication review applies. */
      readonly policyDecisionId?: string;
    }
  | { readonly available: false };

/**
 * BCK-22 owns cases, evidence, decisions and appeals. Content only asks which
 * moderation profile applies and (in a later slice) consumes typed dispositions.
 */
export interface ModerationDispositionPort {
  profileFor(input: {
    readonly typeId: ContentTypeId;
    readonly marketId: MarketId;
    readonly publisherRef: PublisherRefV1;
  }): Promise<ModerationProfileResolution>;
}
