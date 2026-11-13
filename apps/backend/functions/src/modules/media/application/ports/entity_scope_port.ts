import type { MediaEntityBindingV1 } from '../../../../contracts/media_v1.js';
import type { PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';
import type { MediaActor } from './actor_authority_port.js';

export interface EntityScopeRequest {
  readonly actor: MediaActor;
  readonly entity: MediaEntityBindingV1;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly nowUtc: string;
}

export type EntityScopeResult =
  { readonly allowed: true; readonly entityRevision: number } | { readonly allowed: false };

/**
 * The owning domain decides whether this actor may attach media to the exact
 * entity, Publisher and market (BCK-14 v0.4 §34.4). A user id alone never makes
 * an `entityIntent` trusted: the port answers from the owning domain's records.
 */
export interface EntityScopePort {
  authorize(request: EntityScopeRequest): Promise<EntityScopeResult>;
}
