import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createMediaSchemaRegistry,
  mediaTargetRefs,
  readMediaJson,
  type MediaContractTarget,
} from '../../src/contracts/media_schema_registry.js';
import { mediaFailureCodes, mediaFamilies, mediaLifecycles } from '../../src/contracts/media_v1.js';
import { validateMediaContract } from '../../src/contracts/validate_media_contract.js';

function asList(value: unknown): readonly unknown[] {
  return Array.isArray(value) ? (value as readonly unknown[]) : [value];
}

void test('media schemas accept canonical fixtures and fail closed on invalid or newer input', async () => {
  const valid = (await readMediaJson('fixtures/valid.json')) as Record<string, unknown>;
  const invalid = (await readMediaJson('fixtures/invalid.json')) as Record<string, unknown>;
  const forward = (await readMediaJson('fixtures/forward.json')) as Record<string, unknown>;
  assert.deepEqual(Object.keys(valid).sort(), Object.keys(mediaTargetRefs).sort());
  for (const [group, expected] of [
    ['valid', true],
    ['invalid', false],
    ['forward', false],
  ] as const) {
    const fixtures = { valid, invalid, forward }[group];
    for (const [target, value] of Object.entries(fixtures))
      for (const [index, item] of asList(value).entries())
        assert.equal(
          (await validateMediaContract(target as MediaContractTarget, item)).ok,
          expected,
          `${group} ${target}[${index}]`,
        );
  }
});

void test('schema enums equal the TypeScript vocabulary (parity)', async () => {
  const common = (await readMediaJson('media_common.schema.json')) as {
    $defs: { family: { enum: string[] }; lifecycle: { enum: string[] } };
  };
  assert.deepEqual([...common.$defs.family.enum], [...mediaFamilies]);
  assert.deepEqual([...common.$defs.lifecycle.enum], [...mediaLifecycles]);
  const result = (await readMediaJson('media_result.schema.json')) as {
    $defs: { failureCode: { enum: string[] } };
  };
  assert.deepEqual([...result.$defs.failureCode.enum], [...mediaFailureCodes]);
});

void test('schema registry ids are unique and the wire contract never carries object keys', async () => {
  const registry = await createMediaSchemaRegistry();
  assert.equal(new Set(registry.schemas.map((item) => item.id)).size, registry.schemas.length);
  for (const fileName of [
    'media_asset.schema.json',
    'upload_session.schema.json',
    'media_command.schema.json',
  ]) {
    const text = JSON.stringify(await readMediaJson(fileName));
    assert.equal(/objectKey|bucket|signedUrl|publicUrl/iu.test(text), false, fileName);
  }
});
