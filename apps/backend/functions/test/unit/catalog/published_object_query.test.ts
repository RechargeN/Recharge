// D3.4 §2.3: the additive `publishedObject` and `publishedObjectCandidates`
// Discover queries. The envelope stays exact; only listing types, the enabled
// market and bounded pages are accepted; the answer is the Catalog evaluator's.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { CatalogQueryService } from '../../../src/modules/catalog/application/catalog_query_service.js';
import { handleDiscoverQueryRequest } from '../../../src/modules/catalog/application/discover_query_handler.js';

function fakeService() {
  const calls: { method: string; request: unknown }[] = [];
  const service = {
    publishedObject: (request: unknown) => {
      calls.push({ method: 'publishedObject', request });
      return Promise.resolve({ status: 'withheld' });
    },
    publishedObjectCandidates: (request: unknown) => {
      calls.push({ method: 'publishedObjectCandidates', request });
      return Promise.resolve({ status: 'available', items: [], nextCursor: null });
    },
  };
  return { service: service as unknown as CatalogQueryService, calls };
}

const request = (queryType: string, payload: unknown) => ({
  schemaVersion: 1,
  requestId: 'req-1',
  queryType,
  payload,
});

void test('publishedObject asks the evaluator for exactly one listing type and id', async () => {
  const { service, calls } = fakeService();
  assert.deepEqual(
    await handleDiscoverQueryRequest(
      service,
      request('publishedObject', { marketId: 'LV', typeId: 'rental', contentId: 'abc_1' }),
    ),
    {
      schemaVersion: 1,
      queryType: 'publishedObject',
      requestId: 'req-1',
      kind: 'succeeded',
      publishedObject: { status: 'withheld' },
    },
  );
  assert.deepEqual(calls, [
    {
      method: 'publishedObject',
      request: { typeId: 'rental', contentId: 'abc_1', marketId: 'LV' },
    },
  ]);
});

void test('publishedObjectCandidates passes a bounded page with defaults', async () => {
  const { service, calls } = fakeService();
  const result = await handleDiscoverQueryRequest(
    service,
    request('publishedObjectCandidates', { marketId: 'LV', typeId: 'place' }),
  );
  assert.equal((result as { kind: string }).kind, 'succeeded');
  assert.deepEqual(calls, [
    {
      method: 'publishedObjectCandidates',
      request: { typeId: 'place', marketId: 'LV', text: '', limit: 20 },
    },
  ]);
  await handleDiscoverQueryRequest(
    service,
    request('publishedObjectCandidates', {
      marketId: 'LV',
      typeId: 'session',
      text: 'sauna',
      after: 'c_9',
      limit: 50,
    }),
  );
  assert.deepEqual(calls[1], {
    method: 'publishedObjectCandidates',
    request: { typeId: 'session', marketId: 'LV', text: 'sauna', limit: 50, after: 'c_9' },
  });
});

void test('only listing types, the enabled market, safe ids and bounded pages are accepted', async () => {
  const { service, calls } = fakeService();
  const code = async (queryType: string, payload: unknown) => {
    const result = (await handleDiscoverQueryRequest(service, request(queryType, payload))) as {
      kind: string;
      code: string;
    };
    return `${result.kind}:${result.code}`;
  };
  for (const typeId of ['event', 'activity', 'collection', 'scenario', 'find_people', 1, undefined])
    assert.equal(
      await code('publishedObject', { marketId: 'LV', typeId, contentId: 'a' }),
      'rejected:type_id_invalid',
      String(typeId),
    );
  assert.equal(
    await code('publishedObject', { marketId: 'EE', typeId: 'place', contentId: 'a' }),
    'unsupported:market_disabled',
  );
  for (const contentId of ['', 'a/b', 'x'.repeat(129), 7])
    assert.equal(
      await code('publishedObject', { marketId: 'LV', typeId: 'place', contentId }),
      'rejected:content_id_invalid',
    );
  assert.equal(
    await code('publishedObject', {
      marketId: 'LV',
      typeId: 'place',
      contentId: 'a',
      title: 'x',
    }),
    'unsupported:unknown_field:title',
  );
  for (const bad of [
    { limit: 0 },
    { limit: 51 },
    { limit: 2.5 },
    { text: 'x'.repeat(101) },
    { text: 3 },
    { after: 'a/b' },
  ])
    assert.equal(
      await code('publishedObjectCandidates', { marketId: 'LV', typeId: 'place', ...bad }),
      'rejected:published_object_candidates_invalid',
      JSON.stringify(bad),
    );
  assert.equal(calls.length, 0);
});
