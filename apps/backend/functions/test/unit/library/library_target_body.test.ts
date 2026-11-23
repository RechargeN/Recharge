import assert from 'node:assert/strict';
import test from 'node:test';

import { publishedRevisionBody } from '../../../src/modules/library/library_target_body.js';

// A34 staging 2026-11-23: every save to Library was refused "object_unavailable"
// because Library read `body`, while Content stores the published body as the
// JSON string `bodyJson` (firestore_content_repository).

void test('the stored bodyJson is the published body', () => {
  const body = { title: 'Walk', visibility: 'public', location: { city: 'Riga' } };
  assert.deepEqual(publishedRevisionBody({ bodyJson: JSON.stringify(body) }), body);
});

void test('a missing, broken or non-object body is no target', () => {
  assert.equal(publishedRevisionBody(undefined), null);
  assert.equal(publishedRevisionBody({}), null);
  assert.equal(publishedRevisionBody({ bodyJson: '{broken' }), null);
  assert.equal(publishedRevisionBody({ bodyJson: '[1,2]' }), null);
  assert.equal(publishedRevisionBody({ bodyJson: 'null' }), null);
});
