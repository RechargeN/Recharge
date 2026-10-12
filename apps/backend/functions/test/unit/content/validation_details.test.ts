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
