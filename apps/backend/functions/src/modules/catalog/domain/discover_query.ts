import { createHash } from 'node:crypto';

import {
  availabilityNotConnectedReason,
  catalogEnabledTypes,
  catalogMarketCurrencies,
  catalogPolicyRevisions,
  catalogTestOnlyConfig,
} from './catalog_config.js';
import { normalizeText } from './catalog_item.js';

export type DiscoverSort = 'soonest' | 'distance';

/** The applied, canonical query: every membership field normalized. */
export interface DiscoverQuery {
  readonly marketId: string;
  readonly typeIds: readonly string[];
  readonly categoryIds: readonly string[];
  readonly subcategoryIds: readonly string[];
  readonly timeWindow: { readonly fromUtc: string; readonly toUtc: string } | null;
  readonly center: { readonly latitude: number; readonly longitude: number } | null;
  readonly radiusKm: number | null;
  readonly free: boolean;
  readonly maxAmountMinor: number | null;
  readonly currencyCode: string | null;
  readonly wheelchairAccessible: boolean;
  /** Normalized literal tokens; empty when there is no text filter. */
  readonly textTokens: readonly string[];
  readonly sort: DiscoverSort;
}

export type QueryParse =
  | {
      readonly ok: true;
      readonly query: DiscoverQuery;
      readonly fingerprint: string;
      /** Not a membership field: it never changes the fingerprint. */
      readonly pageSize: number;
    }
  | { readonly ok: false; readonly kind: 'unsupported' | 'invalid'; readonly code: string };

const knownKeys = new Set([
  'schemaVersion',
  'marketId',
  'typeIds',
  'categoryIds',
  'subcategoryIds',
  'timeWindow',
  'geo',
  'price',
  'wheelchairAccessible',
  'literalText',
  'onlyAvailable',
  'sort',
  'pageSize',
]);

const idPattern = /^[A-Za-z0-9_.:-]{1,64}$/u;

function canonical(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map((item) => canonical(item)).join(',')}]`;
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object)
    .filter((key) => object[key] !== undefined)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonical(object[key])}`)
    .join(',')}}`;
}

function isInstant(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(value) &&
    Number.isFinite(Date.parse(value))
  );
}

function idList(value: unknown): string[] | null {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 20) return null;
  if (!value.every((item) => typeof item === 'string' && idPattern.test(item))) return null;
  return [...new Set(value as string[])].sort();
}

const unsupported = (code: string): QueryParse => ({ ok: false, kind: 'unsupported', code });
const invalid = (code: string): QueryParse => ({ ok: false, kind: 'invalid', code });

/**
 * Parses and canonicalizes a `DiscoverQueryV1`. An unknown field, version,
 * type or currency is a typed refusal; nothing is mapped to a default query.
 */
export function parseDiscoverQuery(raw: unknown): QueryParse {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw))
    return invalid('query_invalid');
  const value = raw as Record<string, unknown>;
  for (const key of Object.keys(value))
    if (!knownKeys.has(key)) return unsupported(`unknown_field:${key}`);
  if (value.schemaVersion !== 1) return unsupported('unsupported_version');
  const marketId = value.marketId;
  if (typeof marketId !== 'string') return invalid('market_required');
  const area = (catalogTestOnlyConfig.serviceAreas as Record<string, unknown>)[marketId] as
    | { minLatitude: number; maxLatitude: number; minLongitude: number; maxLongitude: number }
    | undefined;
  if (area === undefined) return unsupported('market_disabled');

  // Only Event has an accepted projection; any other type is refused by name.
  const typeIds = idList(value.typeIds);
  if (typeIds === null) return invalid('type_ids_invalid');
  for (const typeId of typeIds)
    if (!catalogEnabledTypes.has(typeId)) return unsupported(`type_disabled:${typeId}`);
  const categoryIds = idList(value.categoryIds);
  const subcategoryIds = idList(value.subcategoryIds);
  if (categoryIds === null) return invalid('category_ids_invalid');
  if (subcategoryIds === null) return invalid('subcategory_ids_invalid');

  // Booking availability is not connected to E1: refused, never assumed.
  if (value.onlyAvailable === true) return unsupported(availabilityNotConnectedReason);
  if (value.onlyAvailable !== undefined && value.onlyAvailable !== false)
    return invalid('only_available_invalid');

  let timeWindow: DiscoverQuery['timeWindow'] = null;
  if (value.timeWindow !== undefined) {
    const window = value.timeWindow as Record<string, unknown> | null;
    if (typeof window !== 'object' || window === null) return invalid('time_window_invalid');
    if (!isInstant(window.fromUtc) || !isInstant(window.toUtc))
      return invalid('time_window_invalid');
    const from = Date.parse(window.fromUtc);
    const to = Date.parse(window.toUtc);
    if (from >= to) return invalid('time_window_invalid');
    if (to - from > catalogTestOnlyConfig.maxTimeWindowDays * 86_400_000)
      return invalid('time_window_too_long');
    timeWindow = {
      fromUtc: new Date(from).toISOString(),
      toUtc: new Date(to).toISOString(),
    };
  }

  let center: DiscoverQuery['center'] = null;
  let radiusKm: number | null = null;
  if (value.geo !== undefined) {
    const geo = value.geo as Record<string, unknown> | null;
    const point = geo?.center as Record<string, unknown> | undefined;
    const latitude = point?.latitude;
    const longitude = point?.longitude;
    if (
      typeof latitude !== 'number' ||
      typeof longitude !== 'number' ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < area.minLatitude ||
      latitude > area.maxLatitude ||
      longitude < area.minLongitude ||
      longitude > area.maxLongitude
    )
      return invalid('geo_center_invalid');
    center = { latitude: Number(latitude.toFixed(6)), longitude: Number(longitude.toFixed(6)) };
    if (geo?.radiusKm !== undefined) {
      const radius = geo.radiusKm;
      if (typeof radius !== 'number' || !Number.isFinite(radius) || radius <= 0)
        return invalid('radius_invalid');
      if (radius > catalogTestOnlyConfig.maxRadiusKm) return invalid('radius_too_large');
      radiusKm = Number(radius.toFixed(3));
    }
  }

  let free = false;
  let maxAmountMinor: number | null = null;
  let currencyCode: string | null = null;
  if (value.price !== undefined) {
    const price = value.price as Record<string, unknown> | null;
    if (typeof price !== 'object' || price === null) return invalid('price_invalid');
    if (price.free !== undefined && price.free !== true) return invalid('price_invalid');
    free = price.free === true;
    if (price.maxAmountMinor !== undefined) {
      if (
        typeof price.maxAmountMinor !== 'number' ||
        !Number.isInteger(price.maxAmountMinor) ||
        price.maxAmountMinor < 0
      )
        return invalid('price_invalid');
      if (price.currencyCode !== catalogMarketCurrencies[marketId])
        return unsupported('currency_mismatch');
      maxAmountMinor = price.maxAmountMinor;
      currencyCode = catalogMarketCurrencies[marketId] ?? null;
    } else if (price.currencyCode !== undefined) return invalid('price_invalid');
    if (free && maxAmountMinor !== null) return invalid('price_invalid');
  }

  if (value.wheelchairAccessible !== undefined && typeof value.wheelchairAccessible !== 'boolean')
    return invalid('accessibility_invalid');

  let textTokens: string[] = [];
  if (value.literalText !== undefined) {
    if (typeof value.literalText !== 'string') return invalid('text_invalid');
    if (value.literalText.length > catalogTestOnlyConfig.maxLiteralTextLength)
      return invalid('text_too_long');
    const tokens = normalizeText(value.literalText)
      .split(' ')
      .filter((token) => token.length >= catalogTestOnlyConfig.minTextTokenLength);
    if (tokens.length === 0) return invalid('text_too_short');
    if (tokens.length > catalogTestOnlyConfig.maxTextTokens) return invalid('too_many_tokens');
    textTokens = [...new Set(tokens)].sort();
  }

  const sort = value.sort ?? 'soonest';
  if (sort !== 'soonest' && sort !== 'distance') return unsupported('sort_unsupported');
  // Distance only for an explicit, valid center: never a silent other order.
  if (sort === 'distance' && center === null) return invalid('distance_requires_center');

  let pageSize: number = catalogTestOnlyConfig.pageSizeDefault;
  if (value.pageSize !== undefined) {
    if (
      typeof value.pageSize !== 'number' ||
      !Number.isInteger(value.pageSize) ||
      value.pageSize < 1 ||
      value.pageSize > catalogTestOnlyConfig.pageSizeMax
    )
      return invalid('page_size_invalid');
    pageSize = value.pageSize;
  }

  const query: DiscoverQuery = {
    marketId,
    typeIds: typeIds.length === 0 ? ['event'] : typeIds,
    categoryIds,
    subcategoryIds,
    timeWindow,
    center,
    radiusKm,
    free,
    maxAmountMinor,
    currencyCode,
    wheelchairAccessible: value.wheelchairAccessible === true,
    textTokens,
    sort,
  };
  return { ok: true, query, fingerprint: queryFingerprint(query), pageSize };
}

/** Opaque, deterministic and bound to contract, environment and visibility scope. */
export function queryFingerprint(query: DiscoverQuery): string {
  return createHash('sha256')
    .update(
      canonical({
        contract: catalogPolicyRevisions.queryContract,
        environment: catalogPolicyRevisions.environment,
        visibilityScope: 'public',
        query,
      }),
      'utf8',
    )
    .digest('hex');
}
