import type { EligiblePlaceLink } from './place_link.js';
import type { TaxonomyDataset } from '../../reference_data/domain/taxonomy_dataset.js';
import { projectActivity } from './activity_projection.js';
import { bookingRefsFor } from '../../content/domain/event_internal_registration.js';
import { catalogEnabledTypes, catalogPolicyRevisions } from './catalog_config.js';

/** A committed BCK-07 publication fact, exactly as Content stored it. */
export interface ContentFact {
  readonly schemaVersion: 1;
  readonly effectId: string;
  readonly kind: string;
  readonly contentId: string;
  readonly publishedRevisionId: string;
  /** Monotonic per Content: the order in which facts apply. */
  readonly pointerRevision: number;
  readonly visibility: string;
  readonly typeId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly marketId: string;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly occurredAtUtc: string;
  /** D2: media Content stopped showing at this fact; absent when none. */
  readonly suppressedMediaIds?: readonly string[];
}

/** The immutable published revision a fact points at (read from Content). */
export interface SourceRevision {
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly typeId: string;
  readonly marketId: string;
  readonly body: Readonly<Record<string, unknown>>;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  /** When Content published this immutable revision. */
  readonly publishedAtUtc: string;
}

export type CatalogExclusionReason =
  | 'withdrawn'
  | 'restricted'
  | 'archived'
  | 'unlisted'
  | 'private'
  | 'type_disabled'
  | 'consent_limited'
  | 'invalid_projection';

export interface CatalogOccurrence {
  readonly id: string;
  readonly startAtUtc: string;
  readonly endAtUtc: string;
  /**
   * v3: only a reference to free internal Booking of this occurrence, derived
   * on the server like the Booking handoff. Terms and availability stay with
   * Booking; the Catalog never shows them.
   */
  readonly bookingRef?: {
    readonly eventId: string;
    readonly occurrenceId: string;
    readonly channel?: 'onsite';
  };
}

export interface CatalogPoint {
  readonly latitude: number;
  readonly longitude: number;
}

export type CatalogPrice =
  | { readonly mode: 'free' }
  | { readonly mode: 'fixed'; readonly amountMinor: number; readonly currencyCode: string };

/**
 * Event catalog projection v3: a public allowlist built from the immutable
 * published revision. No fake coordinates, start times, prices or capacity:
 * what the source does not hold is absent. v2 added the Details facts (full
 * description, schedule mode, revision publication time); v3 adds the
 * occurrence `bookingRef` of internal registration.
 */
export interface CatalogEventItem {
  readonly schemaRevision: string;
  readonly typeId: 'event';
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly sourcePointerRevision: number;
  readonly marketId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly title: string;
  readonly shortDescription: string;
  readonly fullDescription: string;
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly tags: readonly string[];
  readonly eventArchetype: string;
  readonly primaryParticipationMode: string;
  readonly format: string;
  readonly city: string | null;
  readonly venueName: string | null;
  readonly point: CatalogPoint | null;
  /** Why there is no point: online only, or no confirmed public pin. */
  readonly notMappable: 'onlineOnly' | 'noPublicGeo' | null;
  readonly timezoneId: string;
  readonly scheduleMode: 'oneTime' | 'multiDate' | 'recurring';
  /** Sorted by start; the only time facts the Catalog uses. */
  readonly occurrences: readonly CatalogOccurrence[];
  readonly price: CatalogPrice | null;
  readonly coverMediaId: string | null;
  readonly wheelchairAccessible: boolean;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly publishedAtUtc: string;
  /** Normalized text for the literal filter (title, summary, category, city, tags). */
  readonly searchText: string;
}

export interface CatalogActivityItem {
  readonly schemaRevision: 'catalog-activity-projection-v1';
  readonly typeId: 'activity';
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly sourcePointerRevision: number;
  readonly marketId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly title: string;
  readonly shortDescription: string;
  readonly fullDescription?: string;
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly point: CatalogPoint;
  readonly addressLine?: string;
  readonly accessNotes?: string;
  readonly accessCaution?: { readonly isInformal: boolean; readonly note?: string };
  /** Source relation id; never serialized without a fresh Catalog-owned check. */
  readonly linkedPlaceId?: string;
  readonly linkedPlace?: EligiblePlaceLink;
  readonly typicalDurationMinutes: { readonly min: number; readonly max: number };
  readonly suggestedGroupSize?: { readonly min: number; readonly max: number };
  readonly bestTime?: { readonly timeOfDay?: string; readonly season?: string };
  readonly optionalContribution?: {
    readonly kind: string;
    readonly note: string;
    readonly amountHint?: { readonly amountMinor: number; readonly currencyCode: string };
  };
  readonly coverMediaId: string | null;
  readonly galleryMediaIds: readonly string[];
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly publishedAtUtc: string;
  readonly searchText: string;
}
export type CatalogItem = CatalogEventItem | CatalogActivityItem;

export type ProjectionOutcome =
  | { readonly state: 'listed'; readonly item: CatalogItem }
  | { readonly state: 'excluded'; readonly reason: CatalogExclusionReason };

/** NFKC, lower case, letters and digits only, single spaces. */
export function normalizeText(value: string): string {
  return value
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

function record(value: unknown): Readonly<Record<string, unknown>> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

function isInstant(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(value) &&
    Number.isFinite(Date.parse(value))
  );
}

/**
 * The projection of one fact. Visibility is decided first: anything but a
 * visible pointer, a disabled or consent-limited type, or an unlisted/private
 * body is excluded and never reaches Feed, Map or Search.
 */
export function projectFact(input: {
  readonly fact: ContentFact;
  readonly revision: SourceRevision | null;
  readonly typeVisibilityPolicy: string | undefined;
  readonly activityEnabled?: boolean;
  readonly taxonomy?: TaxonomyDataset;
}): ProjectionOutcome {
  const { fact, revision } = input;
  if (
    fact.visibility === 'withdrawn' ||
    fact.visibility === 'restricted' ||
    fact.visibility === 'archived'
  )
    return { state: 'excluded', reason: fact.visibility };
  if (fact.visibility !== 'visible') return { state: 'excluded', reason: 'invalid_projection' };
  if (
    !catalogEnabledTypes.has(fact.typeId) &&
    !(fact.typeId === 'activity' && input.activityEnabled === true)
  )
    return { state: 'excluded', reason: 'type_disabled' };
  if (input.typeVisibilityPolicy !== 'public_catalog')
    return { state: 'excluded', reason: 'consent_limited' };
  if (
    revision === null ||
    revision.contentId !== fact.contentId ||
    revision.publishedRevisionId !== fact.publishedRevisionId ||
    revision.typeId !== fact.typeId ||
    revision.marketId !== fact.marketId ||
    (fact.typeId === 'activity' &&
      revision.referenceRevisions.taxonomyRevisionId !== fact.referenceRevisions.taxonomyRevisionId)
  )
    return { state: 'excluded', reason: 'invalid_projection' };
  const body = revision.body;
  // Activity has no authoring visibility field: the public pointer and registry own it.
  if (fact.typeId === 'activity') {
    if (body.visibility !== undefined) return { state: 'excluded', reason: 'invalid_projection' };
    return projectActivity(fact, revision, input.taxonomy);
  }
  if (body.visibility === 'unlisted') return { state: 'excluded', reason: 'unlisted' };
  if (body.visibility === 'private') return { state: 'excluded', reason: 'private' };
  if (body.visibility !== 'public') return { state: 'excluded', reason: 'invalid_projection' };

  const title = text(body.title);
  const shortDescription = text(body.shortDescription);
  const fullDescription = text(body.fullDescription);
  const categoryId = text(body.categoryId);
  const subcategoryId = text(body.subcategoryId);
  const schedule = record(body.schedule);
  const timezoneId = text(schedule?.timezoneId);
  const scheduleMode = schedule?.scheduleMode;
  const slots = Array.isArray(body.eventSlots) ? body.eventSlots : [];
  const bookingRefs = new Map(
    bookingRefsFor(fact.contentId, body).map((ref) => [ref.occurrenceId, ref]),
  );
  const occurrences: CatalogOccurrence[] = [];
  for (const slot of slots) {
    const value = record(slot);
    if (
      value === null ||
      typeof value.id !== 'string' ||
      !isInstant(value.startAtUtc) ||
      !isInstant(value.endAtUtc) ||
      Date.parse(value.startAtUtc) >= Date.parse(value.endAtUtc)
    )
      return { state: 'excluded', reason: 'invalid_projection' };
    const bookingRef = bookingRefs.get(value.id);
    occurrences.push({
      id: value.id,
      startAtUtc: value.startAtUtc,
      endAtUtc: value.endAtUtc,
      ...(bookingRef === undefined ? {} : { bookingRef: { ...bookingRef } }),
    });
  }
  if (
    title === null ||
    shortDescription === null ||
    fullDescription === null ||
    categoryId === null ||
    subcategoryId === null ||
    timezoneId === null ||
    (scheduleMode !== 'oneTime' && scheduleMode !== 'multiDate' && scheduleMode !== 'recurring') ||
    !isInstant(revision.publishedAtUtc) ||
    occurrences.length === 0
  )
    return { state: 'excluded', reason: 'invalid_projection' };
  occurrences.sort((left, right) =>
    left.startAtUtc === right.startAtUtc
      ? left.id < right.id
        ? -1
        : 1
      : Date.parse(left.startAtUtc) - Date.parse(right.startAtUtc),
  );

  const format = text(body.format) ?? 'offline';
  const location = record(body.location);
  const latitude = location?.latitude;
  const longitude = location?.longitude;
  const pinned =
    format !== 'online' &&
    location?.pinConfirmed === true &&
    typeof latitude === 'number' &&
    typeof longitude === 'number' &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
  const point = pinned ? { latitude, longitude } : null;
  const notMappable = point !== null ? null : format === 'online' ? 'onlineOnly' : 'noPublicGeo';

  const pricing = record(body.pricing);
  const amount = record(pricing?.price);
  let price: CatalogPrice | null = null;
  if (pricing?.mode === 'free') price = { mode: 'free' };
  else if (
    pricing?.mode === 'fixed' &&
    typeof amount?.amountMinor === 'number' &&
    Number.isInteger(amount.amountMinor) &&
    typeof amount.currencyCode === 'string'
  )
    price = { mode: 'fixed', amountMinor: amount.amountMinor, currencyCode: amount.currencyCode };

  const media = record(body.media);
  const cover = record(media?.coverImage);
  const coverMediaId = text(cover?.mediaId);
  // D2: media Content suppresses never reaches Feed, Map, Search or Details,
  // whatever the immutable revision says; replays carry the same list.
  const suppressed = new Set(fact.suppressedMediaIds ?? []);
  const audience = record(body.audience);
  const tags = Array.isArray(body.tags)
    ? body.tags.filter((tag): tag is string => typeof tag === 'string')
    : [];
  const city = text(location?.city);
  const item: CatalogEventItem = {
    schemaRevision: catalogPolicyRevisions.projectionSchema,
    typeId: 'event',
    contentId: fact.contentId,
    publishedRevisionId: fact.publishedRevisionId,
    sourcePointerRevision: fact.pointerRevision,
    marketId: fact.marketId,
    publisherRef: { type: fact.publisherRef.type, id: fact.publisherRef.id },
    title,
    shortDescription,
    fullDescription,
    categoryId,
    subcategoryId,
    tags,
    eventArchetype: text(body.eventArchetype) ?? 'other',
    primaryParticipationMode: text(body.primaryParticipationMode) ?? 'attend',
    format,
    city,
    venueName: text(location?.venueName),
    point,
    notMappable,
    timezoneId,
    scheduleMode,
    occurrences,
    price,
    coverMediaId: coverMediaId !== null && suppressed.has(coverMediaId) ? null : coverMediaId,
    wheelchairAccessible: audience?.wheelchairAccessible === true,
    referenceRevisions: { ...revision.referenceRevisions },
    publishedAtUtc: revision.publishedAtUtc,
    searchText: normalizeText(
      [title, shortDescription, categoryId, subcategoryId, city ?? '', ...tags].join(' '),
    ),
  };
  return { state: 'listed', item };
}
