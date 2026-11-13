import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { Ajv2020 } from 'ajv/dist/2020.js';
import { contentContractRoot } from '../../src/contracts/content_schema_registry.js';
void test('Activity public fixture/schema rejects pseudo Event and private criteria fields', async () => {
  const root = path.resolve(contentContractRoot, '../../discover/v1');
  const schema = JSON.parse(
    await readFile(path.join(root, 'catalog_activity_item.schema.json'), 'utf8'),
  ) as object;
  const fixture = JSON.parse(
    await readFile(path.join(root, 'fixtures/activity.json'), 'utf8'),
  ) as Record<string, unknown>;
  const validate = new Ajv2020({ strict: true, allErrors: true }).compile(schema);
  assert.ok(validate(fixture), JSON.stringify(validate.errors));
  for (const key of ['criteria', 'price', 'occurrences', 'internalModerationEvidence'])
    assert.equal(validate({ ...fixture, [key]: {} }), false, key);
  assert.equal(
    validate({ ...fixture, referenceRevisions: { taxonomyRevisionId: 'unknown' } }),
    false,
  );
  assert.equal(validate({ ...fixture, typicalDurationMinutes: { min: 0, max: 120 } }), false);
  assert.equal(
    validate({
      ...fixture,
      optionalContribution: {
        kind: 'donation',
        note: 'Optional group donation',
        amountHint: { amountMinor: 0, currencyCode: 'EUR' },
      },
    }),
    false,
  );
});

void test('canonical taxonomy artifact satisfies the BCK-20 dataset contract', async () => {
  const root = path.resolve(contentContractRoot, '../../reference_data/v1');
  const schema = JSON.parse(
    await readFile(path.join(root, 'taxonomy_dataset.schema.json'), 'utf8'),
  ) as object;
  const artifact = JSON.parse(
    await readFile(path.join(root, 'artifacts/category-system-1.4.3.json'), 'utf8'),
  ) as Record<string, unknown>;
  const validate = new Ajv2020({ strict: true, allErrors: true }).compile(schema);
  assert.ok(validate(artifact), JSON.stringify(validate.errors));
  assert.equal(validate({ ...artifact, sourceRecordId: 'invented-source' }), false);
});
