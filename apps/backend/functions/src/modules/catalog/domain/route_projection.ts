import {
  routeDistributionTrack,
  validateRouteDistribution,
} from '../../content/domain/type_rules/route_rules.js';
import { routeDistributionHash } from '../../route/route_distribution.js';
import {
  normalizeText,
  type CatalogPoint,
  type ContentFact,
  type ProjectionOutcome,
  type SourceRevision,
} from './catalog_item.js';

/**
 * BCK08-OD-04-R (RTE-PUB-01 RP-12, option B): a public Route, projected from
 * its immutable published revision only. Cards and Map leaves carry the start
 * of the trimmed track, the summary and the `route-preview-dp-v1` preview line;
 * the full trimmed track and waypoints are kept for Details only. Nothing here
 * is derived from the owner's full geometry: it never reaches Content.
 */
export interface CatalogRoutePreview {
  readonly policy: string;
  readonly segments: readonly { readonly polyline: string; readonly connected: boolean }[];
}

export interface CatalogRouteSummary {
  readonly distanceMeters: number;
  readonly ascentMeters: number | null;
  readonly descentMeters: number | null;
  readonly minElevationMeters: number | null;
  readonly maxElevationMeters: number | null;
  readonly segmentCount: number;
  readonly gapCount: number;
}

export interface CatalogRouteItem {
  readonly schemaRevision: 'catalog-route-projection-v1';
  readonly typeId: 'route';
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
  readonly shape: string;
  readonly profileId: string;
  readonly summary: CatalogRouteSummary;
  /** RP-07: direct segments are labelled, never hidden. */
  readonly directSegmentCount: number;
  /** First point of the trimmed track (WGS84 degrees). */
  readonly point: CatalogPoint;
  readonly notMappable: null;
  readonly preview: CatalogRoutePreview;
  /** Details only: the published trimmed segments and waypoints. */
  readonly track: {
    readonly segments: readonly Readonly<Record<string, unknown>>[];
    readonly waypoints: readonly Readonly<Record<string, unknown>>[];
  };
  readonly coverMediaId: string | null;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly publishedAtUtc: string;
  readonly searchText: string;
}

type Json = Readonly<Record<string, unknown>>;
const obj = (value: unknown): Json | null =>
  typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : null;

export function projectRoute(fact: ContentFact, source: SourceRevision): ProjectionOutcome {
  const bad = (): ProjectionOutcome => ({ state: 'excluded', reason: 'invalid_projection' });
  const body = source.body;
  const route = obj(body.route);
  const ref = obj(route?.ref);
  const distribution = obj(route?.distribution);
  // The immutable revision is re-checked here, exactly as Content checked it.
  if (
    distribution === null ||
    ref?.routeId !== fact.contentId ||
    ref.contentHash !== routeDistributionHash(distribution) ||
    validateRouteDistribution(distribution).length > 0 ||
    body.title !== distribution.title ||
    typeof body.title !== 'string' ||
    typeof body.shortDescription !== 'string' ||
    typeof body.fullDescription !== 'string' ||
    typeof body.categoryId !== 'string' ||
    typeof body.subcategoryId !== 'string'
  )
    return bad();
  const track = routeDistributionTrack(distribution);
  const start = track?.[0]?.points[0];
  if (start === undefined) return bad();
  const summary = obj(distribution.summary)!;
  const profile = obj(distribution.profile)!;
  const cover = obj(obj(body.media)?.coverImage);
  return {
    state: 'listed',
    item: {
      schemaRevision: 'catalog-route-projection-v1',
      typeId: 'route',
      contentId: fact.contentId,
      publishedRevisionId: fact.publishedRevisionId,
      sourcePointerRevision: fact.pointerRevision,
      marketId: fact.marketId,
      publisherRef: fact.publisherRef,
      title: body.title,
      shortDescription: body.shortDescription,
      fullDescription: body.fullDescription,
      categoryId: body.categoryId,
      subcategoryId: body.subcategoryId,
      shape: String(distribution.shape),
      profileId: String(profile.id),
      summary: {
        distanceMeters: Number(summary.distanceMeters),
        ascentMeters: summary.ascentMeters as number | null,
        descentMeters: summary.descentMeters as number | null,
        minElevationMeters: summary.minElevationMeters as number | null,
        maxElevationMeters: summary.maxElevationMeters as number | null,
        segmentCount: Number(summary.segmentCount),
        gapCount: Number(summary.gapCount),
      },
      directSegmentCount: Number(distribution.directSegmentCount),
      point: { latitude: start.latE7 / 1e7, longitude: start.lonE7 / 1e7 },
      notMappable: null,
      preview: distribution.preview as CatalogRoutePreview,
      track: {
        segments: distribution.segments as Json[],
        waypoints: distribution.waypoints as Json[],
      },
      coverMediaId:
        typeof cover?.mediaId === 'string' &&
        !(fact.suppressedMediaIds ?? []).includes(cover.mediaId)
          ? cover.mediaId
          : null,
      referenceRevisions: source.referenceRevisions,
      publishedAtUtc: source.publishedAtUtc,
      searchText: normalizeText([body.title, body.shortDescription].join(' ')),
    },
  };
}
