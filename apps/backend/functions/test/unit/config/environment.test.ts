import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createEnvironmentConfig,
  environmentIds,
  parseEnvironmentConfig,
} from '../../../src/config/environment.js';

void test('R1 exposes exactly four logical unbound environments', () => {
  assert.deepEqual(environmentIds, ['local', 'dev', 'stage', 'prod']);
  for (const id of environmentIds) {
    assert.deepEqual(
      parseEnvironmentConfig(createEnvironmentConfig(id)),
      createEnvironmentConfig(id),
    );
  }
});

void test('unknown or cloud-bound environment fails closed', () => {
  assert.throws(() => parseEnvironmentConfig({ environmentId: 'qa' }), /environment_unknown/);
  assert.throws(
    () => parseEnvironmentConfig({ ...createEnvironmentConfig('dev'), cloudAllowed: true }),
    /environment_config_invalid/,
  );
});
