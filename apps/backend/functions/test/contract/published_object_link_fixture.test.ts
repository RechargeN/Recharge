import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { Ajv2020 } from 'ajv/dist/2020.js';
import { contentContractRoot } from '../../src/contracts/content_schema_registry.js';
import { listingTypeIds } from '../../src/modules/catalog/domain/published_object_link.js';

// D3.4 §2.3: the exact-id relation answer exposes allowlisted public facts of an
// eligible listing only; every other status carries nothing (no title, no reason).
void test('published object contract exposes eligible public fields only; other statuses carry nothing', async () => {
  const root = path.resolve(contentContractRoot, '../../discover/v1');
  const schema = JSON.parse(
    await readFile(path.join(root, 'published_object_link_result.schema.json'), 'utf8'),
  ) as { oneOf: { properties: { object?: { properties: { typeId: { enum: string[] } } } } }[] };
  const fixture = JSON.parse(
    await readFile(path.join(root, 'fixtures/published_object_link.json'), 'utf8'),
  ) as { status: string; object: Record<string, unknown> };
  const validate = new Ajv2020({ strict: true }).compile(schema);
  assert.ok(validate(fixture));
  assert.deepEqual(schema.oneOf[0]?.properties.object?.properties.typeId.enum, [...listingTypeIds]);
  for (const typeId of listingTypeIds)
    assert.ok(validate({ ...fixture, object: { ...fixture.object, typeId } }), typeId);
  for (const typeId of ['event', 'activity', 'collection'])
    assert.equal(validate({ ...fixture, object: { ...fixture.object, typeId } }), false, typeId);
  for (const status of ['withheld', 'unknown', 'forbidden', 'unavailable']) {
    assert.ok(validate({ status }));
    assert.equal(validate({ status, object: fixture.object }), false);
    assert.equal(validate({ status, title: 'Quiet Place' }), false);
  }
  assert.equal(validate({ ...fixture, moderationReason: 'private' }), false);
  assert.equal(validate({ ...fixture, object: { ...fixture.object, location: {} } }), false);
});
