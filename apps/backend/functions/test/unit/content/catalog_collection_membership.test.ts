// D3.4 §2.3: the Content-side adapter of the Catalog-owned evaluator. Each of
// the five Collection item types is asked as its own Content type; the
// Catalog answer maps one to one; anything unexpected, a failure or a type
// outside the closed list (including prototype keys) never becomes `ready`.
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CatalogCollectionMembership,
  collectionObjectContentTypes,
  type ListingStatusReader,
} from '../../../src/modules/content/infrastructure/catalog_collection_membership.js';

function reader(answer: (typeId: string) => string | Error) {
  const asked: { typeId: string; contentId: string; marketId: string }[] = [];
  const catalog: ListingStatusReader = {
    status: (input) => {
      asked.push({ ...input });
      const result = answer(input.typeId);
      return result instanceof Error ? Promise.reject(result) : Promise.resolve({ status: result });
    },
  };
  return { catalog, asked };
}

void test('each Collection item type is asked as its Content type', async () => {
  assert.deepEqual(collectionObjectContentTypes, {
    place: 'place',
    route: 'route',
    bookableSession: 'session',
    classWorkshop: 'class_workshop',
    rental: 'rental',
  });
  const { catalog, asked } = reader(() => 'eligible');
  const membership = new CatalogCollectionMembership(catalog);
  for (const objectType of Object.keys(collectionObjectContentTypes))
    assert.equal(
      await membership.statusOf({
        objectType: objectType as never,
        objectId: `id-${objectType}`,
        marketId: 'LV',
      }),
      'ready',
    );
  assert.deepEqual(
    asked.map((item) => item.typeId),
    ['place', 'route', 'session', 'class_workshop', 'rental'],
  );
  assert.ok(asked.every((item) => item.marketId === 'LV' && item.contentId.startsWith('id-')));
});

void test('Catalog answers map one to one; anything else is unavailable', async () => {
  const expected: Readonly<Record<string, string>> = {
    eligible: 'ready',
    withheld: 'withheld',
    unknown: 'unknown',
    forbidden: 'forbidden',
    unavailable: 'unavailable',
    surprising: 'unavailable',
  };
  for (const [status, mapped] of Object.entries(expected)) {
    const membership = new CatalogCollectionMembership(reader(() => status).catalog);
    assert.equal(
      await membership.statusOf({ objectType: 'rental', objectId: 'x', marketId: 'LV' }),
      mapped,
      status,
    );
  }
  const failing = new CatalogCollectionMembership(reader(() => new Error('down')).catalog);
  assert.equal(
    await failing.statusOf({ objectType: 'place', objectId: 'x', marketId: 'LV' }),
    'unavailable',
  );
});

void test('a type outside the closed list is refused without asking Catalog', async () => {
  const { catalog, asked } = reader(() => 'eligible');
  const membership = new CatalogCollectionMembership(catalog);
  for (const objectType of ['event', 'collection', 'scenario', 'constructor', 'toString'])
    assert.equal(
      await membership.statusOf({ objectType: objectType as never, objectId: 'x', marketId: 'LV' }),
      'forbidden',
      objectType,
    );
  assert.equal(asked.length, 0);
});
