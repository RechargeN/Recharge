import assert from 'node:assert/strict';
import test from 'node:test';

import { isReleaseCompatible } from '../../../src/config/release_manifest.js';
import { buildRelease, fixtureIds } from '../../support/platform_fixtures.js';

void test('release manifest is immutable, disabled and compatibility-scoped', () => {
  const current = buildRelease({ id: fixtureIds.first });
  const target = buildRelease({ id: fixtureIds.second });
  assert.ok(Object.isFrozen(current));
  assert.equal(current.status, 'disabled');
  assert.equal(isReleaseCompatible(current, target), true);
  assert.equal(
    isReleaseCompatible(
      current,
      buildRelease({ id: fixtureIds.third, apiSchemaRevision: 'platform-v2' }),
    ),
    false,
  );
});
