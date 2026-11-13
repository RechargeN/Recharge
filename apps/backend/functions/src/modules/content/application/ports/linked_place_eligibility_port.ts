/** Consumer boundary only. Eligibility policy and source reads belong to Catalog. */
export interface LinkedPlaceEligibilityPort {
  check(input: {
    readonly placeId: string;
    readonly marketId: string;
  }): Promise<{ readonly status: 'eligible' | 'unknown' | 'forbidden' | 'unavailable' }>;
}
