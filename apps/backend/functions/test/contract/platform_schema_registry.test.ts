import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { test } from 'node:test';

import type { JsonObject, MinimumClientPolicy } from '../../src/contracts/platform_v1.js';
import {
  createPlatformSchemaRegistry,
  platformSchemaFiles,
  platformTargetRefs,
} from '../../src/contracts/schema_registry.js';
import {
  createSemanticPayloadHash,
  decideIdempotency,
  evaluateClientCompatibility,
} from '../../src/contracts/validate_platform_contract.js';
import { parseIdempotencyKey } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

void test('schema registry has exact unique IDs and deterministic SHA-256 descriptors', async () => {
  const registry = await createPlatformSchemaRegistry();
  assert.equal(registry.schemas.length, platformSchemaFiles.length);
  assert.equal(
    new Set(registry.schemas.map((schema) => schema.id)).size,
    platformSchemaFiles.length,
  );
  for (const schema of registry.schemas) {
    assert.match(schema.sha256, /^[0-9a-f]{64}$/);
  }
  for (const target of Object.keys(platformTargetRefs)) {
    assert.equal(typeof registry.validator(target as keyof typeof platformTargetRefs), 'function');
  }
});

void test('semantic payload hash is order-independent and excludes transport context by construction', () => {
  const firstPayload: JsonObject = { z: 1, nested: { b: true, a: 'x' } };
  const reorderedPayload: JsonObject = { nested: { a: 'x', b: true }, z: 1 };
  const first = createSemanticPayloadHash({
    actorScope: 'user:synthetic',
    commandType: 'profile.update',
    commandVersion: 1,
    payload: firstPayload,
  });
  const second = createSemanticPayloadHash({
    actorScope: 'user:synthetic',
    commandType: 'profile.update',
    commandVersion: 1,
    payload: reorderedPayload,
  });
  assert.equal(first, second);
  assert.match(first, /^sha256:[0-9a-f]{64}$/);
});

void test('same idempotency key with a different semantic payload is rejected', () => {
  const key = parseIdempotencyKey('profile-update-0001');
  const originalHash = createSemanticPayloadHash({
    actorScope: 'user:synthetic',
    commandType: 'profile.update',
    commandVersion: 1,
    payload: { displayName: 'Original' },
  });
  const changedHash = createSemanticPayloadHash({
    actorScope: 'user:synthetic',
    commandType: 'profile.update',
    commandVersion: 1,
    payload: { displayName: 'Changed' },
  });

  const conflict = decideIdempotency('user:synthetic/profile.update/v1', key, changedHash, {
    scopeKey: 'user:synthetic/profile.update/v1',
    idempotencyKey: key,
    semanticPayloadHash: originalHash,
    state: 'committed',
    result: { entityId: '01ARZ3NDEKTSV4RRFFQ69G5FAV' },
  });
  assert.deepEqual(conflict, {
    kind: 'reject',
    code: 'idempotency_conflict',
    semanticPayloadHash: changedHash,
  });
});

void test('same key and semantic hash replays the committed typed result', () => {
  const key = parseIdempotencyKey('profile-update-0001');
  const hash = createSemanticPayloadHash({
    actorScope: 'user:synthetic',
    commandType: 'profile.update',
    commandVersion: 1,
    payload: { displayName: 'Original' },
  });
  const replay = decideIdempotency('user:synthetic/profile.update/v1', key, hash, {
    scopeKey: 'user:synthetic/profile.update/v1',
    idempotencyKey: key,
    semanticPayloadHash: hash,
    state: 'committed',
    result: { revision: 2 },
  });
  assert.equal(replay.kind, 'replay');
});

void test('minimum supported client rejects build and contract independently', () => {
  const policy: MinimumClientPolicy = {
    policyRevision: 1,
    platform: 'android',
    minSupportedBuild: 10,
    recommendedBuild: 20,
    supportedContractMajors: [1],
    effectiveAt: parseUtcInstant('2026-09-21T10:00:00Z'),
  };
  const client = {
    appId: 'recharge-mobile',
    platform: 'android' as const,
    appVersion: '1.0.0',
    buildNumber: 9,
  };
  assert.deepEqual(evaluateClientCompatibility(client, 1, policy), {
    kind: 'rejected',
    code: 'unsupported_client',
  });
  assert.deepEqual(evaluateClientCompatibility({ ...client, buildNumber: 10 }, 2, policy), {
    kind: 'rejected',
    code: 'unsupported_contract',
  });
  assert.deepEqual(evaluateClientCompatibility({ ...client, buildNumber: 15 }, 1, policy), {
    kind: 'supported',
    updateRecommended: true,
  });
});

void test('platform contracts do not import Firebase', async () => {
  const root = path.resolve(process.cwd(), 'src', 'contracts');
  for (const fileName of [
    'platform_v1.ts',
    'schema_registry.ts',
    'validate_platform_contract.ts',
  ]) {
    const source = await readFile(path.join(root, fileName), 'utf8');
    assert.doesNotMatch(source, /from\s+['"]firebase(?:-admin|-functions)?/);
  }
});
