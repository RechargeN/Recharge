import assert from 'node:assert/strict';
import test from 'node:test';

import { isFeatureEnabled } from '../../../src/config/feature_flags.js';
import { buildFeatureFlag } from '../../support/platform_fixtures.js';

void test('R1 feature flags are server-owned and always disabled', () => {
  const flag = buildFeatureFlag();
  assert.equal(flag.enabled, false);
  assert.equal(isFeatureEnabled(flag), false);
  assert.equal(isFeatureEnabled(undefined), false);
});
