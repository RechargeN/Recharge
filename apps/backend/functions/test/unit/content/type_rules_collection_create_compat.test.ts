// D3.4 §5.7 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md): every body the mobile
// mapper produces for a Create Collection draft case (the shared fixture file)
// against the accepted Collection validator under the Emulator reference data
// and the members' live status as the case states it. The wire answer is
// `validation_failed` without these codes, so this is where each case's exact
// reason is proven; the Dart mapper test proves the bodies.
import assert from 'node:assert/strict';
import test from 'node:test';
import { publicValidationDetails } from '../../../src/modules/content/domain/validation_details.js';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import { validateCollectionBody } from '../../../src/modules/content/domain/type_rules/collection_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

interface CompatCase {
  readonly name: string;
  readonly createCase: string;
  readonly unavailableStableKeys: readonly string[];
  readonly expectedIssues: readonly string[];
  readonly expectedViolations: readonly { code: string; fieldPath: string }[];
  readonly body: ContentBody;
}

async function fixture() {
  return (await readContentJson('fixtures/collection_create_compat.json')) as {
    readonly reviewedRevision: number;
    readonly cases: readonly CompatCase[];
  };
}

async function check(item: CompatCase, draftRevision: number) {
  const resolution = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'collection',
  });
  assert.ok(resolution.ok);
  const unavailable = new Set(item.unavailableStableKeys);
  return validateCollectionBody(item.body, {
    typeId: 'collection',
    marketId: 'LV',
    publisherRef: { type: 'page', id: 'page-compat-1' as never },
    createdByUserId: 'server-user-compat',
    actorUserId: 'server-user-compat',
    nowUtc: '2026-10-12T10:00:00.000Z',
    draftRevision,
    publishedObjects: {
      statusOf: (type, id) => (unavailable.has(`${type}:${id}`) ? 'unavailable' : 'ready'),
    },
    market: resolution.market,
    lookups: resolution.lookups,
  });
}

void test('each Create case gets exactly its validator codes under the Emulator reference data', async () => {
  const { reviewedRevision, cases } = await fixture();
  assert.equal(cases.length, 10);
  assert.deepEqual(cases[0]?.expectedIssues, [], 'the first case is the accepted draft');
  for (const item of cases) {
    const issues = await check(item, reviewedRevision);
    assert.deepEqual(issues, item.expectedIssues, `${item.name}: ${item.createCase}`);
    // M1 stage 3 (3-A): the public details the client maps to Create fields.
    assert.deepEqual(publicValidationDetails(issues), item.expectedViolations, item.name);
  }
});

void test('the review belongs to the revision the save produced: any other revision is stale', async () => {
  const { reviewedRevision, cases } = await fixture();
  const valid = cases[0];
  assert.ok(valid);
  assert.deepEqual(await check(valid, reviewedRevision + 1), [
    'collection.composition_review_stale',
  ]);
});

void test('the bodies carry no item geo and no foreign media in snapshots', async () => {
  const { cases } = await fixture();
  for (const item of cases)
    for (const entry of item.body.items as { snapshot: Record<string, unknown> }[]) {
      for (const key of ['latitude', 'longitude', 'geo', 'location', 'point', 'coverMediaId'])
        assert.equal(key in entry.snapshot, false, `${item.name}: ${key}`);
    }
});
