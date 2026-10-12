// D3.4 §2.4 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md): the Emulator answers
// Collection from the pinned canonical BCK-20 artifact. Any existing pair
// applies (the mobile taxonomy makes Collection applicable everywhere), an
// unknown pair does not, and a missing artifact cannot be answered.
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  collectionSubcategoryApplies,
  EmulatorSyntheticReferenceData,
} from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import {
  readLocalTaxonomy,
  taxonomyRevisionId,
} from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';

void test('Collection pins the canonical taxonomy revision and applies to every existing pair', async () => {
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'collection',
  });
  assert.ok(resolution.ok);
  assert.equal(resolution.revisions.taxonomyRevisionId, taxonomyRevisionId);
  const taxonomy = readLocalTaxonomy(taxonomyRevisionId);
  assert.ok(taxonomy.ok);
  let pairs = 0;
  for (const category of taxonomy.dataset.categories)
    for (const subcategory of category.subcategories) {
      pairs += 1;
      assert.equal(
        resolution.lookups.subcategoryApplies('collection', category.id, subcategory.id),
        true,
        `${category.id}/${subcategory.id}`,
      );
    }
  assert.ok(pairs > 500);
  for (const [categoryId, subcategoryId] of [
    ['travel_tours', 'no_such_subcategory'],
    ['no_such_category', 'hidden_gems_tour'],
    ['outdoor_nature_walking', 'hidden_gems_tour'],
  ] as const)
    assert.equal(
      resolution.lookups.subcategoryApplies('collection', categoryId, subcategoryId),
      false,
      `${categoryId}/${subcategoryId}`,
    );
});

void test('without the artifact Collection applicability cannot be answered', () => {
  assert.equal(
    collectionSubcategoryApplies(undefined, 'travel_tours', 'hidden_gems_tour'),
    undefined,
  );
});

void test('other types keep their answers', async () => {
  const data = new EmulatorSyntheticReferenceData();
  const event = await data.resolve({ marketId: 'LV', typeId: 'event' });
  assert.ok(event.ok);
  assert.equal(event.revisions.taxonomyRevisionId, 'test-only-tx-1');
  assert.equal(event.lookups.subcategoryApplies('event', 'any', 'thing'), true);
  const rental = await data.resolve({ marketId: 'LV', typeId: 'rental' });
  assert.ok(rental.ok);
  assert.equal(rental.revisions.taxonomyRevisionId, 'test-only-tx-1');
  const other = await data.resolve({ marketId: 'EE', typeId: 'collection' });
  assert.deepEqual(other, { ok: false, code: 'market_disabled' });
});
