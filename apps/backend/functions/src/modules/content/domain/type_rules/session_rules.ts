import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import {
  IssueCollector,
  hasOnlyKeys,
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
} from './validation_context.js';

/** Session v1.2 / D3.5: validate rules, never expand slots or imply availability. */
export function validateSessionBody(
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
      'session',
    ]),
    issues,
    'session',
  );
  issues.require(context.marketId === 'LV', 'session.market');
  issues.require(
    context.publisherRef.type === 'user' && context.publisherRef.id === context.createdByUserId,
    'session_publisher_ineligible',
  );
  issues.require(isText(body.title, 5, 80), 'session.title');
  issues.require(isText(body.shortDescription, 20, 180), 'session.shortDescription');
  issues.require(isText(body.fullDescription, 50, 2000), 'session.fullDescription');
  const locale =
    typeof body.contentLocale === 'string'
      ? context.lookups.supportsLocale(body.contentLocale)
      : false;
  issues.require(
    locale === true,
    locale === undefined ? 'session.locale_unavailable' : 'session.locale',
  );
  const applies =
    typeof body.categoryId === 'string' && typeof body.subcategoryId === 'string'
      ? context.lookups.subcategoryApplies('session', body.categoryId, body.subcategoryId)
      : false;
  issues.require(
    applies === true,
    applies === undefined ? 'session.taxonomy_unavailable' : 'session_category_not_allowed',
  );
  if (body.criteria !== undefined) issues.require(isRecord(body.criteria), 'session.criteria');
  if (body.tags !== undefined)
    issues.require(
      isStringList(body.tags, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER),
      'session.tags',
    );
  const loc = body.location;
  if (isRecord(loc)) {
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
      'session.location',
    );
    issues.require(
      loc.countryCode === 'LV' &&
        isText(loc.city, 1, Number.MAX_SAFE_INTEGER) &&
        isText(loc.venueName, 1, Number.MAX_SAFE_INTEGER) &&
        isText(loc.addressLine1, 1, Number.MAX_SAFE_INTEGER) &&
        loc.pinConfirmed === true,
      'session_resource_missing',
    );
    if (isNumberIn(loc.latitude, -90, 90) && isNumberIn(loc.longitude, -180, 180)) {
      const inside = context.lookups.pointInServiceArea(loc.latitude, loc.longitude);
      issues.require(
        inside === true,
        inside === undefined
          ? 'session.service_area_unavailable'
          : 'session.location_outside_market',
      );
    } else issues.add('session_resource_missing');
  } else issues.add('session_resource_missing');
  const media = body.media;
  if (isRecord(media)) {
    hasOnlyKeys(
      media,
      new Set(['coverImage', 'gallery', 'rightsConfirmed']),
      issues,
      'session.media',
    );
    issues.require(media.rightsConfirmed === true, 'session_media_incomplete');
    const images = [
      media.coverImage,
      ...(Array.isArray(media.gallery) ? (media.gallery as unknown[]) : []),
    ];
    issues.require(
      isRecord(media.coverImage) && Array.isArray(media.gallery),
      'session_media_incomplete',
    );
    const ids = new Set<string>();
    for (const image of images) {
      if (!isRecord(image)) {
        issues.add('session_media_incomplete');
        continue;
      }
      hasOnlyKeys(image, new Set(['mediaId', 'altText']), issues, 'session.media.image');
      issues.require(isEntityId(image.mediaId), 'session_media_incomplete');
      const alt = image.altText;
      if (
        !isRecord(alt) ||
        typeof body.contentLocale !== 'string' ||
        !isText(alt[body.contentLocale], 1, Number.MAX_SAFE_INTEGER)
      )
        issues.add('session_media_incomplete');
      else
        for (const [language, text] of Object.entries(alt)) {
          issues.require(
            context.lookups.supportsLocale(language) === true &&
              isText(text, 1, Number.MAX_SAFE_INTEGER),
            'session_media_incomplete',
          );
        }
      if (typeof image.mediaId === 'string') {
        issues.require(!ids.has(image.mediaId), 'session.media_duplicate');
        ids.add(image.mediaId);
      }
    }
  } else issues.add('session_media_incomplete');
  const data = body.session;
  if (!isRecord(data)) {
    issues.add('session.payload');
    return issues.result();
  }
  hasOnlyKeys(
    data,
    new Set([
      'schema_version',
      'resource_name',
      'timezone_id',
      'timezone_confirmed',
      'amenity_ids',
      'max_party_size',
      'schedule',
      'exceptions',
      'price',
      'external_booking_url',
      'external_terms_url',
      'revision',
    ]),
    issues,
    'session.payload',
  );
  issues.require(
    data.schema_version === 1 && isInt(data.revision, 0, Number.MAX_SAFE_INTEGER),
    'session.schema',
  );
  issues.require(
    isText(data.resource_name, 1, Number.MAX_SAFE_INTEGER),
    'session_resource_missing',
  );
  issues.require(
    isIanaZone(data.timezone_id) && data.timezone_confirmed === true,
    'session_timezone_invalid',
  );
  issues.require(
    isStringList(data.amenity_ids, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER),
    'session.amenities',
  );
  issues.require(isInt(data.max_party_size, 1, 20), 'session_party_size_out_of_range');
  issues.require(isSafeHttpsUrl(data.external_booking_url), 'session_booking_url_invalid');
  if (data.external_terms_url !== undefined)
    issues.require(isSafeHttpsUrl(data.external_terms_url), 'session.terms_url');
  const price = data.price;
  if (isRecord(price)) {
    hasOnlyKeys(price, new Set(['mode', 'amount_minor', 'currency_code']), issues, 'session.price');
    issues.require(price.mode === 'free' || price.mode === 'fixed', 'session_price_invalid');
    if (price.mode === 'fixed')
      issues.require(
        isInt(price.amount_minor, 1, Number.MAX_SAFE_INTEGER) &&
          price.currency_code === context.market.currencyCode,
        'session_price_invalid',
      );
    else
      issues.require(
        price.amount_minor === undefined && price.currency_code === undefined,
        'session_price_invalid',
      );
  } else issues.add('session_price_invalid');
  const schedule = data.schedule;
  if (isRecord(schedule)) {
    hasOnlyKeys(
      schedule,
      new Set([
        'schedule_revision',
        'dst_policy_version',
        'slot_duration_minutes',
        'buffer_after_slot_minutes',
        'min_notice_minutes',
        'projection_window_days',
        'weekly_rules',
      ]),
      issues,
      'session.schedule',
    );
    issues.require(
      isInt(schedule.schedule_revision, 1, Number.MAX_SAFE_INTEGER),
      'session.schedule_revision',
    );
    issues.require(schedule.dst_policy_version === 1, 'session.dst_policy');
    issues.require(isInt(schedule.slot_duration_minutes, 30, 180), 'session_duration_out_of_range');
    issues.require(
      isInt(schedule.buffer_after_slot_minutes, 0, 180),
      'session_buffer_out_of_range',
    );
    issues.require(isInt(schedule.min_notice_minutes, 0, 10080), 'session_notice_out_of_range');
    const window = context.lookups.sessionProjectionWindowDays?.();
    issues.require(window !== undefined && isInt(window, 1, 90), 'session.policy_unavailable');
    issues.require(
      window !== undefined && schedule.projection_window_days === window,
      'session.projection_policy_mismatch',
    );
    const rules = schedule.weekly_rules;
    if (!Array.isArray(rules) || rules.length === 0 || rules.length > 28)
      issues.add('session_schedule_empty');
    else {
      const sorted: { day: number; start: number; end: number }[] = [];
      const ids = new Set<string>();
      const counts = new Map<number, number>();
      for (const rule of rules) {
        if (!isRecord(rule)) {
          issues.add('session_range_invalid');
          continue;
        }
        hasOnlyKeys(
          rule,
          new Set(['id', 'iso_weekday', 'start_minute_local', 'end_minute_local_exclusive']),
          issues,
          'session.rule',
        );
        issues.require(isEntityId(rule.id) && !ids.has(String(rule.id)), 'session.rule_id');
        ids.add(String(rule.id));
        issues.require(isInt(rule.iso_weekday, 1, 7), 'session_weekday_invalid');
        const valid =
          isInt(rule.start_minute_local, 0, 1439) &&
          isInt(rule.end_minute_local_exclusive, 1, 1440) &&
          rule.start_minute_local < rule.end_minute_local_exclusive;
        issues.require(valid, 'session_range_invalid');
        if (valid && isInt(rule.iso_weekday, 1, 7)) {
          const count = (counts.get(rule.iso_weekday) ?? 0) + 1;
          counts.set(rule.iso_weekday, count);
          issues.require(count <= 4, 'session.too_many_ranges');
          sorted.push({
            day: rule.iso_weekday,
            start: rule.start_minute_local as number,
            end: rule.end_minute_local_exclusive as number,
          });
        }
      }
      sorted.sort((a, b) => a.day - b.day || a.start - b.start);
      for (let i = 1; i < sorted.length; i++) {
        const a = sorted[i - 1]!;
        const b = sorted[i]!;
        issues.require(a.day !== b.day || a.end <= b.start, 'session_range_overlap');
      }
    }
  } else issues.add('session_schedule_empty');
  const exceptions = data.exceptions;
  if (!Array.isArray(exceptions)) issues.add('session_exception_invalid');
  else {
    if (isIanaZone(data.timezone_id)) {
      const today = new Intl.DateTimeFormat('en-CA', {
        timeZone: data.timezone_id,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(new Date(context.nowUtc));
      const active = exceptions.filter(
        (ex) => isRecord(ex) && isLocalDate(ex.end_date_local) && ex.end_date_local >= today,
      );
      issues.require(active.length <= 366, 'session_exception_invalid');
    }
    const ids = new Set<string>();
    for (const ex of exceptions) {
      if (!isRecord(ex)) {
        issues.add('session_exception_invalid');
        continue;
      }
      hasOnlyKeys(
        ex,
        new Set([
          'id',
          'start_date_local',
          'end_date_local',
          'all_day',
          'start_minute_local',
          'end_minute_local_exclusive',
          'private_note',
          'created_by_user_id',
          'created_at_utc',
        ]),
        issues,
        'session.exception',
      );
      issues.require(isEntityId(ex.id) && !ids.has(String(ex.id)), 'session_exception_invalid');
      ids.add(String(ex.id));
      issues.require(
        isLocalDate(ex.start_date_local) &&
          isLocalDate(ex.end_date_local) &&
          ex.start_date_local <= ex.end_date_local,
        'session_exception_invalid',
      );
      issues.require(typeof ex.all_day === 'boolean', 'session_exception_invalid');
      if (ex.all_day === true)
        issues.require(
          ex.start_minute_local === undefined && ex.end_minute_local_exclusive === undefined,
          'session_exception_invalid',
        );
      else
        issues.require(
          isInt(ex.start_minute_local, 0, 1439) &&
            isInt(ex.end_minute_local_exclusive, 1, 1440) &&
            ex.start_minute_local < ex.end_minute_local_exclusive,
          'session_exception_invalid',
        );
      if (ex.private_note !== undefined)
        issues.require(isText(ex.private_note, 0, 140), 'session_exception_invalid');
      // Audit fields are authenticated evidence, not a client grant.
      issues.require(
        ex.created_by_user_id === context.createdByUserId && isInstant(ex.created_at_utc),
        'session.exception_audit',
      );
    }
  }
  return issues.result();
}

export function sessionMediaIds(body: ContentBody): readonly string[] {
  if (!isRecord(body.media)) return [];
  const images = [
    body.media.coverImage,
    ...(Array.isArray(body.media.gallery) ? (body.media.gallery as unknown[]) : []),
  ];
  return images.flatMap((image) =>
    isRecord(image) && typeof image.mediaId === 'string' ? [image.mediaId] : [],
  );
}
