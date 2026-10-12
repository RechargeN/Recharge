export interface EligiblePlaceLink {
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly pointerRevision: number;
  readonly marketId: string;
  readonly title: string;
}
export type PlaceLinkResult =
  | { readonly status: 'eligible'; readonly place: EligiblePlaceLink }
  | { readonly status: 'unknown' | 'forbidden' | 'unavailable' };
export interface PlaceLinkReader {
  check(input: { readonly placeId: string; readonly marketId: string }): Promise<PlaceLinkResult>;
}
