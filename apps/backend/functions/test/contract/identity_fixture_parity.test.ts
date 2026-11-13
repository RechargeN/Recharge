import assert from 'node:assert/strict';
import test from 'node:test';

import type { IdentityContractTarget } from '../../src/contracts/identity_schema_registry.js';
import { readIdentityJson } from '../../src/contracts/identity_schema_registry.js';
import { validateIdentityContract } from '../../src/contracts/validate_identity_contract.js';

void test('identity schemas accept canonical fixtures and fail closed on invalid or newer authority', async () => {
  const valid = (await readIdentityJson('fixtures/valid.json')) as Record<string, unknown>;
  const invalid = (await readIdentityJson('fixtures/invalid.json')) as Record<string, unknown>;
  const forward = (await readIdentityJson('fixtures/forward.json')) as Record<string, unknown>;
  for (const [target, value] of Object.entries(valid)) {
    assert.equal(
      (await validateIdentityContract(target as IdentityContractTarget, value)).ok,
      true,
    );
  }
  for (const [target, value] of Object.entries(invalid)) {
    assert.equal(
      (await validateIdentityContract(target as IdentityContractTarget, value)).ok,
      false,
    );
  }
  for (const [target, value] of Object.entries(forward)) {
    assert.equal(
      (await validateIdentityContract(target as IdentityContractTarget, value)).ok,
      false,
    );
  }
});
