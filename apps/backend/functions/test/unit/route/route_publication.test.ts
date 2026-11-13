import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import {
  routeDistributionTrack,
  validateRouteBody,
  validateRouteDistribution,
} from '../../../src/modules/content/domain/type_rules/route_rules.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';
import { projectFact, type ContentFact } from '../../../src/modules/catalog/domain/catalog_item.js';
import { evaluate } from '../../../src/modules/catalog/domain/evaluation.js';
import { parseDiscoverQuery } from '../../../src/modules/catalog/domain/discover_query.js';
import { parseEntityId } from '../../../src/shared/ids.js';
import { parseRoute, type ParsedRoute } from '../../../src/modules/route/route_contract.js';
import {
  buildRouteDistribution,
  recordedGpsMinTrimMeters,
  routeDistributionHash,
} from '../../../src/modules/route/route_distribution.js';
import {
  decodeSegment,
  previewMaxPoints,
  previewTrack,
  trimTrack,
} from '../../../src/modules/route/route_geometry.js';
import {
  j2PrivateMarkers,
  line,
  type P,
  routeContentBody,
  routeOf,
  waypoint,
  zigzag,
} from '../../support/route_j2_fixtures.js';

type Json = Record<string, unknown>;

function parsed(dto: unknown): ParsedRoute {
  const result = parseRoute(dto);
  assert.ok(result.ok, JSON.stringify(result));
  return result.value;
}

function distribute(dto: unknown, startMeters = 0, endMeters = 0) {
  const built = buildRouteDistribution(parsed(dto), { startMeters, endMeters });
  assert.ok(built.ok, JSON.stringify(built));
  return built;
}

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  const author = randomUUID();
  return {
    typeId: 'route',
    marketId: 'LV',
    publisherRef: { type: 'user', id: author },
    createdByUserId: author,
    actorUserId: author,
    nowUtc: '2026-10-21T10:00:00.000Z',
    draftRevision: 1,
    market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
    lookups: {
      supportsLocale: (locale) => ['en', 'ru', 'lv'].includes(locale),
      subcategoryApplies: (typeId, categoryId, subcategoryId) =>
        typeId === 'route' && categoryId === 'art_culture_museums' && subcategoryId === 'art_walk',
      requiredCriteria: () => [],
      pointInServiceArea: () => true,
    },
    ...overrides,
  } as ContentValidationContext;
}

void test('RP-02/§5: the distribution is the trimmed track and an exact allowlist', () => {
  const dto = routeOf([line(60), line(60, 59)]);
  dto.waypoints.push(waypoint(line(1, 1)[0]!), waypoint(line(1, 80)[0]!));
  const { distribution, contentHash } = distribute(dto, 50, 50);
  assert.equal(contentHash, routeDistributionHash(distribution));
  assert.deepEqual(Object.keys(distribution).sort(), [
    'coordinatePolicy',
    'directSegmentCount',
    'preview',
    'privacyTrimPolicy',
    'profile',
    'schema',
    'segments',
    'shape',
    'start',
    'summary',
    'title',
    'waypoints',
  ]);
  const text = JSON.stringify(distribution);
  for (const marker of j2PrivateMarkers) assert.equal(text.includes(marker), false, marker);
  for (const hidden of ['anchor', 'turning', 'segmentId', 'sourceId', 'parent', 'startMeters'])
    assert.equal(text.includes(hidden), false, hidden);
  // The waypoint inside the hidden start is gone; the other keeps its safety note.
  const waypoints = distribution.waypoints as Json[];
  assert.equal(waypoints.length, 1);
  assert.equal(waypoints[0]!.safetyNote, 'Slippery after rain');
  assert.equal('note' in waypoints[0]!, false);
  // The public start is the first point that survived the trim, not the real start.
  const trimmed = trimTrack(parsed(dto).track, 50, 50).track;
  assert.deepEqual(distribution.start, {
    latE7: trimmed[0]!.points[0]!.latE7,
    lonE7: trimmed[0]!.points[0]!.lonE7,
  });
  assert.notEqual((distribution.start as Json).lonE7, line(1)[0]![1]);
  assert.deepEqual(validateRouteDistribution(distribution), []);
});

void test('RP-02: recorded GPS needs at least 200 m hidden at both ends', () => {
  const dto = routeOf([line(800)], { kinds: ['recordedGps'] });
  for (const [start, end] of [
    [0, 0],
    [recordedGpsMinTrimMeters - 1, recordedGpsMinTrimMeters],
    [recordedGpsMinTrimMeters, recordedGpsMinTrimMeters - 1],
  ] as const)
    assert.deepEqual(buildRouteDistribution(parsed(dto), { startMeters: start, endMeters: end }), {
      ok: false,
      code: 'privacy_trim_required',
    });
  assert.equal(buildRouteDistribution(parsed(dto), { startMeters: 200, endMeters: 200 }).ok, true);
  // A short recorded Route is empty after the mandatory trim and is not published.
  const short = routeOf([line(40)], { kinds: ['recordedGps'] });
  assert.deepEqual(buildRouteDistribution(parsed(short), { startMeters: 200, endMeters: 200 }), {
    ok: false,
    code: 'privacy_trim_empty',
  });
  // Authored geometry may stay untrimmed.
  assert.equal(
    buildRouteDistribution(parsed(routeOf([line(10)])), { startMeters: 0, endMeters: 0 }).ok,
    true,
  );
});

void test('RP-07: direct segments and gaps stay explicit', () => {
  const dto = routeOf([line(10), line(2, 9), line(10, 10), line(10, 40)], {
    kinds: ['freehand', 'intentionalDirect', 'freehand', 'fallbackDirect'],
    gapAfter: [2],
  });
  const { distribution } = distribute(dto);
  const segments = distribution.segments as Json[];
  assert.deepEqual(
    segments.map((s) => [s.sourceKind, s.connected]),
    [
      ['freehand', false],
      ['intentionalDirect', true],
      ['freehand', true],
      ['fallbackDirect', false],
    ],
  );
  assert.equal(distribution.directSegmentCount, 2);
  assert.equal((distribution.summary as Json).gapCount, 1);
  const preview = (distribution.preview as Json).segments as Json[];
  assert.deepEqual(
    preview.map((s) => s.connected),
    segments.map((s) => s.connected),
  );
});

void test('RP-12: the preview is deterministic, bounded and made of trimmed points only', () => {
  const shifted = zigzag(4000).map(([a, b, c]): P => [a, b + 4_000_000, c ?? 0]);
  const dto = routeOf([zigzag(4000), shifted], {
    gapAfter: [0],
  });
  const track = trimTrack(parsed(dto).track, 300, 300).track;
  const first = previewTrack(track);
  assert.deepEqual(previewTrack(track), first);
  const total = first.reduce((n, s) => n + s.points.length, 0);
  assert.ok(total <= previewMaxPoints && total > 100, String(total));
  const known = new Set(track.flatMap((s) => s.points.map((p) => `${p.latE7}:${p.lonE7}`)));
  for (const [index, segment] of first.entries()) {
    const source = track[index]!.points;
    assert.deepEqual(segment.points[0], { ...source[0]!, eleDm: null });
    assert.deepEqual(segment.points.at(-1), { ...source.at(-1)!, eleDm: null });
    for (const p of segment.points) assert.ok(known.has(`${p.latE7}:${p.lonE7}`));
  }
  // A short track is kept as is, without elevation.
  const small = trimTrack(parsed(routeOf([line(20, 0, 1000, 5)])).track, 0, 0).track;
  assert.equal(previewTrack(small)[0]!.points.length, 20);
  assert.equal(previewTrack(small)[0]!.points[0]!.eleDm, null);
});

void test('the validator recomputes every derived field and refuses anything else', () => {
  const dto = routeOf([zigzag(500)]);
  dto.waypoints.push(waypoint(zigzag(500)[300]!), waypoint(zigzag(500)[100]!));
  const { distribution } = distribute(dto);
  assert.deepEqual(validateRouteDistribution(distribution), []);
  const tamper = (change: (d: Json) => void) => {
    const copy = structuredClone(distribution);
    change(copy);
    return validateRouteDistribution(copy);
  };
  assert.deepEqual(
    tamper((d) => ((d.summary as Json).distanceMeters = 1)),
    ['route.derived_mismatch'],
  );
  assert.deepEqual(
    tamper((d) => (d.waypoints as Json[]).reverse()),
    ['route.derived_mismatch'],
  );
  assert.deepEqual(
    tamper((d) => ((d.preview as Json).segments = [])),
    ['route.derived_mismatch'],
  );
  assert.ok(tamper((d) => (d.anchors = [])).includes('route.distribution.unknown_field:anchors'));
  assert.deepEqual(
    tamper((d) => (((d.waypoints as Json[])[0] as Json).note = 'x')),
    ['route.waypoints'],
  );
  assert.deepEqual(
    tamper((d) => (((d.segments as Json[])[0] as Json).sourceKind = 'routed')),
    ['route.geometry'],
  );
  assert.deepEqual(
    tamper((d) => (((d.segments as Json[])[0] as Json).connected = true)),
    ['route.geometry'],
  );
  assert.deepEqual(
    tamper((d) => (d.title = ' ')),
    ['route.title'],
  );
  assert.equal(routeDistributionTrack({ segments: [] }), null);
});

void test('RP-04/08/10: the Content body binds title, hash, category and publisher', () => {
  const { distribution, contentHash } = distribute(routeOf([line(30)]));
  const body = routeContentBody({
    routeId: randomUUID(),
    routeRevisionId: randomUUID(),
    contentHash,
    distribution,
  });
  assert.deepEqual(validateRouteBody(body, context()), []);
  // A Page may publish (RP-04); a foreign user may not.
  assert.deepEqual(
    validateRouteBody(
      body,
      context({ publisherRef: { type: 'page', id: parseEntityId(randomUUID()) } }),
    ),
    [],
  );
  assert.deepEqual(
    validateRouteBody(
      body,
      context({ publisherRef: { type: 'user', id: parseEntityId(randomUUID()) } }),
    ),
    ['route_publisher_ineligible'],
  );
  assert.deepEqual(validateRouteBody({ ...body, title: 'Other' }, context()), [
    'route.title_mismatch',
  ]);
  assert.deepEqual(validateRouteBody({ ...body, subcategoryId: 'artist_talk' }, context()), [
    'route.category',
  ]);
  const tampered = structuredClone(body);
  (tampered.route.distribution.summary as Json).pointCount = 1;
  assert.deepEqual(validateRouteBody(tampered, context()), [
    'route.distribution_hash',
    'route.derived_mismatch',
  ]);
  assert.ok(
    validateRouteBody({ ...body, visibility: 'unlisted' }, context()).includes(
      'route.unknown_field:visibility',
    ),
  );
  assert.deepEqual(validateRouteBody(body, context({ marketId: 'EE' })), ['route.market']);
});

void test('BCK08-OD-04-R: the projection carries start, summary and preview; Details keep the track', () => {
  const { distribution, contentHash } = distribute(routeOf([zigzag(1200)]), 100, 100);
  const routeId = randomUUID();
  const body = routeContentBody({
    routeId,
    routeRevisionId: randomUUID(),
    contentHash,
    distribution,
  });
  const fact: ContentFact = {
    schemaVersion: 1,
    effectId: randomUUID(),
    kind: 'ContentPublished',
    contentId: routeId,
    publishedRevisionId: randomUUID(),
    pointerRevision: 1,
    visibility: 'visible',
    typeId: 'route',
    publisherRef: { type: 'user', id: randomUUID() },
    marketId: 'LV',
    referenceRevisions: {},
    occurredAtUtc: '2026-10-21T10:00:00.000Z',
  };
  const revision = {
    contentId: routeId,
    publishedRevisionId: fact.publishedRevisionId,
    typeId: 'route',
    marketId: 'LV',
    body,
    referenceRevisions: {},
    publishedAtUtc: '2026-10-21T10:00:00.000Z',
  };
  const input = { fact, revision, typeVisibilityPolicy: 'public_catalog' };
  assert.deepEqual(projectFact(input), { state: 'excluded', reason: 'type_disabled' });
  const outcome = projectFact({ ...input, routeEnabled: true });
  assert.equal(outcome.state, 'listed');
  if (outcome.state !== 'listed' || outcome.item.typeId !== 'route') return;
  const item = outcome.item;
  const start = distribution.start as Json;
  assert.deepEqual(item.point, {
    latitude: Number(start.latE7) / 1e7,
    longitude: Number(start.lonE7) / 1e7,
  });
  assert.deepEqual(item.preview, distribution.preview);
  assert.deepEqual(item.track.segments, distribution.segments);
  const previewPoints = item.preview.segments.reduce(
    (n, s) => n + decodeSegment(s.polyline, null, 10_000).length,
    0,
  );
  assert.ok(previewPoints <= previewMaxPoints);
  // A body that does not match its pinned hash is never projected.
  const broken = structuredClone(body);
  broken.route.ref.contentHash = '0'.repeat(64);
  assert.deepEqual(
    projectFact({ ...input, routeEnabled: true, revision: { ...revision, body: broken } }),
    { state: 'excluded', reason: 'invalid_projection' },
  );

  // RP-13: text, category and geo apply; time and price filters do not.
  const query = (raw: Json) => {
    const q = parseDiscoverQuery(
      { schemaVersion: 1, marketId: 'LV', typeIds: ['route'], ...raw },
      false,
      false,
      false,
      true,
    );
    assert.ok(q.ok, JSON.stringify(q));
    return q.query;
  };
  assert.equal(evaluate(item, query({}), Date.now()).eligible, true);
  assert.equal(
    evaluate(item, query({ categoryIds: ['art_culture_museums'] }), Date.now()).eligible,
    true,
  );
  assert.deepEqual(evaluate(item, query({ categoryIds: ['nature'] }), Date.now()), {
    eligible: false,
    reason: 'category',
  });
  assert.deepEqual(evaluate(item, query({ price: { free: true } }), Date.now()), {
    eligible: false,
    reason: 'route_filter_inapplicable',
  });
  assert.equal(
    parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', typeIds: ['route'] }).ok,
    false,
  );
});
