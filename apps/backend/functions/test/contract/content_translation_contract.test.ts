import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { Ajv2020 } from 'ajv/dist/2020.js';

import {
  contentTranslationFailureCodes,
  contentTranslationTargetLocales,
} from '../../src/modules/content_translation/content_translation_contract.js';

const schemaDir = path.resolve(
  process.cwd(),
  '../../../packages/api_contracts/schema/content_translation/v1',
);
interface ResultSchema {
  readonly $defs: {
    readonly failureCode: { readonly enum: string[] };
    readonly offered: {
      readonly properties: { readonly targetLocale: { readonly enum: string[] } };
    };
  };
}
const schema = (name: string) =>
  JSON.parse(readFileSync(path.join(schemaDir, name), 'utf8')) as Record<string, unknown>;

void test('the schema names exactly the refusal codes and languages of the module', () => {
  const result = schema('content_translation_result.schema.json') as unknown as ResultSchema;
  assert.deepEqual(
    [...result.$defs.failureCode.enum].sort(),
    [...contentTranslationFailureCodes].sort(),
  );
  assert.deepEqual(result.$defs.offered.properties.targetLocale.enum, [
    ...contentTranslationTargetLocales,
  ]);
});

void test('the request schema refuses text; the result schema refuses extra fields', () => {
  const ajv = new Ajv2020({ strict: false });
  const validRequest = ajv.compile(schema('content_translation_request.schema.json'));
  const request = {
    schemaVersion: 1,
    requestId: 'req-1',
    contentId: randomUUID(),
    publishedRevisionId: randomUUID(),
    targetLocale: 'ru',
  };
  assert.equal(validRequest(request), true);
  assert.equal(validRequest({ ...request, text: 'translate me' }), false);
  const validResult = ajv.compile(schema('content_translation_result.schema.json'));
  const translated = {
    schemaVersion: 1,
    kind: 'translated',
    contentId: request.contentId,
    publishedRevisionId: request.publishedRevisionId,
    sourceLocale: 'lv',
    targetLocale: 'ru',
    machineTranslated: true,
    fields: { title: 'Перевод' },
  };
  assert.equal(validResult(translated), true);
  assert.equal(validResult({ ...translated, fields: { safetyNotice: 'x' } }), false);
  assert.equal(validResult({ schemaVersion: 1, kind: 'rejected', code: 'same_language' }), true);
  assert.equal(validResult({ schemaVersion: 1, kind: 'rejected', code: 'other' }), false);
});
