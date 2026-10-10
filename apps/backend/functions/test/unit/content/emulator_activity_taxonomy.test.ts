// D3.2 §2.3–§2.4 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md): the Emulator
// Activity taxonomy equals the canonical fixture file the mobile test checks
// against the mobile taxonomy; the Emulator reference data answers Activity
// lookups from it (an unknown pair does not apply) while every other type
// keeps its answers; and the composition refuses a linked Place it cannot
// resolve, on top of an unchanged validator.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import { validateActivityBody } from '../../../src/modules/content/domain/type_rules/activity_rules.js';
import {
  activityEmulatorDependencies,
  activityLinkedPlaceUnresolved,
  emulatorCompositionRules,
} from '../../../src/modules/content/infrastructure/emulator_activity_dependencies.js';
import {
  activityRequiredCriteria,
  activitySubcategoryApplies,
  emulatorActivityTaxonomy,
  emulatorActivityTaxonomyRevisionId,
} from '../../../src/modules/content/infrastructure/emulator_activity_taxonomy.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import { standActivityBody } from '../../stand/stand_content_activity.js';

void test('the Emulator Activity taxonomy is exactly the canonical fixture file', async () => {
  const fixture = (await readContentJson('fixtures/activity_reference_taxonomy.json')) as {
    typeId: string;
    taxonomyRevisionId: string;
    entries: unknown[];
  };
  assert.equal(fixture.typeId, 'activity');
  assert.equal(fixture.taxonomyRevisionId, emulatorActivityTaxonomyRevisionId);
  assert.deepEqual(fixture.entries, JSON.parse(JSON.stringify(emulatorActivityTaxonomy)));
});

void test('Activity applicability and required criteria come from the fixture', () => {
  assert.equal(activitySubcategoryApplies('outdoor_nature_walking', 'forest_walk'), true);
  assert.equal(activitySubcategoryApplies('wellness_recharge', 'meditation'), true);
  // sauna exists in the taxonomy but does not apply to Activity.
  assert.equal(activitySubcategoryApplies('wellness_recharge', 'sauna'), false);
  // An unknown pair, or a real subcategory under the wrong group, does not apply.
  assert.equal(activitySubcategoryApplies('wellness_recharge', 'forest_walk'), false);
  assert.equal(activitySubcategoryApplies('nope', 'nope'), false);
  assert.deepEqual(activityRequiredCriteria('outdoor_nature_walking', 'forest_walk'), [
    'difficulty',
  ]);
  assert.deepEqual(activityRequiredCriteria('water_activities', 'kayak'), [
    'equipment_provided',
    'swimming_required',
  ]);
  assert.deepEqual(activityRequiredCriteria('wellness_recharge', 'meditation'), []);
  // A pair that does not apply names no criteria, so its refusal is one code.
  assert.deepEqual(activityRequiredCriteria('wellness_recharge', 'sauna'), []);
});

void test('reference data uses the Activity taxonomy for Activity only', async () => {
  const data = new EmulatorSyntheticReferenceData();
  const activity = await data.resolve({ marketId: 'LV', typeId: 'activity' });
  const place = await data.resolve({ marketId: 'LV', typeId: 'place' });
  const event = await data.resolve({ marketId: 'LV', typeId: 'event' });
  assert.ok(activity.ok && place.ok && event.ok);
  assert.equal(activity.revisions.taxonomyRevisionId, 'test-only-tx-activity-1');
  assert.equal(place.revisions.taxonomyRevisionId, 'test-only-tx-place-1');
  assert.equal(event.revisions.taxonomyRevisionId, 'test-only-tx-1');
  assert.equal(activity.lookups.subcategoryApplies('activity', 'any', 'sub-random'), false);
  assert.deepEqual(
    activity.lookups.requiredCriteria('activity', 'outdoor_nature_walking', 'forest_walk'),
    ['difficulty'],
  );
  // Place keeps its own taxonomy, Event the synthetic constants.
  assert.equal(place.lookups.subcategoryApplies('place', 'art_culture_museums', 'museum'), true);
  assert.equal(event.lookups.subcategoryApplies('event', 'any', 'sub-random'), true);
  assert.deepEqual(await data.resolve({ marketId: 'EE', typeId: 'activity' }), {
    ok: false,
    code: 'market_disabled',
  });
});

void test('the stand body passes the unchanged validator under the Emulator reference data', async () => {
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'activity',
  });
  assert.ok(resolution.ok);
  const context = {
    typeId: 'activity' as const,
    marketId: 'LV' as never,
    publisherRef: { type: 'page' as const, id: 'page-1' as never },
    createdByUserId: 'user-1',
    actorUserId: 'user-1',
    nowUtc: '2026-10-11T10:00:00.000Z',
    draftRevision: 2,
    market: resolution.market,
    lookups: resolution.lookups,
  };
  const body = standActivityBody({ coverMediaId: 'asset-cover', galleryMediaIds: ['asset-1'] });
  assert.deepEqual(validateActivityBody(body, context as never), []);
  // The taxonomy refuses an inapplicable pair and a missing required criterion.
  assert.deepEqual(
    validateActivityBody(
      { ...body, categoryId: 'wellness_recharge', subcategoryId: 'sauna', criteria: {} },
      context as never,
    ),
    ['activity.subcategory_not_applicable'],
  );
  assert.deepEqual(validateActivityBody({ ...body, criteria: {} }, context as never), [
    'activity.criterion_required:difficulty',
  ]);
});

void test('a linked Place is refused by the composition, not by the validator', () => {
  const body = standActivityBody({ coverMediaId: 'asset-cover', galleryMediaIds: [] });
  const linked = {
    ...body,
    location: {
      ...(body.location as Record<string, unknown>),
      linkedPlaceId: '01HZZZZZZZZZZZZZZZZZZZZZZZ',
    },
  };
  assert.deepEqual(activityEmulatorDependencies(body), []);
  assert.deepEqual(activityEmulatorDependencies({}), []);
  assert.deepEqual(activityEmulatorDependencies({ location: 'x' }), []);
  assert.deepEqual(activityEmulatorDependencies(linked), [activityLinkedPlaceUnresolved]);
  // Any value is refused, even one the validator would itself reject.
  assert.deepEqual(activityEmulatorDependencies({ location: { linkedPlaceId: 'loc_place_1' } }), [
    activityLinkedPlaceUnresolved,
  ]);
  // Only Activity gets a composition rule.
  assert.deepEqual([...emulatorCompositionRules.keys()], ['activity']);
});
