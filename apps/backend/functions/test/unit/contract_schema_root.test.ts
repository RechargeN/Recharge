import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { contractSchemaRoot } from '../../src/contracts/contract_schema_root.js';
import { contentContractRoot } from '../../src/contracts/content_schema_registry.js';

void test('the repository keeps reading packages/api_contracts', () => {
  assert.ok(
    contentContractRoot.endsWith(path.join('packages', 'api_contracts', 'schema', 'content', 'v1')),
  );
});

void test('a deployed bundle reads its own staged copy (2026-11-08 ENOENT in dev)', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'contract-root-'));
  try {
    assert.equal(
      contractSchemaRoot('media', dir),
      path.resolve(dir, '..', '..', '..', 'packages', 'api_contracts', 'schema', 'media', 'v1'),
    );
    mkdirSync(path.join(dir, 'contracts', 'media', 'v1'), { recursive: true });
    assert.equal(contractSchemaRoot('media', dir), path.join(dir, 'contracts', 'media', 'v1'));
    assert.notEqual(
      contractSchemaRoot('content', dir),
      path.join(dir, 'contracts', 'content', 'v1'),
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
