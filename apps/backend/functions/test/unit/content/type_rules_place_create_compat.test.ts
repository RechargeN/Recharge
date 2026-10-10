// D3.1 §5.7 (PLACE_D3_1_PUBLICATION_AMENDMENT.md): every body the mobile
// mapper produces for a Create Place draft case (the shared fixture file)
// against the accepted Place validator under the Emulator reference data. The
// wire answer is `validation_failed` without these codes, so this is where each
// case's exact reason is proven; the Emulator test sends the same bodies.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import { validatePlaceBody } from '../../../src/modules/content/domain/type_rules/place_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

interface CompatCase {
  readonly name: string;
  readonly createCase: string;
  readonly expectedIssues: readonly string[];
  readonly body: ContentBody;
}

async function fixture() {
  return (await readContentJson('fixtures/place_create_compat.json')) as {
    readonly serverOwnerUserId: string;
    readonly cases: readonly CompatCase[];
  };
}

void test('each Create case gets exactly its validator codes under the Emulator reference data', async () => {
  const { serverOwnerUserId, cases } = await fixture();
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'place',
  });
  assert.ok(resolution.ok);
  assert.equal(cases.length, 11);
  assert.deepEqual(cases[0]?.expectedIssues, [], 'the first case is the accepted draft');
  for (const item of cases) {
    const issues = validatePlaceBody(item.body, {
      typeId: 'place',
      marketId: 'LV',
      publisherRef: { type: 'page', id: 'page-compat-1' as never },
      createdByUserId: serverOwnerUserId,
      actorUserId: serverOwnerUserId,
      nowUtc: '2026-10-10T10:00:00.000Z',
      draftRevision: 2,
      market: resolution.market,
      lookups: resolution.lookups,
    });
    assert.deepEqual(issues, item.expectedIssues, `${item.name}: ${item.createCase}`);
  }
});

void test('the author is the server record: another user fails the accepted case', async () => {
  const { cases } = await fixture();
  const valid = cases[0];
  assert.ok(valid);
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'place',
  });
  assert.ok(resolution.ok);
  const issues = validatePlaceBody(valid.body, {
    typeId: 'place',
    marketId: 'LV',
    publisherRef: { type: 'page', id: 'page-compat-1' as never },
    createdByUserId: 'someone-else',
    actorUserId: 'someone-else',
    nowUtc: '2026-10-10T10:00:00.000Z',
    draftRevision: 2,
    market: resolution.market,
    lookups: resolution.lookups,
  });
  assert.deepEqual(issues, ['place.provenance.submittedBy']);
});
