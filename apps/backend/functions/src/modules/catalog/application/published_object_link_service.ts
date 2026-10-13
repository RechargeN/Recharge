import type { ContentCatalogSource, SourcePointer } from './ports.js';
import { normalizeText, type SourceRevision } from '../domain/catalog_item.js';
import type {
  ListingTypeId,
  PublishedObjectCandidatesResult,
  PublishedObjectLinkResult,
} from '../domain/published_object_link.js';

/**
 * The one Catalog-owned evaluator of exact-id relations to published listings
 * (D3.9 Place, D3.4 every listing type). It reads the Content owner's current
 * pointer and immutable revision; Content never decides another object's
 * visibility. The answer is a current source read, not a lease.
 */
export class PublishedObjectLinkService {
  constructor(
    private readonly source: ContentCatalogSource,
    private readonly enabled = false,
  ) {}

  /**
   * With `reportWithheld` a hidden or restricted listing of the right type and
   * market is `withheld`; without it (the D3.9 Place relation) it is
   * `forbidden`, decided before its revision is read.
   */
  async status(
    input: {
      readonly typeId: ListingTypeId;
      readonly contentId: string;
      readonly marketId: string;
    },
    reportWithheld = true,
  ): Promise<PublishedObjectLinkResult> {
    if (!this.enabled || !this.source.pointer) return { status: 'unavailable' };
    try {
      const pointer = await this.source.pointer(input.contentId);
      if (!pointer) return { status: 'unknown' };
      const visible = pointer.visibility === 'visible';
      if (!pointer.currentPublishedRevisionId || (!visible && !reportWithheld))
        return { status: 'forbidden' };
      const revision = await this.source.publishedRevision(pointer.currentPublishedRevisionId);
      if (!revision) return { status: 'unavailable' };
      if (!this.isPublicListing(revision, input)) return { status: 'forbidden' };
      const current = await this.source.pointer(input.contentId);
      if (!stable(pointer, current, revision)) return { status: 'unavailable' };
      if (!visible) return { status: 'withheld' };
      return {
        status: 'eligible',
        object: {
          typeId: input.typeId,
          contentId: input.contentId,
          publishedRevisionId: revision.publishedRevisionId,
          pointerRevision: pointer.revision,
          marketId: revision.marketId,
          title: revision.body.title as string,
        },
      };
    } catch {
      return { status: 'unavailable' };
    }
  }

  /** Bounded page of currently eligible listings of one type; any outage fails the page. */
  async candidates(input: {
    readonly typeId: ListingTypeId;
    readonly marketId: string;
    readonly text: string;
    readonly after?: string;
    readonly limit: number;
  }): Promise<PublishedObjectCandidatesResult> {
    if (!this.enabled || !this.source.pointer) return { status: 'unavailable' };
    if (
      !Number.isInteger(input.limit) ||
      input.limit < 1 ||
      input.limit > 50 ||
      input.text.length > 100
    )
      return { status: 'unavailable' };
    try {
      const pointers = await this.source.pointersPage(input.after ?? null, input.limit);
      const items = [];
      for (const pointer of pointers) {
        const result = await this.status(
          { typeId: input.typeId, contentId: pointer.contentId, marketId: input.marketId },
          false,
        );
        if (result.status === 'unavailable') return { status: 'unavailable' };
        if (
          result.status === 'eligible' &&
          normalizeText(result.object.title).includes(normalizeText(input.text))
        )
          items.push(result.object);
      }
      return {
        status: 'available',
        items,
        nextCursor:
          pointers.length === input.limit ? pointers[pointers.length - 1]!.contentId : null,
      };
    } catch {
      return { status: 'unavailable' };
    }
  }

  private isPublicListing(
    revision: SourceRevision,
    input: {
      readonly typeId: ListingTypeId;
      readonly contentId: string;
      readonly marketId: string;
    },
  ): boolean {
    return (
      revision.typeId === input.typeId &&
      revision.contentId === input.contentId &&
      revision.marketId === input.marketId &&
      this.source.typeVisibilityPolicy(input.typeId) === 'public_catalog' &&
      typeof revision.body.title === 'string' &&
      revision.body.title.trim().length > 0 &&
      (revision.body.visibility === undefined || revision.body.visibility === 'public')
    );
  }
}

/** The pointer did not move between the two reads that bracket the revision read. */
function stable(
  before: SourcePointer,
  after: SourcePointer | null,
  revision: SourceRevision,
): boolean {
  return (
    after !== null &&
    after.revision === before.revision &&
    after.visibility === before.visibility &&
    after.currentPublishedRevisionId === revision.publishedRevisionId
  );
}
