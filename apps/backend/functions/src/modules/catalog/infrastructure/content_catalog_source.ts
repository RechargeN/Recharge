import { canonicalJson, sha256Hex } from '../../content/domain/published_revision.js';
import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import type { ReferenceDataPort } from '../../content/application/ports/reference_data_port.js';
import { resolveContentType } from '../../content/domain/content_type_registry.js';
import type { ContentPublicationFeed } from '../../content/infrastructure/content_publication_feed.js';
import type {
  ContentCatalogSource,
  ReferenceRevisionsPort,
  SourcePointer,
} from '../application/ports.js';
import type { ContentFact, SourceRevision } from '../domain/catalog_item.js';
import { isListingTypeId } from '../domain/published_object_link.js';
import type { FeedCheckpoint } from '../domain/repositories.js';

function toFact(effect: ContentEffectV1): ContentFact {
  return {
    schemaVersion: 1,
    effectId: effect.effectId,
    kind: effect.kind,
    contentId: effect.contentId,
    publishedRevisionId: effect.publishedRevisionId,
    pointerRevision: effect.pointerRevision,
    visibility: effect.visibility,
    typeId: effect.typeId,
    publisherRef: { type: effect.publisherRef.type, id: effect.publisherRef.id },
    marketId: effect.marketId,
    referenceRevisions: { ...effect.referenceRevisions },
    occurredAtUtc: effect.occurredAtUtc,
    // D2 §6: the media Content suppresses travel with every fact (absent when none).
    ...(effect.suppressedMediaIds === undefined
      ? {}
      : { suppressedMediaIds: [...effect.suppressedMediaIds] }),
  };
}

/** Content as the Catalog sees it: only through Content's own read feed. */
export class ContentFeedCatalogSource implements ContentCatalogSource {
  constructor(
    private readonly feed: ContentPublicationFeed,
    private readonly referenceData?: ReferenceDataPort,
  ) {}

  async pointer(contentId: string): Promise<SourcePointer | null> {
    const pointer = await this.feed.pointer(contentId);
    return pointer === null
      ? null
      : {
          contentId: pointer.contentId,
          revision: pointer.revision,
          currentPublishedRevisionId: pointer.currentPublishedRevisionId,
          visibility: pointer.visibility,
        };
  }

  async readTaxonomyRevision(revisionId: string) {
    return (
      this.referenceData?.readTaxonomyRevision?.({ taxonomyRevisionId: revisionId }) ?? {
        ok: false as const,
        code: 'taxonomy_revision_unavailable' as const,
      }
    );
  }

  async effectsAfter(after: FeedCheckpoint | null, limit: number): Promise<readonly ContentFact[]> {
    return (await this.feed.effectsAfter(after, limit)).map(toFact);
  }

  async effectsForContent(
    contentId: string,
    after: { readonly pointerRevision: number; readonly effectId: string } | null,
    limit: number,
  ): Promise<readonly ContentFact[]> {
    return (await this.feed.effectsForContent(contentId, after, limit)).map(toFact);
  }

  latestEffect(): Promise<FeedCheckpoint | null> {
    return this.feed.latestEffect();
  }

  async pointersPage(
    afterContentId: string | null,
    limit: number,
  ): Promise<readonly SourcePointer[]> {
    return (await this.feed.pointersPage(afterContentId, limit)).map((pointer) => ({
      contentId: pointer.contentId,
      revision: pointer.revision,
      currentPublishedRevisionId: pointer.currentPublishedRevisionId,
      visibility: pointer.visibility,
    }));
  }

  async publishedRevision(publishedRevisionId: string): Promise<SourceRevision | null> {
    const revision = await this.feed.publishedRevision(publishedRevisionId);
    if (revision === null) return null;
    if (
      // Projected Activity and every exact-id relation target (D3.9, D3.4).
      (revision.typeId === 'activity' || isListingTypeId(revision.typeId)) &&
      revision.bodyHash !== sha256Hex(canonicalJson(revision.body))
    ) {
      throw new Error('catalog_source_integrity_failed');
    }
    return {
      contentId: revision.contentId,
      publishedRevisionId: revision.publishedRevisionId,
      typeId: revision.typeId,
      marketId: revision.marketId,
      body: revision.body,
      referenceRevisions: { ...revision.referenceRevisions },
      publishedAtUtc: revision.publishedAtUtc,
    };
  }

  typeVisibilityPolicy(typeId: string): string | undefined {
    return resolveContentType(typeId)?.visibilityPolicy;
  }
}

/** Current reference revisions, from the same port Content pins them with. */
export class ReferenceDataRevisions implements ReferenceRevisionsPort {
  constructor(private readonly referenceData: ReferenceDataPort) {}
  async readTaxonomyRevision(revisionId: string) {
    return (
      this.referenceData.readTaxonomyRevision?.({ taxonomyRevisionId: revisionId }) ?? {
        ok: false as const,
        code: 'taxonomy_revision_unavailable' as const,
      }
    );
  }

  async current(
    marketId: string,
    typeId: string,
  ): Promise<Readonly<Record<string, string>> | null> {
    const resolution = await this.referenceData.resolve({
      marketId: marketId as never,
      typeId: typeId as never,
      nowUtc: new Date().toISOString(),
    });
    return resolution.ok ? { ...resolution.revisions } : null;
  }
}
