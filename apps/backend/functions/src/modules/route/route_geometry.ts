/**
 * J1 canonical Route geometry (`wgs84-e7-dm-v1`): bounded polyline/elevation
 * codecs, summary and the `endpoint-radius-v1` privacy trim. Pure functions;
 * nothing here reads storage, the network or local files.
 */
export const coordinatePolicy = 'wgs84-e7-dm-v1';
export const privacyTrimPolicy = 'endpoint-radius-v1';
export const latE7Max = 900_000_000;
export const lonE7Max = 1_800_000_000;
export const eleDmMin = -5_000;
export const eleDmMax = 90_000;
/** Marks a point without elevation in the elevation stream. */
export const eleAbsent = 1_048_576;
export const maxTrimMeters = 2_000;

export interface Point {
  readonly latE7: number;
  readonly lonE7: number;
  readonly eleDm: number | null;
}
export class GeometryError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

function encodeSigned(value: number, out: string[]): void {
  // Arithmetic, not bit operators: doubled E7 longitudes exceed 32 bits.
  let rest = value < 0 ? -2 * value - 1 : 2 * value;
  while (rest >= 32) {
    out.push(String.fromCharCode(32 + (rest % 32) + 63));
    rest = Math.floor(rest / 32);
  }
  out.push(String.fromCharCode(rest + 63));
}

function decodeSigned(text: string, start: number): [number, number] {
  let cursor = start,
    result = 0,
    factor = 1;
  for (let chunks = 0; ; chunks++) {
    // Seven chunks hold 35 bits, enough for every value of this policy.
    if (cursor >= text.length || chunks >= 7) throw new GeometryError('invalid_geometry');
    const code = text.charCodeAt(cursor++) - 63;
    if (code < 0 || code > 63) throw new GeometryError('invalid_geometry');
    result += (code % 32) * factor;
    factor *= 32;
    if (code < 32) break;
  }
  return [result % 2 === 1 ? -(result + 1) / 2 : result / 2, cursor];
}

export function encodePolyline(points: readonly Point[]): string {
  const out: string[] = [];
  let lat = 0,
    lon = 0;
  for (const p of points) {
    encodeSigned(p.latE7 - lat, out);
    encodeSigned(p.lonE7 - lon, out);
    lat = p.latE7;
    lon = p.lonE7;
  }
  return out.join('');
}

export function encodeElevation(points: readonly Point[]): string | null {
  if (points.every((p) => p.eleDm === null)) return null;
  const out: string[] = [];
  for (const p of points) encodeSigned(p.eleDm ?? eleAbsent, out);
  return out.join('');
}

/**
 * Decodes one segment. `budget` is the number of points still allowed for the
 * whole Route; decoding stops as soon as it is exceeded, before more points
 * are allocated. Range checks happen per point.
 */
export function decodeSegment(polyline: string, elevation: string | null, budget: number): Point[] {
  const coordinates: [number, number][] = [];
  let cursor = 0,
    lat = 0,
    lon = 0;
  while (cursor < polyline.length) {
    if (coordinates.length >= budget) throw new GeometryError('point_limit_exceeded');
    let delta: number;
    [delta, cursor] = decodeSigned(polyline, cursor);
    lat += delta;
    [delta, cursor] = decodeSigned(polyline, cursor);
    lon += delta;
    if (Math.abs(lat) > latE7Max || Math.abs(lon) > lonE7Max)
      throw new GeometryError('invalid_geometry');
    coordinates.push([lat, lon]);
  }
  if (coordinates.length < 2) throw new GeometryError('invalid_geometry');
  const elevations: (number | null)[] = [];
  if (elevation === null) coordinates.forEach(() => elevations.push(null));
  else {
    cursor = 0;
    while (cursor < elevation.length) {
      if (elevations.length >= coordinates.length) throw new GeometryError('invalid_geometry');
      let value: number;
      [value, cursor] = decodeSigned(elevation, cursor);
      if (value !== eleAbsent && (value < eleDmMin || value > eleDmMax))
        throw new GeometryError('invalid_geometry');
      elevations.push(value === eleAbsent ? null : value);
    }
    if (elevations.length !== coordinates.length) throw new GeometryError('invalid_geometry');
  }
  const points = coordinates.map(([latE7, lonE7], i) => ({
    latE7,
    lonE7,
    eleDm: elevations[i] ?? null,
  }));
  // Canonical form only: one byte sequence per geometry, so hashes are stable.
  if (encodePolyline(points) !== polyline || encodeElevation(points) !== elevation)
    throw new GeometryError('invalid_geometry');
  return points;
}

const earthRadiusMeters = 6371008.8;
export function distanceMeters(a: Point, b: Point): number {
  const rad = Math.PI / 180 / 1e7;
  const dLat = (b.latE7 - a.latE7) * rad,
    dLon = (b.lonE7 - a.lonE7) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.latE7 * rad) * Math.cos(b.latE7 * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * earthRadiusMeters * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h)));
}

export interface TrackSegment {
  readonly points: readonly Point[];
  /** True when this segment starts where the previous one ended (shared anchor). */
  readonly connected: boolean;
}

export interface Summary {
  pointCount: number;
  segmentCount: number;
  gapCount: number;
  distanceMeters: number;
  ascentMeters: number | null;
  descentMeters: number | null;
  minElevationMeters: number | null;
  maxElevationMeters: number | null;
}

const round2 = (value: number) => Math.round(value * 100) / 100;
export function summarize(track: readonly TrackSegment[]): Summary {
  let points = 0,
    gaps = 0,
    distance = 0,
    ascent = 0,
    descent = 0;
  let min: number | null = null,
    max: number | null = null;
  track.forEach((segment, index) => {
    if (index > 0 && !segment.connected) gaps++;
    points += segment.points.length;
    segment.points.forEach((p, i) => {
      if (p.eleDm !== null) {
        min = min === null ? p.eleDm : Math.min(min, p.eleDm);
        max = max === null ? p.eleDm : Math.max(max, p.eleDm);
      }
      const prev = segment.points[i - 1];
      if (!prev) return;
      distance += distanceMeters(prev, p);
      if (prev.eleDm !== null && p.eleDm !== null) {
        const d = p.eleDm - prev.eleDm;
        if (d > 0) ascent += d;
        else descent -= d;
      }
    });
  });
  const hasElevation = min !== null;
  return {
    pointCount: points,
    segmentCount: track.length,
    gapCount: gaps,
    distanceMeters: round2(distance),
    ascentMeters: hasElevation ? ascent / 10 : null,
    descentMeters: hasElevation ? descent / 10 : null,
    minElevationMeters: min === null ? null : min / 10,
    maxElevationMeters: max === null ? null : max / 10,
  };
}

export interface TrimResult {
  readonly track: TrackSegment[];
  readonly removedStart: number;
  readonly removedEnd: number;
  readonly reenteredStart: boolean;
  readonly reenteredEnd: boolean;
}

/**
 * `endpoint-radius-v1`: the recording trim semantics applied to a persisted
 * Route. Removes the longest prefix closer than `startMeters` to the first
 * point and the longest suffix closer than `endMeters` to the last point,
 * across segment and gap boundaries. Never interpolates or joins anything.
 */
export function trimTrack(
  track: readonly TrackSegment[],
  startMeters: number,
  endMeters: number,
): TrimResult {
  const flat: { s: number; p: Point }[] = [];
  track.forEach((segment, s) => segment.points.forEach((p) => flat.push({ s, p })));
  const first = flat[0],
    last = flat[flat.length - 1];
  if (!first || !last) throw new GeometryError('privacy_trim_empty');
  let from = 0,
    to = flat.length; // exclusive
  if (startMeters > 0)
    while (from < flat.length && distanceMeters(first.p, flat[from]!.p) < startMeters) from++;
  if (endMeters > 0) while (to > from && distanceMeters(last.p, flat[to - 1]!.p) < endMeters) to--;
  const kept = flat.slice(from, to);
  const out: TrackSegment[] = [];
  let currentIndex = -1;
  let current: Point[] = [];
  let connected = false;
  const flush = () => {
    if (current.length >= 2) out.push({ points: current, connected: out.length > 0 && connected });
    current = [];
  };
  for (const { s, p } of kept) {
    if (s !== currentIndex) {
      flush();
      // A segment boundary inside the kept range keeps the original topology.
      connected = currentIndex >= 0 && track[s]!.connected;
      currentIndex = s;
    }
    current.push(p);
  }
  flush();
  if (out.reduce((n, segment) => n + segment.points.length, 0) < 2)
    throw new GeometryError('privacy_trim_empty');
  return {
    track: out,
    removedStart: from,
    removedEnd: flat.length - to,
    reenteredStart:
      startMeters > 0 && kept.some(({ p }) => distanceMeters(first.p, p) < startMeters),
    reenteredEnd: endMeters > 0 && kept.some(({ p }) => distanceMeters(last.p, p) < endMeters),
  };
}
