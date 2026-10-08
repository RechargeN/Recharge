/**
 * TEST-ONLY E1 values for the local `demo-recharge` Catalog, approved by the
 * owner for the local stand only. They are not production defaults and do not
 * close BCK08-OD-08 (freshness thresholds) or BCK08-OD-10 (SLO/cost/limits).
 * Every numeric Catalog limit lives here and nowhere else.
 */
export const catalogTestOnlyConfig = Object.freeze({
  /** Feed/Search page size when the query names none, and the hard maximum. */
  pageSizeDefault: 20,
  pageSizeMax: 50,
  /** Objects one query may evaluate; above it the query is `query_too_broad`. */
  candidateLimit: 2000,
  /** Manual delivery: facts per batch and batches per run. */
  deliveryBatchSize: 100,
  deliveryMaxBatchesPerRun: 50,
  /** Content publication pointers per reconciliation page. */
  reconcileBatchSize: 200,
  /** Content objects per rebuild page. */
  rebuildBatchSize: 200,
  /**
   * Projection age: a snapshot is `fresh` only within this many seconds of the
   * last successful delivery or reconciliation of its set; older is `stale`,
   * never synced is `unknown`. Expired data is never labelled fresh.
   */
  projectionMaxAgeSeconds: 900,
  /** Snapshot token and cursor lifetime. */
  snapshotTtlSeconds: 600,
  /** Geo: largest radius and the service area a query center must be in. */
  maxRadiusKm: 100,
  serviceAreas: Object.freeze({
    LV: Object.freeze({
      minLatitude: 55.6,
      maxLatitude: 58.1,
      minLongitude: 20.9,
      maxLongitude: 28.3,
    }),
  }),
  /** Literal text: characters, tokens, and the shortest token kept. */
  maxLiteralTextLength: 100,
  maxTextTokens: 8,
  minTextTokenLength: 2,
  /** Longest applied time window. */
  maxTimeWindowDays: 366,
});

/** Revisions every snapshot pins (TEST-ONLY baselines, see BCK08-OD-05). */
export const catalogPolicyRevisions = Object.freeze({
  projectionSchema: 'catalog-event-projection-v3',
  ranking: 'test-only-catalog-ranking-1',
  visibility: 'test-only-catalog-visibility-1',
  /** Booking availability is not connected to E1. */
  availabilityComposition: 'availability-not-connected-e1',
  queryContract: 'discover-query-v1',
  environment: 'demo-recharge-emulator',
});

/**
 * Only Event has an accepted public projection in E1 (BCK08-OD-04 stays open):
 * every other type is `type_disabled`, without a generic projection.
 */
export const catalogEnabledTypes: ReadonlySet<string> = new Set(['event']);

/** Market currencies the price filter accepts. */
export const catalogMarketCurrencies: Readonly<Record<string, string>> = Object.freeze({
  LV: 'EUR',
});

/** Why `onlyAvailable` is refused: the source is not connected, not absent. */
export const availabilityNotConnectedReason = 'booking_availability_source_not_connected_in_e1';
