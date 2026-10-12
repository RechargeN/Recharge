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
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';

/**
 * Recharge Activity source rules (RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC v1.4,
 * Approved) — the §9.1 error matrix over the §12 normalized contract.
 * Recommendations from §9.2 (duration/group size outside the suggested range,
 * informal access notice) are warnings and never fail a rule.
 *
 * Activity is evergreen: no start, recurrence, capacity, pricing or booking.
 * Those names are rejected explicitly so Activity cannot silently become an
 * Event, Session, Rental or Route.
 */
const timesOfDay = ['morning', 'afternoon', 'evening', 'night', 'any'] as const;
const seasons = ['winter', 'spring', 'summer', 'autumn', 'any'] as const;
const contributionKinds = ['purchase', 'donation', 'other'] as const;
const sharedGalleryLimit = 12;

const allowedKeys = new Set([
  'title',
  'categoryId',
  'subcategoryId',
  'shortDescription',
  'fullDescription',
  'media',
  'location',
  'typicalDurationMinutes',
  'suggestedGroupSize',
  'optionalContribution',
  'bestTime',
  'criteria',
]);

/** Fields that would turn Activity into another type (§1, §9.1 last row). */
const forbiddenKeys = new Set([
  'startDateTime',
  'startDateTimeUtc',
  'endDateTimeUtc',
  'schedule',
  'occurrence',
  'occurrences',
  'eventSlots',
  'recurrence',
  'capacity',
  'participants',
  'registration',
  'booking',
  'bookingUrl',
  'externalBookingUrl',
  'pricing',
  'price',
  'basePrice',
]);

export function validateActivityBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  for (const key of Object.keys(body))
    if (forbiddenKeys.has(key)) issues.add(`activity.forbidden_field:${key}`);
    else if (!allowedKeys.has(key)) issues.add(`activity.unknown_field:${key}`);
  validateAbout(body, issues, context);
  validateLocation(body.location, issues);
  validateContribution(body.optionalContribution, issues, context);
  validateWhenAndFor(body, issues);
  issues.require(!hasUnreplacedLocalId(body), 'activity.local_id_unreplaced');
  return issues.result();
}

/** Cover then gallery media ids, the exact set Media readiness must confirm. */
export function activityMediaIds(body: ContentBody): readonly string[] {
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

function validateAbout(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  issues.require(isText(body.title, 5, 80), 'activity.title_length');
  issues.require(isText(body.shortDescription, 20, 180), 'activity.short_description_length');
  if (body.fullDescription !== undefined)
    issues.require(isText(body.fullDescription, 0, 1000), 'activity.full_description_length');

  const categoryOk = issues.require(isText(body.categoryId, 1, 64), 'activity.category_required');
  const subcategoryOk = issues.require(
    isText(body.subcategoryId, 1, 64),
    'activity.subcategory_required',
  );
  if (categoryOk && subcategoryOk) {
    const categoryId = body.categoryId as string;
    const subcategoryId = body.subcategoryId as string;
    // Effective applicability (inheritance and overrides) comes from the pinned
    // taxonomy authority, never from a local Activity whitelist.
    const applies = context.lookups.subcategoryApplies('activity', categoryId, subcategoryId);
    if (applies === undefined) issues.add('activity.taxonomy_unavailable');
    else issues.require(applies, 'activity.subcategory_not_applicable');
    const required = context.lookups.requiredCriteria('activity', categoryId, subcategoryId);
    if (required === undefined) issues.add('activity.criteria_registry_unavailable');
    else {
      const criteria = body.criteria;
      if (criteria !== undefined && !isRecord(criteria)) issues.add('activity.criteria_invalid');
      for (const fieldId of required) {
        const value = (criteria as Json | undefined)?.[fieldId];
        if (
          value === undefined ||
          value === null ||
          (typeof value === 'string' && value.trim() === '')
        )
          issues.add(`activity.criterion_required:${fieldId}`);
      }
    }
  }
  validateMedia(body.media, issues);
}

function validateMedia(value: unknown, issues: IssueCollector): void {
  if (!isRecord(value)) {
    issues.add('activity.cover_image_required');
    return;
  }
  hasOnlyKeys(value, new Set(['coverImage', 'gallery']), issues, 'activity.media');
  const mediaRef = (item: unknown): boolean =>
    isRecord(item) &&
    isText(item.mediaId, 1, 128) &&
    (item.altText === undefined || isText(item.altText, 1, 200));
  issues.require(mediaRef(value.coverImage), 'activity.cover_image_required');
  const gallery = value.gallery ?? [];
  if (!issues.require(Array.isArray(gallery), 'activity.gallery_invalid')) return;
  const items = gallery as unknown[];
  issues.require(items.length <= sharedGalleryLimit, 'activity.gallery_too_large');
  issues.require(items.every(mediaRef), 'activity.gallery_invalid');
  const ids = activityMediaIds({ media: value });
  issues.require(new Set(ids).size === ids.length, 'activity.media_duplicate');
}

function validateLocation(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'activity.location_required')) return;
  const location = value as Json;
  hasOnlyKeys(
    location,
    new Set([
      'latitude',
      'longitude',
      'pinConfirmed',
      'addressLine',
      'accessNotes',
      'accessCaution',
      'linkedPlaceId',
    ]),
    issues,
    'activity.location',
  );
  // Activity owns its coordinates; they are never inherited from a Place.
  issues.require(
    isNumberIn(location.latitude, -90, 90) && isNumberIn(location.longitude, -180, 180),
    'activity.location_coordinates_required',
  );
  issues.require(location.pinConfirmed === true, 'activity.pin_confirmation_required');
  if (location.addressLine !== undefined)
    issues.require(isText(location.addressLine, 0, 300), 'activity.address_line_length');
  if (location.accessNotes === undefined || location.accessNotes === '')
    issues.add('activity.access_notes_required');
  else issues.require(isText(location.accessNotes, 10, 300), 'activity.access_notes_length');
  if (location.linkedPlaceId !== undefined)
    // Existence/deletion of the linked Place is resolved by the Catalog owner
    // in a later slice; here it must be a permanent id, never a `loc_*` key.
    issues.require(isEntityId(location.linkedPlaceId), 'activity.linked_place_invalid');
  validateCaution(location.accessCaution, issues);
}

function validateCaution(value: unknown, issues: IssueCollector): void {
  if (value === undefined) return;
  if (!issues.require(isRecord(value), 'activity.access_caution_invalid')) return;
  const caution = value as Json;
  hasOnlyKeys(caution, new Set(['isInformal', 'note']), issues, 'activity.accessCaution');
  if (!issues.require(typeof caution.isInformal === 'boolean', 'activity.access_caution_invalid'))
    return;
  const note = typeof caution.note === 'string' ? caution.note.trim() : '';
  if (caution.isInformal === true) {
    if (note.length === 0) issues.add('activity.access_caution_note_required');
  }
  if (note.length > 0)
    issues.require(isText(caution.note, 1, 200), 'activity.access_caution_note_length');
  // isInformal=false with an empty note normalizes to no caution (§8 step 2).
}

function validateContribution(
  value: unknown,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (value === undefined) return;
  if (!issues.require(isRecord(value), 'activity.contribution_invalid')) return;
  const contribution = value as Json;
  hasOnlyKeys(
    contribution,
    new Set(['kind', 'note', 'amountHint']),
    issues,
    'activity.contribution',
  );
  const hasKind = isEnumValue(contribution.kind, contributionKinds);
  const hasNote = typeof contribution.note === 'string' && contribution.note.trim().length > 0;
  // A partially filled contribution is inconsistent, never silently dropped.
  if (contribution.kind !== undefined) issues.require(hasKind, 'activity.contribution_kind');
  if (hasKind && !hasNote) issues.add('activity.contribution_note_required');
  else if (hasKind && hasNote)
    issues.require(isText(contribution.note, 10, 140), 'activity.contribution_note_length');
  if (!hasKind && (hasNote || contribution.amountHint !== undefined))
    issues.add('activity.contribution_inconsistent');
  if (contribution.amountHint !== undefined) {
    const hint = contribution.amountHint;
    if (!issues.require(isRecord(hint), 'activity.contribution_amount_invalid')) return;
    const money = hint as Json;
    hasOnlyKeys(money, new Set(['amountMinor', 'currencyCode']), issues, 'activity.amountHint');
    issues.require(
      isMinorUnits(money.amountMinor) && money.amountMinor > 0,
      'activity.contribution_amount_not_positive',
    );
    issues.require(
      money.currencyCode === context.market.currencyCode,
      'activity.contribution_currency_unsupported',
    );
  }
}

function validateWhenAndFor(body: ContentBody, issues: IssueCollector): void {
  const range = (value: unknown, label: 'duration' | 'group_size', required: boolean): void => {
    if (value === undefined) {
      if (required) issues.add(`activity.${label}_required`);
      return;
    }
    if (!issues.require(isRecord(value), `activity.${label}_invalid`)) return;
    const pair = value as Json;
    hasOnlyKeys(pair, new Set(['min', 'max']), issues, `activity.${label}`);
    if (
      !issues.require(
        isInt(pair.min, 1, Number.MAX_SAFE_INTEGER) && isInt(pair.max, 1, Number.MAX_SAFE_INTEGER),
        `activity.${label}_not_positive`,
      )
    )
      return;
    issues.require((pair.min as number) <= (pair.max as number), `activity.${label}_range_invalid`);
  };
  range(body.typicalDurationMinutes, 'duration', true);
  range(body.suggestedGroupSize, 'group_size', false);
  const bestTime = body.bestTime;
  if (bestTime === undefined) return;
  if (!issues.require(isRecord(bestTime), 'activity.best_time_invalid')) return;
  const best = bestTime as Json;
  hasOnlyKeys(best, new Set(['timeOfDay', 'season']), issues, 'activity.bestTime');
  if (best.timeOfDay !== undefined)
    issues.require(isEnumValue(best.timeOfDay, timesOfDay), 'activity.best_time_of_day');
  if (best.season !== undefined)
    issues.require(isEnumValue(best.season, seasons), 'activity.best_season');
}
