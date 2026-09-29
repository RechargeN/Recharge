import assert from 'node:assert/strict';
import test from 'node:test';

import {
  contentTargetRefs,
  createContentSchemaRegistry,
  readContentJson,
  type ContentContractTarget,
} from '../../src/contracts/content_schema_registry.js';
import { contentTypeIds } from '../../src/contracts/content_v1.js';
import { validateContentContract } from '../../src/contracts/validate_content_contract.js';

function asList(value: unknown): readonly unknown[] {
  return Array.isArray(value) ? (value as readonly unknown[]) : [value];
}

void test('content schemas accept canonical fixtures and fail closed on invalid or newer input', async () => {
  const valid = (await readContentJson('fixtures/valid.json')) as Record<string, unknown>;
  const invalid = (await readContentJson('fixtures/invalid.json')) as Record<string, unknown>;
  const forward = (await readContentJson('fixtures/forward.json')) as Record<string, unknown>;
  assert.deepEqual(Object.keys(valid).sort(), Object.keys(contentTargetRefs).sort());
  for (const [target, value] of Object.entries(valid))
    for (const item of asList(value))
      assert.equal(
        (await validateContentContract(target as ContentContractTarget, item)).ok,
        true,
        `valid ${target}`,
      );
  for (const [target, value] of Object.entries(invalid))
    for (const item of asList(value))
      assert.equal(
        (await validateContentContract(target as ContentContractTarget, item)).ok,
        false,
        `invalid ${target}`,
      );
  for (const [target, value] of Object.entries(forward))
    for (const item of asList(value))
      assert.equal(
        (await validateContentContract(target as ContentContractTarget, item)).ok,
        false,
        `forward ${target}`,
      );
});

void test('schema type enum equals the exact ten-type registry list', async () => {
  const registry = await createContentSchemaRegistry();
  const common = registry.schemas.find((item) => item.fileName === 'content_common.schema.json');
  assert.ok(common);
  const schema = (await readContentJson('content_common.schema.json')) as {
    $defs: { typeId: { enum: string[] } };
  };
  assert.deepEqual([...schema.$defs.typeId.enum], [...contentTypeIds]);
  assert.equal(contentTypeIds.length, 10);
  assert.equal(contentTypeIds.includes('quick_plan' as never), false);
});
