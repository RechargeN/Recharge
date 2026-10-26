import { deepFreeze } from '../../shared/immutable.js';

/**
 * L3 product analytics contract (ANALYTICS_L3_PRODUCT_ANALYTICS_AMENDMENT.md §3–4,
 * §8). Mirrors `packages/api_contracts/schema/product_analytics/v1/
 * product_analytics_event_registry.v1.json`; the contract test keeps them equal.
 * Only typed allowlisted events and enum values pass; everything else is
 * rejected before any write and is never echoed back or logged.
 */
export const productAnalyticsRegistryRevision = 'pa-l3-v1';
/** Declared purpose; not accepted (PA-B01), so no production policy exists. */
export const productAnalyticsPurposeId = 'product_usage_measurement';
export const productAnalyticsLegalBasisRef = null;
/** No account, Session, device or pseudonymous subject key (BCK21-OD-03 fail-closed). */
export const productAnalyticsSubjectMode = 'none';
export const productAnalyticsDataClass = 'personal';

export const productAnalyticsLimits = deepFreeze({
  batchMaxEvents: 20,
  batchMaxBytes: 8192,
  eventMaxBytes: 512,
  queueMaxEvents: 100,
  queueMaxBytes: 32768,
  maxAttempts: 5,
  sendTimeoutSeconds: 10,
  futureSkewMinutes: 5,
  aggregateReadMaxDays: 31,
});

export const productAnalyticsEnums = deepFreeze({
  objectKind: [
    'event',
    'activity',
    'route',
    'place',
    'session',
    'scenario',
    'find_people',
    'class_workshop',
    'rental',
    'collection',
  ],
  entrySurface: ['details', 'map', 'planner', 'other'],
  publishOutcome: ['published', 'submitted', 'denied', 'failed'],
} as const);
export type ProductAnalyticsEnumId = keyof typeof productAnalyticsEnums;

export const productAnalyticsEventNames = [
  'details_opened',
  'favorite_added',
  'create_publish_finished',
] as const;
export type ProductAnalyticsEventName = (typeof productAnalyticsEventNames)[number];

export interface ProductAnalyticsEventDefinition {
  readonly eventName: ProductAnalyticsEventName;
  readonly eventVersion: number;
  readonly productQuestion: string;
  readonly eventOwner: string;
  readonly processingOwner: string;
  /** The only file allowed to construct this event (repository-relative). */
  readonly producer: string;
  readonly retentionClass: string;
  readonly fields: Readonly<Record<string, ProductAnalyticsEnumId>>;
}

export const productAnalyticsEventRegistry: readonly ProductAnalyticsEventDefinition[] = deepFreeze(
  [
    {
      eventName: 'details_opened',
      eventVersion: 1,
      productQuestion: 'Which object types do people open in Details?',
      eventOwner: 'product.discover',
      processingOwner: 'data_platform',
      producer: 'apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart',
      retentionClass: 'pa.raw_event',
      fields: { object_kind: 'objectKind' },
    },
    {
      eventName: 'favorite_added',
      eventVersion: 1,
      productQuestion: 'Which object types do people save to Favorites, and from which surface?',
      eventOwner: 'product.library',
      processingOwner: 'data_platform',
      producer:
        'apps/mobile/lib/features/favorites/application/controllers/favorites_controller.dart',
      retentionClass: 'pa.raw_event',
      fields: { object_kind: 'objectKind', entry_surface: 'entrySurface' },
    },
    {
      eventName: 'create_publish_finished',
      eventVersion: 1,
      productQuestion: 'For which Create types does a publish attempt end in refusal?',
      eventOwner: 'product.create',
      processingOwner: 'data_platform',
      producer: 'apps/mobile/lib/features/create/application/controllers/create_controller.dart',
      retentionClass: 'pa.raw_event',
      fields: { create_type: 'objectKind', outcome: 'publishOutcome' },
    },
  ],
);

/**
 * Every collection the L3 boundary writes, with its purpose and policy. The
 * inventory test fails on a `productAnalytics*` collection that is missing here.
 */
export const productAnalyticsCollections = Object.freeze({
  events: 'productAnalyticsEvents',
  dailyAggregates: 'productAnalyticsDailyAggregates',
  /** Test-only registry of staff readers; production authority is PA-B07. */
  accessAuthority: 'productAnalyticsAccessAuthority',
  accessAudit: 'productAnalyticsAccessAudit',
});

export const productAnalyticsSinkRegistry = deepFreeze([
  {
    collection: productAnalyticsCollections.events,
    purpose: productAnalyticsPurposeId,
    dataClass: 'personal',
    retentionClass: 'pa.raw_event',
  },
  {
    collection: productAnalyticsCollections.dailyAggregates,
    purpose: productAnalyticsPurposeId,
    dataClass: 'personal',
    retentionClass: 'pa.daily_aggregate',
  },
  {
    collection: productAnalyticsCollections.accessAuthority,
    purpose: 'access_control',
    dataClass: 'personal',
    retentionClass: 'pa.access_authority',
  },
  {
    collection: productAnalyticsCollections.accessAudit,
    purpose: 'access_control',
    dataClass: 'personal',
    retentionClass: 'pa.access_audit',
  },
]);

/** An event that passed the allowlist; nothing else is ever stored. */
export interface ProductAnalyticsEvent {
  readonly eventId: string;
  readonly eventName: ProductAnalyticsEventName;
  readonly eventVersion: number;
  /** Rounded down to the hour by the client; the server stores the day only. */
  readonly occurredAtUtc: string;
  readonly policyRevision: string;
  readonly fields: Readonly<Record<string, string>>;
}

export type ParsedBatchEntry =
  | { readonly valid: true; readonly event: ProductAnalyticsEvent }
  /** `eventId` is echoed only when it is a well-formed UUID v4; nothing else is. */
  | { readonly valid: false; readonly eventId: string | null };

const eventKeys = [
  'eventId',
  'eventName',
  'eventVersion',
  'occurredAtUtc',
  'policyRevision',
  'fields',
] as const;
const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u;
const hourInstant = /^\d{4}-\d{2}-\d{2}T\d{2}:00:00\.000Z$/u;
export const policyRevisionPattern = /^[a-z0-9][a-z0-9.-]{0,63}$/u;

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const prototype: unknown = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function hasExactKeys(value: Record<string, unknown>, keys: readonly string[]): boolean {
  const own = Object.keys(value);
  return own.length === keys.length && keys.every((key) => Object.hasOwn(value, key));
}

export function productAnalyticsDefinition(
  eventName: string,
  eventVersion: unknown,
): ProductAnalyticsEventDefinition | undefined {
  return productAnalyticsEventRegistry.find(
    (definition) => definition.eventName === eventName && definition.eventVersion === eventVersion,
  );
}

export function wellFormedEventId(value: unknown): value is string {
  return typeof value === 'string' && uuidV4.test(value);
}

/** Strict parse of one event; `null` means `rejected_schema`. */
export function parseProductAnalyticsEvent(raw: unknown): ProductAnalyticsEvent | null {
  if (!isPlainRecord(raw) || !hasExactKeys(raw, eventKeys)) return null;
  const { eventId, eventName, eventVersion, occurredAtUtc, policyRevision, fields } = raw;
  if (!wellFormedEventId(eventId) || typeof eventName !== 'string') return null;
  const definition = productAnalyticsDefinition(eventName, eventVersion);
  if (definition === undefined) return null;
  if (typeof occurredAtUtc !== 'string' || !hourInstant.test(occurredAtUtc)) return null;
  const occurred = Date.parse(occurredAtUtc);
  if (!Number.isFinite(occurred) || new Date(occurred).toISOString() !== occurredAtUtc) return null;
  if (typeof policyRevision !== 'string' || !policyRevisionPattern.test(policyRevision))
    return null;
  if (!isPlainRecord(fields) || !hasExactKeys(fields, Object.keys(definition.fields))) return null;
  const parsed: Record<string, string> = {};
  for (const [name, enumId] of Object.entries(definition.fields)) {
    const value = fields[name];
    const allowed: readonly string[] = productAnalyticsEnums[enumId];
    if (typeof value !== 'string' || !allowed.includes(value)) return null;
    parsed[name] = value;
  }
  if (Buffer.byteLength(JSON.stringify(raw), 'utf8') > productAnalyticsLimits.eventMaxBytes)
    return null;
  return deepFreeze({
    eventId,
    eventName: definition.eventName,
    eventVersion: definition.eventVersion,
    occurredAtUtc,
    policyRevision,
    fields: parsed,
  });
}

/**
 * Strict parse of a batch. `null` means `batch_invalid`: the whole batch is
 * refused and nothing is read or written.
 */
export function parseProductAnalyticsBatch(raw: unknown): readonly ParsedBatchEntry[] | null {
  if (!isPlainRecord(raw) || !hasExactKeys(raw, ['schemaVersion', 'events'])) return null;
  if (raw.schemaVersion !== 1 || !Array.isArray(raw.events)) return null;
  const events: unknown[] = raw.events;
  if (events.length < 1 || events.length > productAnalyticsLimits.batchMaxEvents) return null;
  let size: number;
  try {
    size = Buffer.byteLength(JSON.stringify(raw), 'utf8');
  } catch {
    return null;
  }
  if (size > productAnalyticsLimits.batchMaxBytes) return null;
  return events.map((candidate) => {
    const event = parseProductAnalyticsEvent(candidate);
    if (event !== null) return { valid: true, event };
    const eventId = isPlainRecord(candidate) ? candidate.eventId : undefined;
    return { valid: false, eventId: wellFormedEventId(eventId) ? eventId : null };
  });
}

/** `YYYY-MM-DD` of an hour instant that already passed the parser. */
export function eventDayUtc(occurredAtUtc: string): string {
  return occurredAtUtc.slice(0, 10);
}

export function validDayUtc(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) return false;
  const start = Date.parse(`${value}T00:00:00.000Z`);
  return Number.isFinite(start) && new Date(start).toISOString().slice(0, 10) === value;
}
