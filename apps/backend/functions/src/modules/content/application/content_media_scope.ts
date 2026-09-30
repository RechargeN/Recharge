import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import { isContentTypeAvailable, resolveContentType } from '../domain/content_type_registry.js';
import type { ContentRepository } from '../domain/repositories.js';
import type { ContentActor, PublisherEligibilityPort } from './ports/publisher_eligibility_port.js';

/**
 * Structural shape of Media's entity-scope request (BCK-14 v0.4 §34.4). Content
 * does not import the Media module; the wiring checks compatibility.
 */
export interface MediaEntityScopeRequest {
  readonly actor: ContentActor;
  readonly entity: {
    readonly domain: 'content';
    readonly entityId: EntityId;
    readonly purpose: 'contentMedia';
  };
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly nowUtc: string;
}

export type MediaEntityScopeResult =
  { readonly allowed: true; readonly entityRevision: number } | { readonly allowed: false };

export interface ContentMediaScopeDeps {
  readonly repository: ContentRepository;
  readonly eligibility: PublisherEligibilityPort;
}

/**
 * Content's answers to Media, taken from Content's own records (BCK-07 v0.11
 * §37.3): whether this actor may attach media to this exact draft, Publisher and
 * market, and whether an asset is still referenced by a draft or revision.
 */
export class ContentMediaScope {
  constructor(private readonly deps: ContentMediaScopeDeps) {}

  async authorize(request: MediaEntityScopeRequest): Promise<MediaEntityScopeResult> {
    const denied = { allowed: false } as const;
    const draft = await this.deps.repository.transact((tx) =>
      tx.draftByContentId(request.entity.entityId),
    );
    if (draft === null) return denied;
    if (
      draft.publisherRef.type !== request.publisherRef.type ||
      draft.publisherRef.id !== request.publisherRef.id ||
      draft.marketId !== request.marketId
    )
      return denied;
    // A submitted draft is frozen: media cannot be bound to it.
    if (draft.status === 'submitted') return denied;
    const entry = resolveContentType(draft.typeId);
    if (entry === null || !isContentTypeAvailable(entry)) return denied;
    try {
      const eligibility = await this.deps.eligibility.evaluate({
        actor: request.actor,
        publisherRef: request.publisherRef,
        typeId: draft.typeId,
        action: 'update',
        marketId: request.marketId,
        requiredCapability: entry.requiredCapabilities.update,
        nowUtc: request.nowUtc,
      });
      const samePublisher =
        eligibility.publisherRef.type === request.publisherRef.type &&
        eligibility.publisherRef.id === request.publisherRef.id;
      return eligibility.eligible && samePublisher
        ? { allowed: true, entityRevision: draft.revision }
        : denied;
    } catch {
      // Doubt is a refusal: an unreachable authority never grants a binding.
      return denied;
    }
  }

  isReferenced(assetId: string): Promise<boolean> {
    return this.deps.repository.transact((tx) => tx.isMediaReferenced(assetId));
  }
}
