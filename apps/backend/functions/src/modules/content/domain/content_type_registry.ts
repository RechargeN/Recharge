import {
  contentTypeIds,
  type ContentBody,
  type ContentTypeId,
} from '../../../contracts/content_v1.js';

export type ContentAction = 'create' | 'update' | 'read' | 'submit' | 'publish';

/** Bump when an entry's policy or availability changes; pinned by tests. */
export const contentTypeRegistryRevision = 'content-type-registry-v1';

/** How the publication adapter obtains and pins the type's source. */
export type ContentSourceResolver =
  /** The draft body itself is the source, validated by the type validator. */
  | 'inline_body'
  /** An immutable revision owned by another BCK is pinned by reference. */
  | 'pinned_immutable_revision'
  /** Stable IDs of already published objects, order-checked. */
  | 'published_object_membership';

export type ContentTypeUnavailableReason =
  /** No accepted backend source contract exists for the type yet. */
  | 'source_contract_pending'
  /** The source lives in another BCK whose contract is not implemented. */
  | 'dependency_pending';

export type ContentTypeAvailability =
  | { readonly status: 'available' }
  | {
      readonly status: 'unavailable';
      readonly reason: ContentTypeUnavailableReason;
      /** Owning authority the type is waiting for, when it is not Content. */
      readonly dependency?: string;
    };

export interface ContentTypeRegistryEntry {
  readonly typeId: ContentTypeId;
  readonly typeSchemaMajor: 1;
  readonly validatorRevision: string;
  /** Authority that owns the source the adapter validates or pins. */
  readonly sourceAuthority: string;
  readonly sourceResolver: ContentSourceResolver;
  readonly requiredCapabilities: Readonly<Record<ContentAction, string>>;
  readonly allowedPublisherTypes: readonly ('user' | 'page')[];
  readonly moderationProfileId: string;
  readonly visibilityPolicy: 'public_catalog' | 'consent_limited';
  readonly marketPolicy: 'single_market_per_content';
  readonly localizedTextPolicy: 'per_locale_with_declared_fallback';
  readonly discoverFamily: string;
  readonly mapperRevision: string;
  readonly availability: ContentTypeAvailability;
  /**
   * Source validator: returns bounded issue codes (empty = valid). Present
   * exactly when the type is available; otherwise the type fails closed.
   */
  readonly validate?: (body: ContentBody) => readonly string[];
}

const capabilities: Readonly<Record<ContentAction, string>> = Object.freeze({
  create: 'content.create',
  update: 'content.create',
  read: 'content.create',
  submit: 'content.submit',
  publish: 'content.publish',
});

interface EntryInput {
  readonly discoverFamily: string;
  readonly sourceAuthority: string;
  readonly sourceResolver: ContentSourceResolver;
  readonly visibilityPolicy?: ContentTypeRegistryEntry['visibilityPolicy'];
  readonly validate?: (body: ContentBody) => readonly string[];
  readonly dependency?: string;
}

function entry(typeId: ContentTypeId, input: EntryInput): ContentTypeRegistryEntry {
  const availability: ContentTypeAvailability =
    input.validate !== undefined
      ? { status: 'available' }
      : input.dependency !== undefined
        ? { status: 'unavailable', reason: 'dependency_pending', dependency: input.dependency }
        : { status: 'unavailable', reason: 'source_contract_pending' };
  return Object.freeze({
    typeId,
    typeSchemaMajor: 1,
    validatorRevision: input.validate === undefined ? 'unavailable' : `${typeId}-source-v1`,
    sourceAuthority: input.sourceAuthority,
    sourceResolver: input.sourceResolver,
    requiredCapabilities: capabilities,
    allowedPublisherTypes: Object.freeze(['user', 'page'] as const),
    moderationProfileId: `${typeId}.default`,
    visibilityPolicy: input.visibilityPolicy ?? 'public_catalog',
    marketPolicy: 'single_market_per_content',
    localizedTextPolicy: 'per_locale_with_declared_fallback',
    discoverFamily: input.discoverFamily,
    mapperRevision: `${typeId}-mapper-v1`,
    availability: Object.freeze(availability),
    ...(input.validate === undefined ? {} : { validate: input.validate }),
  });
}

const placeKeys = new Set([
  'title',
  'categoryId',
  'subcategoryId',
  'geoVisibility',
  'location',
  'shortDescription',
  'openingHours',
  'mediaIds',
]);

/** Place source validator: profile, geo visibility, hours (BCK-07 §33.1). */
export function validatePlaceBody(body: ContentBody): readonly string[] {
  const issues: string[] = [];
  for (const key of Object.keys(body)) if (!placeKeys.has(key)) issues.push(`unknown_field:${key}`);
  if (!boundedString(body.title, 1, 120)) issues.push('title');
  if (!boundedString(body.categoryId, 1, 64)) issues.push('categoryId');
  if (!boundedString(body.subcategoryId, 1, 64)) issues.push('subcategoryId');
  if (body.geoVisibility !== 'exact' && body.geoVisibility !== 'approximate')
    issues.push('geoVisibility');
  const location = body.location;
  if (
    typeof location !== 'object' ||
    location === null ||
    !inRange((location as Record<string, unknown>).latitude, -90, 90) ||
    !inRange((location as Record<string, unknown>).longitude, -180, 180)
  )
    issues.push('location');
  if (body.shortDescription !== undefined && !boundedString(body.shortDescription, 0, 500))
    issues.push('shortDescription');
  if (body.openingHours !== undefined && !validOpeningHours(body.openingHours))
    issues.push('openingHours');
  if (body.mediaIds !== undefined && !validMediaIds(body.mediaIds)) issues.push('mediaIds');
  return Object.freeze(issues);
}

export function mediaIdsOf(body: ContentBody): readonly string[] {
  return validMediaIds(body.mediaIds) ? (body.mediaIds as readonly string[]) : [];
}

function boundedString(value: unknown, min: number, max: number): boolean {
  return typeof value === 'string' && value.trim().length >= min && value.length <= max;
}

function inRange(value: unknown, min: number, max: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}

function validMediaIds(value: unknown): boolean {
  return (
    Array.isArray(value) &&
    value.length <= 20 &&
    value.every((item) => typeof item === 'string' && item.length >= 1 && item.length <= 128)
  );
}

function validOpeningHours(value: unknown): boolean {
  if (!Array.isArray(value) || value.length > 14) return false;
  const time = /^([01]\d|2[0-3]):[0-5]\d$/;
  return value.every((item) => {
    if (typeof item !== 'object' || item === null) return false;
    const rule = item as Record<string, unknown>;
    return (
      Number.isInteger(rule.weekday) &&
      (rule.weekday as number) >= 0 &&
      (rule.weekday as number) <= 6 &&
      typeof rule.opens === 'string' &&
      time.test(rule.opens) &&
      typeof rule.closes === 'string' &&
      time.test(rule.closes)
    );
  });
}

// Exactly the accepted ten Create types (BCK-07 §33.1). An adapter is
// registered for every type, but only types with a ready source rule are
// available; the rest are explicit, carry their reason and fail closed instead
// of falling back to a generic schema or Event.
const entries: readonly ContentTypeRegistryEntry[] = Object.freeze([
  entry('event', {
    discoverFamily: 'Event',
    sourceAuthority: 'Event classification spec v2.2.3',
    sourceResolver: 'inline_body',
  }),
  entry('activity', {
    discoverFamily: 'Activity',
    sourceAuthority: 'Recharge Activity create block (ACT-CRT-01)',
    sourceResolver: 'inline_body',
  }),
  entry('route', {
    discoverFamily: 'Route',
    sourceAuthority: 'BCK-11 immutable RouteRevision',
    sourceResolver: 'pinned_immutable_revision',
    dependency: 'BCK-11',
  }),
  entry('place', {
    discoverFamily: 'Place',
    sourceAuthority: 'Place create block (PLC-ADP-01)',
    sourceResolver: 'inline_body',
    validate: validatePlaceBody,
  }),
  entry('session', {
    discoverFamily: 'Session',
    sourceAuthority: 'Bookable Session create block (SES-CRT-01)',
    sourceResolver: 'inline_body',
  }),
  entry('scenario', {
    discoverFamily: 'Scenario',
    sourceAuthority: 'BCK-10 immutable ScenarioRevision',
    sourceResolver: 'pinned_immutable_revision',
    dependency: 'BCK-10',
  }),
  entry('find_people', {
    discoverFamily: 'Find People',
    sourceAuthority: 'BCK-06 purpose-limited consented profile revision',
    sourceResolver: 'pinned_immutable_revision',
    visibilityPolicy: 'consent_limited',
    dependency: 'BCK-06',
  }),
  entry('class_workshop', {
    discoverFamily: 'Class/Workshop',
    sourceAuthority: 'typed Class / Workshop experience revision (no typed create block yet)',
    sourceResolver: 'inline_body',
  }),
  entry('rental', {
    discoverFamily: 'Rental',
    sourceAuthority: 'Rental / Equipment create block (RNT-CRT-01)',
    sourceResolver: 'inline_body',
  }),
  entry('collection', {
    discoverFamily: 'Collection',
    sourceAuthority: 'Collection revision of stable published object IDs',
    sourceResolver: 'published_object_membership',
  }),
]);

const byId: ReadonlyMap<string, ContentTypeRegistryEntry> = new Map(
  entries.map((item) => [item.typeId, item]),
);

// Load-time invariants: a broken registry must never start serving.
if (
  entries.length !== contentTypeIds.length ||
  byId.size !== entries.length ||
  contentTypeIds.some((id) => !byId.has(id))
)
  throw new Error('content_type_registry_incomplete');
for (const item of entries)
  if ((item.availability.status === 'available') !== (item.validate !== undefined))
    throw new Error(`content_type_registry_inconsistent:${item.typeId}`);

export const contentTypeRegistry = entries;

/** Returns the registered entry, or null for unknown/newer/foreign type ids. */
export function resolveContentType(typeId: unknown): ContentTypeRegistryEntry | null {
  return typeof typeId === 'string' ? (byId.get(typeId) ?? null) : null;
}

/** True only for a type whose source rules are implemented (fail closed otherwise). */
export function isContentTypeAvailable(item: ContentTypeRegistryEntry): boolean {
  return item.availability.status === 'available' && item.validate !== undefined;
}

/** Kept for existing call sites: a source contract exists iff the type is available. */
export const hasSourceContract = isContentTypeAvailable;
