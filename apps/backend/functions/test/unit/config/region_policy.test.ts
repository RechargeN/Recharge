import assert from 'node:assert/strict';
import test from 'node:test';

import { createDisabledRegionPolicy } from '../../../src/config/region_policy.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

void test('region policy is exact and disabled', () => {
  const policy = createDisabledRegionPolicy(fixtureIds.first, 1, 'local');
  assert.deepEqual(
    [
      policy.firestoreLocation,
      policy.functionsRegion,
      policy.storageRegion,
      policy.exportLocation,
      policy.activationState,
    ],
    ['eur3', 'europe-west1', 'europe-west1', 'EU', 'disabled'],
  );
  assert.ok(Object.isFrozen(policy));
});
