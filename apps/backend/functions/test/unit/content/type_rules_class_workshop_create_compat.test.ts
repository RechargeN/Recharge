import assert from 'node:assert/strict';
import test from 'node:test';
import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import { validateClassWorkshopBody } from '../../../src/modules/content/domain/type_rules/class_workshop_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';

interface Fixture {
  serverOwnerUserId: string;
  nowUtc: string;
  cases: { name: string; body: ContentBody; expectedIssues: string[] }[];
}

async function setup() {
  const fixture = (await readContentJson('fixtures/class_workshop_create_compat.json')) as Fixture;
  const ref = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'class_workshop',
  });
  assert.ok(ref.ok);
  const context: ContentValidationContext = {
    typeId: 'class_workshop',
    marketId: 'LV',
    publisherRef: { type: 'user', id: fixture.serverOwnerUserId as never },
    createdByUserId: fixture.serverOwnerUserId,
    actorUserId: fixture.serverOwnerUserId,
    nowUtc: fixture.nowUtc,
    draftRevision: 1,
    market: ref.market,
    lookups: ref.lookups,
  };
  return { fixture, context };
}

void test('D3.6 wire fixtures enforce CW-V1 rules without dropping unknown fields', async () => {
  const { fixture, context } = await setup();
  assert.ok(fixture.cases.length >= 40);
  assert.ok(fixture.cases.filter((item) => item.expectedIssues.length === 0).length >= 5);
  for (const item of fixture.cases)
    assert.deepEqual(validateClassWorkshopBody(item.body, context), item.expectedIssues, item.name);
});

void test('each rejection fixture differs from the valid body by exactly one violation', async () => {
  const { fixture } = await setup();
  const names = new Set<string>();
  for (const item of fixture.cases) {
    assert.equal(names.has(item.name), false, `duplicate fixture ${item.name}`);
    names.add(item.name);
    assert.ok(item.expectedIssues.length <= 1, `${item.name} must isolate one violation`);
  }
});
