import type { ContentTypeId } from '../../../contracts/content_v1.js';
import type {
  PublishedObjectMembershipPort,
  PublishedObjectMembershipStatus,
} from '../application/ports/published_object_membership_port.js';
import type { CollectionObjectType } from '../domain/type_rules/validation_context.js';

/** Content type id of each Collection item type (CLG-CRT-01 §3.12). */
export const collectionObjectContentTypes: Readonly<Record<CollectionObjectType, ContentTypeId>> =
  Object.freeze({
    place: 'place',
    route: 'route',
    bookableSession: 'session',
    classWorkshop: 'class_workshop',
    rental: 'rental',
  });

/**
 * The Catalog-owned exact-id evaluator, as this adapter needs it. Structural on
 * purpose: Content does not import Catalog; the composition root wires them.
 */
export interface ListingStatusReader {
  status(input: {
    readonly typeId: 'place' | 'route' | 'session' | 'class_workshop' | 'rental';
    readonly contentId: string;
    readonly marketId: string;
  }): Promise<{ readonly status: string }>;
}

/**
 * D3.4: Collection membership over Catalog. Every item type the Collection
 * validator allows is asked for exactly; a type without published objects is
 * simply never `ready`. Any unexpected answer or failure is `unavailable`.
 */
export class CatalogCollectionMembership implements PublishedObjectMembershipPort {
  constructor(private readonly catalog: ListingStatusReader) {}

  async statusOf(input: {
    readonly objectType: CollectionObjectType;
    readonly objectId: string;
    readonly marketId: string;
  }): Promise<PublishedObjectMembershipStatus> {
    // Only the closed Collection item types are asked; anything else is refused.
    if (!Object.hasOwn(collectionObjectContentTypes, input.objectType)) return 'forbidden';
    const typeId = collectionObjectContentTypes[input.objectType] as Parameters<
      ListingStatusReader['status']
    >[0]['typeId'];
    try {
      const { status } = await this.catalog.status({
        typeId,
        contentId: input.objectId,
        marketId: input.marketId,
      });
      switch (status) {
        case 'eligible':
          return 'ready';
        case 'withheld':
        case 'unknown':
        case 'forbidden':
          return status;
        default:
          return 'unavailable';
      }
    } catch {
      return 'unavailable';
    }
  }
}
