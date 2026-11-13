import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { Ajv2020 } from 'ajv/dist/2020.js';
import { contentContractRoot } from '../../src/contracts/content_schema_registry.js';
void test('Place link contract exposes eligible public fields only; failures contain no labels or internal authority', async () => {
  const root = path.resolve(contentContractRoot, '../../discover/v1');
  const schema = JSON.parse(
    await readFile(path.join(root, 'place_link_result.schema.json'), 'utf8'),
  ) as object;
  const fixture = JSON.parse(
    await readFile(path.join(root, 'fixtures/place_link.json'), 'utf8'),
  ) as Record<string, unknown>;
  const validate = new Ajv2020({ strict: true }).compile(schema);
  assert.ok(validate(fixture));
  for (const status of ['unknown', 'forbidden', 'unavailable']) {
    assert.ok(validate({ status }));
    assert.equal(validate({ status, place: fixture.place }), false);
  }
  assert.equal(validate({ ...fixture, moderationReason: 'private' }), false);
});
