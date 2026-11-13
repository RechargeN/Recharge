import {
  roundApproximate,
  scenarioDistributionHash,
  validateScenarioDistribution,
  type ScenarioDistributionMode,
  type ScenarioStopLookup,
} from '../content/domain/type_rules/scenario_rules.js';
import { record } from '../library/library_contract.js';

type Json = Record<string, unknown>;

export type DistributionResult =
  | { readonly ok: true; readonly distribution: Json; readonly contentHash: string }
  | { readonly ok: false; readonly issues: readonly string[] };

const list = (value: unknown): Json[] =>
  Array.isArray(value) ? value.map((v) => record(v)).filter((v): v is Json => v !== null) : [];
const text = (value: unknown): string | null =>
  typeof value === 'string' && value.trim() !== '' ? value.trim() : null;

/**
 * SCN-PUB-01 §5 allowlist mapper: builds the distribution of an I2 Scenario
 * draft field by field. Nothing is copied by default: participants, private
 * notes, origin, capabilities, totals internals, catalog snapshots and the
 * locations of catalog stops never reach the result (SP-10). Unscheduled
 * optional items stay private; a private location stays in the result only so
 * the shared validator can refuse it, and a refused result is never stored.
 */
export function mapScenarioDistribution(
  draft: unknown,
  mode: ScenarioDistributionMode,
  lookup?: ScenarioStopLookup,
): DistributionResult {
  const d = record(draft);
  const s = record(d?.scenario);
  if (!d || !s) return { ok: false, issues: ['scenario.distribution'] };
  const issues: string[] = [];
  const dated = s.dateMode === 'dated';
  const days = list(s.days);
  const items = new Map(list(s.items).map((item) => [String(item.id), item]));
  const locations = new Map(list(s.locations).map((location) => [String(location.id), location]));
  const scheduled = new Set<string>();
  for (const day of days)
    for (const id of Array.isArray(day.itemIds) ? day.itemIds : [])
      if (items.has(String(id))) scheduled.add(String(id));
  for (const [id, item] of items)
    if (!scheduled.has(id) && item.role === 'mandatory')
      issues.push('scenario.mandatory_unscheduled');

  // Only the author's own places are distributed; a catalog stop is its reference.
  const own = (id: unknown): string | null => {
    const location = typeof id === 'string' ? locations.get(id) : undefined;
    return location !== undefined && location.sourceObjectId == null ? (id as string) : null;
  };
  const usedLocations = new Set<string>();
  const use = (id: string | null) => {
    if (id !== null) usedLocations.add(id);
    return id;
  };
  const stopOf = (item: Json): Json => {
    const source = record(item.source) ?? {};
    switch (source.type) {
      case 'catalog':
        return { type: 'catalog', objectType: source.objectType, objectId: source.objectId };
      case 'custom_location':
        return {
          type: 'custom',
          startLocationId: use(own(item.startLocationId)),
          endLocationId: use(own(item.endLocationId)),
        };
      case 'planned_transport':
        return {
          type: 'transport',
          transportKind: source.kind,
          carrierName: text(source.carrierName),
          serviceLabel: text(source.publicServiceLabel),
          notLive: true,
          startLocationId: use(own(item.startLocationId)),
          endLocationId: use(own(item.endLocationId)),
        };
      default:
        return { type: 'time_block', title: text(source.title) ?? '' };
    }
  };
  const timeOf = (item: Json): Json | null => {
    const planned = record(record(item.schedule)?.planned);
    if (!planned) return null;
    if (planned.type === 'dated')
      return {
        type: 'dated',
        startAtUtc: planned.fixedStartAtUtc ?? null,
        endAtUtc: planned.fixedEndAtUtc ?? null,
      };
    return {
      type: 'template',
      startDayIndex: planned.startDayIndex ?? 0,
      start: planned.preferredStart ?? planned.windowStart ?? null,
      end: planned.preferredEnd ?? planned.windowEnd ?? null,
    };
  };

  const currency = String(s.displayCurrencyCode);
  let fromMinor = 0;
  let unknownCount = 0;
  const addCost = (cost: unknown) => {
    for (const component of list(record(cost)?.components)) {
      const amount = record(component.amount);
      if (component.knowledge === 'free') continue;
      if (
        (component.knowledge === 'known' || component.knowledge === 'estimated') &&
        amount?.currencyCode === currency &&
        Number.isSafeInteger(amount.minorUnits) &&
        Number(amount.minorUnits) >= 0
      )
        fromMinor += Number(amount.minorUnits);
      else unknownCount++;
    }
  };

  const outItems: Json[] = [];
  for (const [id, item] of items) {
    if (!scheduled.has(id)) continue;
    addCost(item.cost);
    outItems.push({
      id,
      dayId: item.dayId,
      kind: item.kind,
      role: item.role,
      alternativeGroupId: item.alternativeGroupId ?? null,
      selected: item.selected === true,
      publicNote: typeof item.publicNote === 'string' ? item.publicNote : '',
      durationMinutes: item.durationMinutes ?? null,
      stop: stopOf(item),
      time: timeOf(item),
    });
  }
  const outLocations: Json[] = [];
  for (const id of usedLocations) {
    const location = locations.get(id)!;
    const point = record(location.point) ?? {};
    const approximate = location.disclosure === 'approximate';
    const coordinate = (value: unknown) =>
      typeof value === 'number' && approximate ? roundApproximate(value) : value;
    outLocations.push({
      id,
      disclosure: location.disclosure,
      title: location.title,
      point: { latitude: coordinate(point.latitude), longitude: coordinate(point.longitude) },
      address: approximate ? null : text(location.address),
      timezoneId: location.timezoneId ?? null,
    });
  }
  const publicLocation = (id: unknown) =>
    typeof id === 'string' && locations.get(id)?.disclosure === 'public' && usedLocations.has(id);
  const byId = new Map(outItems.map((item) => [String(item.id), item]));
  const outLegs: Json[] = [];
  for (const leg of list(s.legs)) {
    const from = byId.get(String(leg.fromItemId));
    const to = byId.get(String(leg.toItemId));
    if (from === undefined || to === undefined) continue;
    addCost(leg.cost);
    const drawable =
      publicLocation(record(from.stop)?.endLocationId) &&
      publicLocation(record(to.stop)?.startLocationId);
    outLegs.push({
      id: leg.id,
      dayId: leg.dayId,
      fromItemId: leg.fromItemId,
      toItemId: leg.toItemId,
      mode: leg.mode,
      distanceM: leg.distanceM ?? null,
      durationMinutes: leg.durationMinutes ?? null,
      polyline: drawable && Array.isArray(leg.displayPolyline) ? leg.displayPolyline : [],
    });
  }
  const party = record(s.party) ?? {};
  const distribution: Json = {
    schemaVersion: 1,
    mode,
    title: typeof d.title === 'string' ? d.title.trim() : '',
    format: s.format,
    dateMode: s.dateMode,
    defaultTimezoneId: s.defaultTimezoneId,
    displayCurrencyCode: currency,
    party: { peopleCount: party.peopleCount, kind: party.kind },
    budget: { currencyCode: currency, fromMinor, unknownCount },
    days: days.map((day) => ({
      id: day.id,
      dayIndex: day.dayIndex,
      title: text(day.title),
      timezoneId: day.timezoneId ?? null,
      localDate: dated ? (day.localDate ?? null) : null,
      itemIds: (Array.isArray(day.itemIds) ? day.itemIds : []).filter((id) =>
        scheduled.has(String(id)),
      ),
    })),
    items: outItems,
    locations: outLocations,
    legs: outLegs,
  };
  issues.push(...validateScenarioDistribution(distribution, mode, lookup));
  if (issues.length > 0) return { ok: false, issues: [...new Set(issues)].slice(0, 50) };
  return { ok: true, distribution, contentHash: scenarioDistributionHash(distribution) };
}
