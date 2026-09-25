import assert from 'node:assert/strict';
import test from 'node:test';

import { createFeatureFlag, isFeatureEnabled } from '../../../src/config/feature_flags.js';
import { buildFeatureFlag } from '../../support/platform_fixtures.js';

void test('R1 feature flags default off and enable only through an explicit revision', () => {
  const flag = buildFeatureFlag();
  assert.equal(flag.enabled, false);
  assert.equal(isFeatureEnabled(flag), false);
  assert.equal(isFeatureEnabled(undefined), false);
  assert.equal(
    isFeatureEnabled(
      createFeatureFlag({
        revision: 2,
        environmentId: 'local',
        marketId: 'LV',
        capabilityId: 'booking.create',
        enabled: true,
        createdAtUtc: '2026-09-24T00:00:00.000Z',
      }),
    ),
    true,
  );
});
