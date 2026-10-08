import { catalogTestOnlyConfig } from './catalog_config.js';
import type { CatalogEventItem, CatalogOccurrence, CatalogPoint } from './catalog_item.js';
import type { DiscoverQuery } from './discover_query.js';

/**
 * TEST-ONLY E1 ranking and time semantics (owner-approved baseline; BCK08-OD-05
 * stays open). `nowMs` is the server time pinned in the snapshot, never the
 * client clock, so every page of one result uses the same instant.
 *
 * - An occurrence has ended when `end <= now`, is running when
 *   `start <= now < end`, and is upcoming when `start > now`.
 * - An Event is eligible when at least one occurrence has not ended (and, with
 *   a time window, that occurrence overlaps the window); otherwise `ended`.
 * - The deciding occurrence is the earliest such occurrence; later ones do not
 *   change the order.
 * - Default order: `max(start, now)` (running Events first, all equal), then
 *   upcoming by start; ties by `contentId`.
 * - Distance order (only with an explicit valid center): Events with a public
 *   point by whole metres, then the default key, then `contentId`; Events
 *   without a point come after all of them in the default order.
 */
export type OccurrenceState = 'ended' | 'running' | 'upcoming';

export function occurrenceState(occurrence: CatalogOccurrence, nowMs: number): OccurrenceState {
  if (Date.parse(occurrence.endAtUtc) <= nowMs) return 'ended';
  if (Date.parse(occurrence.startAtUtc) <= nowMs) return 'running';
  return 'upcoming';
}

/** The earliest not-ended occurrence (inside the window when one is applied). */
export function decidingOccurrence(
  item: CatalogEventItem,
  nowMs: number,
  window: DiscoverQuery['timeWindow'],
): CatalogOccurrence | null {
  const from = window === null ? null : Date.parse(window.fromUtc);
  const to = window === null ? null : Date.parse(window.toUtc);
  for (const occurrence of item.occurrences) {
    if (occurrenceState(occurrence, nowMs) === 'ended') continue;
    if (from !== null && to !== null) {
      const start = Date.parse(occurrence.startAtUtc);
      const end = Date.parse(occurrence.endAtUtc);
      if (!(start < to && end > from)) continue;
    }
    return occurrence;
  }
  return null;
}

/** Great-circle distance in whole metres (haversine, mean Earth radius). */
export function distanceMeters(from: CatalogPoint, to: CatalogPoint): number {
  const radius = 6_371_008.8;
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = toRadians(to.latitude - from.latitude);
  const dLon = toRadians(to.longitude - from.longitude);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(from.latitude)) * Math.cos(toRadians(to.latitude)) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * radius * Math.asin(Math.min(1, Math.sqrt(a))));
}

/** Stable total sort key; compared element by element, `contentId` last. */
export type SortKey = readonly [number, number, number, string];

export function compareKeys(left: SortKey, right: SortKey): number {
  for (let index = 0; index < 3; index += 1) {
    const difference = (left[index] as number) - (right[index] as number);
    if (difference !== 0) return difference;
  }
  return left[3] < right[3] ? -1 : left[3] > right[3] ? 1 : 0;
}

export type Evaluation =
  | {
      readonly eligible: true;
      readonly occurrence: CatalogOccurrence;
      readonly remainingOccurrences: number;
      readonly distanceMeters: number | null;
      readonly key: SortKey;
    }
  | { readonly eligible: false; readonly reason: string };

/** Exact evaluation of one listed item against the applied query at `nowMs`. */
export function evaluate(item: CatalogEventItem, query: DiscoverQuery, nowMs: number): Evaluation {
  if (item.marketId !== query.marketId) return { eligible: false, reason: 'market' };
  if (!query.typeIds.includes(item.typeId)) return { eligible: false, reason: 'type' };
  if (query.categoryIds.length > 0 && !query.categoryIds.includes(item.categoryId))
    return { eligible: false, reason: 'category' };
  if (query.subcategoryIds.length > 0 && !query.subcategoryIds.includes(item.subcategoryId))
    return { eligible: false, reason: 'subcategory' };
  if (query.wheelchairAccessible && !item.wheelchairAccessible)
    return { eligible: false, reason: 'accessibility' };
  if (query.free && item.price?.mode !== 'free') return { eligible: false, reason: 'price' };
  if (query.maxAmountMinor !== null) {
    const price = item.price;
    const fits =
      price !== null &&
      (price.mode === 'free' ||
        (price.currencyCode === query.currencyCode && price.amountMinor <= query.maxAmountMinor));
    if (!fits) return { eligible: false, reason: 'price' };
  }
  for (const token of query.textTokens)
    if (!item.searchText.includes(token)) return { eligible: false, reason: 'text' };

  const occurrence = decidingOccurrence(item, nowMs, query.timeWindow);
  if (occurrence === null)
    return { eligible: false, reason: query.timeWindow === null ? 'ended' : 'time_window' };

  let distance: number | null = null;
  if (query.center !== null && item.point !== null)
    distance = distanceMeters(query.center, item.point);
  if (query.radiusKm !== null) {
    if (item.point === null) return { eligible: false, reason: 'not_mappable' };
    if ((distance ?? Number.POSITIVE_INFINITY) > query.radiusKm * 1000)
      return { eligible: false, reason: 'radius' };
  }

  const soonest = Math.max(Date.parse(occurrence.startAtUtc), nowMs);
  const key: SortKey =
    query.sort === 'distance'
      ? distance === null
        ? [1, 0, soonest, item.contentId]
        : [0, distance, soonest, item.contentId]
      : [0, soonest, 0, item.contentId];
  const remainingOccurrences = item.occurrences.filter(
    (candidate) =>
      occurrenceState(candidate, nowMs) !== 'ended' &&
      Date.parse(candidate.startAtUtc) > Date.parse(occurrence.startAtUtc),
  ).length;
  return { eligible: true, occurrence, remainingOccurrences, distanceMeters: distance, key };
}

export type Freshness = 'fresh' | 'stale' | 'unknown';

const strictness: Readonly<Record<Freshness, number>> = { fresh: 0, stale: 1, unknown: 2 };

/** The overall state is the strictest required component. */
export function strictest(...states: readonly Freshness[]): Freshness {
  return states.reduce<Freshness>(
    (worst, state) => (strictness[state] > strictness[worst] ? state : worst),
    'fresh',
  );
}

/** Projection age against the last successful delivery or reconciliation. */
export function projectionFreshness(lastSourceSyncAtUtc: string | null, nowMs: number): Freshness {
  if (lastSourceSyncAtUtc === null) return 'unknown';
  const age = nowMs - Date.parse(lastSourceSyncAtUtc);
  // A sync time in the future is clock skew: never claimed as fresh.
  if (!Number.isFinite(age) || age < 0) return 'unknown';
  return age <= catalogTestOnlyConfig.projectionMaxAgeSeconds * 1000 ? 'fresh' : 'stale';
}

/** Reference component: an item pinned to other revisions than current is stale. */
export function referenceFreshness(
  pinned: Readonly<Record<string, string>>,
  current: Readonly<Record<string, string>> | null,
): Freshness {
  if (current === null) return 'unknown';
  for (const [name, revision] of Object.entries(current))
    if (pinned[name] !== revision) return 'stale';
  return 'fresh';
}
