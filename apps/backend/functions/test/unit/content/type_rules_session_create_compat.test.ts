import assert from 'node:assert/strict';
import test from 'node:test';
import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import { validateSessionBody } from '../../../src/modules/content/domain/type_rules/session_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';

interface Fixture {
  serverOwnerUserId: string;
  cases: { name: string; body: ContentBody; expectedIssues: string[] }[];
}
async function setup() {
  const fixture = (await readContentJson('fixtures/session_create_compat.json')) as Fixture;
  const ref = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'session',
  });
  assert.ok(ref.ok);
  const context: ContentValidationContext = {
    typeId: 'session',
    marketId: 'LV',
    publisherRef: { type: 'user', id: fixture.serverOwnerUserId as never },
    createdByUserId: fixture.serverOwnerUserId,
    actorUserId: fixture.serverOwnerUserId,
    nowUtc: '2026-10-18T10:00:00Z',
    draftRevision: 1,
    market: ref.market,
    lookups: ref.lookups,
  };
  return { fixture, context };
}
void test('D3.5 wire fixtures enforce Session rules without dropping unsupported fields', async () => {
  const { fixture, context } = await setup();
  for (const item of fixture.cases)
    assert.deepEqual(validateSessionBody(item.body, context), item.expectedIssues, item.name);
});
