import assert from 'node:assert/strict';
import test from 'node:test';

import {
  readReferenceDataJson,
  referenceDataTargetRefs,
} from '../../../src/contracts/reference_data_schema_registry.js';
import { validateReferenceDataContract } from '../../../src/contracts/validate_reference_data_contract.js';

void test('valid fixtures pass and invalid/forward fixtures fail closed', async () => {
  const valid = (await readReferenceDataJson('fixtures/valid.json')) as Record<string, unknown>;
  const invalid = (await readReferenceDataJson('fixtures/invalid.json')) as Record<string, unknown>;
  const forward = (await readReferenceDataJson('fixtures/forward.json')) as Record<string, unknown>;
  for (const target of Object.keys(
    referenceDataTargetRefs,
  ) as (keyof typeof referenceDataTargetRefs)[]) {
    assert.equal(
      (await validateReferenceDataContract(target, valid[target])).ok,
      true,
      `${target} valid`,
    );
    assert.equal(
      (await validateReferenceDataContract(target, invalid[target])).ok,
      false,
      `${target} invalid`,
    );
    assert.equal(
      (await validateReferenceDataContract(target, forward[target])).ok,
      false,
      `${target} forward`,
    );
  }
});
