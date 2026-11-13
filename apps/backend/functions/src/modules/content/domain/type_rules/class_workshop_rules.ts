import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import { resolveLocalTime } from './event_rules.js';
import {
  IssueCollector,
  hasOnlyKeys,
  isEnumValue,
  isRecord,
  isText,
  isInt,
  isNumberIn,
  isIanaZone,
  isLocalDate,
  isSafeHttpsUrl,
  isStringList,
  isInstant,
  type ContentValidationContext,
  type ContentRuleIssues,
  type Json,
} from './validation_context.js';

/** Class/Workshop v1.2 §34.4 (CW-V1) limits, accepted by the owner (CLS-OD-03). */
export const classWorkshopLimits = Object.freeze({
  titleMin: 3,
  titleMax: 100,
  shortDescriptionMin: 20,
  shortDescriptionMax: 180,
  fullDescriptionMin: 50,
  fullDescriptionMax: 10000,
  fixedSeriesMax: 60,
  occurrenceMinutesMin: 15,
  occurrenceMinutesMax: 720,
  outcomesMax: 10,
  outcomeMin: 3,
  outcomeMax: 160,
  modulesMax: 20,
  moduleTitleMin: 3,
  moduleTitleMax: 120,
  listItemsMax: 20,
  listItemMin: 2,
  listItemMax: 120,
  groupLimitMax: 500,
  galleryMax: 10,
  providerLabelMin: 2,
  providerLabelMax: 60,
  instructorNameMin: 2,
  instructorNameMax: 80,
  instructorBioMin: 20,
  instructorBioMax: 500,
});

const offeringKinds = ['class', 'workshop', 'masterclass', 'course', 'experience'] as const;
const resultRequiredKinds = new Set(['workshop', 'masterclass', 'experience']);
const max = Number.MAX_SAFE_INTEGER;
const L = classWorkshopLimits;

/** A resolved, validated occurrence on the UTC timeline. */
interface ResolvedOccurrence {
  readonly startMs: number;
  readonly endMs: number;
}

/**
 * Class/Workshop v1.2 §34 (CW-V1) / D3.6: validate the declared single class or
 * fixed series. Never expands recurrence, stores availability or treats the
 * declared group limit as inventory; unknown, future and legacy fields refuse.
 */
export function validateClassWorkshopBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  hasOnlyKeys(
    body,
    new Set([
      'title',
      'shortDescription',
      'fullDescription',
      'contentLocale',
      'categoryId',
      'subcategoryId',
      'tags',
      'criteria',
      'location',
      'media',
      'class_workshop',
    ]),
    issues,
    'class_workshop',
  );
  issues.require(context.marketId === 'LV', 'class_workshop.market');
  issues.require(
    context.publisherRef.type === 'user' && context.publisherRef.id === context.createdByUserId,
    'class_workshop_publisher_ineligible',
  );
  issues.require(isText(body.title, L.titleMin, L.titleMax), 'class_workshop.title');
  issues.require(
    isText(body.shortDescription, L.shortDescriptionMin, L.shortDescriptionMax),
    'class_workshop.shortDescription',
  );
  issues.require(
    isText(body.fullDescription, L.fullDescriptionMin, L.fullDescriptionMax),
    'class_workshop.fullDescription',
  );
  const locale =
    typeof body.contentLocale === 'string'
      ? context.lookups.supportsLocale(body.contentLocale)
      : false;
  issues.require(
    locale === true,
    locale === undefined ? 'class_workshop.locale_unavailable' : 'class_workshop.locale',
  );
  validateTaxonomy(body, context, issues);
  if (body.tags !== undefined)
    issues.require(isStringList(body.tags, max, max), 'class_workshop.tags');
  validateMedia(body, context, issues);

  const data = body.class_workshop;
  if (!isRecord(data)) {
    issues.add('class_workshop.payload');
    return issues.result();
  }
  hasOnlyKeys(
    data,
    new Set([
      'schema_version',
      'offering_kind',
      'context_kind',
      'delivery_format',
      'public_location_mode',
      'safe_area_label',
      'online_provider_label',
      'timezone_id',
      'timezone_confirmed',
      'dst_policy_version',
      'occurrences',
      'instructor',
      'learning',
      'included_materials',
      'requirements',
      'declared_group_limit',
      'price',
      'enrollment',
    ]),
    issues,
    'class_workshop.payload',
  );
  issues.require(data.schema_version === 1, 'class_workshop.schema_unsupported');
  const kindOk = issues.require(
    isEnumValue(data.offering_kind, offeringKinds),
    'class_workshop.offering_kind',
  );
  validateDelivery(body, data, context, issues);
  const occurrences = validateSchedule(data, issues);
  if (occurrences !== null) {
    const now = Date.parse(context.nowUtc);
    // CLS-OD-04: a published revision stays activatable while one class is ahead.
    issues.require(
      occurrences.some((item) => item.startMs > now),
      'class_workshop_no_future_occurrence',
    );
  }
  validateInstructor(data, kindOk ? String(data.offering_kind) : undefined, issues);
  validateLearning(data, kindOk ? String(data.offering_kind) : undefined, issues);
  issues.require(isItemList(data.included_materials), 'class_workshop.included_materials');
  issues.require(isItemList(data.requirements), 'class_workshop.requirements');
  if (data.declared_group_limit !== undefined && data.declared_group_limit !== null)
    issues.require(
      isInt(data.declared_group_limit, 1, L.groupLimitMax),
      'class_workshop.declared_group_limit',
    );
  validatePrice(data, context, issues);
  validateEnrollment(data, issues);
  return issues.result();
}

/**
 * CLS-OD-04, submit and approved publish only: every declared class starts
 * after the server's now. Activation of an immutable revision needs one.
 */
export function classWorkshopPastOccurrenceIssues(
  body: ContentBody,
  nowUtc: string,
): ContentRuleIssues {
  const data = body.class_workshop;
  if (!isRecord(data) || !Array.isArray(data.occurrences)) return ['class_workshop.payload'];
  const now = Date.parse(nowUtc);
  for (const item of data.occurrences as unknown[])
    if (!isRecord(item) || !isInstant(item.start_at_utc) || Date.parse(item.start_at_utc) <= now)
      return ['class_workshop_occurrence_in_past'];
  return [];
}

export function classWorkshopMediaIds(body: ContentBody): readonly string[] {
  if (!isRecord(body.media)) return [];
  const images = [
    body.media.coverImage,
    ...(Array.isArray(body.media.gallery) ? (body.media.gallery as unknown[]) : []),
  ];
  return images.flatMap((image) =>
    isRecord(image) && typeof image.mediaId === 'string' ? [image.mediaId] : [],
  );
}

function isItemList(value: unknown): boolean {
  return (
    Array.isArray(value) &&
    value.length <= L.listItemsMax &&
    value.every((item) => isText(item, L.listItemMin, L.listItemMax))
  );
}

function validateTaxonomy(
  body: ContentBody,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  if (typeof body.categoryId !== 'string' || typeof body.subcategoryId !== 'string') {
    issues.add('class_workshop_category_not_allowed');
    return;
  }
  const applies = context.lookups.subcategoryApplies(
    'class_workshop',
    body.categoryId,
    body.subcategoryId,
  );
  issues.require(
    applies === true,
    applies === undefined
      ? 'class_workshop.taxonomy_unavailable'
      : 'class_workshop_category_not_allowed',
  );
  if (body.criteria !== undefined && !isRecord(body.criteria)) {
    issues.add('class_workshop.criteria');
    return;
  }
  // CLS-OD-06: required fields of the active profile block publication.
  const required = context.lookups.requiredCriteria(
    'class_workshop',
    body.categoryId,
    body.subcategoryId,
  );
  if (required === undefined) {
    issues.add('class_workshop.criteria_registry_unavailable');
    return;
  }
  const criteria = body.criteria;
  for (const fieldId of required) {
    const value = criteria?.[fieldId];
    if (value === undefined || value === null || (typeof value === 'string' && value.trim() === ''))
      issues.add(`class_workshop.criterion_required:${fieldId}`);
  }
}

function validateMedia(
  body: ContentBody,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  const media = body.media;
  if (!isRecord(media)) {
    issues.add('class_workshop_media_incomplete');
    return;
  }
  hasOnlyKeys(
    media,
    new Set(['coverImage', 'gallery', 'rightsConfirmed']),
    issues,
    'class_workshop.media',
  );
  issues.require(media.rightsConfirmed === true, 'class_workshop_media_incomplete');
  issues.require(
    isRecord(media.coverImage) && Array.isArray(media.gallery),
    'class_workshop_media_incomplete',
  );
  if (Array.isArray(media.gallery))
    issues.require(media.gallery.length <= L.galleryMax, 'class_workshop.gallery_too_large');
  const images = [
    media.coverImage,
    ...(Array.isArray(media.gallery) ? (media.gallery as unknown[]) : []),
  ];
  const ids = new Set<string>();
  for (const image of images) {
    if (!isRecord(image)) {
      issues.add('class_workshop_media_incomplete');
      continue;
    }
    hasOnlyKeys(image, new Set(['mediaId', 'altText']), issues, 'class_workshop.media.image');
    issues.require(isEntityId(image.mediaId), 'class_workshop_media_incomplete');
    const alt = image.altText;
    if (
      !isRecord(alt) ||
      typeof body.contentLocale !== 'string' ||
      !isText(alt[body.contentLocale], 1, max)
    )
      issues.add('class_workshop_media_incomplete');
    else
      for (const [language, text] of Object.entries(alt))
        issues.require(
          context.lookups.supportsLocale(language) === true && isText(text, 1, max),
          'class_workshop_media_incomplete',
        );
    if (typeof image.mediaId === 'string') {
      issues.require(!ids.has(image.mediaId), 'class_workshop.media_duplicate');
      ids.add(image.mediaId);
    }
  }
}

function validateDelivery(
  body: ContentBody,
  data: Json,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  const format = data.delivery_format;
  if (
    !issues.require(
      isEnumValue(format, ['offline', 'online_live', 'hybrid'] as const),
      'class_workshop.delivery_format',
    )
  )
    return;
  const label = data.online_provider_label;
  if (format === 'online_live') {
    issues.require(body.location === undefined, 'class_workshop_location_mismatch');
    issues.require(
      data.public_location_mode === undefined && data.safe_area_label === undefined,
      'class_workshop_location_mismatch',
    );
    issues.require(
      isText(label, L.providerLabelMin, L.providerLabelMax),
      'class_workshop.online_provider_label',
    );
    return;
  }
  if (label !== undefined)
    issues.require(
      format === 'hybrid' && isText(label, L.providerLabelMin, L.providerLabelMax),
      'class_workshop.online_provider_label',
    );
  const mode = data.public_location_mode;
  if (
    issues.require(
      isEnumValue(mode, ['point', 'area_only'] as const),
      'class_workshop.public_location_mode',
    )
  )
    issues.require(
      mode === 'area_only'
        ? isText(data.safe_area_label, 1, max)
        : data.safe_area_label === undefined,
      'class_workshop.safe_area_label',
    );
  const loc = body.location;
  if (!isRecord(loc)) {
    issues.add('class_workshop_location_missing');
    return;
  }
  hasOnlyKeys(
    loc,
    new Set([
      'countryCode',
      'city',
      'venueName',
      'addressLine1',
      'latitude',
      'longitude',
      'pinConfirmed',
    ]),
    issues,
    'class_workshop.location',
  );
  issues.require(
    loc.countryCode === 'LV' &&
      isText(loc.city, 1, max) &&
      isText(loc.venueName, 1, max) &&
      isText(loc.addressLine1, 1, max) &&
      loc.pinConfirmed === true,
    'class_workshop_location_missing',
  );
  if (isNumberIn(loc.latitude, -90, 90) && isNumberIn(loc.longitude, -180, 180)) {
    const inside = context.lookups.pointInServiceArea(loc.latitude, loc.longitude);
    issues.require(
      inside === true,
      inside === undefined
        ? 'class_workshop.service_area_unavailable'
        : 'class_workshop.location_outside_market',
    );
  } else issues.add('class_workshop_location_missing');
}

/** Resolves one wall-clock minute with the explicit overlap fold (CLS-OD-04). */
function resolveWall(
  zone: string,
  date: string,
  minute: number,
  fold: unknown,
  issues: IssueCollector,
): number | null {
  const earlier = resolveLocalTime(zone, date, minute, 'reject', 'earlierOffset');
  if (earlier === 'gap_rejected') {
    issues.add('class_workshop_dst_gap');
    return null;
  }
  const later = resolveLocalTime(zone, date, minute, 'reject', 'laterOffset');
  if (later === 'gap_rejected') {
    issues.add('class_workshop_dst_gap');
    return null;
  }
  if (earlier.utcMs === later.utcMs) return earlier.utcMs;
  if (fold === 'earlier') return earlier.utcMs;
  if (fold === 'later') return later.utcMs;
  issues.add('class_workshop_dst_overlap_unresolved');
  return null;
}

function isAmbiguous(zone: string, date: string, minute: number): boolean {
  const earlier = resolveLocalTime(zone, date, minute, 'reject', 'earlierOffset');
  const later = resolveLocalTime(zone, date, minute, 'reject', 'laterOffset');
  return earlier !== 'gap_rejected' && later !== 'gap_rejected' && earlier.utcMs !== later.utcMs;
}

function validateSchedule(
  data: Json,
  issues: IssueCollector,
): readonly ResolvedOccurrence[] | null {
  const contextKind = data.context_kind;
  issues.require(
    isEnumValue(contextKind, ['single_class', 'fixed_series'] as const),
    'class_workshop.context_kind',
  );
  const zone = data.timezone_id;
  const zoneOk = issues.require(
    isIanaZone(zone) && data.timezone_confirmed === true,
    'class_workshop_timezone_invalid',
  );
  issues.require(data.dst_policy_version === 1, 'class_workshop.dst_policy');
  const list = data.occurrences;
  if (!Array.isArray(list) || list.length === 0) {
    issues.add('class_workshop_schedule_empty');
    return null;
  }
  if (contextKind === 'single_class')
    issues.require(list.length === 1, 'class_workshop_context_count');
  if (contextKind === 'fixed_series')
    issues.require(
      list.length >= 2 && list.length <= L.fixedSeriesMax,
      'class_workshop_context_count',
    );
  const resolved: ResolvedOccurrence[] = [];
  const ids = new Set<string>();
  let complete = true;
  for (const item of list as unknown[]) {
    if (!isRecord(item)) {
      issues.add('class_workshop_occurrence_invalid');
      complete = false;
      continue;
    }
    hasOnlyKeys(
      item,
      new Set([
        'id',
        'local_date',
        'start_minute_local',
        'end_minute_local',
        'fold',
        'start_at_utc',
        'end_at_utc',
        'title',
      ]),
      issues,
      'class_workshop.occurrence',
    );
    issues.require(
      isEntityId(item.id) && !ids.has(String(item.id)),
      'class_workshop.occurrence_id',
    );
    ids.add(String(item.id));
    if (item.title !== undefined && item.title !== null)
      issues.require(isText(item.title, 1, max), 'class_workshop.occurrence_title');
    issues.require(
      item.fold === undefined ||
        item.fold === null ||
        item.fold === 'earlier' ||
        item.fold === 'later',
      'class_workshop.fold',
    );
    const shape =
      isLocalDate(item.local_date) &&
      isInt(item.start_minute_local, 0, 1439) &&
      isInt(item.end_minute_local, 1, 1440) &&
      item.start_minute_local < item.end_minute_local;
    if (!issues.require(shape, 'class_workshop_occurrence_invalid') || !zoneOk) {
      complete = false;
      continue;
    }
    const tz = zone as string;
    const date = item.local_date as string;
    const startMinute = item.start_minute_local as number;
    const endMinute = item.end_minute_local as number;
    const hasFold = item.fold === 'earlier' || item.fold === 'later';
    // A fold is a decision for an ambiguous wall time only, never decoration.
    if (hasFold && !isAmbiguous(tz, date, startMinute) && !isAmbiguous(tz, date, endMinute % 1440))
      issues.add('class_workshop_dst_fold_unexpected');
    const startMs = resolveWall(tz, date, startMinute, item.fold, issues);
    // 1440 is the next local midnight, which is never inside a DST transition here.
    const endMs =
      endMinute === 1440
        ? resolveWall(tz, nextDate(date), 0, item.fold, issues)
        : resolveWall(tz, date, endMinute, item.fold, issues);
    if (startMs === null || endMs === null) {
      complete = false;
      continue;
    }
    // The server recomputes UTC; a client value that differs is refused.
    issues.require(
      isInstant(item.start_at_utc) &&
        isInstant(item.end_at_utc) &&
        Date.parse(item.start_at_utc) === startMs &&
        Date.parse(item.end_at_utc) === endMs,
      'class_workshop_utc_mismatch',
    );
    const minutes = (endMs - startMs) / 60000;
    issues.require(
      minutes >= L.occurrenceMinutesMin && minutes <= L.occurrenceMinutesMax,
      'class_workshop_duration_out_of_range',
    );
    resolved.push({ startMs, endMs });
  }
  for (let index = 1; index < resolved.length; index++) {
    const previous = resolved[index - 1]!;
    const current = resolved[index]!;
    issues.require(current.startMs > previous.startMs, 'class_workshop_occurrences_unsorted');
    issues.require(current.startMs >= previous.endMs, 'class_workshop_occurrence_overlap');
  }
  return complete && resolved.length > 0 ? resolved : null;
}

function nextDate(date: string): string {
  const next = new Date(`${date}T00:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  return next.toISOString().slice(0, 10);
}

function validateInstructor(data: Json, kind: string | undefined, issues: IssueCollector): void {
  const instructor = data.instructor;
  if (!isRecord(instructor)) {
    issues.add('class_workshop_instructor_missing');
    return;
  }
  hasOnlyKeys(
    instructor,
    new Set(['same_as_publisher', 'display_name', 'short_bio']),
    issues,
    'class_workshop.instructor',
  );
  const bioOk = isText(instructor.short_bio, L.instructorBioMin, L.instructorBioMax);
  if (instructor.same_as_publisher === true) {
    issues.require(instructor.display_name === undefined, 'class_workshop.instructor_name');
    if (instructor.short_bio !== undefined) issues.require(bioOk, 'class_workshop.instructor_bio');
  } else if (instructor.same_as_publisher === false) {
    issues.require(
      isText(instructor.display_name, L.instructorNameMin, L.instructorNameMax),
      'class_workshop_instructor_missing',
    );
    issues.require(bioOk, 'class_workshop_instructor_missing');
  } else issues.add('class_workshop_instructor_missing');
  // CW-V1 §34.1: masterclass expertise is the instructor's short bio.
  if (kind === 'masterclass') issues.require(bioOk, 'class_workshop_masterclass_bio_required');
}

function validateLearning(data: Json, kind: string | undefined, issues: IssueCollector): void {
  const learning = data.learning;
  if (!isRecord(learning)) {
    issues.add('class_workshop_learning_missing');
    return;
  }
  hasOnlyKeys(
    learning,
    new Set(['outcomes', 'modules', 'prerequisites', 'take_home_result']),
    issues,
    'class_workshop.learning',
  );
  const outcomes = learning.outcomes;
  issues.require(
    Array.isArray(outcomes) &&
      outcomes.length >= 1 &&
      outcomes.length <= L.outcomesMax &&
      outcomes.every((item) => isText(item, L.outcomeMin, L.outcomeMax)),
    'class_workshop_outcomes_invalid',
  );
  const modules = learning.modules;
  if (!Array.isArray(modules) || modules.length === 0 || modules.length > L.modulesMax)
    issues.add('class_workshop_modules_invalid');
  else {
    const ids = new Set<string>();
    for (const module of modules as unknown[]) {
      if (!isRecord(module)) {
        issues.add('class_workshop_modules_invalid');
        continue;
      }
      hasOnlyKeys(module, new Set(['id', 'title']), issues, 'class_workshop.module');
      issues.require(
        isEntityId(module.id) &&
          !ids.has(String(module.id)) &&
          isText(module.title, L.moduleTitleMin, L.moduleTitleMax),
        'class_workshop_modules_invalid',
      );
      ids.add(String(module.id));
    }
  }
  const prerequisites = learning.prerequisites;
  if (isRecord(prerequisites)) {
    hasOnlyKeys(prerequisites, new Set(['mode', 'items']), issues, 'class_workshop.prerequisites');
    const items = prerequisites.items;
    issues.require(
      (prerequisites.mode === 'none' && Array.isArray(items) && items.length === 0) ||
        (prerequisites.mode === 'listed' &&
          Array.isArray(items) &&
          items.length >= 1 &&
          isItemList(items)),
      'class_workshop_prerequisites_invalid',
    );
  } else issues.add('class_workshop_prerequisites_invalid');
  const result = learning.take_home_result;
  if (kind !== undefined && resultRequiredKinds.has(kind))
    issues.require(isText(result, 1, max), 'class_workshop_take_home_required');
  else if (result !== undefined && result !== null)
    issues.require(isText(result, 1, max), 'class_workshop.take_home_result');
}

function validatePrice(
  data: Json,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  const price = data.price;
  if (!isRecord(price)) {
    issues.add('class_workshop_price_invalid');
    return;
  }
  hasOnlyKeys(
    price,
    new Set(['mode', 'amount_minor', 'currency_code', 'scope']),
    issues,
    'class_workshop.price',
  );
  if (price.mode === 'fixed') {
    issues.require(
      isInt(price.amount_minor, 1, max) && price.currency_code === context.market.currencyCode,
      'class_workshop_price_invalid',
    );
    const scopes = ['per_person_per_class', 'per_person_full_series'] as const;
    issues.require(
      isEnumValue(price.scope, scopes) &&
        (data.context_kind !== 'single_class' || price.scope === 'per_person_per_class'),
      'class_workshop_price_scope_invalid',
    );
  } else
    issues.require(
      (price.mode === 'free' || price.mode === 'not_provided') &&
        price.amount_minor === undefined &&
        price.currency_code === undefined &&
        price.scope === undefined,
      'class_workshop_price_invalid',
    );
}

function validateEnrollment(data: Json, issues: IssueCollector): void {
  const enrollment = data.enrollment;
  if (!isRecord(enrollment)) {
    issues.add('class_workshop_enrollment_invalid');
    return;
  }
  hasOnlyKeys(
    enrollment,
    new Set(['mode', 'external_url', 'information_reason']),
    issues,
    'class_workshop.enrollment',
  );
  if (enrollment.mode === 'external')
    issues.require(
      isSafeHttpsUrl(enrollment.external_url) && enrollment.information_reason === undefined,
      'class_workshop_enrollment_url_invalid',
    );
  else
    issues.require(
      enrollment.mode === 'information_only' &&
        enrollment.external_url === undefined &&
        isEnumValue(enrollment.information_reason, ['closed', 'on_site', 'not_provided'] as const),
      'class_workshop_enrollment_invalid',
    );
}
