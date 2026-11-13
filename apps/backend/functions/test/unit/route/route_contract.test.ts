import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import {
  hashCommand,
  parseCommand,
  parsePrivacyTrim,
  parseQuery,
  parseRoute,
  routeJsonBytes,
  routeLimits,
  type ParsedRoute,
} from '../../../src/modules/route/route_contract.js';
import {
  decodeSegment,
  eleAbsent,
  encodeElevation,
  encodePolyline,
  summarize,
  trimTrack,
  type Point,
} from '../../../src/modules/route/route_geometry.js';

type P = [number, number, number?];
const pt = ([latE7, lonE7, eleDm]: P): Point => ({ latE7, lonE7, eleDm: eleDm ?? null });
/** A walk east along a parallel near Riga: `step` E7 units (~0.6 m per 100). */
function line(n: number, start = 0, step = 1000, ele?: number): P[] {
  return Array.from(
    { length: n },
    (_, i) => [569_496_000, 241_052_000 + (start + i) * step, ele] as P,
  );
}
export function routeOf(parts: P[][], options: { gapAfter?: number[]; kinds?: string[] } = {}) {
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
      sourceId: 'author-freehand',
      parentSegmentId: null,
      polyline: encodePolyline(p),
      elevation: encodeElevation(p),
    });
    previousTo = to;
  });
  return {
    schemaVersion: 1,
    coordinatePolicy: 'wgs84-e7-dm-v1',
    title: 'Riga loop',
    shape: 'oneWay',
    turningAnchorId: null,
    profile: { id: 'walking', version: 1 },
    anchors,
    segments,
    waypoints: [] as Record<string, unknown>[],
  };
}
function waypoint(at: P, extra: Record<string, unknown> = {}) {
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
    description: null,
    note: null,
    safetyNote: null,
    ...extra,
  };
}
function ok(raw: unknown): ParsedRoute {
  const r = parseRoute(raw);
  assert.ok(r.ok, JSON.stringify(r));
  return r.value;
}
const code = (raw: unknown) => {
  const r = parseRoute(raw);
  return r.ok ? 'ok' : r.code;
};

void test('polyline/elevation codecs are canonical, bounded and range checked', () => {
  const extreme: Point[] = [
    { latE7: 900_000_000, lonE7: 1_800_000_000, eleDm: 90_000 },
    { latE7: -900_000_000, lonE7: -1_800_000_000, eleDm: -5_000 },
    { latE7: 0, lonE7: 0, eleDm: null },
  ];
  const polyline = encodePolyline(extreme),
    elevation = encodeElevation(extreme);
  assert.deepEqual(decodeSegment(polyline, elevation, 3), extreme);
  assert.equal(encodeElevation([pt([1, 1]), pt([2, 2])]), null);
  assert.throws(() => decodeSegment(polyline, elevation, 2), /point_limit_exceeded/);
  for (const bad of [
    polyline + '?', // trailing incomplete value
    polyline.slice(0, -1),
    polyline.replace(/.$/, ' '), // character outside the alphabet
    '~~~~~~~~?', // value wider than 35 bits
    encodePolyline([pt([900_000_001, 0]), pt([0, 0])]),
    encodePolyline([pt([0, 0])]), // a segment needs two points
  ])
    assert.throws(() => decodeSegment(bad, null, 10), /invalid_geometry/);
  const two = [pt([0, 0, 10]), pt([1, 1, 10])];
  for (const bad of [
    encodeElevation([pt([0, 0, 90_001]), pt([1, 1, 1])]),
    encodeElevation([pt([0, 0, 1])]), // count mismatch
    encodeElevation([...two, pt([2, 2, 1])]),
  ])
    assert.throws(() => decodeSegment(encodePolyline(two), bad, 10), /invalid_geometry/);
  // Partial elevation uses the sentinel; nothing is dropped or interpolated.
  const partial = [pt([0, 0, 15]), pt([1, 1]), pt([2, 2, -3])];
  assert.deepEqual(
    decodeSegment(encodePolyline(partial), encodeElevation(partial), 3).map((p) => p.eleDm),
    [15, null, -3],
  );
  assert.equal(eleAbsent > 90_000, true);
});

void test('limits accept the exact bound and refuse the next value', () => {
  // Points: 10 000 across segments; 10 001 aborts decoding.
  const exact = routeOf([line(5_000), line(5_000, 4_999)]);
  assert.equal(
    ok(exact).track.reduce((n, s) => n + s.points.length, 0),
    routeLimits.points,
  );
  assert.equal(code(routeOf([line(5_000), line(5_001, 4_999)])), 'point_limit_exceeded');
  // Segments 120 / 121, anchors 100 / 101.
  const many = (n: number) => Array.from({ length: n }, (_, i) => line(2, i));
  const r120 = routeOf(many(120));
  r120.anchors = r120.anchors.slice(0, 100);
  assert.equal(code(r120), 'invalid_geometry'); // trimmed anchors are referenced
  assert.equal(code({ ...routeOf(many(99)) }), 'ok'); // 100 anchors
  assert.equal(code(routeOf(many(100))), 'request_invalid'); // 101 anchors
  const shared = routeOf(many(2));
  const s0 = shared.segments[0]!;
  shared.segments = Array.from({ length: 121 }, (_, order) => ({
    ...s0,
    segmentId: randomUUID(),
    order,
  }));
  assert.equal(code(shared), 'request_invalid');
  shared.segments = shared.segments.slice(0, 120);
  assert.equal(code(shared), 'ok');
  // Waypoints 250 / 251 and text bounds.
  const base = routeOf([line(3)]);
  base.waypoints = Array.from({ length: 250 }, () => waypoint([569_496_000, 241_052_000]));
  assert.equal(code(base), 'ok');
  base.waypoints.push(waypoint([569_496_000, 241_052_000]));
  assert.equal(code(base), 'request_invalid');
  for (const [field, max] of [
    ['title', 120],
    ['description', 1000],
    ['note', 1000],
    ['safetyNote', 1000],
  ] as const) {
    const r = routeOf([line(3)]);
    r.waypoints = [waypoint([0, 0], { [field]: 'x'.repeat(max) })];
    assert.equal(code(r), 'ok');
    r.waypoints = [waypoint([0, 0], { [field]: 'x'.repeat(max + 1) })];
    assert.equal(code(r), 'request_invalid', field);
  }
  const titled = routeOf([line(3)]);
  assert.equal(code({ ...titled, title: 'x'.repeat(200) }), 'ok');
  assert.equal(code({ ...titled, title: 'x'.repeat(201) }), 'request_invalid');
  // Canonical JSON bytes: exactly 200 KiB passes, one more byte is refused first.
  const big = routeOf([line(3)]);
  const filler = () =>
    waypoint([0, 0], { description: 'd'.repeat(1000), note: 'n'.repeat(1000), safetyNote: '' });
  while (routeJsonBytes(big) + 2400 < routeLimits.routeJsonBytes) big.waypoints.push(filler());
  let fill = routeLimits.routeJsonBytes - routeJsonBytes(big);
  for (const w of big.waypoints) {
    const n = Math.min(fill, 1000);
    w.safetyNote = 's'.repeat(n);
    fill -= n;
    if (fill === 0) break;
  }
  assert.equal(routeJsonBytes(big), routeLimits.routeJsonBytes);
  assert.equal(code(big), 'ok');
  const last = big.waypoints.find((w) => (w.safetyNote as string).length < 1000)!;
  last.safetyNote = (last.safetyNote as string) + 's';
  assert.equal(routeJsonBytes(big), routeLimits.routeJsonBytes + 1);
  assert.equal(code(big), 'payload_too_large');
});

void test('coordinates, numbers, kinds, references and text are refused explicitly', () => {
  const r = () => routeOf([line(3)]);
  const anchor = (v: Record<string, unknown>) => {
    const x = r();
    Object.assign(x.anchors[0]!, v);
    return code(x);
  };
  assert.equal(anchor({ latE7: 900_000_001 }), 'invalid_geometry');
  assert.equal(anchor({ lonE7: -1_800_000_001 }), 'invalid_geometry');
  for (const bad of [1.5, Number.NaN, Number.POSITIVE_INFINITY, '569496000', null])
    assert.equal(anchor({ latE7: bad }), 'invalid_geometry');
  const kind = (k: string) => {
    const x = r();
    x.segments[0]!.sourceKind = k;
    return code(x);
  };
  assert.equal(kind('routed'), 'license_blocked');
  assert.equal(kind('generated'), 'license_blocked');
  assert.equal(kind('verifiedActivity'), 'request_invalid');
  const extra = r();
  (extra.segments[0] as Record<string, unknown>).timestamps = [];
  assert.equal(code(extra), 'request_invalid');
  assert.equal(code({ ...r(), extensions: {} }), 'request_invalid');
  assert.equal(code({ ...r(), coordinatePolicy: 'wgs84-e5' }), 'request_invalid');
  assert.equal(code({ ...r(), schemaVersion: 2 }), 'request_invalid');
  const missingAnchor = r();
  missingAnchor.segments[0]!.toAnchorId = randomUUID();
  assert.equal(code(missingAnchor), 'invalid_geometry');
  const orderGap = routeOf([line(3), line(3, 2)]);
  orderGap.segments[1]!.order = 2;
  assert.equal(code(orderGap), 'invalid_geometry');
  for (const text of ['a\u0000b', 'a\u001bb', '\ud800', 'x\udc00'])
    assert.equal(code({ ...r(), title: text }), 'request_invalid');
  assert.equal(code({ ...r(), title: 'Tab\tand\nnewline 🌲' }), 'ok');
  const wp = r();
  wp.waypoints = [waypoint([0, 0], { segmentId: randomUUID() })];
  assert.equal(code(wp), 'invalid_geometry');
});

void test('explicit gaps are kept and summarized, never joined', () => {
  const route = ok(routeOf([line(3), line(3, 10, 1000, 50)], { gapAfter: [0] }));
  assert.deepEqual(
    route.track.map((s) => s.connected),
    [false, false],
  );
  const s = summarize(route.track);
  assert.equal(s.gapCount, 1);
  assert.equal(s.pointCount, 6);
  // Only the in-segment distances count; nothing spans the gap.
  const one = summarize([route.track[0]!]).distanceMeters;
  assert.ok(Math.abs(s.distanceMeters - 2 * one) < 0.02);
  assert.equal(s.minElevationMeters, 5);
});

void test('import provenance is verified against the data it declares', () => {
  const sourceId = 'gpx-0123456789abcdef';
  const imported = (parts: P[][], kinds: string[], bridges: number | null) => {
    const route = routeOf(parts, { kinds });
    route.segments.forEach((s) => {
      if (s.sourceKind === 'importedGpx') s.sourceId = sourceId;
      else s.sourceId = 'gpx-direct-bridge';
    });
    return {
      schemaVersion: 1,
      requestId: randomUUID(),
      ownerContext: randomUUID(),
      idempotencyKey: 'import-' + randomUUID(),
      commandType: 'import',
      routeId: randomUUID(),
      expectedRevision: 0,
      route,
      importSource: {
        sourceId,
        parserVersion: 'gpx-inspector-v2',
        transformations: [
          { code: 'strip-timestamps', count: null },
          { code: 'strip-metadata', count: null },
          { code: 'quantize-e7-dm', count: null },
          ...(bridges === null ? [] : [{ code: 'direct-gap-bridge', count: bridges }]),
        ],
      },
    };
  };
  const a = line(3),
    b = line(3, 10);
  const bridge: P[] = [a[2]!, b[0]!];
  const good = imported([a, bridge, b], ['importedGpx', 'intentionalDirect', 'importedGpx'], 1);
  const parsed = parseCommand(good);
  assert.ok(parsed.ok, JSON.stringify(parsed));
  const result = (c: unknown) => {
    const r = parseCommand(c);
    return r.ok ? 'ok' : r.code;
  };
  assert.equal(
    result(imported([a, bridge, b], ['importedGpx', 'intentionalDirect', 'importedGpx'], 0)),
    'provenance_unverified',
  );
  assert.equal(
    result(imported([a, bridge, b], ['importedGpx', 'recordedGps', 'importedGpx'], 1)),
    'provenance_unverified',
  );
  assert.equal(
    result(
      imported([a, [a[2]!, b[1]!], b], ['importedGpx', 'intentionalDirect', 'importedGpx'], 1),
    ),
    'provenance_unverified',
  );
  assert.equal(
    result(imported([[a[0]!, a[0]!, a[1]!]], ['importedGpx'], null)),
    'provenance_unverified',
  );
  const foreign = imported([a], ['importedGpx'], null);
  foreign.route.segments[0]!.sourceId = 'gpx-ffffffffffffffff';
  assert.equal(result(foreign), 'provenance_unverified');
  const noStrip = imported([a], ['importedGpx'], null);
  noStrip.importSource.transformations.shift();
  assert.equal(result(noStrip), 'request_invalid');
  assert.equal(result({ ...good, expectedRevision: 1 }), 'request_invalid');
  assert.equal(result({ ...good, provenance: { verification: 'verified' } }), 'request_invalid');
  // The intent hash ignores only the per-attempt request ID.
  const again = parseCommand({ ...good, requestId: randomUUID() });
  assert.ok(again.ok && parsed.ok);
  assert.equal(hashCommand(again.value), hashCommand(parsed.value));
  const changed = parseCommand({ ...good, route: { ...good.route, title: 'changed' } });
  assert.ok(changed.ok);
  assert.notEqual(hashCommand(changed.value), hashCommand(parsed.value));
});

void test('privacy trim: bounds, prefix/suffix, gaps, re-entry, empty and summary', () => {
  assert.deepEqual(parsePrivacyTrim({ startMeters: 2000, endMeters: 0 }), {
    startMeters: 2000,
    endMeters: 0,
  });
  for (const bad of [
    { startMeters: 2001, endMeters: 0 },
    { startMeters: -1, endMeters: 0 },
    { startMeters: 1.5, endMeters: 0 },
    { startMeters: 0 },
    { startMeters: 0, endMeters: 0, keepOriginal: true },
  ])
    assert.equal(parsePrivacyTrim(bad), null);
  // 1000 E7 units of longitude at 56.95°N ≈ 6.08 m.
  const route = ok(routeOf([line(10, 0, 1000, 100), line(10, 9, 1000, 120)]));
  const none = trimTrack(route.track, 0, 0);
  assert.deepEqual(none.track, route.track);
  const trimmed = trimTrack(route.track, 20, 13);
  // Start: points at 0, 6, 12, 18 m are closer than 20 m; end: 0, 6, 12 m.
  assert.equal(trimmed.removedStart, 4);
  assert.equal(trimmed.removedEnd, 3);
  assert.equal(trimmed.track[0]!.points[0]!.lonE7, 241_056_000);
  const lastSeg = trimmed.track[trimmed.track.length - 1]!.points;
  assert.equal(lastSeg[lastSeg.length - 1]!.lonE7, 241_067_000);
  // A whole first segment inside the radius disappears; the next starts unconnected.
  const crossing = trimTrack(route.track, 60, 0);
  assert.equal(crossing.track.length, 1);
  assert.equal(crossing.track[0]!.connected, false);
  assert.ok(crossing.track[0]!.points.every((p) => p.eleDm === 120));
  assert.equal(summarize(crossing.track).segmentCount, 1);
  assert.throws(() => trimTrack(route.track, 2000, 0), /privacy_trim_empty/);
  assert.throws(() => trimTrack(route.track, 60, 60), /privacy_trim_empty/);
  // Explicit gaps survive trimming as gaps.
  const gapped = ok(routeOf([line(5), line(5, 20), line(5, 40)], { gapAfter: [0, 1] }));
  const g = trimTrack(gapped.track, 10, 10);
  assert.deepEqual(
    g.track.map((s) => s.connected),
    [false, false, false],
  );
  assert.equal(summarize(g.track).gapCount, 2);
  // A loop coming back near the start keeps those points and reports it.
  const loop = ok(routeOf([[...line(5), ...line(5).reverse().slice(1)]]));
  const back = trimTrack(loop.track, 10, 0);
  assert.equal(back.reenteredStart, true);
  assert.equal(back.track[0]!.points.length, 9 - 2);
});

void test('queries are strict and carry no authority fields', () => {
  const id = randomUUID();
  assert.deepEqual(parseQuery({ schemaVersion: 1, requestId: id, queryType: 'get', routeId: id }), {
    queryType: 'get',
    routeId: id,
  });
  assert.ok(parseQuery({ schemaVersion: 1, requestId: id, queryType: 'list', cursor: null }));
  for (const bad of [
    { schemaVersion: 1, requestId: id, queryType: 'get', routeId: id, ownerId: id },
    { schemaVersion: 1, requestId: id, queryType: 'trimmedView', routeId: id },
    { schemaVersion: 1, requestId: id, queryType: 'trimmedView', routeId: id, expectedRevision: 0 },
    { schemaVersion: 1, requestId: id, queryType: 'source', routeId: id },
    { schemaVersion: 1, requestId: id, queryType: 'list', cursor: 'x' },
  ])
    assert.equal(parseQuery(bad), null);
});
