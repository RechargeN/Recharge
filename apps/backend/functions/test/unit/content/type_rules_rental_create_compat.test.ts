// D3.3 §4 (RENTAL_D3_3_PUBLICATION_AMENDMENT.md): every body the mobile mapper
// produces for a Create Rental draft case (the shared fixture file) against the
// accepted Rental validator under the Emulator TEST-ONLY Rental policy. The
// wire answer is `validation_failed` without these codes (§2 Q7), so this is
// where each case's exact reason is proven.
import assert from 'node:assert/strict';
import test from 'node:test';
import { publicValidationDetails } from '../../../src/modules/content/domain/validation_details.js';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import { validateRentalBody } from '../../../src/modules/content/domain/type_rules/rental_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

interface CompatCase {
  readonly name: string;
  readonly createCase: string;
  readonly expectedIssues: readonly string[];
  readonly expectedViolations: readonly { code: string; fieldPath: string }[];
  readonly body: ContentBody;
}

void test('each Create case gets exactly its validator codes under the Emulator Rental policy', async () => {
  const fixture = (await readContentJson('fixtures/rental_create_compat.json')) as {
    readonly typeId: string;
    readonly actorUserId: string;
    readonly nowUtc: string;
    readonly cases: readonly CompatCase[];
  };
  assert.equal(fixture.typeId, 'rental');
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'rental',
  });
  assert.ok(resolution.ok);
  assert.equal(fixture.cases.length, 10);
  assert.deepEqual(fixture.cases[0]?.expectedIssues, [], 'the first case is the accepted draft');
  for (const item of fixture.cases) {
    const issues = validateRentalBody(item.body, {
      typeId: 'rental',
      marketId: 'LV',
      publisherRef: { type: 'page', id: 'page-compat-1' as never },
      createdByUserId: fixture.actorUserId,
      actorUserId: fixture.actorUserId,
      nowUtc: fixture.nowUtc,
      draftRevision: 2,
      market: resolution.market,
      lookups: resolution.lookups,
    });
    assert.deepEqual(issues, item.expectedIssues, `${item.name}: ${item.createCase}`);
    // M1 stage 3 (3-A): the public details the client maps to Create fields.
    assert.deepEqual(publicValidationDetails(issues), item.expectedViolations, item.name);
    // Every case carries exactly one reason, so the fixture isolates each rule.
    assert.ok(item.expectedIssues.length <= 1, item.name);
  }
});

void test('the accepted case fails for another acting user (Q3)', async () => {
  const fixture = (await readContentJson('fixtures/rental_create_compat.json')) as {
    readonly actorUserId: string;
    readonly nowUtc: string;
    readonly cases: readonly CompatCase[];
  };
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'rental',
  });
  assert.ok(resolution.ok);
  const valid = fixture.cases[0];
  assert.ok(valid);
  const issues = validateRentalBody(valid.body, {
    typeId: 'rental',
    marketId: 'LV',
    publisherRef: { type: 'page', id: 'page-compat-1' as never },
    createdByUserId: fixture.actorUserId,
    actorUserId: '01HZZZZZZZZZZZZZZZZZZZZZZ9',
    nowUtc: fixture.nowUtc,
    draftRevision: 2,
    market: resolution.market,
    lookups: resolution.lookups,
  });
  assert.deepEqual(issues, ['rental.attestation_user']);
});
