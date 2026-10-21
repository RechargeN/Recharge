import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import type { ParsedRoute, PrivacyTrim } from './route_contract.js';
import {
  coordinatePolicy,
  distanceAlongTrack,
  distanceMeters,
  encodeElevation,
  encodePolyline,
  GeometryError,
  previewPolicy,
  previewTrack,
  privacyTrimPolicy,
  summarize,
  trimTrack,
  type Point,
  type TrackSegment,
} from './route_geometry.js';

/**
 * J2 / RTE-PUB-01 §5: the public distribution of one Route revision. It is built
 * only from the privacy-trimmed track (RP-02) and is an exact allowlist: no
 * anchors, turning anchor, trim radii, re-entry flags, provenance, source or
 * parent ids, notes, receipts or owner data. Every derived field (summary,
 * direct count, start, waypoint distances, preview) is recomputed from the
 * published segments, so Content can verify the snapshot on its own.
 */
export const routeDistributionSchema = 'route-distribution-v1';

/** RP-02: a Route with recorded GPS hides at least this much at both ends. */
export const recordedGpsMinTrimMeters = 200;

/** RP-07: direct segments stay labelled in the public revision. */
export const directSourceKinds: readonly string[] = Object.freeze([
  'intentionalDirect',
  'fallbackDirect',
]);

export interface DistributedSegment {
  readonly sourceKind: string;
  readonly polyline: string;
  readonly elevation: string | null;
  readonly connected: boolean;
}

export interface DistributedWaypoint {
  readonly typeId: string;
  readonly title: string | null;
  readonly safetyNote: string | null;
  readonly latE7: number;
  readonly lonE7: number;
  readonly eleDm: number | null;
}

type Stored = Record<string, unknown>;

/**
 * J1 rule shared with the trimmed view: a waypoint next to a hidden endpoint
 * would reveal it, so it is removed. Returns the waypoints that stay.
 */
export function visibleWaypoints(route: ParsedRoute, trim: PrivacyTrim): Stored[] {
  const first = route.track[0]!.points[0]!;
  const lastSegment = route.track[route.track.length - 1]!.points;
  const last = lastSegment[lastSegment.length - 1]!;
  const near = (w: Stored, origin: Point, meters: number) =>
    meters > 0 &&
    distanceMeters({ latE7: w.latE7 as number, lonE7: w.lonE7 as number, eleDm: null }, origin) <
      meters;
  return (route.dto.waypoints as Stored[]).filter(
    (w) => !near(w, first, trim.startMeters) && !near(w, last, trim.endMeters),
  );
}

/** Fields derived from the published segments and waypoints only. */
export function derivedDistributionFields(
  track: readonly TrackSegment[],
  sourceKinds: readonly string[],
  waypoints: readonly DistributedWaypoint[],
) {
  const start = track[0]!.points[0]!;
  return {
    waypoints: waypoints
      .map((w, index) => ({
        w,
        index,
        along: distanceAlongTrack(track, { latE7: w.latE7, lonE7: w.lonE7, eleDm: null }),
      }))
      .sort((a, b) => a.along - b.along || a.index - b.index)
      .map(({ w, along }) => ({ ...w, distanceFromStartMeters: along })),
    summary: summarize(track),
    directSegmentCount: sourceKinds.filter((kind) => directSourceKinds.includes(kind)).length,
    start: { latE7: start.latE7, lonE7: start.lonE7 },
    preview: {
      policy: previewPolicy,
      segments: previewTrack(track).map((s) => ({
        polyline: encodePolyline(s.points),
        connected: s.connected,
      })),
    },
  };
}

export function routeDistributionHash(distribution: unknown): string {
  return sha256Hex(canonicalJson(distribution));
}

export type DistributionResult =
  | { readonly ok: true; readonly distribution: Stored; readonly contentHash: string }
  | { readonly ok: false; readonly code: string };

/** Builds the public snapshot of one stored J1 Route and its current trim. */
export function buildRouteDistribution(route: ParsedRoute, trim: PrivacyTrim): DistributionResult {
  const dto = route.dto;
  if (
    route.segments.some((s) => s.sourceKind === 'recordedGps') &&
    (trim.startMeters < recordedGpsMinTrimMeters || trim.endMeters < recordedGpsMinTrimMeters)
  )
    return { ok: false, code: 'privacy_trim_required' };
  if (typeof dto.title !== 'string' || dto.title.trim().length === 0)
    return { ok: false, code: 'title_required' };
  let trimmed: ReturnType<typeof trimTrack>;
  try {
    trimmed = trimTrack(route.track, trim.startMeters, trim.endMeters);
  } catch (e) {
    if (e instanceof GeometryError) return { ok: false, code: e.code };
    throw e;
  }
  const kinds = trimmed.sources.map((index) => route.segments[index]!.sourceKind);
  const segments: DistributedSegment[] = trimmed.track.map((s, i) => ({
    sourceKind: kinds[i]!,
    polyline: encodePolyline(s.points),
    elevation: encodeElevation(s.points),
    connected: s.connected,
  }));
  const waypoints: DistributedWaypoint[] = visibleWaypoints(route, trim).map((w) => ({
    typeId: w.typeId as string,
    title: w.title as string | null,
    safetyNote: w.safetyNote as string | null,
    latE7: w.latE7 as number,
    lonE7: w.lonE7 as number,
    eleDm: w.eleDm as number | null,
  }));
  const profile = dto.profile as Stored;
  const distribution = {
    schema: routeDistributionSchema,
    coordinatePolicy,
    privacyTrimPolicy,
    title: dto.title,
    shape: dto.shape,
    profile: { id: profile.id, version: profile.version },
    segments,
    ...derivedDistributionFields(trimmed.track, kinds, waypoints),
  };
  return { ok: true, distribution, contentHash: routeDistributionHash(distribution) };
}
