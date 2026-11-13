import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import { isContentTypeAvailable, resolveContentType } from '../domain/content_type_registry.js';
import {
  isPubliclyVisible,
  mediaConfirmationsOf,
  suppressedMediaIds,
} from '../domain/publication_pointer.js';
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
    // A submitted draft is frozen and a rolled-back import (D4.1) is a tombstone:
    // media cannot be bound to either.
    if (draft.status === 'submitted' || draft.status === 'rolledBack') return denied;
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

  /**
   * Content's answer to the D2 delivery gate (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md`
   * §4): the pin of an asset only while the publication is publicly visible, its
   * current revision attaches the asset, Content does not suppress it and the
   * publisher confirmed its epoch. Anything else is `null`; nothing is revealed.
   */
  async deliverablePin(request: {
    readonly contentId: string;
    readonly assetId: string;
  }): Promise<DeliverablePin | null> {
    return this.deps.repository.transact(async (tx) => {
      const pointer = await tx.pointer(request.contentId);
      if (!isPubliclyVisible(pointer) || pointer?.currentPublishedRevisionId == null) return null;
      if (suppressedMediaIds(pointer).some((id) => id === request.assetId)) return null;
      const confirmation = mediaConfirmationsOf(pointer).find(
        (item) => item.assetId === request.assetId,
      );
      if (confirmation === undefined) return null;
      const revision = await tx.publishedRevision(pointer.currentPublishedRevisionId);
      const pin = revision?.mediaAttachments.find((item) => item.assetId === request.assetId);
      if (revision === null || pin === undefined) return null;
      return {
        contentId: pointer.contentId,
        pointerRevision: pointer.revision,
        publishedRevisionId: revision.publishedRevisionId,
        sourceGeneration: pin.sourceGeneration,
        variantManifestRevision: pin.variantManifestRevision,
        revocationEpoch: confirmation.revocationEpoch,
      };
    });
  }
}

/** Structural shape of Media's published-media question (D2 §4, step 2). */
export interface DeliverablePin {
  readonly contentId: string;
  readonly pointerRevision: number;
  readonly publishedRevisionId: string;
  readonly sourceGeneration: string;
  readonly variantManifestRevision: string;
  readonly revocationEpoch: number;
}
