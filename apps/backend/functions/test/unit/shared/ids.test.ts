import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isEntityId, parseEntityId, parseIdempotencyKey } from '../../../src/shared/ids.js';

void test('accepts canonical ULID and UUID entity references', () => {
  assert.equal(isEntityId('01ARZ3NDEKTSV4RRFFQ69G5FAV'), true);
  assert.equal(isEntityId('550e8400-e29b-41d4-a716-446655440000'), true);
  assert.equal(parseEntityId('01ARZ3NDEKTSV4RRFFQ69G5FAV'), '01ARZ3NDEKTSV4RRFFQ69G5FAV');
});

void test('rejects temporary, name-derived and malformed references', () => {
  for (const value of ['loc_profile_1', 'Riga', '', '01ARZ3NDEKTSV4RRFFQ69G5FAI']) {
    assert.equal(isEntityId(value), false, value);
    assert.throws(() => parseEntityId(value), TypeError);
  }
});

void test('idempotency keys are bounded opaque values', () => {
  assert.equal(parseIdempotencyKey('profile-update-0001'), 'profile-update-0001');
  assert.throws(() => parseIdempotencyKey('short'), TypeError);
  assert.throws(() => parseIdempotencyKey('contains whitespace'), TypeError);
});
