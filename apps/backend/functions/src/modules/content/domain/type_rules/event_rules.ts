import type { ContentBody } from '../../../../contracts/content_v1.js';
import {
  IssueCollector,
  hasOnlyKeys,
  hasUnreplacedLocalId,
  isCountryCode,
  isEnumValue,
  isIanaZone,
  isInstant,
  isInt,
  isLocalDate,
  isMinorUnits,
  isNumberIn,
  isRecord,
  isSafeHttpsUrl,
  isStringList,
  isText,
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';
import { isEntityId } from '../../../../shared/ids.js';

/**
 * Event source rules for the approved subset: capability C0 + schedule-C1
 * (EVENT_CREATE_CORE_SCHEDULE_SLICE_SPEC EVT-CRT-01) over the canonical Event
 * Classification v2.2.3 archetype/participation axes and EVENT_CREATE_SPEC.
 *
 * Supported: classification, name/category/criteria/media, offline/online/hybrid
 * with a public link or external registration, one-time/all-day/multi-day,
 * multi-date and recurring schedules with DST policies and exception dates,
 * audience/amenities, `free`/`fixed` price with `none`/`onsite`/`external`
 * collection, registration `none`/`external`, and `public`/`unlisted`.
 *
 * Everything beyond it (admission, inventory, Recharge Booking, ticket types,
 * donations, internal payments, private access, occurrence overrides, typed
 * deadlines, program items, relations, provider records) is rejected by name so
 * an unsupported variant can never pass as a partially valid Event. The event
 * archetype is always an explicit choice: it is never derived from the category.
 */
export const eventArchetypes = [
  'performance',
  'screening',
  'exhibition',
  'open_stage',
  'meet_greet',
  'talk',
  'discussion',
  'conference',
  'networking',
  'social_meetup',
  'hosted_game',
  'open_play',
  'competition',
  'class_session',
  'workshop',
  'retreat_camp',
  'wellness_session',
  'tasting',
  'shared_meal',
  'party',
  'celebration',
  'festival',
  'market_fair',
  'auction',
  'launch_promotion',
  'open_day',
  'tour_excursion',
  'outdoor_gathering',
  'community_action',
  'volunteering',
  'fundraiser',
  'family_program',
  'ceremony',
  'other',
] as const;

export const participationModes = [
  'watch',
  'attend',
  'play',
  'compete',
  'perform',
  'practice',
  'learn',
  'create',
  'meet_people',
  'date',
  'visit',
  'explore',
  'eat_drink',
  'shop',
  'support',
  'volunteer',
  'travel',
] as const;

export const eventRuleConfig = Object.freeze({
  maxRecurringProjection: 180,
  maxMultiDates: 366,
  maxExceptionDates: 366,
  maxRecurrenceInterval: 366,
  maxOccurrenceCount: 1000,
  maxBufferMinutes: 1440,
});

const formats = ['offline', 'online', 'hybrid'] as const;
const onlineAccessModes = ['publicLink', 'externalRegistration'] as const;
const scheduleModes = ['oneTime', 'multiDate', 'recurring'] as const;
const frequencies = ['daily', 'weekly', 'monthly', 'yearly'] as const;
const endModes = ['never', 'untilDate', 'occurrenceCount'] as const;
const monthlyPolicies = ['skipInvalidDate', 'useLastDay'] as const;
const gapPolicies = ['shiftForward', 'reject'] as const;
const overlapPolicies = ['earlierOffset', 'laterOffset'] as const;
const visibilities = ['public', 'unlisted'] as const;
const pricingModels = ['per_person', 'fixed_group'] as const;

/** Capabilities beyond C0 + schedule-C1: named so the rejection is explicit. */
const unsupportedCapabilities = new Set([
  'admission',
  'admissionMode',
  'registrationMode',
  'confirmationMode',
  'eligibilityRules',
  'guestPolicy',
  'waitlistPolicy',
  'onsiteAdmissionPolicy',
  'interestPolicy',
  'attendancePolicy',
  'inventory',
  'inventoryAuthority',
  'inventoryShapes',
  'inventoryPools',
  'ticketTypes',
  'paymentConfigurationRef',
  'refundPolicy',
  'checkInPolicy',
  'bookingPolicy',
  'occurrenceOverrides',
  'registrationDeadlineRule',
  'admissionWindows',
  'accessPolicy',
  'protectedOnlineAccessRef',
  'videos',
  'eventRelations',
  'unlinkedCredits',
  'routeRef',
  'programItemRefs',
  'sourceRecords',
  'fieldAuthority',
  'freshness',
]);

/** Server-owned or derived state a Creator can never author. */
const serverOwnedKeys = new Set([
  'lifecycleStatus',
  'moderationStatus',
  'currentParticipants',
  'publishedAtUtc',
  'revisionVersion',
  'startAtUtc',
  'endAtUtc',
  'publisherRef',
]);

const topLevelKeys = new Set([
  'eventArchetype',
  'eventArchetypeOtherReason',
  'primaryParticipationMode',
  'additionalParticipationModes',
  'title',
  'categoryId',
  'subcategoryId',
  'tags',
  'shortDescription',
  'fullDescription',
  'criteria',
  'media',
  'format',
  'onlineAccessMode',
  'publicOnlineUrl',
  'location',
  'schedule',
  'eventSlots',
  'audience',
  'amenityIds',
  'pricing',
  'participants',
  'registration',
  'visibility',
]);

export function validateEventBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  for (const key of Object.keys(body)) {
    if (topLevelKeys.has(key)) continue;
    if (unsupportedCapabilities.has(key)) issues.add(`event.unsupported_capability:${key}`);
    else if (serverOwnedKeys.has(key)) issues.add(`event.server_owned_field:${key}`);
    else issues.add(`event.unknown_field:${key}`);
  }
  validateClassification(body, issues);
  validateNameAndCategory(body, issues, context);
  validateMedia(body.media, issues);
  const format = validateFormatAndAccess(body, issues);
  validateLocation(body.location, format, issues);
  validateScheduleAndSlots(body, issues, context);
  validateAudience(body, issues);
  validatePricing(body.pricing, issues, context);
  validateParticipants(body.participants, issues);
  validateRegistration(body, issues);
  if (body.visibility === 'private') issues.add('event.unsupported_capability:visibility.private');
  else issues.require(isEnumValue(body.visibility, visibilities), 'event.visibility');
  issues.require(!hasUnreplacedLocalId(body), 'event.local_id_unreplaced');
  return issues.result();
}

/** Cover then gallery media ids, the exact set Media readiness must confirm. */
export function eventMediaIds(body: ContentBody): readonly string[] {
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

function validateClassification(body: ContentBody, issues: IssueCollector): void {
  // Explicit only: the archetype is never inferred from category or title.
  const archetypeOk = issues.require(
    isEnumValue(body.eventArchetype, eventArchetypes),
    'event.eventArchetype',
  );
  if (archetypeOk && body.eventArchetype === 'other')
    issues.require(isText(body.eventArchetypeOtherReason, 3, 300), 'event.archetype_other_reason');
  else if (body.eventArchetypeOtherReason !== undefined)
    issues.add('event.archetype_reason_without_other');
  const primaryOk = issues.require(
    isEnumValue(body.primaryParticipationMode, participationModes),
    'event.primaryParticipationMode',
  );
  const additional = body.additionalParticipationModes ?? [];
  if (
    !issues.require(
      Array.isArray(additional) &&
        additional.every((mode) => isEnumValue(mode, participationModes)),
      'event.additionalParticipationModes',
    )
  )
    return;
  const modes = additional as string[];
  issues.require(modes.length <= 3, 'event.additional_participation_limit');
  issues.require(new Set(modes).size === modes.length, 'event.participation_mode_duplicate');
  if (primaryOk)
    issues.require(
      !modes.includes(body.primaryParticipationMode as string),
      'event.participation_mode_duplicate',
    );
}

function validateNameAndCategory(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  issues.require(isText(body.title, 3, 100), 'event.title_length');
  issues.require(isText(body.shortDescription, 20, 240), 'event.short_description_length');
  issues.require(isText(body.fullDescription, 50, 20000), 'event.full_description_length');
  if (body.tags !== undefined) issues.require(isStringList(body.tags, 10, 40), 'event.tags');
  const categoryOk = issues.require(isText(body.categoryId, 1, 64), 'event.category_required');
  const subcategoryOk = issues.require(
    isText(body.subcategoryId, 1, 64),
    'event.subcategory_required',
  );
  if (!categoryOk || !subcategoryOk) return;
  const categoryId = body.categoryId as string;
  const subcategoryId = body.subcategoryId as string;
  const applies = context.lookups.subcategoryApplies('event', categoryId, subcategoryId);
  if (applies === undefined) issues.add('event.taxonomy_unavailable');
  else issues.require(applies, 'event.subcategory_not_applicable');
  const required = context.lookups.requiredCriteria('event', categoryId, subcategoryId);
  if (required === undefined) {
    issues.add('event.criteria_registry_unavailable');
    return;
  }
  const criteria = body.criteria;
  if (criteria !== undefined && !isRecord(criteria)) {
    issues.add('event.criteria_invalid');
    return;
  }
  for (const fieldId of required) {
    const value = criteria?.[fieldId];
    if (value === undefined || value === null || value === '')
      issues.add(`event.criterion_required:${fieldId}`);
  }
}

function validateMedia(value: unknown, issues: IssueCollector): void {
  if (!isRecord(value)) {
    issues.add('event.cover_required');
    return;
  }
  hasOnlyKeys(value, new Set(['coverImage', 'gallery', 'rightsConfirmed']), issues, 'event.media');
  // Alt text is mandatory for the cover and every gallery asset.
  const asset = (item: unknown, missing: string): void => {
    if (!isRecord(item) || !isText(item.mediaId, 1, 128)) {
      issues.add(missing);
      return;
    }
    hasOnlyKeys(item, new Set(['mediaId', 'altText']), issues, 'event.mediaAsset');
    issues.require(isText(item.altText, 3, 200), 'event.alt_text_required');
  };
  asset(value.coverImage, 'event.cover_required');
  const gallery = value.gallery ?? [];
  if (issues.require(Array.isArray(gallery), 'event.gallery_invalid'))
    for (const item of gallery as unknown[]) asset(item, 'event.gallery_invalid');
  issues.require(value.rightsConfirmed === true, 'event.media_rights_required');
  const ids = eventMediaIds({ media: value });
  issues.require(new Set(ids).size === ids.length, 'event.media_duplicate');
}

type Format = (typeof formats)[number];

function validateFormatAndAccess(body: ContentBody, issues: IssueCollector): Format | undefined {
  const format = body.format;
  if (!isEnumValue(format, formats)) {
    issues.add('event.format');
    return undefined;
  }
  const needsOnline = format === 'online' || format === 'hybrid';
  if (!needsOnline) {
    // An offline event shows no online access at all.
    issues.require(
      body.onlineAccessMode === undefined && body.publicOnlineUrl === undefined,
      'event.online_access_not_allowed',
    );
    return format;
  }
  if (body.onlineAccessMode === 'internalBooking') {
    issues.add('event.unsupported_capability:onlineAccessMode.internalBooking');
    return format;
  }
  if (
    !issues.require(
      isEnumValue(body.onlineAccessMode, onlineAccessModes),
      'event.online_access_required',
    )
  )
    return format;
  if (body.onlineAccessMode === 'publicLink')
    issues.require(isSafeHttpsUrl(body.publicOnlineUrl), 'event.public_online_url_invalid');
  else issues.require(body.publicOnlineUrl === undefined, 'event.public_url_with_external_access');
  return format;
}

function validateLocation(
  value: unknown,
  format: Format | undefined,
  issues: IssueCollector,
): void {
  if (!issues.require(isRecord(value), 'event.location_required')) return;
  const location = value as Json;
  hasOnlyKeys(
    location,
    new Set([
      'marketCityId',
      'countryCode',
      'city',
      'venueName',
      'formattedAddress',
      'meetingPoint',
      'latitude',
      'longitude',
      'pinConfirmed',
      'accuracy',
    ]),
    issues,
    'event.location',
  );
  // Every event, online included, is published into a market by id, not by name.
  issues.require(isText(location.marketCityId, 1, 64), 'event.market_city_required');
  issues.require(isCountryCode(location.countryCode), 'event.country_code');
  if (format === 'online') {
    issues.require(
      location.latitude === undefined &&
        location.longitude === undefined &&
        location.pinConfirmed !== true,
      'event.online_has_physical_location',
    );
    return;
  }
  issues.require(isText(location.city, 1, 100), 'event.city_required');
  if (location.venueName !== undefined)
    issues.require(isText(location.venueName, 1, 150), 'event.venue_name');
  const hasAddress = isText(location.formattedAddress, 1, 300);
  const hasMeeting = isText(location.meetingPoint, 1, 300);
  issues.require(hasAddress || hasMeeting, 'event.location_required');
  const pointOk = issues.require(
    isNumberIn(location.latitude, -90, 90) && isNumberIn(location.longitude, -180, 180),
    'event.location_coordinates_required',
  );
  if (pointOk) issues.require(location.pinConfirmed === true, 'event.location_pin_unconfirmed');
  if (location.accuracy !== undefined)
    issues.require(
      isEnumValue(location.accuracy, ['rooftop', 'interpolated', 'approximate', 'manual'] as const),
      'event.location_accuracy',
    );
}

function validateAudience(body: ContentBody, issues: IssueCollector): void {
  if (body.amenityIds !== undefined) {
    const ok = issues.require(isStringList(body.amenityIds, 100, 64), 'event.amenityIds');
    if (ok)
      issues.require(
        new Set(body.amenityIds as string[]).size === (body.amenityIds as string[]).length,
        'event.amenityIds_duplicate',
      );
  }
  if (body.audience === undefined) return;
  const audience = body.audience;
  if (!isRecord(audience)) {
    issues.add('event.audience');
    return;
  }
  hasOnlyKeys(
    audience,
    new Set([
      'ageMin',
      'ageMax',
      'familyFriendly',
      'kidsAllowed',
      'petFriendly',
      'wheelchairAccessible',
    ]),
    issues,
    'event.audience',
  );
  const min = audience.ageMin;
  const max = audience.ageMax;
  if (min !== undefined) issues.require(isInt(min, 0, 120), 'event.age_min_invalid');
  if (max !== undefined) issues.require(isInt(max, 0, 120), 'event.age_max_invalid');
  if (isInt(min, 0, 120) && isInt(max, 0, 120))
    issues.require(min <= max, 'event.age_range_invalid');
  for (const key of [
    'familyFriendly',
    'kidsAllowed',
    'petFriendly',
    'wheelchairAccessible',
  ] as const)
    if (audience[key] !== undefined)
      issues.require(typeof audience[key] === 'boolean', `event.audience_${key}`);
  if (audience.kidsAllowed === true && isInt(min, 0, 120) && min >= 18)
    issues.add('event.audience_kids_conflict');
}

function validatePricing(
  value: unknown,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(isRecord(value), 'event.pricing_required')) return;
  const pricing = value as Json;
  hasOnlyKeys(
    pricing,
    new Set(['mode', 'price', 'pricingModel', 'paymentCollectionMode', 'externalPaymentUrl']),
    issues,
    'event.pricing',
  );
  if (pricing.mode === 'ticketTypes' || pricing.mode === 'donation') {
    issues.add(`event.unsupported_capability:pricing.${pricing.mode}`);
    return;
  }
  if (!issues.require(isEnumValue(pricing.mode, ['free', 'fixed'] as const), 'event.pricing_mode'))
    return;
  if (pricing.paymentCollectionMode === 'internal') {
    issues.add('event.unsupported_capability:paymentCollectionMode.internal');
    return;
  }
  if (
    !issues.require(
      isEnumValue(pricing.paymentCollectionMode, ['none', 'onsite', 'external'] as const),
      'event.payment_collection_mode',
    )
  )
    return;
  if (pricing.mode === 'free') {
    // A free event neither has a price nor collects payment.
    issues.require(
      pricing.price === undefined &&
        pricing.pricingModel === undefined &&
        pricing.externalPaymentUrl === undefined &&
        pricing.paymentCollectionMode === 'none',
      'event.free_price_conflict',
    );
    return;
  }
  const price = pricing.price;
  const priceOk =
    isRecord(price) &&
    isMinorUnits(price.amountMinor) &&
    price.amountMinor > 0 &&
    Object.keys(price).every((key) => key === 'amountMinor' || key === 'currencyCode');
  issues.require(priceOk, 'event.fixed_price_required');
  if (priceOk)
    issues.require(price.currencyCode === context.market.currencyCode, 'event.price_currency');
  issues.require(isEnumValue(pricing.pricingModel, pricingModels), 'event.pricing_model');
  issues.require(pricing.paymentCollectionMode !== 'none', 'event.payment_mode_unavailable');
  if (pricing.paymentCollectionMode === 'external')
    issues.require(
      isSafeHttpsUrl(pricing.externalPaymentUrl),
      'event.external_payment_url_invalid',
    );
  else
    issues.require(pricing.externalPaymentUrl === undefined, 'event.payment_url_without_external');
}

function validateParticipants(value: unknown, issues: IssueCollector): void {
  if (value === undefined) return;
  if (!isRecord(value)) {
    issues.add('event.participants');
    return;
  }
  const participants = value;
  hasOnlyKeys(
    participants,
    new Set(['capacityMode', 'capacity', 'minParticipants']),
    issues,
    'event.participants',
  );
  const mode = participants.capacityMode;
  if (
    !issues.require(
      isEnumValue(mode, ['known', 'unknown', 'unlimited'] as const),
      'event.capacity_mode',
    )
  )
    return;
  // `unknown` and `unlimited` are explicit modes, never inferred from a null.
  if (mode === 'known')
    issues.require(isInt(participants.capacity, 1, 10000000), 'event.capacity_required');
  else issues.require(participants.capacity === undefined, 'event.capacity_not_allowed');
  const minimum = participants.minParticipants;
  if (minimum === undefined) return;
  if (!isInt(minimum, 1, 10000000)) {
    issues.add('event.min_participants');
    return;
  }
  const capacity = participants.capacity;
  if (isInt(capacity, 1, 10000000))
    issues.require(minimum <= capacity, 'event.min_exceeds_capacity');
}

function validateRegistration(body: ContentBody, issues: IssueCollector): void {
  const registration = body.registration;
  if (!isRecord(registration)) {
    issues.add('event.registration_required');
    return;
  }
  hasOnlyKeys(registration, new Set(['mode', 'externalBookingUrl']), issues, 'event.registration');
  if (registration.mode === 'internal') {
    issues.add('event.unsupported_capability:registration.internal');
    return;
  }
  if (
    !issues.require(
      isEnumValue(registration.mode, ['none', 'external'] as const),
      'event.registration_mode',
    )
  )
    return;
  if (registration.mode === 'external')
    issues.require(
      isSafeHttpsUrl(registration.externalBookingUrl),
      'event.external_booking_url_invalid',
    );
  else
    issues.require(
      registration.externalBookingUrl === undefined,
      'event.booking_url_without_registration',
    );
  // External online access is only possible through external registration.
  if (body.onlineAccessMode === 'externalRegistration')
    issues.require(registration.mode === 'external', 'event.online_access_registration_conflict');
}

// --- Schedule ---------------------------------------------------------------

interface Recurrence {
  readonly frequency: (typeof frequencies)[number];
  readonly interval: number;
  readonly weekdays: readonly number[];
  readonly monthlyDayPolicy: (typeof monthlyPolicies)[number];
  readonly endMode: (typeof endModes)[number];
  readonly untilLocalDate: string | undefined;
  readonly occurrenceCount: number | undefined;
  readonly exceptionLocalDates: ReadonlySet<string>;
  readonly dstGapPolicy: (typeof gapPolicies)[number];
  readonly dstOverlapPolicy: (typeof overlapPolicies)[number];
}

interface Schedule {
  readonly timezoneId: string;
  readonly scheduleMode: (typeof scheduleModes)[number];
  readonly allDay: boolean;
  readonly localStartDate: string;
  readonly startMinute: number;
  readonly durationMinutes: number;
  readonly multiDateLocalDates: readonly string[];
  readonly recurrence: Recurrence | undefined;
}

interface ExpectedSlot {
  readonly localDate: string;
  readonly startMs: number;
  readonly endMs: number;
}

const dayMs = 86400000;

function validateScheduleAndSlots(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  const schedule = parseSchedule(body.schedule, issues);
  const slots = body.eventSlots;
  if (!issues.require(Array.isArray(slots) && slots.length >= 1, 'event.occurrences_required'))
    return;
  const slotList = slots as unknown[];
  const shapesOk = slotList.every((slot) => slotShapeOk(slot, issues));
  const now = Date.parse(context.nowUtc);
  if (shapesOk) {
    const starts = slotList.map((slot) => Date.parse((slot as Json).startAtUtc as string));
    issues.require(
      starts.every((start, index) => index === 0 || start > (starts[index - 1] ?? 0)),
      'event.occurrences_not_sorted_unique',
    );
    const ids = slotList.map((slot) => (slot as Json).id as string);
    issues.require(new Set(ids).size === ids.length, 'event.occurrence_id_duplicate');
    issues.require(
      starts.some((start) => start > now),
      'event.future_occurrence_required',
    );
  }
  if (schedule === undefined || !shapesOk) return;

  const expected = expandSchedule(schedule, now, issues);
  if (expected === undefined) return;
  const limit =
    schedule.scheduleMode === 'recurring'
      ? Math.min(eventRuleConfig.maxRecurringProjection, expected.length)
      : expected.length;
  const exact = schedule.scheduleMode !== 'recurring';
  // Recurring series are materialized as a rolling projection: the client slots
  // must be a leading run of the deterministic expansion, never arbitrary times.
  const lengthOk = exact ? slotList.length === expected.length : slotList.length <= limit;
  if (!issues.require(lengthOk, 'event.occurrences_mismatch')) return;
  const matches = slotList.every((slot, index) => {
    const candidate = slot as Json;
    const wanted = expected[index];
    return (
      wanted !== undefined &&
      candidate.localDate === wanted.localDate &&
      Date.parse(candidate.startAtUtc as string) === wanted.startMs &&
      Date.parse(candidate.endAtUtc as string) === wanted.endMs
    );
  });
  issues.require(matches, 'event.occurrences_mismatch');
}

function slotShapeOk(slot: unknown, issues: IssueCollector): boolean {
  if (!isRecord(slot)) {
    issues.add('event.occurrence_invalid');
    return false;
  }
  hasOnlyKeys(
    slot,
    new Set(['id', 'localDate', 'startAtUtc', 'endAtUtc', 'shiftedForDst']),
    issues,
    'event.occurrence',
  );
  const ok =
    isEntityId(slot.id) &&
    isLocalDate(slot.localDate) &&
    isInstant(slot.startAtUtc) &&
    isInstant(slot.endAtUtc) &&
    Date.parse(slot.startAtUtc) < Date.parse(slot.endAtUtc) &&
    (slot.shiftedForDst === undefined || typeof slot.shiftedForDst === 'boolean');
  if (!ok) issues.add('event.occurrence_invalid');
  return ok;
}

function parseSchedule(
  value: unknown,
  issues: IssueCollector,
):
  | (Schedule & {
      readonly allowsPartialAttendanceValue: boolean;
    })
  | undefined {
  if (!issues.require(isRecord(value), 'event.schedule_required')) return undefined;
  const raw = value as Json;
  hasOnlyKeys(
    raw,
    new Set([
      'timezoneId',
      'scheduleMode',
      'allDay',
      'localStartDate',
      'startMinute',
      'durationMinutes',
      'multiDateLocalDates',
      'recurrence',
      'allowsPartialAttendance',
      'minimumVisitDurationMinutes',
      'bufferBeforeMinutes',
      'bufferAfterMinutes',
    ]),
    issues,
    'event.schedule',
  );
  const zoneOk = issues.require(isIanaZone(raw.timezoneId), 'event.timezone_required');
  const modeOk = issues.require(
    isEnumValue(raw.scheduleMode, scheduleModes),
    'event.schedule_mode',
  );
  const durationOk = issues.require(
    isInt(raw.durationMinutes, 1, 525600),
    'event.duration_invalid',
  );
  const startOk = issues.require(isInt(raw.startMinute, 0, 1439), 'event.start_minute_invalid');
  const dateOk = issues.require(isLocalDate(raw.localStartDate), 'event.local_start_date_invalid');
  const allDayOk = issues.require(typeof raw.allDay === 'boolean', 'event.all_day');
  if (allDayOk && raw.allDay === true && durationOk)
    issues.require((raw.durationMinutes as number) % 1440 === 0, 'event.all_day_duration_invalid');

  for (const key of ['bufferBeforeMinutes', 'bufferAfterMinutes'] as const)
    issues.require(isInt(raw[key], 0, eventRuleConfig.maxBufferMinutes), `event.${key}`);
  const partial = raw.allowsPartialAttendance;
  issues.require(typeof partial === 'boolean', 'event.allows_partial_attendance');
  if (partial === true) {
    const minimum = raw.minimumVisitDurationMinutes;
    if (
      issues.require(isInt(minimum, 1, 525600), 'event.minimum_visit_duration_required') &&
      durationOk
    )
      issues.require(
        (minimum as number) <= (raw.durationMinutes as number),
        'event.minimum_visit_exceeds_duration',
      );
  } else
    issues.require(
      raw.minimumVisitDurationMinutes === undefined,
      'event.minimum_visit_not_cleared',
    );

  const dates = raw.multiDateLocalDates;
  let multiDates: string[] = [];
  if (raw.scheduleMode === 'multiDate') {
    const datesOk = issues.require(
      Array.isArray(dates) &&
        dates.length >= 1 &&
        dates.length <= eventRuleConfig.maxMultiDates &&
        dates.every(isLocalDate),
      'event.multi_dates_invalid',
    );
    if (datesOk) {
      multiDates = dates as string[];
      issues.require(new Set(multiDates).size === multiDates.length, 'event.multi_date_duplicate');
    }
  } else issues.require(dates === undefined, 'event.multi_dates_not_allowed');

  let recurrence: Recurrence | undefined;
  if (raw.scheduleMode === 'recurring')
    recurrence = parseRecurrence(raw.recurrence, raw.localStartDate, issues);
  else issues.require(raw.recurrence === undefined, 'event.recurrence_not_allowed');

  if (!zoneOk || !modeOk || !durationOk || !startOk || !dateOk || !allDayOk) return undefined;
  if (raw.scheduleMode === 'multiDate' && multiDates.length === 0) return undefined;
  if (raw.scheduleMode === 'recurring' && recurrence === undefined) return undefined;
  return {
    timezoneId: raw.timezoneId as string,
    scheduleMode: raw.scheduleMode as Schedule['scheduleMode'],
    allDay: raw.allDay as boolean,
    localStartDate: raw.localStartDate as string,
    startMinute: raw.startMinute as number,
    durationMinutes: raw.durationMinutes as number,
    multiDateLocalDates: multiDates,
    recurrence,
    allowsPartialAttendanceValue: partial === true,
  };
}

function parseRecurrence(
  value: unknown,
  localStartDate: unknown,
  issues: IssueCollector,
): Recurrence | undefined {
  if (!issues.require(isRecord(value), 'event.recurrence_invalid')) return undefined;
  const rule = value as Json;
  hasOnlyKeys(
    rule,
    new Set([
      'frequency',
      'interval',
      'weekdays',
      'monthlyDayPolicy',
      'endMode',
      'untilLocalDate',
      'occurrenceCount',
      'exceptionLocalDates',
      'dstGapPolicy',
      'dstOverlapPolicy',
    ]),
    issues,
    'event.recurrence',
  );
  const frequencyOk = issues.require(
    isEnumValue(rule.frequency, frequencies),
    'event.recurrence_frequency',
  );
  const intervalOk = issues.require(
    isInt(rule.interval, 1, eventRuleConfig.maxRecurrenceInterval),
    'event.recurrence_interval',
  );
  const endOk = issues.require(isEnumValue(rule.endMode, endModes), 'event.recurrence_end_mode');
  const gapOk = issues.require(isEnumValue(rule.dstGapPolicy, gapPolicies), 'event.dst_gap_policy');
  const overlapOk = issues.require(
    isEnumValue(rule.dstOverlapPolicy, overlapPolicies),
    'event.dst_overlap_policy',
  );

  let weekdays: number[] = [];
  if (rule.frequency === 'weekly') {
    const ok = issues.require(
      Array.isArray(rule.weekdays) &&
        rule.weekdays.length >= 1 &&
        rule.weekdays.length <= 7 &&
        rule.weekdays.every((day) => isInt(day, 1, 7)) &&
        new Set(rule.weekdays).size === rule.weekdays.length,
      'event.recurrence_weekdays',
    );
    if (ok) weekdays = rule.weekdays as number[];
  } else issues.require(rule.weekdays === undefined, 'event.recurrence_weekdays_not_allowed');

  let monthlyPolicy: (typeof monthlyPolicies)[number] = 'skipInvalidDate';
  if (rule.frequency === 'monthly') {
    if (
      issues.require(
        isEnumValue(rule.monthlyDayPolicy, monthlyPolicies),
        'event.monthly_day_policy',
      )
    )
      monthlyPolicy = rule.monthlyDayPolicy as (typeof monthlyPolicies)[number];
  } else issues.require(rule.monthlyDayPolicy === undefined, 'event.monthly_policy_not_allowed');

  let until: string | undefined;
  let count: number | undefined;
  if (rule.endMode === 'never')
    issues.require(
      rule.untilLocalDate === undefined && rule.occurrenceCount === undefined,
      'event.recurrence_end_fields',
    );
  else if (rule.endMode === 'untilDate') {
    issues.require(rule.occurrenceCount === undefined, 'event.recurrence_end_fields');
    if (issues.require(isLocalDate(rule.untilLocalDate), 'event.recurrence_until_invalid')) {
      until = rule.untilLocalDate as string;
      if (isLocalDate(localStartDate))
        issues.require(until >= localStartDate, 'event.recurrence_until_before_start');
    }
  } else if (rule.endMode === 'occurrenceCount') {
    issues.require(rule.untilLocalDate === undefined, 'event.recurrence_end_fields');
    if (
      issues.require(
        isInt(rule.occurrenceCount, 1, eventRuleConfig.maxOccurrenceCount),
        'event.recurrence_count_required',
      )
    )
      count = rule.occurrenceCount as number;
  }

  const exceptions = rule.exceptionLocalDates ?? [];
  let exceptionSet = new Set<string>();
  if (
    issues.require(
      Array.isArray(exceptions) &&
        exceptions.length <= eventRuleConfig.maxExceptionDates &&
        exceptions.every(isLocalDate),
      'event.recurrence_exception_invalid',
    )
  )
    exceptionSet = new Set(exceptions as string[]);

  if (!frequencyOk || !intervalOk || !endOk || !gapOk || !overlapOk) return undefined;
  return {
    frequency: rule.frequency as Recurrence['frequency'],
    interval: rule.interval as number,
    weekdays,
    monthlyDayPolicy: monthlyPolicy,
    endMode: rule.endMode as Recurrence['endMode'],
    untilLocalDate: until,
    occurrenceCount: count,
    exceptionLocalDates: exceptionSet,
    dstGapPolicy: rule.dstGapPolicy as Recurrence['dstGapPolicy'],
    dstOverlapPolicy: rule.dstOverlapPolicy as Recurrence['dstOverlapPolicy'],
  };
}

function dateMs(iso: string): number {
  return Date.parse(`${iso}T00:00:00.000Z`);
}

function isoOf(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/** ISO weekday 1..7 (Monday..Sunday) of a calendar date. */
function isoWeekday(ms: number): number {
  const day = new Date(ms).getUTCDay();
  return day === 0 ? 7 : day;
}

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function recurringDates(schedule: Schedule, rule: Recurrence, nowMs: number): readonly string[] {
  const anchorMs = dateMs(schedule.localStartDate);
  const anchor = new Date(anchorMs);
  const horizonMs = nowMs + 548 * dayMs;
  const untilMs =
    rule.endMode === 'untilDate' && rule.untilLocalDate ? dateMs(rule.untilLocalDate) : undefined;
  const target =
    rule.endMode === 'occurrenceCount'
      ? (rule.occurrenceCount ?? 0)
      : eventRuleConfig.maxRecurringProjection;
  const result: string[] = [];
  for (
    let cursor = anchorMs;
    result.length < target && cursor <= horizonMs && (untilMs === undefined || cursor <= untilMs);
    cursor += dayMs
  ) {
    if (!matches(anchor, anchorMs, cursor, rule)) continue;
    const iso = isoOf(cursor);
    if (!rule.exceptionLocalDates.has(iso)) result.push(iso);
  }
  return result;
}

function matches(anchor: Date, anchorMs: number, cursor: number, rule: Recurrence): boolean {
  const days = Math.round((cursor - anchorMs) / dayMs);
  if (days < 0) return false;
  const date = new Date(cursor);
  switch (rule.frequency) {
    case 'daily':
      return days % rule.interval === 0;
    case 'weekly':
      // Weeks are counted from the anchor date, exactly like the client.
      return (
        Math.floor(days / 7) % rule.interval === 0 && rule.weekdays.includes(isoWeekday(cursor))
      );
    case 'monthly': {
      const monthDelta =
        (date.getUTCFullYear() - anchor.getUTCFullYear()) * 12 +
        date.getUTCMonth() -
        anchor.getUTCMonth();
      if (monthDelta < 0 || monthDelta % rule.interval !== 0) return false;
      const last = daysInMonth(date.getUTCFullYear(), date.getUTCMonth() + 1);
      if (date.getUTCDate() === anchor.getUTCDate()) return true;
      return (
        rule.monthlyDayPolicy === 'useLastDay' &&
        anchor.getUTCDate() > last &&
        date.getUTCDate() === last
      );
    }
    case 'yearly':
      return (
        (date.getUTCFullYear() - anchor.getUTCFullYear()) % rule.interval === 0 &&
        date.getUTCMonth() === anchor.getUTCMonth() &&
        date.getUTCDate() === anchor.getUTCDate()
      );
  }
}

function expandSchedule(
  schedule: Schedule,
  nowMs: number,
  issues: IssueCollector,
): readonly ExpectedSlot[] | undefined {
  const dates =
    schedule.scheduleMode === 'oneTime'
      ? [schedule.localStartDate]
      : schedule.scheduleMode === 'multiDate'
        ? [...schedule.multiDateLocalDates].sort()
        : recurringDates(schedule, schedule.recurrence as Recurrence, nowMs);
  const rule = schedule.recurrence;
  const gap = rule?.dstGapPolicy ?? 'shiftForward';
  const overlap = rule?.dstOverlapPolicy ?? 'earlierOffset';
  const slots: ExpectedSlot[] = [];
  for (const localDate of dates) {
    if (rule?.exceptionLocalDates.has(localDate) === true) continue;
    const start = resolveLocalTime(
      schedule.timezoneId,
      localDate,
      schedule.allDay ? 0 : schedule.startMinute,
      gap,
      overlap,
    );
    if (start === 'gap_rejected') {
      issues.add('event.dst_gap_rejected');
      return undefined;
    }
    let endMs: number;
    if (schedule.allDay) {
      const endDate = isoOf(dateMs(localDate) + (schedule.durationMinutes / 1440) * dayMs);
      const end = resolveLocalTime(schedule.timezoneId, endDate, 0, gap, overlap);
      if (end === 'gap_rejected') {
        issues.add('event.dst_gap_rejected');
        return undefined;
      }
      endMs = end.utcMs;
    } else endMs = start.utcMs + schedule.durationMinutes * 60000;
    slots.push({ localDate, startMs: start.utcMs, endMs });
  }
  slots.sort((left, right) => left.startMs - right.startMs);
  if (slots.length === 0) {
    issues.add('event.occurrences_required');
    return undefined;
  }
  return slots;
}

// --- Time zones -------------------------------------------------------------

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (formatter === undefined) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

/** Offset of the zone from UTC in minutes at a given instant. */
function offsetMinutesAt(timeZone: string, utcMs: number): number {
  const fields: Record<string, number> = {};
  for (const part of formatterFor(timeZone).formatToParts(new Date(utcMs)))
    if (part.type !== 'literal') fields[part.type] = Number(part.value);
  const local = Date.UTC(
    fields.year ?? 1970,
    (fields.month ?? 1) - 1,
    fields.day ?? 1,
    (fields.hour ?? 0) % 24,
    fields.minute ?? 0,
    fields.second ?? 0,
  );
  return Math.round((local - utcMs) / 60000);
}

/**
 * Resolves a wall-clock time to a UTC instant with explicit DST policies:
 * a skipped time (gap) is shifted forward or rejected, an ambiguous time
 * (overlap) takes the earlier or later offset.
 */
export function resolveLocalTime(
  timeZone: string,
  localDate: string,
  minuteOfDay: number,
  gapPolicy: 'shiftForward' | 'reject',
  overlapPolicy: 'earlierOffset' | 'laterOffset',
): { readonly utcMs: number; readonly shifted: boolean } | 'gap_rejected' {
  const wall = dateMs(localDate) + minuteOfDay * 60000;
  const before = offsetMinutesAt(timeZone, wall - dayMs);
  const after = offsetMinutesAt(timeZone, wall + dayMs);
  const valid = [...new Set([before, after])]
    .map((offset) => ({ offset, utcMs: wall - offset * 60000 }))
    .filter((candidate) => offsetMinutesAt(timeZone, candidate.utcMs) === candidate.offset)
    .sort((left, right) => left.utcMs - right.utcMs);
  if (valid.length === 0) {
    if (gapPolicy === 'reject') return 'gap_rejected';
    // The wall time does not exist: keep the pre-transition offset so the
    // instant lands after the gap (the clock moves forward).
    return { utcMs: wall - before * 60000, shifted: true };
  }
  const chosen = overlapPolicy === 'earlierOffset' ? valid[0] : valid[valid.length - 1];
  return { utcMs: (chosen ?? valid[0])?.utcMs ?? wall, shifted: false };
}
