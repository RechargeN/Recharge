// D3.1 §2.3: the Emulator Place taxonomy equals the canonical fixture file the
// mobile test checks against the mobile taxonomy, and the Emulator reference
// data answers Place lookups from it while every other type keeps the
// synthetic constants.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import {
  emulatorPlaceTaxonomy,
  emulatorPlaceTaxonomyRevisionId,
  placeRequiredCriteria,
  placeSubcategoryApplies,
} from '../../../src/modules/content/infrastructure/emulator_place_taxonomy.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

void test('the Emulator Place taxonomy is exactly the canonical fixture file', async () => {
  const fixture = (await readContentJson('fixtures/place_reference_taxonomy.json')) as {
    typeId: string;
    taxonomyRevisionId: string;
    entries: unknown[];
  };
  assert.equal(fixture.typeId, 'place');
  assert.equal(fixture.taxonomyRevisionId, emulatorPlaceTaxonomyRevisionId);
  assert.deepEqual(fixture.entries, JSON.parse(JSON.stringify(emulatorPlaceTaxonomy)));
});

void test('Place applicability and required criteria come from the fixture', () => {
  assert.equal(placeSubcategoryApplies('art_culture_museums', 'museum'), true);
  assert.equal(placeSubcategoryApplies('outdoor_nature_walking', 'park'), true);
  // artist_talk exists in the taxonomy but applies to Event only.
  assert.equal(placeSubcategoryApplies('art_culture_museums', 'artist_talk'), false);
  // An unknown pair, or a real subcategory under the wrong group, does not apply.
  assert.equal(placeSubcategoryApplies('art_culture_museums', 'park'), false);
  assert.equal(placeSubcategoryApplies('nope', 'nope'), false);
  assert.deepEqual(placeRequiredCriteria('outdoor_nature_walking', 'park'), ['difficulty']);
  assert.deepEqual(placeRequiredCriteria('art_culture_museums', 'museum'), []);
  // A pair that does not apply names no criteria, so its refusal is one code.
  assert.deepEqual(placeRequiredCriteria('art_culture_museums', 'artist_talk'), []);
});

void test('reference data uses the Place taxonomy for Place only', async () => {
  const data = new EmulatorSyntheticReferenceData();
  const place = await data.resolve({ marketId: 'LV', typeId: 'place' });
  const event = await data.resolve({ marketId: 'LV', typeId: 'event' });
  assert.ok(place.ok && event.ok);
  assert.equal(place.revisions.taxonomyRevisionId, 'test-only-tx-place-1');
  assert.equal(event.revisions.taxonomyRevisionId, 'test-only-tx-1');
  assert.equal(
    place.lookups.subcategoryApplies('place', 'art_culture_museums', 'artist_talk'),
    false,
  );
  assert.deepEqual(place.lookups.requiredCriteria('place', 'outdoor_nature_walking', 'park'), [
    'difficulty',
  ]);
  // Event keeps the synthetic constants: any subcategory, no criteria.
  assert.equal(event.lookups.subcategoryApplies('event', 'any', 'sub-random'), true);
  assert.deepEqual(event.lookups.requiredCriteria('event', 'any', 'sub-random'), []);
  assert.deepEqual(await data.resolve({ marketId: 'EE', typeId: 'place' }), {
    ok: false,
    code: 'market_disabled',
  });
});
