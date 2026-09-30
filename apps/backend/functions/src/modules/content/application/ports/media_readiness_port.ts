import type {
  ContentTypeId,
  MediaAttachmentV1,
  MediaNotReadyReason,
} from '../../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';

/**
 * Readiness is evidence, never an attach: the attachments it returns are frozen
 * into the immutable revision only when publish writes it.
 */
export type MediaReadiness =
  | {
      readonly ready: true;
      readonly mediaRevision: string;
      readonly attachments: readonly MediaAttachmentV1[];
    }
  | { readonly ready: false; readonly reason: MediaNotReadyReason };

/**
 * BCK-14 remains the Media authority; pending, foreign, stale, restricted or
 * unknown media is not ready. `pinned` is required for rollback and comes from
 * the stored target revision, never from the caller.
 */
export interface MediaReadinessPort {
  check(input: {
    readonly contentId: string;
    readonly typeId: ContentTypeId;
    readonly marketId: MarketId;
    readonly publisherRef: PublisherRefV1;
    readonly mediaIds: readonly string[];
    readonly pinned?: readonly MediaAttachmentV1[];
  }): Promise<MediaReadiness>;
}
