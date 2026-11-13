import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { CatalogQueryService } from '../../../src/modules/catalog/application/catalog_query_service.js';
import { handleDiscoverQueryRequest } from '../../../src/modules/catalog/application/discover_query_handler.js';

const snapshot = { projectionSetId: 'set-1', projectionSetRevision: 7 };
const freshness = {
  overall: 'fresh',
  projection: 'fresh',
  reference: 'fresh',
  availability: 'not_connected',
};

/** Records every call; answers with canned results. */
function fakeService(overrides: Partial<Record<'feed' | 'map' | 'details', unknown>> = {}) {
  const calls: { method: string; request: unknown }[] = [];
  const answer = (method: 'feed' | 'map' | 'details', fallback: unknown) => (request: unknown) => {
    calls.push({ method, request });
    return Promise.resolve(overrides[method] ?? fallback);
  };
  const page = {
    kind: 'succeeded',
    snapshotToken: 'token-1',
    snapshot,
    freshness,
    items: [{ ref: { typeId: 'event', contentId: 'c-1' }, publishedRevisionId: 'r-1' }],
    nextCursor: null,
    totalEligible: 1,
  };
  const service = {
    feed: answer('feed', page),
    search: answer('feed', page),
    map: answer('map', {
      kind: 'succeeded',
      snapshotToken: 'token-1',
      snapshot,
      freshness,
      leaves: [],
      notMappable: 0,
      totalEligible: 0,
    }),
    details: answer('details', {
      kind: 'succeeded',
      state: 'listed',
      reason: null,
      item: { contentId: 'c-1' },
      changedSinceSnapshot: false,
    }),
  };
  return { service: service as unknown as CatalogQueryService, calls };
}

const request = (queryType: string, payload: unknown, extra: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  requestId: 'req-1',
  queryType,
  payload,
  ...extra,
});

void test('the envelope is exact and refuses by name', async () => {
  const { service, calls } = fakeService();
  const code = async (raw: unknown) => {
    const result = (await handleDiscoverQueryRequest(service, raw)) as {
      kind: string;
      code: string;
    };
    return `${result.kind}:${result.code}`;
  };
  assert.equal(await code([]), 'rejected:invalid_request');
  assert.equal(
    await code(request('feed', { query: {} }, { extra: 1 })),
    'unsupported:unknown_field:extra',
  );
  assert.equal(
    await code({ ...request('feed', { query: {} }), requestId: 'bad id' }),
    'rejected:request_id_invalid',
  );
  assert.equal(await code(request('feed', null)), 'rejected:payload_invalid');
  assert.equal(await code(request('feed', {})), 'rejected:query_required');
  assert.equal(
    await code(request('feed', { query: {}, snapshotToken: '' })),
    'rejected:snapshot_token_invalid',
  );
  assert.equal(await code(request('feed', { query: {}, cursor: 5 })), 'rejected:cursor_invalid');
  assert.equal(await code(request('map', { query: {}, viewport: 3 })), 'rejected:viewport_invalid');
  assert.equal(
    await code(request('details', { contentId: '../x' })),
    'rejected:content_id_invalid',
  );
  assert.equal(
    await code(request('details', { contentId: 'c-1', snapshotToken: 'token-1' })),
    'rejected:snapshot_requires_query',
  );
  assert.equal(
    await code(request('details', { contentId: 'c-1', cursor: 'x' })),
    'unsupported:unknown_field:cursor',
  );
  assert.equal(calls.length, 0, 'no refused request reaches the Catalog');
});

void test('Feed and Search return the snapshot page; Search uses the literal path', async () => {
  const { service, calls } = fakeService();
  const feed = await handleDiscoverQueryRequest(service, request('feed', { query: { a: 1 } }));
  assert.deepEqual(feed, {
    schemaVersion: 1,
    queryType: 'feed',
    requestId: 'req-1',
    kind: 'succeeded',
    page: {
      snapshotToken: 'token-1',
      projectionSetId: 'set-1',
      projectionSetRevision: 7,
      freshness,
      items: [{ ref: { typeId: 'event', contentId: 'c-1' }, publishedRevisionId: 'r-1' }],
      nextCursor: null,
      totalEligible: 1,
    },
  });
  await handleDiscoverQueryRequest(
    service,
    request('search', { query: { a: 1 }, snapshotToken: 't', cursor: 'c' }),
  );
  assert.deepEqual(calls[1], {
    method: 'feed',
    request: { query: { a: 1 }, snapshotToken: 't', cursor: 'c' },
  });
});

void test('Details never carries an item for excluded or absent content', async () => {
  const { service } = fakeService({
    details: {
      kind: 'succeeded',
      state: 'excluded',
      reason: 'restricted',
      item: { leaked: true },
      changedSinceSnapshot: true,
    },
  });
  const result = await handleDiscoverQueryRequest(
    service,
    request('details', { contentId: 'c-1', snapshotToken: 't', query: {} }),
  );
  assert.deepEqual(result.details, {
    state: 'excluded',
    reason: 'restricted',
    item: null,
    changedSinceSnapshot: true,
  });
});

void test('a Catalog failure keeps its typed kind and code', async () => {
  const { service } = fakeService({ feed: { kind: 'stale', code: 'snapshot_superseded' } });
  assert.deepEqual(await handleDiscoverQueryRequest(service, request('feed', { query: {} })), {
    schemaVersion: 1,
    queryType: 'feed',
    requestId: 'req-1',
    kind: 'stale',
    code: 'snapshot_superseded',
  });
});
