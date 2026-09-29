import {
  contentTypeIds,
  type ContentBody,
  type ContentTypeId,
} from '../../../contracts/content_v1.js';

export type ContentAction = 'create' | 'update' | 'read' | 'submit' | 'publish';

export interface ContentTypeRegistryEntry {
  readonly typeId: ContentTypeId;
  readonly typeSchemaMajor: 1;
  readonly validatorRevision: string;
  readonly requiredCapabilities: Readonly<Record<ContentAction, string>>;
  readonly allowedPublisherTypes: readonly ('user' | 'page')[];
  readonly moderationProfileId: string;
  readonly discoverFamily: string;
  readonly mapperRevision: string;
  /**
   * Source validator: returns bounded issue codes (empty = valid). Absent means
   * the type has no registered source contract yet and fails closed.
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

function entry(
  typeId: ContentTypeId,
  discoverFamily: string,
  validate?: (body: ContentBody) => readonly string[],
): ContentTypeRegistryEntry {
  return Object.freeze({
    typeId,
    typeSchemaMajor: 1,
    validatorRevision: validate === undefined ? 'unavailable' : `${typeId}-source-v1`,
    requiredCapabilities: capabilities,
    allowedPublisherTypes: Object.freeze(['user', 'page'] as const),
    moderationProfileId: `${typeId}.default`,
    discoverFamily,
    mapperRevision: `${typeId}-mapper-v1`,
    ...(validate === undefined ? {} : { validate }),
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

// Exactly the accepted ten Create types (BCK-07 §33.1). Only Place has a
// registered source validator in this slice; every other entry is explicit but
// unavailable and fails closed instead of falling back to a generic schema.
const entries: readonly ContentTypeRegistryEntry[] = Object.freeze([
  entry('event', 'Event'),
  entry('activity', 'Activity'),
  entry('route', 'Route'),
  entry('place', 'Place', validatePlaceBody),
  entry('session', 'Session'),
  entry('scenario', 'Scenario'),
  entry('find_people', 'Find People'),
  entry('class_workshop', 'Class/Workshop'),
  entry('rental', 'Rental'),
  entry('collection', 'Collection'),
]);

const byId: ReadonlyMap<string, ContentTypeRegistryEntry> = new Map(
  entries.map((item) => [item.typeId, item]),
);

if (entries.length !== contentTypeIds.length || contentTypeIds.some((id) => !byId.has(id)))
  throw new Error('content_type_registry_incomplete');

export const contentTypeRegistry = entries;

/** Returns the registered entry, or null for unknown/newer/foreign type ids. */
export function resolveContentType(typeId: unknown): ContentTypeRegistryEntry | null {
  return typeof typeId === 'string' ? (byId.get(typeId) ?? null) : null;
}

export function hasSourceContract(item: ContentTypeRegistryEntry): boolean {
  return item.validate !== undefined;
}
