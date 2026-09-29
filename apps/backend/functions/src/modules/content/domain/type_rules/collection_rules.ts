import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import {
  IssueCollector,
  hasOnlyKeys,
  hasUnreplacedLocalId,
  isEnumValue,
  isInt,
  isMinorUnits,
  isNumberIn,
  isRecord,
  isText,
  type CollectionObjectType,
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';

/**
 * Collection / Guide source rules (COLLECTION_GUIDE_CREATE_BLOCK_SPEC v1.0,
 * Approved). Section 11 lists what blocks publication; "requires review but
 * does not block" items (soft item-count hint, empty notes, self-publisher share,
 * budget mismatch) are warnings and never fail a rule here.
 *
 * A Collection references only already published objects of five listing types
 * by stable id. It never embeds unpublished objects, and it can never reference
 * another Collection, a Scenario, an Event, an Activity or Find People.
 */
export const collectionRuleConfig = Object.freeze({
  minPublishableItemCount: 3,
  curatorNoteMaxGraphemes: 300,
  sectionTitleMaxLength: 80,
  maxItems: 500,
  maxSections: 50,
});

const objectTypes: readonly CollectionObjectType[] = [
  'place',
  'route',
  'bookableSession',
  'classWorkshop',
  'rental',
];
const budgetTiers = ['free', 'low', 'medium', 'high'] as const;
const visibilities = ['public', 'unlisted'] as const;
const sourceStatuses = ['ready', 'stale', 'unavailable'] as const;

const topLevelKeys = new Set([
  'title',
  'shortDescription',
  'fullDescription',
  'categoryId',
  'subcategoryId',
  'media',
  'areaLabel',
  'areaId',
  'anchor',
  'budgetTier',
  'visibility',
  'sections',
  'items',
  'compositionReview',
]);

const snapshotGeoKeys = ['latitude', 'longitude', 'lat', 'lng', 'geo', 'location', 'point'];
const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });

function graphemeCount(value: string): number {
  return [...segmenter.segment(value)].length;
}

export function validateCollectionBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  hasOnlyKeys(body, topLevelKeys, issues, 'collection');
  validateEnvelope(body, issues, context);
  const sectionIds = validateSections(body.sections, issues);
  validateItems(body.items, body.compositionReview, sectionIds, issues, context);
  issues.require(!hasUnreplacedLocalId(body), 'collection.local_id_unreplaced');
  return issues.result();
}

/** Cover then gallery media ids, the exact set Media readiness must confirm. */
export function collectionMediaIds(body: ContentBody): readonly string[] {
  const media = body.media;
  if (!isRecord(media)) return [];
  const ids: string[] = [];
  if (isRecord(media.coverImage) && typeof media.coverImage.mediaId === 'string')
    ids.push(media.coverImage.mediaId);
  if (Array.isArray(media.gallery))
    for (const item of media.gallery)
      if (isRecord(item) && typeof item.mediaId === 'string') ids.push(item.mediaId);
  return ids;
}

function validateEnvelope(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  issues.require(isText(body.title, 1, 200), 'collection.title_required');
  issues.require(isText(body.shortDescription, 1, 300), 'collection.short_description_required');
  if (body.fullDescription !== undefined)
    issues.require(isText(body.fullDescription, 0, 5000), 'collection.full_description_length');
  issues.require(isText(body.areaLabel, 1, 120), 'collection.area_required');
  if (body.areaId !== undefined) issues.require(isText(body.areaId, 1, 64), 'collection.area_id');
  issues.require(isEnumValue(body.visibility, visibilities), 'collection.visibility');
  if (body.budgetTier !== undefined)
    issues.require(isEnumValue(body.budgetTier, budgetTiers), 'collection.budget_tier');
  validateAnchor(body.anchor, issues);

  const categoryOk = issues.require(isText(body.categoryId, 1, 64), 'collection.category_required');
  const subcategoryOk = issues.require(
    isText(body.subcategoryId, 1, 64),
    'collection.subcategory_required',
  );
  if (categoryOk && subcategoryOk) {
    const applies = context.lookups.subcategoryApplies(
      'collection',
      body.categoryId as string,
      body.subcategoryId as string,
    );
    if (applies === undefined) issues.add('collection.taxonomy_unavailable');
    else issues.require(applies, 'collection.subcategory_not_applicable');
  }
  validateMedia(body.media, issues);
}

function validateAnchor(value: unknown, issues: IssueCollector): void {
  if (value === undefined) return;
  // The anchor is one reference point for the whole area, not an item location.
  const ok =
    isRecord(value) &&
    Object.keys(value).every((key) => key === 'latitude' || key === 'longitude') &&
    isNumberIn(value.latitude, -90, 90) &&
    isNumberIn(value.longitude, -180, 180);
  issues.require(ok, 'collection.anchor_invalid');
}

function validateMedia(value: unknown, issues: IssueCollector): void {
  if (!isRecord(value)) {
    issues.add('collection.cover_image_required');
    return;
  }
  hasOnlyKeys(value, new Set(['coverImage', 'gallery']), issues, 'collection.media');
  const mediaRef = (item: unknown): boolean =>
    isRecord(item) &&
    isText(item.mediaId, 1, 128) &&
    (item.altText === undefined || isText(item.altText, 1, 200));
  issues.require(mediaRef(value.coverImage), 'collection.cover_image_required');
  const gallery = value.gallery ?? [];
  if (!issues.require(Array.isArray(gallery), 'collection.gallery_invalid')) return;
  const items = gallery as unknown[];
  issues.require(items.length <= 12, 'collection.gallery_too_large');
  issues.require(items.every(mediaRef), 'collection.gallery_invalid');
  const ids = collectionMediaIds({ media: value });
  issues.require(new Set(ids).size === ids.length, 'collection.media_duplicate');
}

/** Returns the set of valid section ids after checking dense ordering. */
function validateSections(value: unknown, issues: IssueCollector): ReadonlySet<string> {
  const sections = value ?? [];
  if (!issues.require(Array.isArray(sections), 'collection.sections_invalid')) return new Set();
  const list = sections as unknown[];
  issues.require(list.length <= collectionRuleConfig.maxSections, 'collection.too_many_sections');
  const ids = new Set<string>();
  const orders: number[] = [];
  for (const item of list) {
    if (
      !isRecord(item) ||
      !isText(item.id, 1, 64) ||
      !isText(item.title, 1, collectionRuleConfig.sectionTitleMaxLength) ||
      !isInt(item.order, 0, 100000)
    ) {
      issues.add('collection.section_invalid');
      continue;
    }
    hasOnlyKeys(item, new Set(['id', 'title', 'order']), issues, 'collection.section');
    if (ids.has(item.id)) issues.add('collection.section_duplicate');
    ids.add(item.id);
    orders.push(item.order);
  }
  issues.require(isDense(orders), 'collection.section_order_not_dense');
  return ids;
}

function isDense(orders: readonly number[]): boolean {
  const sorted = [...orders].sort((left, right) => left - right);
  return sorted.every((order, index) => order === index);
}

function validateItems(
  value: unknown,
  compositionReview: unknown,
  sectionIds: ReadonlySet<string>,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(Array.isArray(value), 'collection.items_required')) return;
  const items = value as unknown[];
  // A curated list of one or two objects carries no curation value.
  issues.require(
    items.length >= collectionRuleConfig.minPublishableItemCount,
    'collection.min_items',
  );
  issues.require(items.length <= collectionRuleConfig.maxItems, 'collection.too_many_items');

  const stableKeys = new Set<string>();
  const itemIds = new Set<string>();
  const ordersByScope = new Map<string, number[]>();
  const unavailableKeys = new Set<string>();
  let unresolved = false;

  for (const item of items) {
    if (!isRecord(item)) {
      issues.add('collection.item_invalid');
      continue;
    }
    hasOnlyKeys(
      item,
      new Set([
        'id',
        'ref',
        'snapshot',
        'sourceStatus',
        'order',
        'sectionId',
        'curatorNote',
        'highlight',
      ]),
      issues,
      'collection.item',
    );
    // Item ids are permanent ULID/UUIDs and never the referenced object id.
    const itemId = item.id;
    if (!isEntityId(itemId)) {
      issues.add('collection.item_id_invalid');
      continue;
    }
    if (itemIds.has(itemId)) issues.add('collection.item_id_duplicate');
    itemIds.add(itemId);

    const ref = item.ref;
    if (
      !isRecord(ref) ||
      !isEntityId(ref.objectId) ||
      !objectTypes.includes(ref.objectType as CollectionObjectType)
    ) {
      // Collections, Scenarios, Events, Activities and Find People cannot be
      // referenced: the object type enum is closed.
      issues.add('collection.item_ref_invalid');
      continue;
    }
    hasOnlyKeys(ref, new Set(['objectId', 'objectType']), issues, 'collection.ref');
    issues.require(ref.objectId !== itemId, 'collection.item_id_is_object_id');
    const stableKey = `${ref.objectType as string}:${ref.objectId}`;
    if (stableKeys.has(stableKey)) issues.add('collection.duplicate_item');
    stableKeys.add(stableKey);

    if (item.sectionId !== undefined && item.sectionId !== null) {
      if (typeof item.sectionId !== 'string' || !sectionIds.has(item.sectionId))
        issues.add('collection.orphan_section');
    }
    const scope = typeof item.sectionId === 'string' ? item.sectionId : '';
    if (isInt(item.order, 0, 1000000)) {
      const bucket = ordersByScope.get(scope) ?? [];
      bucket.push(item.order);
      ordersByScope.set(scope, bucket);
    } else issues.add('collection.item_order_invalid');

    if (item.curatorNote !== undefined) {
      if (typeof item.curatorNote !== 'string') issues.add('collection.curator_note_invalid');
      else
        issues.require(
          graphemeCount(item.curatorNote) <= collectionRuleConfig.curatorNoteMaxGraphemes,
          'collection.curator_note_length',
        );
    }
    if (item.highlight !== undefined)
      issues.require(typeof item.highlight === 'boolean', 'collection.highlight_invalid');
    if (item.sourceStatus !== undefined)
      issues.require(isEnumValue(item.sourceStatus, sourceStatuses), 'collection.source_status');
    validateSnapshot(item.snapshot, issues);

    // The client snapshot and its `sourceStatus` are hints; the live status of
    // the referenced published object decides what needs acknowledgement.
    const live = context.publishedObjects?.statusOf(
      ref.objectType as CollectionObjectType,
      ref.objectId,
    );
    if (live === undefined) unresolved = true;
    else if (live === 'unavailable') unavailableKeys.add(stableKey);
  }
  for (const orders of ordersByScope.values())
    issues.require(isDense(orders), 'collection.item_order_not_dense');
  if (unresolved) issues.add('collection.published_objects_unavailable');
  else validateReview(compositionReview, context, stableKeys, unavailableKeys, issues);
}

function validateSnapshot(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'collection.snapshot_invalid')) return;
  const snapshot = value as Json;
  hasOnlyKeys(
    snapshot,
    new Set([
      'title',
      'coverMediaId',
      'categoryLabel',
      'publisherRef',
      'priceFromMinorUnits',
      'currency',
      'checkedAtUtc',
    ]),
    issues,
    'collection.snapshot',
  );
  issues.require(isText(snapshot.title, 1, 200), 'collection.snapshot_title');
  // Privacy invariant: a persisted fallback snapshot never carries geo.
  if (snapshotGeoKeys.some((key) => key in snapshot))
    issues.add('collection.snapshot_geo_forbidden');
  if (snapshot.priceFromMinorUnits !== undefined)
    issues.require(isMinorUnits(snapshot.priceFromMinorUnits), 'collection.snapshot_price');
  if (snapshot.checkedAtUtc !== undefined)
    issues.require(
      typeof snapshot.checkedAtUtc === 'string' &&
        Number.isFinite(Date.parse(snapshot.checkedAtUtc)),
      'collection.snapshot_checked_at',
    );
}

/**
 * The composition review must belong to exactly this revision and acknowledge
 * exactly the objects that are unavailable right now. Writing the review is
 * itself a draft update, so the client stores `draftRevision = expected + 1`;
 * any later edit bumps the revision and therefore invalidates the review.
 */
function validateReview(
  review: unknown,
  context: ContentValidationContext,
  stableKeys: ReadonlySet<string>,
  unavailableKeys: ReadonlySet<string>,
  issues: IssueCollector,
): void {
  if (!isRecord(review)) {
    issues.add('collection.composition_review_required');
    return;
  }
  hasOnlyKeys(
    review,
    new Set(['draftRevision', 'reviewedAtUtc', 'acknowledgedUnavailableStableKeys']),
    issues,
    'collection.compositionReview',
  );
  const keys = review.acknowledgedUnavailableStableKeys;
  const reviewedAt = review.reviewedAtUtc;
  if (
    review.draftRevision !== context.draftRevision ||
    typeof reviewedAt !== 'string' ||
    !Number.isFinite(Date.parse(reviewedAt)) ||
    !Array.isArray(keys) ||
    keys.some((key) => typeof key !== 'string')
  ) {
    issues.add('collection.composition_review_stale');
    return;
  }
  const acknowledged = new Set(keys as string[]);
  const withinItems = [...acknowledged].every((key) => stableKeys.has(key));
  const exact =
    acknowledged.size === unavailableKeys.size &&
    [...unavailableKeys].every((key) => acknowledged.has(key));
  issues.require(withinItems && exact, 'collection.composition_review_mismatch');
}
