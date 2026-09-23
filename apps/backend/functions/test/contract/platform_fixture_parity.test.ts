import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { Money, MinimumClientPolicy } from '../../src/contracts/platform_v1.js';
import {
  createPlatformSchemaRegistry,
  type PlatformContractTarget,
  readPlatformJson,
} from '../../src/contracts/schema_registry.js';
import { validatePlatformContract } from '../../src/contracts/validate_platform_contract.js';

interface FixtureCase {
  readonly target: PlatformContractTarget;
  readonly reason?: string;
  readonly expectedValid?: boolean;
  readonly value: unknown;
}

function fixtureCases(value: unknown): readonly FixtureCase[] {
  assert.equal(typeof value, 'object');
  assert.notEqual(value, null);
  const cases = (value as { readonly cases?: unknown }).cases;
  assert.ok(Array.isArray(cases));
  return cases as readonly FixtureCase[];
}

void test('all valid and backward fixtures pass Draft 2020-12 validation', async () => {
  const registry = await createPlatformSchemaRegistry();
  for (const fixtureName of ['fixtures/valid.json', 'fixtures/backward.json'] as const) {
    for (const fixture of fixtureCases(await readPlatformJson(fixtureName))) {
      const validator = registry.validator(fixture.target);
      assert.equal(
        validator(fixture.value),
        true,
        `${fixtureName}: ${JSON.stringify(validator.errors)}`,
      );
    }
  }
});

void test('all invalid fixtures fail closed', async () => {
  const registry = await createPlatformSchemaRegistry();
  for (const fixture of fixtureCases(await readPlatformJson('fixtures/invalid.json'))) {
    const validator = registry.validator(fixture.target);
    assert.equal(validator(fixture.value), false, fixture.reason);
  }
});

void test('forward fixtures distinguish additive payload from critical changes', async () => {
  const registry = await createPlatformSchemaRegistry();
  for (const fixture of fixtureCases(await readPlatformJson('fixtures/forward.json'))) {
    const validator = registry.validator(fixture.target);
    assert.equal(validator(fixture.value), fixture.expectedValid, fixture.reason);
  }
});

void test('validated schema values narrow to the TypeScript contract consumers', async () => {
  const money = await validatePlatformContract<Money>('money', {
    minorUnits: 1250,
    currency: 'EUR',
  });
  assert.equal(money.ok, true);
  if (money.ok) {
    assert.equal(Number.isInteger(money.value.minorUnits), true);
    assert.equal(money.value.currency, 'EUR');
  }

  const policy = await validatePlatformContract<MinimumClientPolicy>('minimumClientPolicy', {
    policyRevision: 1,
    platform: 'android',
    minSupportedBuild: 10,
    recommendedBuild: 20,
    supportedContractMajors: [1],
    effectiveAt: '2026-09-21T10:00:00.000Z',
  });
  assert.equal(policy.ok, true);
});

void test('Money and timezone cannot be inferred from market or device context', async () => {
  assert.equal((await validatePlatformContract('money', { minorUnits: 1250 })).ok, false);
  assert.equal((await validatePlatformContract('ianaTimezone', '+03:00')).ok, false);
  assert.equal((await validatePlatformContract('ianaTimezone', 'Europe/Riga')).ok, true);
});
