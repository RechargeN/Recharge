import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import { canonicalJson, sha256Hex } from '../published_revision.js';
import {
  IssueCollector,
  hasOnlyKeys,
  isEnumValue,
  isIanaZone,
  isInt,
  isInstant,
  isNumberIn,
  isRecord,
  isText,
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';

/**
 * SCN-PUB-01 (SCENARIO_PUBLICATION_BCK10_AMENDMENT.md §5): the one validator of a
 * Scenario distribution snapshot. Planning runs it before it stores an immutable
 * public or unlisted revision; Content runs it again at submit, publish and
 * activation. Every level is an exact allowlist: an extra field (participants,
 * notes, invites, origin, private locations) is an issue, never ignored.
 */
export type ScenarioDistributionMode = 'public' | 'unlisted';

/** Catalog object types a distributed stop may reference by exact id. */
export const scenarioStopObjectTypes = ['event', 'place', 'activity', 'bookable_session'] as const;
export type ScenarioStopObjectType = (typeof scenarioStopObjectTypes)[number];

/** Current status of one referenced object; `undefined` when it could not be resolved. */
export type ScenarioStopLookup = (
  objectType: ScenarioStopObjectType,
  objectId: string,
) => 'ready' | 'unavailable' | undefined;

export const scenarioDistributionLimits = Object.freeze({
  maxDays: 30,
  maxItems: 250,
  maxLocations: 500,
  maxLegs: 500,
  maxPolylinePoints: 200,
  minActiveItems: 2,
  maxPublicNote: 500,
  maxPeople: 50,
});

const itemKinds = [
  'visit',
  'event',
  'activity',
  'bookable_session',
  'stay',
  'planned_transport',
  'time_block',
] as const;
const roles = ['mandatory', 'optional', 'alternative'] as const;
const formats = ['city', 'day', 'weekend', 'trip'] as const;
const partyKinds = ['solo', 'couple', 'friends', 'family', 'group', 'mixed'] as const;
const travelModes = ['walking', 'bicycle', 'car', 'taxi', 'transit', 'other'] as const;
const transportKinds = ['bus', 'train', 'tram', 'trolleybus', 'ferry', 'flight', 'other'] as const;

/** Which stop sources each item kind accepts (Scenario Builder v1.7 §6). */
const kindSources: Readonly<Record<string, readonly string[]>> = Object.freeze({
  visit: ['catalog:place', 'custom'],
  event: ['catalog:event'],
  activity: ['catalog:activity', 'custom'],
  bookable_session: ['catalog:bookable_session'],
  stay: ['catalog:place', 'custom'],
  planned_transport: ['transport'],
  time_block: ['time_block'],
});

export function scenarioDistributionHash(distribution: unknown): string {
  return sha256Hex(canonicalJson(distribution));
}

/** `approximate` points carry at most two decimals (about 1 km). */
export function roundApproximate(value: number): number {
  return Math.round(value * 100) / 100;
}

function isPoint(value: unknown): value is { latitude: number; longitude: number } {
  return (
    isRecord(value) &&
    Object.keys(value).length === 2 &&
    isNumberIn(value.latitude, -90, 90) &&
    isNumberIn(value.longitude, -180, 180)
  );
}

function isLocalTime(value: unknown): boolean {
  return (
    value === null ||
    (isRecord(value) &&
      Object.keys(value).length === 2 &&
      isInt(value.hour, 0, 23) &&
      isInt(value.minute, 0, 59))
  );
}

function isLocalDateParts(value: unknown): boolean {
  if (!isRecord(value) || Object.keys(value).length !== 3) return false;
  const { year, month, day } = value;
  if (!isInt(year, 2000, 2200) || !isInt(month, 1, 12) || !isInt(day, 1, 31)) return false;
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

/** Catalog stop references of a distribution, de-duplicated (malformed ones skipped). */
export function scenarioStopRefs(
  distribution: unknown,
): readonly { objectType: ScenarioStopObjectType; objectId: string }[] {
  if (!isRecord(distribution) || !Array.isArray(distribution.items)) return [];
  const seen = new Map<string, { objectType: ScenarioStopObjectType; objectId: string }>();
  for (const raw of distribution.items as unknown[]) {
    if (!isRecord(raw) || !isRecord(raw.stop) || raw.stop.type !== 'catalog') continue;
    const { objectType, objectId } = raw.stop;
    if (isEnumValue(objectType, scenarioStopObjectTypes) && isEntityId(objectId))
      seen.set(`${objectType}:${objectId}`, { objectType, objectId });
  }
  return [...seen.values()];
}

export function validateScenarioDistribution(
  value: unknown,
  mode: ScenarioDistributionMode,
  lookup?: ScenarioStopLookup,
): ContentRuleIssues {
  const issues = new IssueCollector();
  if (!isRecord(value)) {
    issues.add('scenario.distribution');
    return issues.result();
  }
  const d = value;
  hasOnlyKeys(
    d,
    new Set([
      'schemaVersion',
      'mode',
      'title',
      'format',
      'dateMode',
      'defaultTimezoneId',
      'displayCurrencyCode',
      'party',
      'budget',
      'days',
      'items',
      'locations',
      'legs',
    ]),
    issues,
    'scenario',
  );
  issues.require(d.schemaVersion === 1, 'scenario.schema_version');
  issues.require(d.mode === mode, 'scenario.mode');
  issues.require(isText(d.title, 3, 120), 'scenario.title');
  issues.require(isEnumValue(d.format, formats), 'scenario.format');
  const dated = d.dateMode === 'dated';
  issues.require(d.dateMode === 'template' || dated, 'scenario.date_mode');
  if (mode === 'public') issues.require(!dated, 'scenario.dated_public_unsupported');
  issues.require(
    typeof d.displayCurrencyCode === 'string' && /^[A-Z]{3}$/.test(d.displayCurrencyCode),
    'scenario.currency',
  );
  const defaultZone = isIanaZone(d.defaultTimezoneId) ? d.defaultTimezoneId : null;
  if (
    !isRecord(d.party) ||
    Object.keys(d.party).length !== 2 ||
    !isInt(d.party.peopleCount, 1, scenarioDistributionLimits.maxPeople) ||
    !isEnumValue(d.party.kind, partyKinds)
  )
    issues.add('scenario.party');
  if (
    !isRecord(d.budget) ||
    Object.keys(d.budget).length !== 3 ||
    d.budget.currencyCode !== d.displayCurrencyCode ||
    !isInt(d.budget.fromMinor, 0, Number.MAX_SAFE_INTEGER) ||
    !isInt(d.budget.unknownCount, 0, scenarioDistributionLimits.maxItems)
  )
    issues.add('scenario.budget');
  const days = Array.isArray(d.days) ? (d.days as unknown[]) : null;
  const items = Array.isArray(d.items) ? (d.items as unknown[]) : null;
  const locations = Array.isArray(d.locations) ? (d.locations as unknown[]) : null;
  const legs = Array.isArray(d.legs) ? (d.legs as unknown[]) : null;
  if (
    days === null ||
    items === null ||
    locations === null ||
    legs === null ||
    days.length < 1 ||
    days.length > scenarioDistributionLimits.maxDays ||
    items.length > scenarioDistributionLimits.maxItems ||
    locations.length > scenarioDistributionLimits.maxLocations ||
    legs.length > scenarioDistributionLimits.maxLegs
  ) {
    issues.add('scenario.structure');
    return issues.result();
  }
  const ids = new Set<string>();
  const unique = (id: unknown): boolean => {
    if (!isEntityId(id) || ids.has(id)) return false;
    ids.add(id);
    return true;
  };

  const locationById = new Map<string, Json>();
  for (const raw of locations) {
    if (!isRecord(raw) || !unique(raw.id)) {
      issues.add('scenario.location');
      continue;
    }
    hasOnlyKeys(
      raw,
      new Set(['id', 'disclosure', 'title', 'point', 'address', 'timezoneId']),
      issues,
      'scenario.location',
    );
    const approximate = raw.disclosure === 'approximate';
    // Only the author's own public or approximate places are ever distributed.
    issues.require(raw.disclosure === 'public' || approximate, 'scenario.private_location');
    issues.require(isText(raw.title, 1, 120), 'scenario.location_title');
    issues.require(isPoint(raw.point), 'scenario.location_point');
    if (approximate && isPoint(raw.point))
      issues.require(
        roundApproximate(raw.point.latitude) === raw.point.latitude &&
          roundApproximate(raw.point.longitude) === raw.point.longitude,
        'scenario.approximate_precision',
      );
    issues.require(
      raw.address === null || (!approximate && isText(raw.address, 1, 200)),
      'scenario.location_address',
    );
    issues.require(raw.timezoneId === null || isIanaZone(raw.timezoneId), 'scenario.timezone');
    locationById.set(raw.id as string, raw);
  }

  const dayById = new Map<string, Json>();
  for (const raw of days) {
    if (!isRecord(raw) || !unique(raw.id)) {
      issues.add('scenario.day');
      continue;
    }
    hasOnlyKeys(
      raw,
      new Set(['id', 'dayIndex', 'title', 'timezoneId', 'localDate', 'itemIds']),
      issues,
      'scenario.day',
    );
    issues.require(isInt(raw.dayIndex, 0, scenarioDistributionLimits.maxDays - 1), 'scenario.day');
    issues.require(raw.title === null || isText(raw.title, 1, 120), 'scenario.day_title');
    issues.require(
      isIanaZone(raw.timezoneId) || (raw.timezoneId === null && defaultZone !== null),
      'scenario.timezone',
    );
    issues.require(
      dated ? isLocalDateParts(raw.localDate) : raw.localDate === null,
      'scenario.day_date',
    );
    issues.require(Array.isArray(raw.itemIds), 'scenario.day');
    dayById.set(raw.id as string, raw);
  }

  const itemById = new Map<string, Json>();
  const groups = new Map<string, number>();
  let active = 0;
  for (const raw of items) {
    if (!isRecord(raw) || !unique(raw.id)) {
      issues.add('scenario.item');
      continue;
    }
    hasOnlyKeys(
      raw,
      new Set([
        'id',
        'dayId',
        'kind',
        'role',
        'alternativeGroupId',
        'selected',
        'publicNote',
        'durationMinutes',
        'stop',
        'time',
      ]),
      issues,
      'scenario.item',
    );
    itemById.set(raw.id as string, raw);
    issues.require(typeof raw.dayId === 'string' && dayById.has(raw.dayId), 'scenario.item_day');
    if (raw.kind === 'route') issues.add('scenario.route_item_unsupported');
    else issues.require(isEnumValue(raw.kind, itemKinds), 'scenario.item_kind');
    issues.require(isEnumValue(raw.role, roles), 'scenario.item_role');
    issues.require(typeof raw.selected === 'boolean', 'scenario.item_selected');
    issues.require(
      typeof raw.publicNote === 'string' &&
        raw.publicNote.length <= scenarioDistributionLimits.maxPublicNote,
      'scenario.public_note',
    );
    issues.require(
      raw.durationMinutes === null || isInt(raw.durationMinutes, 1, 30 * 24 * 60),
      'scenario.item_duration',
    );
    if (raw.role === 'alternative') {
      if (typeof raw.alternativeGroupId !== 'string' || !isEntityId(raw.alternativeGroupId))
        issues.add('scenario.alternative_group');
      else
        groups.set(
          raw.alternativeGroupId,
          (groups.get(raw.alternativeGroupId) ?? 0) + (raw.selected === true ? 1 : 0),
        );
      if (raw.selected === true) active++;
    } else {
      issues.require(raw.alternativeGroupId === null, 'scenario.alternative_group');
      active++;
    }
    validateStop(raw, locationById, issues, lookup);
    validateTime(raw.time, dated, issues);
  }
  for (const selected of groups.values())
    issues.require(selected === 1, 'scenario.alternative_selection');
  issues.require(active >= scenarioDistributionLimits.minActiveItems, 'scenario.min_items');

  const placed = new Set<string>();
  for (const day of dayById.values())
    for (const id of Array.isArray(day.itemIds) ? (day.itemIds as unknown[]) : []) {
      const item = typeof id === 'string' ? itemById.get(id) : undefined;
      if (item === undefined || placed.has(id as string) || item.dayId !== day.id)
        issues.add('scenario.day_items');
      else placed.add(id as string);
    }
  issues.require(placed.size === itemById.size, 'scenario.unscheduled_item');

  for (const raw of legs) {
    if (!isRecord(raw) || !unique(raw.id)) {
      issues.add('scenario.leg');
      continue;
    }
    hasOnlyKeys(
      raw,
      new Set([
        'id',
        'dayId',
        'fromItemId',
        'toItemId',
        'mode',
        'distanceM',
        'durationMinutes',
        'polyline',
      ]),
      issues,
      'scenario.leg',
    );
    const from = typeof raw.fromItemId === 'string' ? itemById.get(raw.fromItemId) : undefined;
    const to = typeof raw.toItemId === 'string' ? itemById.get(raw.toItemId) : undefined;
    issues.require(
      typeof raw.dayId === 'string' &&
        dayById.has(raw.dayId) &&
        from !== undefined &&
        to !== undefined,
      'scenario.leg_refs',
    );
    issues.require(isEnumValue(raw.mode, travelModes), 'scenario.leg_mode');
    issues.require(
      raw.distanceM === null || isNumberIn(raw.distanceM, 0, 5_000_000),
      'scenario.leg_distance',
    );
    issues.require(
      raw.durationMinutes === null || isInt(raw.durationMinutes, 0, 7 * 24 * 60),
      'scenario.leg_duration',
    );
    const polyline = Array.isArray(raw.polyline) ? (raw.polyline as unknown[]) : null;
    if (
      polyline === null ||
      polyline.length > scenarioDistributionLimits.maxPolylinePoints ||
      !polyline.every(isPoint)
    )
      issues.add('scenario.leg_polyline');
    else if (polyline.length > 0)
      // A drawn line would reveal any endpoint it touches: both must be public places.
      issues.require(
        publicEndpoint(from, 'end', locationById) && publicEndpoint(to, 'start', locationById),
        'scenario.leg_polyline_private',
      );
  }
  return issues.result();
}

function publicEndpoint(
  item: Json | undefined,
  side: 'start' | 'end',
  locations: ReadonlyMap<string, Json>,
): boolean {
  if (item === undefined || !isRecord(item.stop)) return false;
  const id = item.stop[side === 'start' ? 'startLocationId' : 'endLocationId'];
  return typeof id === 'string' && locations.get(id)?.disclosure === 'public';
}

function validateStop(
  item: Json,
  locations: ReadonlyMap<string, Json>,
  issues: IssueCollector,
  lookup: ScenarioStopLookup | undefined,
): void {
  const stop = item.stop;
  if (!isRecord(stop)) {
    issues.add('scenario.stop');
    return;
  }
  const location = (id: unknown) => typeof id === 'string' && locations.has(id);
  let source: string;
  switch (stop.type) {
    case 'catalog': {
      hasOnlyKeys(stop, new Set(['type', 'objectType', 'objectId']), issues, 'scenario.stop');
      if (!isEnumValue(stop.objectType, scenarioStopObjectTypes) || !isEntityId(stop.objectId)) {
        issues.add(
          stop.objectType === 'route' ? 'scenario.route_item_unsupported' : 'scenario.stop',
        );
        return;
      }
      source = `catalog:${stop.objectType}`;
      // Exact current status from the owning authority; a snapshot is never proof.
      const status = lookup?.(stop.objectType, stop.objectId);
      if (status === undefined) issues.add('scenario.stops_unresolved');
      else issues.require(status === 'ready', 'scenario.stop_unavailable');
      break;
    }
    case 'custom':
      hasOnlyKeys(
        stop,
        new Set(['type', 'startLocationId', 'endLocationId']),
        issues,
        'scenario.stop',
      );
      issues.require(
        location(stop.startLocationId) && location(stop.endLocationId),
        'scenario.stop_location',
      );
      source = 'custom';
      break;
    case 'transport':
      hasOnlyKeys(
        stop,
        new Set([
          'type',
          'transportKind',
          'carrierName',
          'serviceLabel',
          'notLive',
          'startLocationId',
          'endLocationId',
        ]),
        issues,
        'scenario.stop',
      );
      issues.require(isEnumValue(stop.transportKind, transportKinds), 'scenario.transport');
      // Planned transport is a schedule, never a live departure (§9 invariant 7).
      issues.require(stop.notLive === true, 'scenario.transport_live');
      for (const field of ['carrierName', 'serviceLabel'])
        issues.require(stop[field] === null || isText(stop[field], 1, 120), 'scenario.transport');
      for (const field of ['startLocationId', 'endLocationId'])
        issues.require(stop[field] === null || location(stop[field]), 'scenario.stop_location');
      source = 'transport';
      break;
    case 'time_block':
      hasOnlyKeys(stop, new Set(['type', 'title']), issues, 'scenario.stop');
      issues.require(isText(stop.title, 1, 120), 'scenario.time_block');
      source = 'time_block';
      break;
    default:
      issues.add('scenario.stop');
      return;
  }
  if (typeof item.kind === 'string' && item.kind !== 'route')
    issues.require(kindSources[item.kind]?.includes(source) === true, 'scenario.kind_source');
}

function validateTime(time: unknown, dated: boolean, issues: IssueCollector): void {
  if (time === null) return;
  if (!isRecord(time)) {
    issues.add('scenario.time');
    return;
  }
  if (time.type === 'template' && !dated) {
    hasOnlyKeys(time, new Set(['type', 'startDayIndex', 'start', 'end']), issues, 'scenario.time');
    issues.require(
      isInt(time.startDayIndex, 0, scenarioDistributionLimits.maxDays - 1) &&
        isLocalTime(time.start) &&
        isLocalTime(time.end),
      'scenario.time',
    );
    return;
  }
  if (time.type === 'dated' && dated) {
    hasOnlyKeys(time, new Set(['type', 'startAtUtc', 'endAtUtc']), issues, 'scenario.time');
    issues.require(
      (time.startAtUtc === null || isInstant(time.startAtUtc)) &&
        (time.endAtUtc === null || isInstant(time.endAtUtc)),
      'scenario.time',
    );
    return;
  }
  issues.add('scenario.time');
}

/**
 * The Content body of a public Scenario: shared public fields reviewed by
 * moderation plus the pinned BCK-10 distribution. Personal publisher only
 * (SP-02); title comes from the distribution; the ref binds the body to the
 * immutable Planning revision by hash (SP-06).
 */
export function validateScenarioBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  hasOnlyKeys(
    body,
    new Set(['title', 'shortDescription', 'fullDescription', 'contentLocale', 'media', 'scenario']),
    issues,
    'scenario',
  );
  issues.require(context.marketId === 'LV', 'scenario.market');
  issues.require(
    context.publisherRef.type === 'user' && context.publisherRef.id === context.createdByUserId,
    'scenario_publisher_ineligible',
  );
  issues.require(isText(body.shortDescription, 20, 180), 'scenario.shortDescription');
  issues.require(isText(body.fullDescription, 20, 2000), 'scenario.fullDescription');
  const locale =
    typeof body.contentLocale === 'string'
      ? context.lookups.supportsLocale(body.contentLocale)
      : false;
  issues.require(
    locale === true,
    locale === undefined ? 'scenario.locale_unavailable' : 'scenario.locale',
  );
  const media = body.media;
  if (!isRecord(media)) issues.add('scenario.media');
  else {
    hasOnlyKeys(media, new Set(['coverImage', 'rightsConfirmed']), issues, 'scenario.media');
    if (media.coverImage !== undefined) {
      const cover = media.coverImage;
      issues.require(
        isRecord(cover) &&
          Object.keys(cover).length === 2 &&
          isEntityId(cover.mediaId) &&
          isRecord(cover.altText) &&
          Object.values(cover.altText).every((text) => isText(text, 1, 200)),
        'scenario.cover',
      );
      issues.require(media.rightsConfirmed === true, 'scenario.media_rights');
    }
  }
  const scenario = body.scenario;
  if (!isRecord(scenario) || !isRecord(scenario.ref)) {
    issues.add('scenario.ref');
    return issues.result();
  }
  hasOnlyKeys(scenario, new Set(['ref', 'distribution']), issues, 'scenario');
  const ref = scenario.ref;
  issues.require(
    Object.keys(ref).length === 3 &&
      isEntityId(ref.scenarioId) &&
      isEntityId(ref.scenarioRevisionId) &&
      typeof ref.contentHash === 'string' &&
      /^[a-f0-9]{64}$/.test(ref.contentHash),
    'scenario.ref',
  );
  issues.require(
    ref.contentHash === scenarioDistributionHash(scenario.distribution),
    'scenario.distribution_hash',
  );
  const distribution = scenario.distribution;
  issues.require(
    isRecord(distribution) && body.title === distribution.title,
    'scenario.title_mismatch',
  );
  const lookup = context.publishedObjects;
  for (const issue of validateScenarioDistribution(
    distribution,
    'public',
    lookup === undefined ? undefined : (type, id) => lookup.statusOf(type, id),
  ))
    issues.add(issue);
  return issues.result();
}

export function scenarioMediaIds(body: ContentBody): readonly string[] {
  const media = body.media;
  if (!isRecord(media) || !isRecord(media.coverImage)) return [];
  return typeof media.coverImage.mediaId === 'string' ? [media.coverImage.mediaId] : [];
}
