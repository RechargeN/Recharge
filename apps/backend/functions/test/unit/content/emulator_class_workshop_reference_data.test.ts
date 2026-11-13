import assert from 'node:assert/strict';
import test from 'node:test';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import { taxonomyRevisionId } from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';

void test('Class uses the pinned taxonomy C applicability and blocking profile criteria', async () => {
  const refs = new EmulatorSyntheticReferenceData();
  const result = await refs.resolve({ marketId: 'LV', typeId: 'class_workshop' });
  assert.ok(result.ok);
  assert.equal(result.revisions.taxonomyRevisionId, taxonomyRevisionId);
  const lookups = result.lookups;
  assert.equal(
    lookups.subcategoryApplies('class_workshop', 'workshops_masterclasses', 'pottery'),
    true,
  );
  assert.equal(lookups.subcategoryApplies('class_workshop', 'dance', 'salsa'), true);
  assert.equal(lookups.subcategoryApplies('class_workshop', 'sport', 'tennis'), false);
  assert.equal(lookups.subcategoryApplies('class_workshop', 'unknown', 'unknown'), false);
  assert.deepEqual(
    lookups.requiredCriteria('class_workshop', 'workshops_masterclasses', 'pottery'),
    ['equipment_provided', 'skill_level'],
  );
  assert.deepEqual(lookups.requiredCriteria('class_workshop', 'dance', 'salsa'), ['skill_level']);
  assert.deepEqual(lookups.requiredCriteria('class_workshop', 'sport', 'tennis'), []);
  // Session keeps its advisory criteria and its own window; Class has no window.
  assert.equal(lookups.sessionProjectionWindowDays?.(), undefined);
  const session = await refs.resolve({ marketId: 'LV', typeId: 'session' });
  assert.ok(session.ok);
  assert.deepEqual(session.lookups.requiredCriteria('session', 'sport', 'tennis'), []);
  assert.deepEqual(await refs.resolve({ marketId: 'EE', typeId: 'class_workshop' }), {
    ok: false,
    code: 'market_disabled',
  });
});
