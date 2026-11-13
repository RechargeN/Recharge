// D3.3 §2 Q1a/Q1b (RENTAL_D3_3_PUBLICATION_AMENDMENT.md): the TEST-ONLY
// Emulator Rental policy equals its canonical fixture file; it answers only
// the explicit test pairs, and only while the pair exists in the pinned BCK-20
// revision; every other type keeps having no Rental policy; and the stand body
// passes the unchanged Rental validator under it.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import { validateRentalBody } from '../../../src/modules/content/domain/type_rules/rental_rules.js';
import { emulatorActivationClosedTypes } from '../../../src/modules/content/infrastructure/emulator_rental_dependencies.js';
import {
  emulatorRentalCategories,
  emulatorRentalPairs,
  emulatorRentalPolicy,
  emulatorRentalPolicyBase,
  emulatorRentalPolicyId,
  emulatorRentalRequirements,
} from '../../../src/modules/content/infrastructure/emulator_rental_policy.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import {
  readLocalTaxonomy,
  taxonomyRevisionId,
  type TaxonomyDataset,
} from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';
import { standRentalBody } from '../../stand/stand_content_rental.js';

function dataset(): TaxonomyDataset {
  const read = readLocalTaxonomy(taxonomyRevisionId);
  assert.ok(read.ok);
  return read.dataset;
}

void test('the Emulator Rental policy is exactly the canonical fixture file', async () => {
  const fixture = (await readContentJson('fixtures/rental_reference_policy.json')) as Record<
    string,
    unknown
  >;
  assert.equal(fixture.typeId, 'rental');
  assert.equal(fixture.policyId, emulatorRentalPolicyId);
  assert.deepEqual(fixture.categories, [...emulatorRentalCategories]);
  assert.deepEqual(fixture.pairs, JSON.parse(JSON.stringify(emulatorRentalPairs)));
  assert.deepEqual(fixture.base, { ...emulatorRentalPolicyBase });
  assert.deepEqual(fixture.requirements, JSON.parse(JSON.stringify(emulatorRentalRequirements)));
});

void test('every test pair exists in the pinned BCK-20 revision under a whitelisted category', () => {
  const data = dataset();
  for (const pair of emulatorRentalPairs) {
    assert.ok(
      (emulatorRentalCategories as readonly string[]).includes(pair.categoryId),
      pair.categoryId,
    );
    const policy = emulatorRentalPolicy(data, pair.categoryId, pair.subcategoryId);
    assert.ok(policy?.enabled, `${pair.categoryId}/${pair.subcategoryId}`);
    assert.equal(policy.policyVersion, '1.0');
  }
});

void test('a pair outside the test list, unknown to BCK-20 or outside the whitelist has no policy', () => {
  const data = dataset();
  // yoga exists in BCK-20 under sport, but its applicability to Rental is not decided.
  assert.equal(emulatorRentalPolicy(data, 'sport', 'yoga'), undefined);
  assert.equal(emulatorRentalPolicy(data, 'sport', 'not_a_subcategory'), undefined);
  assert.equal(emulatorRentalPolicy(data, 'art_culture_museums', 'museum'), undefined);
  // A listed pair the pinned revision does not contain fails closed too.
  const without: TaxonomyDataset = {
    ...data,
    categories: data.categories.map((category) =>
      category.id === 'water_activities'
        ? {
            ...category,
            subcategories: category.subcategories.filter((sub) => sub.id !== 'kayak'),
          }
        : category,
    ),
  };
  assert.equal(emulatorRentalPolicy(without, 'water_activities', 'kayak'), undefined);
});

void test('category flags follow the whitelist requirements', () => {
  const data = dataset();
  assert.equal(emulatorRentalPolicy(data, 'sport', 'cycling')?.requiresSizeOrVariant, true);
  assert.equal(emulatorRentalPolicy(data, 'water_activities', 'kayak')?.requiresSafetyNotice, true);
  const auto = emulatorRentalPolicy(data, 'auto_moto', 'offroad_trip');
  assert.equal(auto?.requiresIdAtHandover, true);
  assert.equal(auto?.requiresMinRenterAge, true);
});

void test('reference data answers a Rental policy for Rental only, pinned to BCK-20', async () => {
  const data = new EmulatorSyntheticReferenceData();
  const rental = await data.resolve({ marketId: 'LV', typeId: 'rental' });
  const activity = await data.resolve({ marketId: 'LV', typeId: 'activity' });
  const event = await data.resolve({ marketId: 'LV', typeId: 'event' });
  assert.ok(rental.ok && activity.ok && event.ok);
  assert.equal(rental.revisions.taxonomyRevisionId, taxonomyRevisionId);
  assert.ok(rental.lookups.rentalPolicy?.('water_activities', 'kayak'));
  assert.equal(rental.lookups.rentalPolicy?.('sport', 'yoga'), undefined);
  assert.equal('rentalPolicy' in activity.lookups, false);
  assert.equal('rentalPolicy' in event.lookups, false);
  assert.deepEqual(await data.resolve({ marketId: 'EE', typeId: 'rental' }), {
    ok: false,
    code: 'market_disabled',
  });
});

void test('the stand body passes the unchanged Rental validator; the cover stays required', async () => {
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'rental',
  });
  assert.ok(resolution.ok);
  const actor = '01HZZZZZZZZZZZZZZZZZZZZZZ1';
  const anchor = '2026-10-12T00:00:00.000Z';
  const context = {
    typeId: 'rental' as const,
    marketId: 'LV' as never,
    publisherRef: { type: 'page' as const, id: 'page-1' as never },
    createdByUserId: actor,
    actorUserId: actor,
    nowUtc: '2026-10-12T10:00:00.000Z',
    draftRevision: 2,
    market: resolution.market,
    lookups: resolution.lookups,
  };
  const body = standRentalBody({
    actorUserId: actor,
    mediaRefs: ['asset-cover'],
    anchorUtc: anchor,
  });
  assert.deepEqual(validateRentalBody(body, context as never), []);
  assert.deepEqual(validateRentalBody({ ...body, mediaRefs: [] }, context as never), [
    'rental.cover_required',
  ]);
  assert.deepEqual(
    validateRentalBody({ ...body, subcategoryId: 'yoga', categoryId: 'sport' }, context as never),
    ['rental.policy_unavailable'],
  );
  // Another acting user than the one who attested and created the block.
  assert.ok(
    validateRentalBody(body, {
      ...context,
      actorUserId: '01HZZZZZZZZZZZZZZZZZZZZZZ2',
    }).includes('rental.attestation_user'),
  );
  // Eight days later the confirmation is stale under the test policy.
  assert.ok(
    validateRentalBody(body, { ...context, nowUtc: '2026-10-20T10:00:00.000Z' }).includes(
      'rental.coverage_stale',
    ),
  );
});

void test('only Rental activation is closed by the Emulator composition', () => {
  assert.deepEqual([...emulatorActivationClosedTypes], ['rental']);
});
