import assert from 'node:assert/strict';
import test from 'node:test';
import { publicValidationDetails } from '../../../src/modules/content/domain/validation_details.js';
import { rejected, toContentWireResult } from '../../../src/modules/content/domain/failures.js';

void test('public details are stable, bounded and never include caller keys or raw values', () => {
  const details = publicValidationDetails([
    'activity.title_length',
    'activity.title_length',
    'activity.criterion_required:difficulty',
    'activity.criterion_required:secret_value',
    'activity.unknown_field:phone@example.com',
    'internal.error:/private',
    'constructor',
    'toString',
    '__proto__',
  ]);
  assert.deepEqual(details, [
    { code: 'activity.title_length', fieldPath: '/body/title' },
    { code: 'activity.criterion_required', fieldPath: '/body/criteria/difficulty' },
  ]);
  assert.equal(Object.isFrozen(details), true);
  assert.equal(JSON.stringify(details).includes('secret'), false);
  assert.deepEqual(toContentWireResult('submission', rejected('validation_failed', details)), {
    schemaVersion: 1,
    kind: 'rejected',
    code: 'validation_failed',
    violations: details,
  });
});
void test('legacy general failures remain byte-for-byte shaped; other errors carry no details', () => {
  assert.deepEqual(toContentWireResult('submission', rejected('validation_failed')), {
    schemaVersion: 1,
    kind: 'rejected',
    code: 'validation_failed',
  });
  assert.deepEqual(
    toContentWireResult(
      'submission',
      rejected('capability_denied', publicValidationDetails(['activity.title_length'])),
    ),
    {
      schemaVersion: 1,
      kind: 'rejected',
      code: 'capability_denied',
    },
  );
  assert.deepEqual(
    publicValidationDetails(Array.from({ length: 100 }, (_, i) => `unknown.${i}`)),
    [],
  );
});

void test('M1 stage 3: Place, Rental and Collection get exact public fields, never caller keys', () => {
  assert.deepEqual(
    publicValidationDetails([
      'place.media.cover_missing',
      'place.criteria.required_missing:difficulty',
      'place.criteria.required_missing:Bad Key',
      'place.contacts.unknown_field:secret',
      'rental.cover_required',
      'rental.private_field_forbidden:internalNote',
      'rental.group.unknown_field:serial',
      'collection.composition_review_mismatch',
      'collection.item.unknown_field:payload',
    ]),
    [
      { code: 'place.media.cover_missing', fieldPath: '/body/media/coverImage' },
      { code: 'place.criteria.required_missing', fieldPath: '/body/criteria/difficulty' },
      { code: 'rental.cover_required', fieldPath: '/body/mediaRefs' },
      { code: 'rental.private_field_forbidden', fieldPath: '/body' },
      { code: 'collection.composition_review_mismatch', fieldPath: '/body/compositionReview' },
    ],
  );
  const text = JSON.stringify(
    publicValidationDetails([
      'rental.private_field_forbidden:internalNote',
      'place.contacts.unknown_field:secret',
    ]),
  );
  assert.equal(text.includes('internalNote'), false);
  assert.equal(text.includes('secret'), false);
});

void test('every public code and path of the allowlist matches the content_result schema', async () => {
  const { readContentJson } = await import('../../../src/contracts/content_schema_registry.js');
  const schema = (await readContentJson('content_result.schema.json')) as {
    $defs: {
      validationViolation: {
        properties: { code: { pattern: string }; fieldPath: { pattern: string } };
      };
    };
  };
  const codePattern = new RegExp(schema.$defs.validationViolation.properties.code.pattern, 'u');
  const pathPattern = new RegExp(
    schema.$defs.validationViolation.properties.fieldPath.pattern,
    'u',
  );
  const source = await import('node:fs').then((fs) =>
    fs.readFileSync(
      new URL('../../../../src/modules/content/domain/validation_details.ts', import.meta.url),
      'utf8',
    ),
  );
  const codes = [
    ...source.matchAll(/^\s+'((?:activity|place|rental|collection)\.[^']+)': '/gmu),
  ].map((m) => m[1] as string);
  assert.ok(codes.length > 250, `allowlist size ${codes.length}`);
  for (const issue of codes) {
    const details = publicValidationDetails([issue]);
    assert.equal(details.length, 1, issue);
    assert.match(details[0]!.code, codePattern, issue);
    assert.match(details[0]!.fieldPath, pathPattern, issue);
  }
  assert.deepEqual(
    publicValidationDetails(['place.pricing.entryType', 'place.hours.mode_unsupported:seasonal']),
    [
      { code: 'place.pricing.entry_type', fieldPath: '/body/pricing/entryType' },
      { code: 'place.hours.mode_unsupported', fieldPath: '/body/hours/mode' },
    ],
  );
});
