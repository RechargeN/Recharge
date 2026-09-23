import assert from 'node:assert/strict';
import test from 'node:test';

import { privacyTargetRefs, readPrivacyJson } from '../../src/contracts/privacy_schema_registry.js';
import { validatePrivacyContract } from '../../src/contracts/validate_privacy_contract.js';

void test('privacy schemas accept valid fixtures and fail closed on invalid or newer versions', async () => {
  const valid = (await readPrivacyJson('fixtures/valid.json')) as Record<string, unknown>;
  const invalid = (await readPrivacyJson('fixtures/invalid.json')) as Record<string, unknown>;
  const forward = (await readPrivacyJson('fixtures/forward.json')) as Record<string, unknown>;
  for (const target of Object.keys(privacyTargetRefs) as (keyof typeof privacyTargetRefs)[]) {
    assert.equal(
      (await validatePrivacyContract(target, valid[target])).ok,
      true,
      `${target} valid`,
    );
    assert.equal(
      (await validatePrivacyContract(target, invalid[target])).ok,
      false,
      `${target} invalid`,
    );
    assert.equal(
      (await validatePrivacyContract(target, forward[target])).ok,
      false,
      `${target} forward`,
    );
  }
});
