import type { MediaFamily } from '../../../../contracts/media_v1.js';
import type { PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { EntityId } from '../../../../shared/ids.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';

/** Server-resolved caller; never a client-supplied claim. */
export interface MediaActor {
  readonly userId: EntityId;
  readonly sessionId: EntityId;
}

export interface MediaAuthorityRequest {
  readonly actor: MediaActor;
  readonly marketId: MarketId;
  readonly publisherRef?: PublisherRefV1;
  readonly family: MediaFamily;
  readonly action: 'upload' | 'read' | 'manage';
  readonly nowUtc: string;
}

export type MediaAuthorityResult =
  | { readonly allowed: true; readonly authorityRevision: number }
  | {
      readonly allowed: false;
      readonly reason:
        'session_invalid' | 'membership_inactive' | 'capability_denied' | 'market_disabled';
    };

/**
 * BCK-06 access evaluated at backend time: Session and revocation, market,
 * capability and exact PublisherRef membership. A cached AccessSnapshot or App
 * Check is never authority (BCK-14 §6).
 */
export interface MediaActorAuthorityPort {
  evaluate(request: MediaAuthorityRequest): Promise<MediaAuthorityResult>;
}

/**
 * Authoritative privacy, moderation or security input that restricts or lifts a
 * restriction on an asset. A restriction is never accepted from a client: the
 * instruction is verified here first, and unknown, stale or foreign ones mutate
 * nothing.
 */
export interface MediaRestrictionAuthority {
  verifyRestriction(input: {
    readonly assetId: string;
    readonly decisionRef: string;
    readonly restricted: boolean;
  }): Promise<boolean>;
}
