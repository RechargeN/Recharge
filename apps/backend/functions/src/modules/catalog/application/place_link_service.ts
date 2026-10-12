import type { ContentCatalogSource } from './ports.js';
import type { EligiblePlaceLink, PlaceLinkReader, PlaceLinkResult } from '../domain/place_link.js';
import { normalizeText } from '../domain/catalog_item.js';
export class PlaceLinkService implements PlaceLinkReader {
  constructor(
    private readonly source: ContentCatalogSource,
    private readonly enabled = false,
  ) {}
  async check(input: {
    readonly placeId: string;
    readonly marketId: string;
  }): Promise<PlaceLinkResult> {
    if (!this.enabled || !this.source.pointer) return { status: 'unavailable' };
    try {
      const pointer = await this.source.pointer(input.placeId);
      if (!pointer) return { status: 'unknown' };
      if (pointer.visibility !== 'visible' || !pointer.currentPublishedRevisionId)
        return { status: 'forbidden' };
      const revision = await this.source.publishedRevision(pointer.currentPublishedRevisionId);
      if (!revision) return { status: 'unavailable' };
      if (
        revision.typeId !== 'place' ||
        revision.contentId !== input.placeId ||
        revision.marketId !== input.marketId ||
        this.source.typeVisibilityPolicy('place') !== 'public_catalog' ||
        typeof revision.body.title !== 'string' ||
        !revision.body.title.trim() ||
        (revision.body.visibility !== undefined && revision.body.visibility !== 'public')
      )
        return { status: 'forbidden' };
      const current = await this.source.pointer(input.placeId);
      if (
        !current ||
        current.revision !== pointer.revision ||
        current.visibility !== 'visible' ||
        current.currentPublishedRevisionId !== revision.publishedRevisionId
      )
        return { status: 'unavailable' };
      return {
        status: 'eligible',
        place: {
          contentId: input.placeId,
          publishedRevisionId: revision.publishedRevisionId,
          pointerRevision: current.revision,
          marketId: revision.marketId,
          title: revision.body.title,
        },
      };
    } catch {
      return { status: 'unavailable' };
    }
  }
  async candidates(input: {
    readonly marketId: string;
    readonly text: string;
    readonly after?: string;
    readonly limit: number;
  }): Promise<
    | {
        readonly status: 'available';
        readonly items: readonly EligiblePlaceLink[];
        readonly nextCursor: string | null;
      }
    | { readonly status: 'unavailable' }
  > {
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
      const items: EligiblePlaceLink[] = [];
      for (const pointer of pointers) {
        const result = await this.check({ placeId: pointer.contentId, marketId: input.marketId });
        if (result.status === 'unavailable') return { status: 'unavailable' };
        if (
          result.status === 'eligible' &&
          normalizeText(result.place.title).includes(normalizeText(input.text))
        )
          items.push(result.place);
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
}
