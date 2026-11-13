import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import { canonicalJson } from '../published_revision.js';
import {
  routeLimits,
  safeText,
  storableSourceKinds,
  token,
} from '../../../route/route_contract.js';
import {
  derivedDistributionFields,
  routeDistributionHash,
  routeDistributionSchema,
  type DistributedWaypoint,
} from '../../../route/route_distribution.js';
import {
  coordinatePolicy,
  decodeSegment,
  eleDmMax,
  eleDmMin,
  GeometryError,
  latE7Max,
  lonE7Max,
  privacyTrimPolicy,
  type TrackSegment,
} from '../../../route/route_geometry.js';
import {
  IssueCollector,
  hasOnlyKeys,
  isInt,
  isRecord,
  isText,
  type ContentRuleIssues,
  type ContentValidationContext,
} from './validation_context.js';

/**
 * J2 / RTE-PUB-01 §5: the one validator of a Route distribution snapshot.
 * Content runs it at submit, publish and activation, and the Catalog before
 * it projects. Every level is an exact allowlist, and every derived field is
 * recomputed from the published segments, so the snapshot cannot carry
 * anything the BCK-11 mapper would not have produced from a trimmed track.
 */
const distributionKeys = new Set([
  'schema',
  'coordinatePolicy',
  'privacyTrimPolicy',
  'title',
  'shape',
  'profile',
  'segments',
  'waypoints',
  'summary',
  'directSegmentCount',
  'start',
  'preview',
]);
const segmentKeys = ['sourceKind', 'polyline', 'elevation', 'connected'];
const waypointKeys = [
  'typeId',
  'title',
  'safetyNote',
  'latE7',
  'lonE7',
  'eleDm',
  'distanceFromStartMeters',
];
const exact = (value: Record<string, unknown>, keys: readonly string[]) =>
  Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key));
const nullableText = (value: unknown, max: number) => value === null || safeText(value, max);

/** The decoded published track, or `null` when the segments are not valid. */
export function routeDistributionTrack(distribution: unknown): TrackSegment[] | null {
  const segments = isRecord(distribution) ? distribution.segments : undefined;
  if (!Array.isArray(segments) || segments.length < 1 || segments.length > routeLimits.segments)
    return null;
  const track: TrackSegment[] = [];
  let budget = routeLimits.points;
  for (const [index, raw] of segments.entries()) {
    if (
      !isRecord(raw) ||
      !exact(raw, segmentKeys) ||
      !storableSourceKinds.includes(String(raw.sourceKind)) ||
      typeof raw.polyline !== 'string' ||
      (raw.elevation !== null && typeof raw.elevation !== 'string') ||
      typeof raw.connected !== 'boolean' ||
      (index === 0 && raw.connected)
    )
      return null;
    try {
      const points = decodeSegment(raw.polyline, raw.elevation, budget);
      budget -= points.length;
      track.push({ points, connected: raw.connected });
    } catch (e) {
      if (e instanceof GeometryError) return null;
      throw e;
    }
  }
  return track;
}

export function validateRouteDistribution(distribution: unknown): ContentRuleIssues {
  const issues = new IssueCollector();
  if (!isRecord(distribution)) return ['route.distribution'];
  hasOnlyKeys(distribution, distributionKeys, issues, 'route.distribution');
  issues.require(
    distribution.schema === routeDistributionSchema &&
      distribution.coordinatePolicy === coordinatePolicy &&
      distribution.privacyTrimPolicy === privacyTrimPolicy,
    'route.distribution_policy',
  );
  issues.require(
    typeof distribution.title === 'string' &&
      distribution.title.trim().length > 0 &&
      safeText(distribution.title, routeLimits.title),
    'route.title',
  );
  issues.require(
    ['oneWay', 'loop', 'outAndBack'].includes(String(distribution.shape)),
    'route.shape',
  );
  const profile = distribution.profile;
  issues.require(
    isRecord(profile) &&
      exact(profile, ['id', 'version']) &&
      token(profile.id) &&
      isInt(profile.version, 1, 1000),
    'route.profile',
  );
  const track = routeDistributionTrack(distribution);
  if (track === null) {
    issues.add('route.geometry');
    return issues.result();
  }
  const rawWaypoints = distribution.waypoints;
  if (!Array.isArray(rawWaypoints) || rawWaypoints.length > routeLimits.waypoints) {
    issues.add('route.waypoints');
    return issues.result();
  }
  const waypoints: DistributedWaypoint[] = [];
  for (const raw of rawWaypoints) {
    if (
      !isRecord(raw) ||
      !exact(raw, waypointKeys) ||
      !token(raw.typeId) ||
      !nullableText(raw.title, routeLimits.waypointTitle) ||
      !nullableText(raw.safetyNote, routeLimits.longText) ||
      !isInt(raw.latE7, -latE7Max, latE7Max) ||
      !isInt(raw.lonE7, -lonE7Max, lonE7Max) ||
      !(raw.eleDm === null || isInt(raw.eleDm, eleDmMin, eleDmMax))
    ) {
      issues.add('route.waypoints');
      return issues.result();
    }
    waypoints.push({
      typeId: raw.typeId,
      title: raw.title as string | null,
      safetyNote: raw.safetyNote as string | null,
      latE7: raw.latE7,
      lonE7: raw.lonE7,
      eleDm: raw.eleDm,
    });
  }
  const kinds = (distribution.segments as { sourceKind: string }[]).map((s) => s.sourceKind);
  const derived = derivedDistributionFields(track, kinds, waypoints);
  issues.require(
    canonicalJson(derived) ===
      canonicalJson({
        waypoints: rawWaypoints,
        summary: distribution.summary,
        directSegmentCount: distribution.directSegmentCount,
        start: distribution.start,
        preview: distribution.preview,
      }),
    'route.derived_mismatch',
  );
  return issues.result();
}

/**
 * The Content body of a public Route: shared public fields reviewed by
 * moderation plus the pinned BCK-11 distribution. Personal or Page publisher
 * (RP-04); the title comes from the distribution; the ref binds the body to the
 * immutable Route revision by hash (RP-01); the category is a `route` pair of
 * the canonical Category System (RP-10).
 */
export function validateRouteBody(
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
      'media',
      'route',
    ]),
    issues,
    'route',
  );
  issues.require(context.marketId === 'LV', 'route.market');
  issues.require(
    context.publisherRef.type === 'page' ||
      (context.publisherRef.type === 'user' && context.publisherRef.id === context.createdByUserId),
    'route_publisher_ineligible',
  );
  issues.require(isText(body.shortDescription, 20, 180), 'route.shortDescription');
  issues.require(isText(body.fullDescription, 20, 2000), 'route.fullDescription');
  const locale =
    typeof body.contentLocale === 'string'
      ? context.lookups.supportsLocale(body.contentLocale)
      : false;
  issues.require(
    locale === true,
    locale === undefined ? 'route.locale_unavailable' : 'route.locale',
  );
  if (
    issues.require(
      isText(body.categoryId, 1, 64) && isText(body.subcategoryId, 1, 64),
      'route.category_required',
    )
  ) {
    const applies = context.lookups.subcategoryApplies(
      'route',
      body.categoryId as string,
      body.subcategoryId as string,
    );
    if (applies === undefined) issues.add('route.taxonomy_unavailable');
    else issues.require(applies, 'route.category');
  }
  const media = body.media;
  if (!isRecord(media)) issues.add('route.media');
  else {
    hasOnlyKeys(media, new Set(['coverImage', 'rightsConfirmed']), issues, 'route.media');
    if (media.coverImage !== undefined) {
      const cover = media.coverImage;
      issues.require(
        isRecord(cover) &&
          Object.keys(cover).length === 2 &&
          isEntityId(cover.mediaId) &&
          isRecord(cover.altText) &&
          Object.values(cover.altText).every((text) => isText(text, 1, 200)),
        'route.cover',
      );
      issues.require(media.rightsConfirmed === true, 'route.media_rights');
    }
  }
  const route = body.route;
  if (!isRecord(route) || !isRecord(route.ref)) {
    issues.add('route.ref');
    return issues.result();
  }
  hasOnlyKeys(route, new Set(['ref', 'distribution']), issues, 'route');
  const ref = route.ref;
  issues.require(
    Object.keys(ref).length === 3 &&
      isEntityId(ref.routeId) &&
      isEntityId(ref.routeRevisionId) &&
      typeof ref.contentHash === 'string' &&
      /^[a-f0-9]{64}$/.test(ref.contentHash),
    'route.ref',
  );
  issues.require(
    ref.contentHash === routeDistributionHash(route.distribution),
    'route.distribution_hash',
  );
  const distribution = route.distribution;
  issues.require(
    isRecord(distribution) && body.title === distribution.title,
    'route.title_mismatch',
  );
  for (const issue of validateRouteDistribution(distribution)) issues.add(issue);
  return issues.result();
}

export function routeMediaIds(body: ContentBody): readonly string[] {
  const media = body.media;
  if (!isRecord(media) || !isRecord(media.coverImage)) return [];
  return typeof media.coverImage.mediaId === 'string' ? [media.coverImage.mediaId] : [];
}
