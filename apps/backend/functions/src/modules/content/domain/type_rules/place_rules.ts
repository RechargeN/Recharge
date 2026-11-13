import type { ContentBody } from '../../../../contracts/content_v1.js';
import {
  IssueCollector,
  containsContactLike,
  hasOnlyKeys,
  hasUnreplacedLocalId,
  intervalsOverlap,
  isAllCaps,
  isCountryCode,
  isEmail,
  isEnumValue,
  isIanaZone,
  isInt,
  isLocalDate,
  isMinorUnits,
  isLocalMinute,
  isNumberIn,
  isOpeningPeriod,
  isPhone,
  isRecord,
  isSafeHttpsUrl,
  isStringList,
  isText,
  weeklyIntervals,
  type ContentRuleIssues,
  type OpeningPeriod,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';

/**
 * Place source rules (PLACE_CREATE_BLOCK_SPEC v1.0, Approved): the public Place
 * model of §9.2 without the server-owned lifecycle/moderation/revision axes.
 * Blocking errors follow §10.2; warnings (§10.3) are not rule failures.
 */
const placeKinds = ['managedVenue', 'publicSpace', 'pointOfInterest'] as const;
const relationships = ['owner', 'staff', 'visitor', 'curator'] as const;
const accuracies = ['rooftop', 'interpolated', 'approximate', 'manual'] as const;
// `seasonal` is Phase 2 in the spec and is rejected explicitly until enabled.
const supportedHoursModes = ['regular', 'alwaysOpen', 'unknown'] as const;
const entryTypes = ['free', 'paid', 'mixed', 'notApplicable', 'unknown'] as const;
const operationalStatuses = ['operating', 'temporarilyClosed', 'permanentlyClosed'] as const;
const sourceTypes: Readonly<Record<(typeof relationships)[number], string>> = {
  owner: 'ownerSubmission',
  staff: 'staffSubmission',
  visitor: 'creatorSubmission',
  curator: 'creatorSubmission',
};

const topLevelKeys = new Set([
  'title',
  'placeKind',
  'relationshipToPlace',
  'shortDescription',
  'fullDescription',
  'contentLocale',
  'languages',
  'categoryId',
  'subcategoryId',
  'tags',
  'criteria',
  'location',
  'hours',
  'operationalStatus',
  'visitPlanning',
  'amenityIds',
  'amenityUnknownIds',
  'pricing',
  'contacts',
  'media',
  'provenance',
]);

export function validatePlaceBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  hasOnlyKeys(body, topLevelKeys, issues, 'place');
  validateIdentity(body, issues, context);
  validateCategory(body, issues, context);
  validateLocation(body.location, issues, context);
  validateHours(body.hours, issues);
  validateOperationalStatus(body.operationalStatus, issues);
  validateVisitPlanning(body.visitPlanning, issues);
  validateAmenities(body, issues);
  validatePricing(body.pricing, issues, context);
  validateContacts(body.contacts, issues);
  validateMedia(body.media, issues);
  validateProvenance(body, issues, context);
  issues.require(!hasUnreplacedLocalId(body), 'place.local_id_unreplaced');
  return issues.result();
}

/** Cover then gallery media ids, the exact set Media readiness must confirm. */
export function placeMediaIds(body: ContentBody): readonly string[] {
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

function validateIdentity(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (issues.require(isText(body.title, 2, 100), 'place.title')) {
    const title = body.title as string;
    issues.require(!containsContactLike(title), 'place.title.contact_like');
    issues.require(!isAllCaps(title), 'place.title.all_caps');
  }
  issues.require(isEnumValue(body.placeKind, placeKinds), 'place.placeKind');
  issues.require(isEnumValue(body.relationshipToPlace, relationships), 'place.relationshipToPlace');
  issues.require(isText(body.shortDescription, 20, 180), 'place.shortDescription');
  if (body.fullDescription !== undefined)
    issues.require(isText(body.fullDescription, 50, 5000), 'place.fullDescription');

  if (typeof body.contentLocale !== 'string' || body.contentLocale.length === 0)
    issues.add('place.contentLocale');
  else {
    const supported = context.lookups.supportsLocale(body.contentLocale);
    if (supported === undefined) issues.add('place.contentLocale.registry_unavailable');
    else issues.require(supported, 'place.contentLocale.unsupported');
  }
  if (body.languages !== undefined) {
    if (!issues.require(isStringList(body.languages, 10, 35), 'place.languages')) return;
    for (const language of body.languages as string[]) {
      if (language === 'other') continue;
      const supported = context.lookups.supportsLocale(language);
      if (supported === undefined) issues.add('place.languages.registry_unavailable');
      else issues.require(supported, 'place.languages.unsupported');
    }
  }
}

function validateCategory(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  const categoryOk = issues.require(isText(body.categoryId, 1, 64), 'place.categoryId');
  const subcategoryOk = issues.require(isText(body.subcategoryId, 1, 64), 'place.subcategoryId');
  if (body.tags !== undefined) issues.require(isStringList(body.tags, 20, 40), 'place.tags');
  if (!categoryOk || !subcategoryOk) return;
  const categoryId = body.categoryId as string;
  const subcategoryId = body.subcategoryId as string;
  // Category is chosen by the Creator; it is never inferred from the title.
  const applies = context.lookups.subcategoryApplies('place', categoryId, subcategoryId);
  if (applies === undefined) issues.add('place.taxonomy_unavailable');
  else issues.require(applies, 'place.subcategory.not_applicable');
  const required = context.lookups.requiredCriteria('place', categoryId, subcategoryId);
  if (required === undefined) {
    issues.add('place.criteria.registry_unavailable');
    return;
  }
  const criteria = body.criteria;
  if (criteria !== undefined && !isRecord(criteria)) {
    issues.add('place.criteria');
    return;
  }
  for (const fieldId of required) {
    const value = criteria?.[fieldId];
    if (value === undefined || value === null || value === '')
      issues.add(`place.criteria.required_missing:${fieldId}`);
  }
}

function validateLocation(
  value: unknown,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(isRecord(value), 'place.location')) return;
  const location = value as Json;
  hasOnlyKeys(
    location,
    new Set([
      'marketCityId',
      'countryCode',
      'city',
      'district',
      'formattedAddress',
      'addressComponents',
      'point',
      'locationLabel',
      'entranceHint',
      'timezoneId',
      'accuracy',
      'pinConfirmed',
      'geocodedAtUtc',
    ]),
    issues,
    'place.location',
  );
  issues.require(isText(location.marketCityId, 1, 64), 'place.location.marketCityId');
  issues.require(isCountryCode(location.countryCode), 'place.location.countryCode');
  issues.require(isText(location.city, 1, 100), 'place.location.city');
  if (location.district !== undefined)
    issues.require(isText(location.district, 1, 100), 'place.location.district');
  const hasAddress = isText(location.formattedAddress, 1, 300);
  const hasLabel = isText(location.locationLabel, 1, 200);
  if (location.formattedAddress !== undefined && !hasAddress)
    issues.add('place.location.formattedAddress');
  if (location.locationLabel !== undefined && !hasLabel) issues.add('place.location.locationLabel');
  issues.require(hasAddress || hasLabel, 'place.location.address_or_label_missing');
  if (location.addressComponents !== undefined)
    issues.require(isRecord(location.addressComponents), 'place.location.addressComponents');
  if (location.entranceHint !== undefined) {
    if (issues.require(isText(location.entranceHint, 1, 300), 'place.location.entranceHint'))
      issues.require(
        !containsContactLike(location.entranceHint as string),
        'place.location.entranceHint.sensitive',
      );
  }
  issues.require(isIanaZone(location.timezoneId), 'place.location.timezoneId');
  issues.require(isEnumValue(location.accuracy, accuracies), 'place.location.accuracy');
  issues.require(location.pinConfirmed === true, 'place.location.pin_unconfirmed');
  if (location.geocodedAtUtc !== undefined)
    issues.require(
      typeof location.geocodedAtUtc === 'string' &&
        Number.isFinite(Date.parse(location.geocodedAtUtc)),
      'place.location.geocodedAtUtc',
    );
  const point = location.point;
  if (
    !issues.require(
      isRecord(point) &&
        isNumberIn(point.latitude, -90, 90) &&
        isNumberIn(point.longitude, -180, 180),
      'place.location.point',
    )
  )
    return;
  const { latitude, longitude } = point as { latitude: number; longitude: number };
  const inside = context.lookups.pointInServiceArea(latitude, longitude);
  if (inside === undefined) issues.add('place.location.service_area_unavailable');
  else issues.require(inside, 'place.location.outside_service_area');
}

type Period = OpeningPeriod;

const periodShapeOk = isOpeningPeriod;

function validateHours(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'place.hours')) return;
  const hours = value as Json;
  hasOnlyKeys(
    hours,
    new Set(['mode', 'weeklyPeriods', 'seasons', 'exceptions']),
    issues,
    'place.hours',
  );
  const weekly = hours.weeklyPeriods ?? [];
  const seasons = hours.seasons ?? [];
  const exceptions = hours.exceptions ?? [];
  if (
    !issues.require(
      Array.isArray(weekly) && Array.isArray(seasons) && Array.isArray(exceptions),
      'place.hours.shape',
    )
  )
    return;
  const mode = hours.mode;
  if (mode === 'seasonal') issues.add('place.hours.mode_unsupported:seasonal');
  else if (!issues.require(isEnumValue(mode, supportedHoursModes), 'place.hours.mode')) return;
  const weeklyList = weekly as unknown[];
  const exceptionList = exceptions as unknown[];
  if ((seasons as unknown[]).length > 0 && mode !== 'seasonal')
    issues.add('place.hours.seasons_unsupported');
  if (mode === 'regular') {
    issues.require(weeklyList.length > 0, 'place.hours.weekly_required');
    if (weeklyList.length > 28) issues.add('place.hours.too_many_periods');
    const valid = weeklyList.every((item) => periodShapeOk(item, true));
    if (!issues.require(valid, 'place.hours.period_invalid')) return;
    issues.require(
      !intervalsOverlap(weeklyIntervals(weeklyList as Period[])),
      'place.hours.period_overlap',
    );
  } else if (mode === 'alwaysOpen') {
    issues.require(weeklyList.length === 0, 'place.hours.always_open_has_periods');
  } else if (mode === 'unknown') {
    issues.require(
      weeklyList.length === 0 && exceptionList.length === 0,
      'place.hours.unknown_has_data',
    );
  }
  validateExceptions(exceptionList, issues);
}

function validateExceptions(exceptions: readonly unknown[], issues: IssueCollector): void {
  if (exceptions.length > 366) issues.add('place.hours.too_many_exceptions');
  const dates = new Set<string>();
  for (const item of exceptions) {
    if (!isRecord(item) || typeof item.id !== 'string' || !isLocalDate(item.localDate)) {
      issues.add('place.hours.exception_invalid');
      continue;
    }
    if (dates.has(item.localDate)) issues.add('place.hours.exception_duplicate');
    dates.add(item.localDate);
    if (item.publicNote !== undefined && !isText(item.publicNote, 1, 200))
      issues.add('place.hours.exception_note');
    const periods = item.periods ?? [];
    if (!Array.isArray(periods)) {
      issues.add('place.hours.exception_invalid');
    } else if (item.kind === 'closedAllDay') {
      if (periods.length > 0) issues.add('place.hours.exception_closed_has_periods');
    } else if (item.kind === 'customHours') {
      if (periods.length === 0 || !periods.every((entry) => periodShapeOk(entry, false)))
        issues.add('place.hours.exception_periods');
      else {
        const asWeek = (periods as Omit<Period, 'dayOfWeek'>[]).map((entry) => ({
          ...entry,
          dayOfWeek: 1,
        }));
        if (intervalsOverlap(weeklyIntervals(asWeek))) issues.add('place.hours.exception_overlap');
      }
    } else issues.add('place.hours.exception_kind');
  }
}

function validateOperationalStatus(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'place.operationalStatus')) return;
  const status = value as Json;
  hasOnlyKeys(
    status,
    new Set(['status', 'startLocalDate', 'endLocalDate', 'publicNote']),
    issues,
    'place.operationalStatus',
  );
  if (
    !issues.require(
      isEnumValue(status.status, operationalStatuses),
      'place.operationalStatus.status',
    )
  )
    return;
  if (status.publicNote !== undefined)
    issues.require(isText(status.publicNote, 1, 200), 'place.operationalStatus.publicNote');
  const start = status.startLocalDate;
  const end = status.endLocalDate;
  if (status.status === 'temporarilyClosed') {
    if (!issues.require(isLocalDate(start), 'place.operationalStatus.start_required')) return;
    if (end !== undefined)
      issues.require(isLocalDate(end) && end >= (start as string), 'place.operationalStatus.end');
  } else {
    issues.require(
      start === undefined && end === undefined,
      'place.operationalStatus.dates_not_allowed',
    );
  }
}

function validateVisitPlanning(value: unknown, issues: IssueCollector): void {
  if (value === undefined) return;
  if (!issues.require(isRecord(value), 'place.visitPlanning')) return;
  const plan = value as Json;
  hasOnlyKeys(
    plan,
    new Set([
      'recommendedVisitMinutes',
      'minimumVisitMinutes',
      'allowsShortVisit',
      'bestTimeWindows',
      'busyTimeNotes',
      'weatherDependent',
      'arrivalBufferMinutes',
      'exitBufferMinutes',
    ]),
    issues,
    'place.visitPlanning',
  );
  const recommended = plan.recommendedVisitMinutes;
  if (recommended !== undefined)
    issues.require(isInt(recommended, 10, 1440), 'place.visitPlanning.recommendedVisitMinutes');
  const minimum = plan.minimumVisitMinutes;
  if (minimum !== undefined) {
    const ok = isInt(minimum, 1, 1440);
    issues.require(ok, 'place.visitPlanning.minimumVisitMinutes');
    if (ok && typeof recommended === 'number' && minimum > recommended)
      issues.add('place.visitPlanning.minimum_exceeds_recommended');
  }
  if (plan.allowsShortVisit !== undefined) {
    if (
      issues.require(
        typeof plan.allowsShortVisit === 'boolean',
        'place.visitPlanning.allowsShortVisit',
      )
    )
      if (plan.allowsShortVisit === true && minimum === undefined)
        issues.add('place.visitPlanning.short_visit_needs_minimum');
  }
  if (plan.weatherDependent !== undefined)
    issues.require(
      typeof plan.weatherDependent === 'boolean',
      'place.visitPlanning.weatherDependent',
    );
  if (plan.busyTimeNotes !== undefined)
    issues.require(isText(plan.busyTimeNotes, 1, 300), 'place.visitPlanning.busyTimeNotes');
  for (const key of ['arrivalBufferMinutes', 'exitBufferMinutes'] as const)
    if (plan[key] !== undefined)
      issues.require(isInt(plan[key], 0, 120), `place.visitPlanning.${key}`);
  if (plan.bestTimeWindows !== undefined) {
    const windows = plan.bestTimeWindows;
    const ok =
      Array.isArray(windows) &&
      windows.length <= 14 &&
      windows.every(
        (item) =>
          isRecord(item) &&
          isInt(item.dayOfWeek, 1, 7) &&
          isLocalMinute(item.startMinute) &&
          isLocalMinute(item.endMinute) &&
          item.endMinute > item.startMinute &&
          isText(item.reason, 1, 120),
      );
    issues.require(ok, 'place.visitPlanning.bestTimeWindows');
  }
}

function validateAmenities(body: ContentBody, issues: IssueCollector): void {
  const known = body.amenityIds ?? [];
  const unknown = body.amenityUnknownIds ?? [];
  const okKnown = isStringList(known, 100, 64);
  const okUnknown = isStringList(unknown, 100, 64);
  issues.require(okKnown, 'place.amenityIds');
  issues.require(okUnknown, 'place.amenityUnknownIds');
  if (okKnown && okUnknown) {
    const knownSet = new Set(known);
    // A tri-state amenity cannot be both confirmed and "don't know".
    if (unknown.some((id) => knownSet.has(id))) issues.add('place.amenities.conflict');
    if (knownSet.size !== known.length) issues.add('place.amenityIds.duplicate');
  }
}

function validatePricing(
  value: unknown,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(isRecord(value), 'place.pricing')) return;
  const pricing = value as Json;
  hasOnlyKeys(
    pricing,
    new Set([
      'entryType',
      'entryPriceFrom',
      'entryPriceTo',
      'typicalSpendFrom',
      'typicalSpendTo',
      'currencyCode',
      'pricingNote',
      'officialPricingUrl',
      'pricingConfirmedAtUtc',
    ]),
    issues,
    'place.pricing',
  );
  if (!issues.require(isEnumValue(pricing.entryType, entryTypes), 'place.pricing.entryType'))
    return;
  issues.require(
    pricing.currencyCode === context.market.currencyCode,
    'place.pricing.currencyCode',
  );
  const amounts = ['entryPriceFrom', 'entryPriceTo', 'typicalSpendFrom', 'typicalSpendTo'] as const;
  for (const key of amounts)
    if (pricing[key] !== undefined)
      issues.require(isMinorUnits(pricing[key]), `place.pricing.${key}`);
  const range = (from: unknown, to: unknown, code: string): void => {
    if (isMinorUnits(from) && isMinorUnits(to) && from > to) issues.add(code);
  };
  range(pricing.entryPriceFrom, pricing.entryPriceTo, 'place.pricing.entry_range');
  range(pricing.typicalSpendFrom, pricing.typicalSpendTo, 'place.pricing.spend_range');
  const type = pricing.entryType;
  if (type === 'paid' || type === 'mixed')
    issues.require(isMinorUnits(pricing.entryPriceFrom), 'place.pricing.entryPriceFrom_required');
  else
    issues.require(
      pricing.entryPriceFrom === undefined && pricing.entryPriceTo === undefined,
      'place.pricing.entry_prices_not_cleared',
    );
  if (pricing.pricingNote !== undefined)
    issues.require(isText(pricing.pricingNote, 1, 300), 'place.pricing.pricingNote');
  if (type === 'mixed')
    issues.require(isText(pricing.pricingNote, 1, 300), 'place.pricing.note_required');
  if (pricing.officialPricingUrl !== undefined)
    issues.require(isSafeHttpsUrl(pricing.officialPricingUrl), 'place.pricing.officialPricingUrl');
}

function validateContacts(value: unknown, issues: IssueCollector): void {
  if (value === undefined) return;
  if (!issues.require(isRecord(value), 'place.contacts')) return;
  const contacts = value as Json;
  hasOnlyKeys(
    contacts,
    new Set(['website', 'phone', 'email', 'bookingUrl', 'socialUrls', 'contactsConfirmedAtUtc']),
    issues,
    'place.contacts',
  );
  if (contacts.website !== undefined)
    issues.require(isSafeHttpsUrl(contacts.website), 'place.contacts.website');
  if (contacts.bookingUrl !== undefined)
    issues.require(isSafeHttpsUrl(contacts.bookingUrl), 'place.contacts.bookingUrl');
  if (contacts.phone !== undefined) issues.require(isPhone(contacts.phone), 'place.contacts.phone');
  if (contacts.email !== undefined) issues.require(isEmail(contacts.email), 'place.contacts.email');
  if (contacts.socialUrls !== undefined) {
    const list = contacts.socialUrls;
    issues.require(
      Array.isArray(list) && list.length <= 10 && list.every((item) => isSafeHttpsUrl(item)),
      'place.contacts.socialUrls',
    );
  }
}

function validateMedia(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'place.media')) return;
  const media = value as Json;
  hasOnlyKeys(media, new Set(['coverImage', 'gallery']), issues, 'place.media');
  const cover = media.coverImage;
  const mediaRef = (item: unknown): boolean =>
    isRecord(item) &&
    isText(item.mediaId, 1, 128) &&
    (item.altText === undefined || isText(item.altText, 1, 200)) &&
    (item.attribution === undefined || isText(item.attribution, 1, 200));
  issues.require(mediaRef(cover), 'place.media.cover_missing');
  const gallery = media.gallery ?? [];
  if (!issues.require(Array.isArray(gallery), 'place.media.gallery')) return;
  const items = gallery as unknown[];
  issues.require(items.length <= 12, 'place.media.gallery_too_large');
  issues.require(items.every(mediaRef), 'place.media.gallery_item');
  const ids = placeMediaIdsFrom(cover, items);
  issues.require(new Set(ids).size === ids.length, 'place.media.duplicate');
}

function placeMediaIdsFrom(cover: unknown, gallery: readonly unknown[]): string[] {
  const ids: string[] = [];
  if (isRecord(cover) && typeof cover.mediaId === 'string') ids.push(cover.mediaId);
  for (const item of gallery)
    if (isRecord(item) && typeof item.mediaId === 'string') ids.push(item.mediaId);
  return ids;
}

function validateProvenance(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  const value = body.provenance;
  if (!issues.require(isRecord(value), 'place.provenance')) return;
  const provenance = value as Json;
  hasOnlyKeys(
    provenance,
    new Set([
      'sourceType',
      'submittedByUserId',
      'relationshipClaim',
      'createdAtUtc',
      'lastConfirmedAtUtc',
      'hoursConfirmedAtUtc',
      'pricingConfirmedAtUtc',
      'contactsConfirmedAtUtc',
    ]),
    issues,
    'place.provenance',
  );
  // The author is proven by the authenticated actor, never by client claim.
  issues.require(
    provenance.submittedByUserId === context.createdByUserId,
    'place.provenance.submittedBy',
  );
  const relationship = body.relationshipToPlace;
  if (isEnumValue(relationship, relationships)) {
    issues.require(
      provenance.relationshipClaim === relationship,
      'place.provenance.relationshipClaim',
    );
    issues.require(
      provenance.sourceType === sourceTypes[relationship],
      'place.provenance.sourceType',
    );
  }
  for (const key of [
    'createdAtUtc',
    'lastConfirmedAtUtc',
    'hoursConfirmedAtUtc',
    'pricingConfirmedAtUtc',
    'contactsConfirmedAtUtc',
  ] as const) {
    const at = provenance[key];
    if (key === 'createdAtUtc' || key === 'lastConfirmedAtUtc' || at !== undefined)
      issues.require(
        typeof at === 'string' && Number.isFinite(Date.parse(at)),
        `place.provenance.${key}`,
      );
  }
}
