// D3.2 §5.7 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md): every body the mobile
// mapper produces for a Create Activity draft case (the shared fixture file)
// against the accepted Activity validator under the Emulator reference data.
// BCK07-VALIDATION-DETAILS-01 adds allowlisted public codes/paths to the
// general refusal; the Emulator test sends the same bodies and checks them.
import assert from 'node:assert/strict';
import { publicValidationDetails } from '../../../src/modules/content/domain/validation_details.js';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import { validateActivityBody } from '../../../src/modules/content/domain/type_rules/activity_rules.js';
import { activityEmulatorDependencies } from '../../../src/modules/content/infrastructure/emulator_activity_dependencies.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

interface CompatCase {
  readonly name: string;
  readonly createCase: string;
  readonly expectedIssues: readonly string[];
  readonly expectedViolations: readonly { code: string; fieldPath: string }[];
  readonly body: ContentBody;
}

void test('each Create case gets exactly its validator codes under the Emulator reference data', async () => {
  const { typeId, cases } = (await readContentJson('fixtures/activity_create_compat.json')) as {
    readonly typeId: string;
    readonly cases: readonly CompatCase[];
  };
  assert.equal(typeId, 'activity');
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'activity',
  });
  assert.ok(resolution.ok);
  assert.equal(cases.length, 26);
  assert.deepEqual(cases[0]?.expectedIssues, [], 'the first case is the accepted draft');
  for (const item of cases) {
    const issues = validateActivityBody(item.body, {
      typeId: 'activity',
      marketId: 'LV',
      publisherRef: { type: 'page', id: 'page-compat-1' as never },
      createdByUserId: 'server-owner-compat-1',
      actorUserId: 'server-owner-compat-1',
      nowUtc: '2026-10-11T10:00:00.000Z',
      draftRevision: 2,
      market: resolution.market,
      lookups: resolution.lookups,
    });
    assert.deepEqual(issues, item.expectedIssues, `${item.name}: ${item.createCase}`);
    assert.deepEqual(publicValidationDetails(issues), item.expectedViolations, item.name);
    // The mapper never sends a linked Place, so the composition adds nothing.
    assert.deepEqual(activityEmulatorDependencies(item.body), [], item.name);
  }
});
