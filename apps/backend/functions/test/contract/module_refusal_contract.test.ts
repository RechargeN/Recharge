import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { test } from 'node:test';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

import { identitySessionFailureCodes } from '../../src/contracts/identity_session_v1.js';
import { libraryRefusalCodes, rejected } from '../../src/modules/library/library_contract.js';
import { privacyIntakeRefusalCodes } from '../../src/modules/privacy_orchestration/application/privacy_request_intake.js';
import {
  quickPlanRefusalCodes,
  reject as rejectQuickPlan,
  rejectScenario,
  scenarioRefusalCodes,
} from '../../src/modules/quick_plan/quick_plan_contract.js';
import {
  reject as rejectRoute,
  routeRefusalCodes,
} from '../../src/modules/route/route_contract.js';
import {
  moduleTransportRefusalCodes,
  rejected as transportRejected,
} from '../../src/shared/failures.js';

/**
 * L4.8: the refusal schemas in packages/api_contracts and the code lists the
 * backend compiles against hold exactly the same codes, and refusals the
 * backend builds validate. The compiler keeps every `reject(...)` inside its
 * list; this test keeps the list equal to the schema.
 */
const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;
const root = path.resolve(process.cwd(), '..', '..', '..', 'packages', 'api_contracts', 'schema');

async function json(...parts: string[]): Promise<unknown> {
  return JSON.parse(await readFile(path.join(root, ...parts), 'utf8')) as unknown;
}

function compile(schema: unknown): ValidateFunction {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  return ajv.compile(schema as object);
}

function enumOf(schema: unknown, name: string): string[] {
  const defs = (schema as { $defs: Record<string, { enum: string[] }> }).$defs;
  return defs[name]!.enum;
}

function sameCodes(actual: readonly string[], expected: readonly string[], label: string): void {
  assert.deepEqual([...actual].sort(), [...expected].sort(), label);
}

const modules = [
  ['library', libraryRefusalCodes],
  ['quick_plan', quickPlanRefusalCodes],
  ['scenario', scenarioRefusalCodes],
  ['route', routeRefusalCodes],
] as const;

for (const [name, codes] of modules) {
  void test(`${name}: schema enum equals the backend code list and fixtures hold`, async () => {
    const schema = await json(name, 'v1', `${name}_refusal.schema.json`);
    sameCodes(enumOf(schema, 'refusalCode'), codes, name);
    for (const code of moduleTransportRefusalCodes) {
      assert.ok((codes as readonly string[]).includes(code), `${name} lists transport ${code}`);
    }
    const validate = compile(schema);
    for (const value of (await json(name, 'v1', 'fixtures', 'valid.json')) as unknown[]) {
      assert.equal(validate(value), true, `${name} valid ${JSON.stringify(value)}`);
    }
    for (const file of ['invalid.json', 'forward.json']) {
      for (const value of (await json(name, 'v1', 'fixtures', file)) as unknown[]) {
        assert.equal(validate(value), false, `${name} ${file} ${JSON.stringify(value)}`);
      }
    }
    assert.equal(validate(transportRejected('feature_disabled')), true, `${name} transport answer`);
  });
}

void test('refusals the backend builds validate against their schemas', async () => {
  const built = [
    ['library', rejected('revision_conflict', { currentRevision: 2, ownerRevision: 3 })],
    ['quick_plan', rejectQuickPlan('deleted', { serverRevision: 2 })],
    ['scenario', rejectScenario('distribution_invalid', { issues: [] })],
    ['route', rejectRoute('publication_active', { serverRevision: 2 })],
  ] as const;
  for (const [name, value] of built) {
    const validate = compile(await json(name, 'v1', `${name}_refusal.schema.json`));
    assert.equal(validate(value), true, `${name} ${JSON.stringify(validate.errors)}`);
  }
});

void test('privacy intake: schema enum equals the backend list and fixtures hold', async () => {
  const schema = await json('privacy', 'v1', 'privacy_intake_refusal.schema.json');
  sameCodes(enumOf(schema, 'refusalCode'), privacyIntakeRefusalCodes, 'privacy intake');
  const validate = compile(schema);
  const fixture = (kind: string) =>
    json('privacy', 'v1', 'fixtures', `intake_refusal_${kind}.json`) as Promise<unknown[]>;
  for (const value of await fixture('valid')) assert.equal(validate(value), true);
  for (const kind of ['invalid', 'forward']) {
    for (const value of await fixture(kind)) assert.equal(validate(value), false, kind);
  }
});

void test('identity session: failure enum equals the backend list', async () => {
  const schema = await json('identity', 'v1', 'identity_session_result.schema.json');
  sameCodes(enumOf(schema, 'failureCode'), identitySessionFailureCodes, 'identity session');
  const validate = compile(schema);
  const answer = (code: string) => ({
    schemaVersion: 1,
    commandType: 'establishIdentitySession',
    requestId: 'req_identity_session_1',
    serverTime: '2026-09-22T00:04:00.000Z',
    kind: 'rejected',
    error: { schemaVersion: 1, code, retryable: false, correlationId: 'req_identity_session_1' },
  });
  for (const code of identitySessionFailureCodes) {
    assert.equal(validate(answer(code)), true, code);
  }
  assert.equal(validate(answer('future_refusal_code')), false);
});

void test('positive control: a code missing from a list is detected', () => {
  assert.throws(() => sameCodes(['a', 'b'], ['a'], 'control'));
});
