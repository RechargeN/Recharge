import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

void test('reference data contracts and domain do not import Firebase', async () => {
  const files = [
    'src/contracts/reference_data_v1.ts',
    'src/contracts/reference_data_schema_registry.ts',
    'src/modules/reference_data/domain/market_config.ts',
    'src/modules/reference_data/application/reference_data_service.ts',
  ];
  for (const file of files) {
    const source = await readFile(file, 'utf8');
    assert.equal(/firebase-(?:admin|functions)|@google-cloud/u.test(source), false, file);
  }
});
