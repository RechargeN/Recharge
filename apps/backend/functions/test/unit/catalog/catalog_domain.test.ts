import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  availabilityNotConnectedReason,
  catalogTestOnlyConfig,
} from '../../../src/modules/catalog/domain/catalog_config.js';
import {
  projectFact,
  type CatalogEventItem,
  type ContentFact,
  type SourceRevision,
} from '../../../src/modules/catalog/domain/catalog_item.js';
import { parseDiscoverQuery } from '../../../src/modules/catalog/domain/discover_query.js';
import {
  compareKeys,
  decidingOccurrence,
  evaluate,
  projectionFreshness,
  referenceFreshness,
  strictest,
} from '../../../src/modules/catalog/domain/evaluation.js';
import {
  issueCursor,
  issueSnapshot,
  verifyCursor,
  verifySnapshot,
} from '../../../src/modules/catalog/domain/snapshot.js';

const refs = {
  marketConfigRevisionId: 'mc-1',
  taxonomyRevisionId: 'tx-1',
  localizationRevisionId: 'loc-1',
};

function fact(overrides: Partial<ContentFact> = {}): ContentFact {
  return {
    schemaVersion: 1,
    effectId: 'rev-1:ContentPublished',
    kind: 'ContentPublished',
    contentId: 'content-1',
    publishedRevisionId: 'rev-1',
    pointerRevision: 1,
    visibility: 'visible',
    typeId: 'event',
    publisherRef: { type: 'page', id: 'page-1' },
    marketId: 'LV',
    referenceRevisions: refs,
    occurredAtUtc: '2035-01-01T00:00:00.000Z',
    ...overrides,
  };
}

function slot(id: string, start: string, end: string) {
  return { id, localDate: start.slice(0, 10), startAtUtc: start, endAtUtc: end };
}

function body(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    title: 'Ceramics evening',
    shortDescription: 'Shape your own bowl on the wheel',
    fullDescription: 'Private-ish long text that the Catalog must not copy into cards',
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    eventArchetype: 'workshop',
    primaryParticipationMode: 'learn',
    format: 'offline',
    location: {
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      formattedAddress: 'Brivibas iela 1',
      latitude: 56.95,
      longitude: 24.1,
      pinConfirmed: true,
    },
    schedule: { timezoneId: 'Europe/Riga', scheduleMode: 'oneTime' },
    eventSlots: [slot('s1', '2035-10-10T15:00:00.000Z', '2035-10-10T17:00:00.000Z')],
    pricing: { mode: 'free', paymentCollectionMode: 'none' },
    registration: { mode: 'external', externalBookingUrl: 'https://example.com/book' },
    publicOnlineUrl: undefined,
    media: {
      coverImage: { mediaId: 'asset-1', altText: 'A bowl' },
      gallery: [],
      rightsConfirmed: true,
    },
    audience: { wheelchairAccessible: true },
    visibility: 'public',
    ...overrides,
  };
}

function revision(overrides: Record<string, unknown> = {}): SourceRevision {
  return {
    contentId: 'content-1',
    publishedRevisionId: 'rev-1',
    typeId: 'event',
    marketId: 'LV',
    body: body(overrides),
    referenceRevisions: refs,
    publishedAtUtc: '2026-09-01T10:00:00.000Z',
  };
}

function item(
  overrides: Record<string, unknown> = {},
  factOverrides: Partial<ContentFact> = {},
): CatalogEventItem {
  const outcome = projectFact({
    fact: fact(factOverrides),
    revision: { ...revision(overrides), contentId: factOverrides.contentId ?? 'content-1' },
    typeVisibilityPolicy: 'public_catalog',
  });
  assert.equal(outcome.state, 'listed', JSON.stringify(outcome));
  if (outcome.state !== 'listed' || outcome.item.typeId !== 'event')
    throw new Error('not listed Event');
  return outcome.item;
}

void test('the test-only config holds exactly the approved E1 values', () => {
  assert.deepEqual(
    {
      pageSizeDefault: catalogTestOnlyConfig.pageSizeDefault,
      pageSizeMax: catalogTestOnlyConfig.pageSizeMax,
      candidateLimit: catalogTestOnlyConfig.candidateLimit,
      deliveryBatchSize: catalogTestOnlyConfig.deliveryBatchSize,
      deliveryMaxBatchesPerRun: catalogTestOnlyConfig.deliveryMaxBatchesPerRun,
      reconcileBatchSize: catalogTestOnlyConfig.reconcileBatchSize,
      rebuildBatchSize: catalogTestOnlyConfig.rebuildBatchSize,
      projectionMaxAgeSeconds: catalogTestOnlyConfig.projectionMaxAgeSeconds,
      snapshotTtlSeconds: catalogTestOnlyConfig.snapshotTtlSeconds,
      maxRadiusKm: catalogTestOnlyConfig.maxRadiusKm,
      maxLiteralTextLength: catalogTestOnlyConfig.maxLiteralTextLength,
      maxTextTokens: catalogTestOnlyConfig.maxTextTokens,
      minTextTokenLength: catalogTestOnlyConfig.minTextTokenLength,
      maxTimeWindowDays: catalogTestOnlyConfig.maxTimeWindowDays,
    },
    {
      pageSizeDefault: 20,
      pageSizeMax: 50,
      candidateLimit: 2000,
      deliveryBatchSize: 100,
      deliveryMaxBatchesPerRun: 50,
      reconcileBatchSize: 200,
      rebuildBatchSize: 200,
      projectionMaxAgeSeconds: 900,
      snapshotTtlSeconds: 600,
      maxRadiusKm: 100,
      maxLiteralTextLength: 100,
      maxTextTokens: 8,
      minTextTokenLength: 2,
      maxTimeWindowDays: 366,
    },
  );
  assert.deepEqual(catalogTestOnlyConfig.serviceAreas.LV, {
    minLatitude: 55.6,
    maxLatitude: 58.1,
    minLongitude: 20.9,
    maxLongitude: 28.3,
  });
});

void test('one applied query has one fingerprint; paging is not a membership field', () => {
  const base = {
    schemaVersion: 1,
    marketId: 'LV',
    categoryIds: ['b', 'a'],
    literalText: 'Pottery  WHEEL',
  };
  const first = parseDiscoverQuery(base);
  const second = parseDiscoverQuery({
    ...base,
    categoryIds: ['a', 'b', 'a'],
    literalText: 'wheel pottery',
    pageSize: 5,
  });
  assert.ok(first.ok && second.ok);
  if (!first.ok || !second.ok) return;
  assert.equal(first.fingerprint, second.fingerprint);
  assert.deepEqual(first.query.textTokens, ['pottery', 'wheel']);
  const other = parseDiscoverQuery({ ...base, sort: 'soonest', price: { free: true } });
  assert.ok(other.ok && other.fingerprint !== first.fingerprint);
});

void test('unknown, disabled or unconnected parts are typed refusals, never defaults', () => {
  const refuse = (raw: Record<string, unknown>) => {
    const result = parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', ...raw });
    return result.ok ? 'ok' : `${result.kind}:${result.code}`;
  };
  assert.equal(refuse({ mood: 'calm' }), 'unsupported:unknown_field:mood');
  assert.equal(refuse({ schemaVersion: 2 }), 'unsupported:unsupported_version');
  assert.equal(refuse({ marketId: 'EE' }), 'unsupported:market_disabled');
  assert.equal(refuse({ typeIds: ['place'] }), 'unsupported:type_disabled:place');
  assert.equal(refuse({ onlyAvailable: true }), `unsupported:${availabilityNotConnectedReason}`);
  assert.equal(availabilityNotConnectedReason, 'booking_availability_source_not_connected_in_e1');
  assert.equal(refuse({ sort: 'distance' }), 'invalid:distance_requires_center');
  assert.equal(refuse({ sort: 'popular' }), 'unsupported:sort_unsupported');
  assert.equal(
    refuse({ geo: { center: { latitude: 59.4, longitude: 24.7 } } }),
    'invalid:geo_center_invalid',
  );
  assert.equal(
    refuse({ geo: { center: { latitude: 56.95, longitude: 24.1 }, radiusKm: 100.5 } }),
    'invalid:radius_too_large',
  );
  assert.equal(
    refuse({
      timeWindow: { fromUtc: '2035-01-01T00:00:00.000Z', toUtc: '2036-01-03T00:00:00.000Z' },
    }),
    'invalid:time_window_too_long',
  );
  assert.equal(
    refuse({ price: { maxAmountMinor: 500, currencyCode: 'USD' } }),
    'unsupported:currency_mismatch',
  );
  assert.equal(refuse({ literalText: 'a b' }), 'invalid:text_too_short');
  assert.equal(refuse({ literalText: 'aa bb cc dd ee ff gg hh ii' }), 'invalid:too_many_tokens');
  assert.equal(refuse({ literalText: 'x'.repeat(101) }), 'invalid:text_too_long');
  assert.equal(refuse({ pageSize: 51 }), 'invalid:page_size_invalid');
  assert.equal(refuse({}), 'ok');
});

void test('the projection is an allowlist and hidden content is never listed', () => {
  const listed = item();
  assert.equal(listed.title, 'Ceramics evening');
  assert.deepEqual(listed.point, { latitude: 56.95, longitude: 24.1 });
  assert.equal(listed.wheelchairAccessible, true);
  // v2: the full description is a Details fact; cards never carry it (the
  // Discover query test checks Feed, Search and Map payloads).
  assert.equal(
    listed.fullDescription,
    'Private-ish long text that the Catalog must not copy into cards',
  );
  assert.equal(listed.scheduleMode, 'oneTime');
  assert.equal(listed.publishedAtUtc, '2026-09-01T10:00:00.000Z');
  assert.equal(JSON.stringify(listed).includes('example.com'), false, 'no booking URL');
  const excluded = (
    factOverrides: Partial<ContentFact>,
    bodyOverrides: Record<string, unknown> = {},
    policy = 'public_catalog',
  ) => {
    const outcome = projectFact({
      fact: fact(factOverrides),
      revision: revision(bodyOverrides),
      typeVisibilityPolicy: policy,
    });
    return outcome.state === 'excluded' ? outcome.reason : 'listed';
  };
  assert.equal(excluded({ visibility: 'withdrawn' }), 'withdrawn');
  assert.equal(excluded({ visibility: 'restricted' }), 'restricted');
  assert.equal(excluded({ visibility: 'archived' }), 'archived');
  assert.equal(excluded({}, { visibility: 'unlisted' }), 'unlisted');
  assert.equal(excluded({}, { visibility: 'private' }), 'private');
  assert.equal(excluded({ typeId: 'place' }), 'type_disabled');
  assert.equal(excluded({}, {}, 'consent_limited'), 'consent_limited');
  assert.equal(excluded({ publishedRevisionId: 'rev-other' }), 'invalid_projection');
  const online = item({ format: 'online', location: { marketCityId: 'riga', countryCode: 'LV' } });
  assert.equal(online.point, null);
  assert.equal(online.notMappable, 'onlineOnly');
});

void test('time: running first, upcoming by start, ended out; the earliest open occurrence decides', () => {
  const now = Date.parse('2035-10-10T16:00:00.000Z');
  const query = parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV' });
  assert.ok(query.ok);
  if (!query.ok) return;
  const multi = item({
    eventSlots: [
      slot('a', '2035-10-09T15:00:00.000Z', '2035-10-09T17:00:00.000Z'),
      slot('b', '2035-10-10T15:00:00.000Z', '2035-10-10T17:00:00.000Z'),
      slot('c', '2035-10-11T15:00:00.000Z', '2035-10-11T17:00:00.000Z'),
    ],
  });
  assert.equal(decidingOccurrence(multi, now, null)?.id, 'b', 'the ended one is skipped');
  const evaluated = evaluate(multi, query.query, now);
  assert.ok(evaluated.eligible);
  if (!evaluated.eligible) return;
  assert.equal(evaluated.key[1], now, 'a running occurrence sorts as now');
  assert.equal(evaluated.remainingOccurrences, 1);
  const ended = item({
    eventSlots: [slot('a', '2035-10-09T15:00:00.000Z', '2035-10-09T17:00:00.000Z')],
  });
  assert.deepEqual(evaluate(ended, query.query, now), { eligible: false, reason: 'ended' });
  // With a window, the earliest open occurrence inside it decides.
  const windowed = parseDiscoverQuery({
    schemaVersion: 1,
    marketId: 'LV',
    timeWindow: { fromUtc: '2035-10-11T00:00:00.000Z', toUtc: '2035-10-12T00:00:00.000Z' },
  });
  assert.ok(windowed.ok);
  if (!windowed.ok) return;
  assert.equal(decidingOccurrence(multi, now, windowed.query.timeWindow)?.id, 'c');
});

void test('order is total: running ties break by id, distance only with a center', () => {
  const now = Date.parse('2035-10-10T16:00:00.000Z');
  const soonest = parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV' });
  const byDistance = parseDiscoverQuery({
    schemaVersion: 1,
    marketId: 'LV',
    sort: 'distance',
    geo: { center: { latitude: 56.95, longitude: 24.1 } },
  });
  assert.ok(soonest.ok && byDistance.ok);
  if (!soonest.ok || !byDistance.ok) return;
  const running = (id: string) =>
    item(
      { eventSlots: [slot('r', '2035-10-10T15:00:00.000Z', '2035-10-10T17:00:00.000Z')] },
      { contentId: id },
    );
  const upcoming = item(
    { eventSlots: [slot('u', '2035-10-10T18:00:00.000Z', '2035-10-10T19:00:00.000Z')] },
    { contentId: 'a-upcoming' },
  );
  const keys = [running('z-run'), upcoming, running('b-run')].map((value) => {
    const result = evaluate(value, soonest.query, now);
    assert.ok(result.eligible);
    return result.eligible ? result.key : null;
  });
  const order = keys
    .map((key, index) => ({ key: key!, index }))
    .sort((left, right) => compareKeys(left.key, right.key))
    .map((entry) => entry.key[3]);
  assert.deepEqual(order, ['b-run', 'z-run', 'a-upcoming']);

  const near = item(
    { location: { city: 'Riga', latitude: 56.951, longitude: 24.101, pinConfirmed: true } },
    { contentId: 'near' },
  );
  const far = item(
    { location: { city: 'Jurmala', latitude: 56.97, longitude: 23.77, pinConfirmed: true } },
    { contentId: 'far' },
  );
  const online = item({ format: 'online', location: {} }, { contentId: 'online' });
  const distanceOrder = [far, online, near]
    .map((value) => {
      const result = evaluate(value, byDistance.query, now);
      assert.ok(result.eligible);
      return result.eligible ? result.key : null;
    })
    .sort((left, right) => compareKeys(left!, right!))
    .map((key) => key![3]);
  assert.deepEqual(distanceOrder, ['near', 'far', 'online'], 'no point comes last');
});

void test('snapshot and cursor are opaque, bound and expire', () => {
  const nowMs = Date.parse('2035-10-10T16:00:00.000Z');
  const { token } = issueSnapshot({
    queryFingerprint: 'fp-1',
    projectionSetId: 'set-1',
    projectionSetRevision: 7,
    referenceDatasetRevision: 'r',
    nowMs,
  });
  assert.ok(verifySnapshot(token, 'fp-1', nowMs).ok);
  assert.deepEqual(verifySnapshot(token, 'fp-2', nowMs), {
    ok: false,
    code: 'snapshot_query_mismatch',
  });
  assert.deepEqual(verifySnapshot(token, 'fp-1', nowMs + 600_000), {
    ok: false,
    code: 'snapshot_expired',
  });
  const [payload, tag] = token.split('.');
  const forged = `${Buffer.from(JSON.stringify({ ...JSON.parse(Buffer.from(payload!, 'base64url').toString()), projectionSetRevision: 99 })).toString('base64url')}.${tag}`;
  assert.deepEqual(verifySnapshot(forged, 'fp-1', nowMs), { ok: false, code: 'snapshot_invalid' });
  const cursor = issueCursor(token, [0, 1, 0, 'id']);
  assert.ok(verifyCursor(cursor, token).ok);
  const other = issueSnapshot({
    queryFingerprint: 'fp-1',
    projectionSetId: 'set-1',
    projectionSetRevision: 8,
    referenceDatasetRevision: 'r',
    nowMs,
  });
  assert.deepEqual(verifyCursor(cursor, other.token), {
    ok: false,
    code: 'cursor_snapshot_mismatch',
  });
});

void test('freshness: age decides, expired data is never fresh, the strictest wins', () => {
  const synced = '2035-10-10T16:00:00.000Z';
  const at = (seconds: number) => Date.parse(synced) + seconds * 1000;
  assert.equal(projectionFreshness(synced, at(900)), 'fresh');
  assert.equal(projectionFreshness(synced, at(901)), 'stale');
  assert.equal(projectionFreshness(null, at(0)), 'unknown');
  assert.equal(projectionFreshness(synced, at(-1)), 'unknown', 'a future sync is not fresh');
  assert.equal(referenceFreshness(refs, refs), 'fresh');
  assert.equal(referenceFreshness(refs, { ...refs, taxonomyRevisionId: 'tx-2' }), 'stale');
  assert.equal(strictest('fresh', 'stale'), 'stale');
  assert.equal(strictest('stale', 'unknown', 'fresh'), 'unknown');
});
