import type { ContentCatalogSource } from './ports.js';
import { PublishedObjectLinkService } from './published_object_link_service.js';
import type { EligiblePublishedObject } from '../domain/published_object_link.js';
import type { EligiblePlaceLink, PlaceLinkReader, PlaceLinkResult } from '../domain/place_link.js';

/**
 * D3.9 Activity → Place relation over the shared Catalog evaluator. Its
 * answers are unchanged: a hidden or restricted Place is `forbidden`.
 */
export class PlaceLinkService implements PlaceLinkReader {
  readonly #objects: PublishedObjectLinkService;

  constructor(source: ContentCatalogSource, enabled = false) {
    this.#objects = new PublishedObjectLinkService(source, enabled);
  }

  async check(input: {
    readonly placeId: string;
    readonly marketId: string;
  }): Promise<PlaceLinkResult> {
    const result = await this.#objects.status(
      { typeId: 'place', contentId: input.placeId, marketId: input.marketId },
      false,
    );
    if (result.status === 'eligible') return { status: 'eligible', place: place(result.object) };
    return { status: result.status === 'withheld' ? 'forbidden' : result.status };
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
    const result = await this.#objects.candidates({ typeId: 'place', ...input });
    return result.status === 'available'
      ? { status: 'available', items: result.items.map(place), nextCursor: result.nextCursor }
      : result;
  }
}

function place(object: EligiblePublishedObject): EligiblePlaceLink {
  return {
    contentId: object.contentId,
    publishedRevisionId: object.publishedRevisionId,
    pointerRevision: object.pointerRevision,
    marketId: object.marketId,
    title: object.title,
  };
}
