import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { record } from '../library/library_contract.js';
import {
  coordinatePolicy,
  decodeSegment,
  GeometryError,
  latE7Max,
  lonE7Max,
  eleDmMax,
  eleDmMin,
  maxTrimMeters,
  type Point,
  type TrackSegment,
} from './route_geometry.js';

/** J1: default-off, Emulator-only owner Route storage and sync. */
export const routeFlag = 'route.owner_sync';
export const routeCollections = Object.freeze({
  routes: 'routes',
  receipts: 'routeCommandReceipts',
});
export const routeLimits = Object.freeze({
  routeJsonBytes: 204_800,
  points: 10_000,
  segments: 120,
  anchors: 100,
  waypoints: 250,
  title: 200,
  waypointTitle: 120,
  longText: 1_000,
  listPage: 50,
});
/** Provider geometry (`routed`, `generated`) is not storable without license evidence. */
export const storableSourceKinds = Object.freeze([
  'importedGpx',
  'recordedGps',
  'freehand',
  'intentionalDirect',
  'fallbackDirect',
]);
const providerSourceKinds = ['routed', 'generated'];
export const importTransformations = Object.freeze([
  'strip-timestamps',
  'strip-metadata',
  'quantize-e7-dm',
  'drop-consecutive-duplicates',
  'direct-gap-bridge',
]);
const requiredImportTransformations = ['strip-timestamps', 'strip-metadata', 'quantize-e7-dm'];

export type Result = Readonly<Record<string, unknown>>;
export const reject = (code: string, extra: Result = {}): Result => ({
  schemaVersion: 1,
  kind: 'rejected',
  code,
  ...extra,
});

/** Every key present and no other key: absent optional values are explicit nulls. */
function keys(value: Record<string, unknown>, expected: readonly string[]): boolean {
  const actual = Object.keys(value);
  return actual.length === expected.length && actual.every((k) => expected.includes(k));
}
const integer = (v: unknown, min: number, max: number): v is number =>
  Number.isSafeInteger(v) && (v as number) >= min && (v as number) <= max;
const token = (v: unknown): v is string =>
  typeof v === 'string' && /^[A-Za-z0-9._:-]{1,64}$/.test(v);
// Control characters other than tab/newline and lone surrogates are refused.
const controls = /[\u0000-\u0008\u000B-\u001F\u007F]/;
function safeText(v: unknown, max: number): boolean {
  if (typeof v !== 'string' || v.length > max || controls.test(v)) return false;
  for (let i = 0; i < v.length; i++) {
    const c = v.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff) {
      const next = v.charCodeAt(i + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) return false;
      i++;
    } else if (c >= 0xdc00 && c <= 0xdfff) return false;
  }
  return true;
}
const optionalText = (v: unknown, max: number) => v === null || safeText(v, max);
const optionalId = (v: unknown) => v === null || isEntityId(v);
const lat = (v: unknown) => integer(v, -latE7Max, latE7Max);
const lon = (v: unknown) => integer(v, -lonE7Max, lonE7Max);

export interface ParsedSegment {
  readonly segmentId: string;
  readonly sourceKind: string;
  readonly sourceId: string;
  readonly parentSegmentId: string | null;
  readonly points: readonly Point[];
}
export interface ParsedRoute {
  readonly dto: Record<string, unknown>;
  readonly segments: readonly ParsedSegment[];
  readonly track: readonly TrackSegment[];
}
type Parsed<T> = { ok: true; value: T } | { ok: false; code: string };
const fail = (code: string): { ok: false; code: string } => ({ ok: false, code });

export function routeJsonBytes(route: unknown): number {
  return Buffer.byteLength(JSON.stringify(route ?? null), 'utf8');
}

/** Full structural and geometric validation of one canonical Route. */
export function parseRoute(raw: unknown): Parsed<ParsedRoute> {
  if (routeJsonBytes(raw) > routeLimits.routeJsonBytes) return fail('payload_too_large');
  const r = record(raw);
  if (
    !r ||
    !keys(r, [
      'schemaVersion',
      'coordinatePolicy',
      'title',
      'shape',
      'turningAnchorId',
      'profile',
      'anchors',
      'segments',
      'waypoints',
    ]) ||
    r.schemaVersion !== 1 ||
    r.coordinatePolicy !== coordinatePolicy ||
    !safeText(r.title, routeLimits.title) ||
    !['oneWay', 'loop', 'outAndBack'].includes(String(r.shape)) ||
    !optionalId(r.turningAnchorId) ||
    !Array.isArray(r.anchors) ||
    !Array.isArray(r.segments) ||
    !Array.isArray(r.waypoints)
  )
    return fail('request_invalid');
  const profile = record(r.profile);
  if (!profile || !keys(profile, ['id', 'version']) || !token(profile.id))
    return fail('request_invalid');
  if (!integer(profile.version, 1, 1000)) return fail('request_invalid');
  if (r.anchors.length > routeLimits.anchors) return fail('request_invalid');
  if (r.segments.length > routeLimits.segments) return fail('request_invalid');
  if (r.waypoints.length > routeLimits.waypoints) return fail('request_invalid');
  const ids = new Set<string>();
  const unique = (id: unknown) => {
    if (!isEntityId(id) || ids.has(id)) return false;
    ids.add(id);
    return true;
  };
  const anchors = new Set<string>();
  for (const raw of r.anchors) {
    const a = record(raw);
    if (!a || !keys(a, ['anchorId', 'latE7', 'lonE7']) || !unique(a.anchorId))
      return fail('request_invalid');
    if (!lat(a.latE7) || !lon(a.lonE7)) return fail('invalid_geometry');
    anchors.add(a.anchorId as string);
  }
  if (r.turningAnchorId !== null && !anchors.has(r.turningAnchorId))
    return fail('invalid_geometry');
  const byOrder = new Map<number, Record<string, unknown>>();
  for (const raw of r.segments) {
    const s = record(raw);
    if (
      !s ||
      !keys(s, [
        'segmentId',
        'order',
        'fromAnchorId',
        'toAnchorId',
        'sourceKind',
        'derivation',
        'sourceId',
        'parentSegmentId',
        'polyline',
        'elevation',
      ]) ||
      !unique(s.segmentId) ||
      !integer(s.order, 0, routeLimits.segments - 1) ||
      byOrder.has(s.order) ||
      !['original', 'mirrored'].includes(String(s.derivation)) ||
      !token(s.sourceId) ||
      !optionalId(s.parentSegmentId) ||
      typeof s.polyline !== 'string' ||
      (s.elevation !== null && typeof s.elevation !== 'string')
    )
      return fail('request_invalid');
    if (providerSourceKinds.includes(String(s.sourceKind))) return fail('license_blocked');
    if (!storableSourceKinds.includes(String(s.sourceKind))) return fail('request_invalid');
    if (!anchors.has(s.fromAnchorId as string) || !anchors.has(s.toAnchorId as string))
      return fail('invalid_geometry');
    byOrder.set(s.order, s);
  }
  const segments: ParsedSegment[] = [];
  const track: TrackSegment[] = [];
  let budget = routeLimits.points;
  for (let order = 0; order < byOrder.size; order++) {
    const s = byOrder.get(order);
    if (!s) return fail('invalid_geometry');
    let points: Point[];
    try {
      points = decodeSegment(s.polyline as string, s.elevation as string | null, budget);
    } catch (e) {
      if (e instanceof GeometryError) return fail(e.code);
      throw e;
    }
    budget -= points.length;
    const previous = byOrder.get(order - 1);
    segments.push({
      segmentId: s.segmentId as string,
      sourceKind: s.sourceKind as string,
      sourceId: s.sourceId as string,
      parentSegmentId: s.parentSegmentId as string | null,
      points,
    });
    track.push({ points, connected: previous?.toAnchorId === s.fromAnchorId });
  }
  for (const raw of r.waypoints) {
    const w = record(raw);
    if (
      !w ||
      !keys(w, [
        'waypointId',
        'segmentId',
        'anchorId',
        'latE7',
        'lonE7',
        'eleDm',
        'typeId',
        'trackState',
        'title',
        'description',
        'note',
        'safetyNote',
      ]) ||
      !unique(w.waypointId) ||
      !optionalId(w.segmentId) ||
      !optionalId(w.anchorId) ||
      !token(w.typeId) ||
      !['onTrack', 'offTrackConfirmed', 'unresolved'].includes(String(w.trackState)) ||
      !optionalText(w.title, routeLimits.waypointTitle) ||
      !optionalText(w.description, routeLimits.longText) ||
      !optionalText(w.note, routeLimits.longText) ||
      !optionalText(w.safetyNote, routeLimits.longText)
    )
      return fail('request_invalid');
    if (
      !lat(w.latE7) ||
      !lon(w.lonE7) ||
      (w.eleDm !== null && !integer(w.eleDm, eleDmMin, eleDmMax)) ||
      (w.segmentId !== null && !segments.some((s) => s.segmentId === w.segmentId)) ||
      (w.anchorId !== null && !anchors.has(w.anchorId))
    )
      return fail('invalid_geometry');
  }
  return { ok: true, value: { dto: r, segments, track } };
}

export interface ImportSource {
  sourceId: string;
  parserVersion: string;
  transformations: { code: string; count: number | null }[];
}
export interface PrivacyTrim {
  startMeters: number;
  endMeters: number;
}
export interface RouteCommand {
  schemaVersion: 1;
  requestId: string;
  ownerContext: string;
  idempotencyKey: string;
  commandType: 'import' | 'save' | 'setPrivacyTrim' | 'delete';
  routeId: string;
  expectedRevision: number;
  route?: ParsedRoute;
  importSource?: ImportSource;
  privacyTrim?: PrivacyTrim;
  raw: Record<string, unknown>;
}

function parseImportSource(raw: unknown): ImportSource | null {
  const s = record(raw);
  if (
    !s ||
    !keys(s, ['sourceId', 'parserVersion', 'transformations']) ||
    !token(s.sourceId) ||
    !/^gpx-[0-9a-f]{16}$/.test(s.sourceId) ||
    !token(s.parserVersion) ||
    !Array.isArray(s.transformations) ||
    s.transformations.length > importTransformations.length
  )
    return null;
  const seen = new Set<string>();
  for (const raw of s.transformations) {
    const t = record(raw);
    if (
      !t ||
      !keys(t, ['code', 'count']) ||
      !importTransformations.includes(String(t.code)) ||
      seen.has(String(t.code)) ||
      (t.count !== null && !integer(t.count, 0, 200_000))
    )
      return null;
    seen.add(String(t.code));
  }
  if (!requiredImportTransformations.every((c) => seen.has(c))) return null;
  return s as unknown as ImportSource;
}

export function parsePrivacyTrim(raw: unknown): PrivacyTrim | null {
  const t = record(raw);
  return t &&
    keys(t, ['startMeters', 'endMeters']) &&
    integer(t.startMeters, 0, maxTrimMeters) &&
    integer(t.endMeters, 0, maxTrimMeters)
    ? { startMeters: t.startMeters, endMeters: t.endMeters }
    : null;
}

/** Parses the envelope; the Route body is size-checked before it is walked. */
export function parseCommand(raw: unknown): Parsed<RouteCommand> {
  const r = record(raw);
  const base = [
    'schemaVersion',
    'requestId',
    'ownerContext',
    'idempotencyKey',
    'commandType',
    'routeId',
    'expectedRevision',
  ];
  const extra: Record<string, string[]> = {
    import: ['route', 'importSource'],
    save: ['route'],
    setPrivacyTrim: ['privacyTrim'],
    delete: [],
  };
  const type = String(r?.commandType);
  const fields = extra[type];
  if (
    !r ||
    !fields ||
    !Object.hasOwn(extra, type) ||
    !keys(r, [...base, ...fields]) ||
    r.schemaVersion !== 1 ||
    !isEntityId(r.requestId) ||
    !isEntityId(r.ownerContext) ||
    !isIdempotencyKey(r.idempotencyKey) ||
    !isEntityId(r.routeId) ||
    !integer(r.expectedRevision, 0, Number.MAX_SAFE_INTEGER) ||
    (type === 'import' && r.expectedRevision !== 0)
  )
    return fail('request_invalid');
  const command = { ...(r as unknown as RouteCommand), raw: r };
  if (type === 'import' || type === 'save') {
    const route = parseRoute(r.route);
    if (!route.ok) return route;
    command.route = route.value;
  }
  if (type === 'import') {
    const source = parseImportSource(r.importSource);
    if (!source) return fail('request_invalid');
    command.importSource = source;
    const verdict = verifyImport(command.route!, source);
    if (verdict) return fail(verdict);
  }
  if (type === 'setPrivacyTrim') {
    const trim = parsePrivacyTrim(r.privacyTrim);
    if (!trim) return fail('privacy_trim_invalid');
    command.privacyTrim = trim;
  }
  return { ok: true, value: command };
}

const samePoint = (a: Point | undefined, b: Point | undefined) =>
  !!a && !!b && a.latE7 === b.latE7 && a.lonE7 === b.lonE7;

/**
 * The import command is the only path that creates `importedGpx` geometry. It
 * may contain imported parts and the user-confirmed 2-point direct bridges
 * between them, nothing else; declared transformations must match the data.
 */
function verifyImport(route: ParsedRoute, source: ImportSource): string | null {
  const segments = route.segments;
  if (segments.length === 0) return 'invalid_geometry';
  let bridges = 0;
  for (let i = 0; i < segments.length; i++) {
    const s = segments[i]!;
    if (s.sourceKind === 'importedGpx') {
      if (s.sourceId !== source.sourceId || s.parentSegmentId !== null)
        return 'provenance_unverified';
      for (let j = 1; j < s.points.length; j++)
        if (samePoint(s.points[j - 1], s.points[j])) return 'provenance_unverified';
    } else if (s.sourceKind === 'intentionalDirect') {
      const before = segments[i - 1],
        after = segments[i + 1];
      if (
        s.points.length !== 2 ||
        before?.sourceKind !== 'importedGpx' ||
        after?.sourceKind !== 'importedGpx' ||
        !route.track[i]!.connected ||
        !route.track[i + 1]!.connected ||
        !samePoint(before.points[before.points.length - 1], s.points[0]) ||
        !samePoint(s.points[1], after.points[0])
      )
        return 'provenance_unverified';
      bridges++;
    } else return 'provenance_unverified';
  }
  const declared = source.transformations.find((t) => t.code === 'direct-gap-bridge');
  if ((declared?.count ?? 0) !== bridges) return 'provenance_unverified';
  return null;
}

/** Hash of the immutable intent: everything except the per-attempt request ID. */
export const hashCommand = (c: RouteCommand) => {
  const body = { ...c.raw };
  delete body.requestId;
  return sha256Hex(canonicalJson(body));
};

export interface RouteQuery {
  queryType: 'get' | 'list' | 'trimmedView';
  routeId?: string;
  cursor?: string | null;
  expectedRevision?: number;
}
export function parseQuery(raw: unknown): RouteQuery | null {
  const r = record(raw);
  if (!r || r.schemaVersion !== 1 || !isEntityId(r.requestId)) return null;
  switch (r.queryType) {
    case 'get':
      return keys(r, ['schemaVersion', 'requestId', 'queryType', 'routeId']) &&
        isEntityId(r.routeId)
        ? { queryType: 'get', routeId: r.routeId }
        : null;
    case 'list':
      return keys(r, ['schemaVersion', 'requestId', 'queryType', 'cursor']) &&
        (r.cursor === null || isEntityId(r.cursor))
        ? { queryType: 'list', cursor: r.cursor }
        : null;
    case 'trimmedView':
      return keys(r, ['schemaVersion', 'requestId', 'queryType', 'routeId', 'expectedRevision']) &&
        isEntityId(r.routeId) &&
        integer(r.expectedRevision, 1, Number.MAX_SAFE_INTEGER)
        ? { queryType: 'trimmedView', routeId: r.routeId, expectedRevision: r.expectedRevision }
        : null;
    default:
      return null;
  }
}
