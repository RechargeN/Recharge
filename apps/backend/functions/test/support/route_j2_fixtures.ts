import { randomUUID } from 'node:crypto';

import {
  encodeElevation,
  encodePolyline,
  type Point,
} from '../../src/modules/route/route_geometry.js';

/** Markers that must never appear in a public answer (notes, descriptions, provenance). */
export const j2PrivateMarkers = Object.freeze([
  'PRIVATE-note',
  'PRIVATE-description',
  'PRIVATE-source',
]);

export type P = [number, number, number?];
export const pt = ([latE7, lonE7, eleDm]: P): Point => ({ latE7, lonE7, eleDm: eleDm ?? null });

/** A walk east along a parallel near Riga: `step` E7 units (~0.6 m per 100). */
export function line(n: number, start = 0, step = 1000, ele?: number): P[] {
  return Array.from(
    { length: n },
    (_, i) => [569_496_000, 241_052_000 + (start + i) * step, ele] as P,
  );
}

/** A wiggly walk: every point leaves the straight line, so simplification has work. */
export function zigzag(n: number, step = 1000): P[] {
  return Array.from(
    { length: n },
    (_, i) =>
      [569_496_000 + (i % 7) * 300 - (i % 3) * 200, 241_052_000 + i * step, 100 + (i % 5)] as P,
  );
}

/** A canonical J1 Route DTO from parts; `gapAfter` leaves an explicit gap. */
export function routeOf(
  parts: P[][],
  options: { gapAfter?: number[]; kinds?: string[]; title?: string } = {},
) {
  const anchors: Record<string, unknown>[] = [];
  const segments: Record<string, unknown>[] = [];
  let previousTo: string | null = null;
  parts.forEach((points, order) => {
    const first = points[0]!,
      last = points[points.length - 1]!;
    let from = previousTo;
    if (from === null || options.gapAfter?.includes(order - 1)) {
      from = randomUUID();
      anchors.push({ anchorId: from, latE7: first[0], lonE7: first[1] });
    }
    const to = randomUUID();
    anchors.push({ anchorId: to, latE7: last[0], lonE7: last[1] });
    const p = points.map(pt);
    segments.push({
      segmentId: randomUUID(),
      order,
      fromAnchorId: from,
      toAnchorId: to,
      sourceKind: options.kinds?.[order] ?? 'freehand',
      derivation: 'original',
      sourceId: 'PRIVATE-source',
      parentSegmentId: null,
      polyline: encodePolyline(p),
      elevation: encodeElevation(p),
    });
    previousTo = to;
  });
  return {
    schemaVersion: 1,
    coordinatePolicy: 'wgs84-e7-dm-v1',
    title: options.title ?? 'Riga riverside walk',
    shape: 'oneWay',
    turningAnchorId: null,
    profile: { id: 'walking', version: 1 },
    anchors,
    segments,
    waypoints: [] as Record<string, unknown>[],
  };
}

export function waypoint(at: P, extra: Record<string, unknown> = {}) {
  return {
    waypointId: randomUUID(),
    segmentId: null,
    anchorId: null,
    latE7: at[0],
    lonE7: at[1],
    eleDm: null,
    typeId: 'water',
    trackState: 'offTrackConfirmed',
    title: 'Tap',
    description: 'PRIVATE-description',
    note: 'PRIVATE-note',
    safetyNote: 'Slippery after rain',
    ...extra,
  };
}

/** The public Content body around one distribution (RP-08, RP-10). */
export function routeContentBody(input: {
  readonly routeId: string;
  readonly routeRevisionId: string;
  readonly contentHash: string;
  readonly distribution: Record<string, unknown>;
}) {
  return {
    title: input.distribution.title,
    shortDescription: 'A calm riverside walk through Riga parks',
    fullDescription: 'A calm riverside walk through Riga parks with benches and a water tap.',
    contentLocale: 'en',
    categoryId: 'art_culture_museums',
    subcategoryId: 'art_walk',
    media: {},
    route: {
      ref: {
        routeId: input.routeId,
        routeRevisionId: input.routeRevisionId,
        contentHash: input.contentHash,
      },
      distribution: input.distribution,
    },
  };
}
