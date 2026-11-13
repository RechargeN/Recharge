import {
  scenarioDistributionHash,
  validateScenarioDistribution,
} from '../../content/domain/type_rules/scenario_rules.js';
import {
  normalizeText,
  type CatalogPoint,
  type ContentFact,
  type ProjectionOutcome,
  type SourceRevision,
} from './catalog_item.js';

/**
 * BCK08-OD-04-S (SP-12): a public Scenario template, projected from its
 * immutable published revision only. No category, no occurrence, no price
 * filter: a Scenario is found by text, format and day count. The itinerary is
 * the already allowlisted distribution; catalog stops stay references and are
 * resolved fresh at read time (SP-09/SP-10).
 */
export interface CatalogScenarioStopRef {
  readonly itemId: string;
  readonly objectType: string;
  readonly objectId: string;
}

export interface CatalogScenarioItem {
  readonly schemaRevision: 'catalog-scenario-projection-v1';
  readonly typeId: 'scenario';
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly sourcePointerRevision: number;
  readonly marketId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly title: string;
  readonly shortDescription: string;
  readonly fullDescription: string;
  readonly format: string;
  readonly dayCount: number;
  readonly itemCount: number;
  readonly budget: {
    readonly currencyCode: string;
    readonly fromMinor: number;
    readonly unknownCount: number;
  };
  /** First own public/approximate location of day 1; never a catalog stop's point. */
  readonly point: CatalogPoint | null;
  readonly notMappable: 'noPublicGeo' | null;
  /** Active items that are not catalog stops: always available. */
  readonly ownActiveItems: number;
  /** Active catalog stops, checked fresh before any answer. */
  readonly stops: readonly CatalogScenarioStopRef[];
  readonly itinerary: Readonly<Record<string, unknown>>;
  readonly coverMediaId: string | null;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly publishedAtUtc: string;
  readonly searchText: string;
}

type Json = Readonly<Record<string, unknown>>;
const obj = (value: unknown): Json | null =>
  typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : null;
const list = (value: unknown): Json[] =>
  Array.isArray(value) ? value.map(obj).filter((v): v is Json => v !== null) : [];

export function projectScenario(fact: ContentFact, source: SourceRevision): ProjectionOutcome {
  const bad = (): ProjectionOutcome => ({ state: 'excluded', reason: 'invalid_projection' });
  const body = source.body;
  const scenario = obj(body.scenario);
  const ref = obj(scenario?.ref);
  const itinerary = obj(scenario?.distribution);
  // The immutable revision is re-checked here; a stop outage is not an error yet.
  if (
    itinerary === null ||
    ref?.contentHash !== scenarioDistributionHash(itinerary) ||
    validateScenarioDistribution(itinerary, 'public', () => 'ready').length > 0 ||
    typeof body.title !== 'string' ||
    typeof body.shortDescription !== 'string' ||
    typeof body.fullDescription !== 'string'
  )
    return bad();
  const items = list(itinerary.items);
  const active = items.filter((item) => item.role !== 'alternative' || item.selected === true);
  const stops: CatalogScenarioStopRef[] = [];
  let ownActiveItems = 0;
  for (const item of active) {
    const stop = obj(item.stop);
    if (stop?.type === 'catalog')
      stops.push({
        itemId: String(item.id),
        objectType: String(stop.objectType),
        objectId: String(stop.objectId),
      });
    else ownActiveItems++;
  }
  const locations = new Map(list(itinerary.locations).map((l) => [String(l.id), l]));
  const days = list(itinerary.days).sort((a, b) => Number(a.dayIndex) - Number(b.dayIndex));
  const byId = new Map(items.map((item) => [String(item.id), item]));
  let point: CatalogPoint | null = null;
  const firstDay = days[0];
  for (const id of Array.isArray(firstDay?.itemIds) ? (firstDay.itemIds as unknown[]) : []) {
    const stop = obj(byId.get(String(id))?.stop);
    const locationId =
      typeof stop?.startLocationId === 'string'
        ? stop.startLocationId
        : typeof stop?.endLocationId === 'string'
          ? stop.endLocationId
          : '';
    const location = locations.get(locationId);
    const p = obj(location?.point);
    if (p && typeof p.latitude === 'number' && typeof p.longitude === 'number') {
      point = { latitude: p.latitude, longitude: p.longitude };
      break;
    }
  }
  const budget = obj(itinerary.budget)!;
  const cover = obj(obj(body.media)?.coverImage);
  return {
    state: 'listed',
    item: {
      schemaRevision: 'catalog-scenario-projection-v1',
      typeId: 'scenario',
      contentId: fact.contentId,
      publishedRevisionId: fact.publishedRevisionId,
      sourcePointerRevision: fact.pointerRevision,
      marketId: fact.marketId,
      publisherRef: fact.publisherRef,
      title: body.title,
      shortDescription: body.shortDescription,
      fullDescription: body.fullDescription,
      format: String(itinerary.format),
      dayCount: days.length,
      itemCount: active.length,
      budget: {
        currencyCode: String(budget.currencyCode),
        fromMinor: Number(budget.fromMinor),
        unknownCount: Number(budget.unknownCount),
      },
      point,
      notMappable: point === null ? 'noPublicGeo' : null,
      ownActiveItems,
      stops,
      itinerary,
      coverMediaId:
        typeof cover?.mediaId === 'string' &&
        !(fact.suppressedMediaIds ?? []).includes(cover.mediaId)
          ? cover.mediaId
          : null,
      referenceRevisions: source.referenceRevisions,
      publishedAtUtc: source.publishedAtUtc,
      searchText: normalizeText(
        [body.title, body.shortDescription, String(itinerary.format)].join(' '),
      ),
    },
  };
}
