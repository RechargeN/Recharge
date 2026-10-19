import assert from 'node:assert/strict';
import test from 'node:test';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import { taxonomyRevisionId } from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';
void test('Session uses pinned canonical taxonomy and current platform 30, never permissive applicability', async () => {
  const refs = new EmulatorSyntheticReferenceData();
  const result = await refs.resolve({ marketId: 'LV', typeId: 'session' });
  assert.ok(result.ok);
  assert.equal(result.revisions.taxonomyRevisionId, taxonomyRevisionId);
  assert.equal(result.lookups.sessionProjectionWindowDays?.(), 30);
  assert.equal(result.lookups.subcategoryApplies('session', 'sport', 'tennis'), true);
  assert.equal(result.lookups.subcategoryApplies('session', 'unknown', 'unknown'), false);
  assert.equal(result.lookups.subcategoryApplies('session', 'games_indoor', 'bowling'), false);
  assert.deepEqual(
    result.lookups.requiredCriteria('session', 'sport', 'tennis'),
    [],
    'SES-D14 advisory',
  );
  const other = await refs.resolve({ marketId: 'LV', typeId: 'event' });
  assert.ok(other.ok);
  assert.equal(other.lookups.sessionProjectionWindowDays?.(), undefined);
  assert.deepEqual(await refs.resolve({ marketId: 'EE', typeId: 'session' }), {
    ok: false,
    code: 'market_disabled',
  });
});
