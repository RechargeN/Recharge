/**
 * Durable public listing types another object may relate to by exact id
 * (D3.4): Place, Route, Session, Class/Workshop and Rental. Time-bound or
 * container types (Event, Activity, Scenario, Find People, Collection) are
 * never relation targets here. A type whose Content publication is not
 * available simply has no eligible object.
 */
export const listingTypeIds = Object.freeze([
  'place',
  'route',
  'session',
  'class_workshop',
  'rental',
] as const);

export type ListingTypeId = (typeof listingTypeIds)[number];

export function isListingTypeId(value: unknown): value is ListingTypeId {
  return typeof value === 'string' && (listingTypeIds as readonly string[]).includes(value);
}

/** Allowlisted public facts of an eligible object; never draft, private or moderation data. */
export interface EligiblePublishedObject {
  readonly typeId: ListingTypeId;
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly pointerRevision: number;
  readonly marketId: string;
  readonly title: string;
}

/**
 * `withheld`: a public listing of exactly this type and market whose owner hid
 * it or moderation restricted it. It carries no reason and no title; only an
 * exact-id relation that already names the object learns it.
 */
export type PublishedObjectLinkResult =
  | { readonly status: 'eligible'; readonly object: EligiblePublishedObject }
  | { readonly status: 'withheld' | 'unknown' | 'forbidden' | 'unavailable' };

export type PublishedObjectCandidatesResult =
  | {
      readonly status: 'available';
      readonly items: readonly EligiblePublishedObject[];
      readonly nextCursor: string | null;
    }
  | { readonly status: 'unavailable' };
