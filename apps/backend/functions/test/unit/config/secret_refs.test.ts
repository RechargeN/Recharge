import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createUnboundSecretReference,
  rejectSecretMaterial,
} from '../../../src/config/secret_refs.js';

void test('secret config stores an unbound logical reference only', () => {
  const reference = createUnboundSecretReference({
    environmentId: 'local',
    logicalName: 'API_KEY',
    referenceName: 'api-key',
  });
  assert.equal(reference.bindingState, 'unbound');
  assert.equal('value' in reference, false);
});

void test('inline secret material is rejected', () => {
  assert.throws(
    () => rejectSecretMaterial({ credentials: 'forbidden' }),
    /secret_material_forbidden/,
  );
  assert.throws(
    () => rejectSecretMaterial({ nested: { privateKey: 'forbidden' } }),
    /secret_material_forbidden/,
  );
});
