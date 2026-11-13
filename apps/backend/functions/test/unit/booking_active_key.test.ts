import assert from 'node:assert/strict';
import { test } from 'node:test';
import { activeBookingKeyId, activeKeyMatches } from '../../src/inventory/active_key.js';

void test('active key is deterministic for actor occurrence and general scope', () => {
  const id = activeBookingKeyId('user', 'occurrence');
  assert.match(id, /^[0-9a-f]{64}$/u);
  assert.equal(id, activeBookingKeyId('user', 'occurrence'));
  assert.notEqual(id, activeBookingKeyId('other', 'occurrence'));
});

void test('mismatched or dangling key shape fails closed', () => {
  const valid = {
    schemaVersion: 1,
    scopeVersion: 'booking_active_scope_v1',
    actorId: 'user',
    occurrenceId: 'occ',
    admissionTrackId: 'general',
    bookingId: 'booking',
    bookingRevision: 1,
    createdAt: '2026-08-29T00:00:00Z',
    updatedAt: '2026-08-29T00:00:00Z',
  };
  assert.equal(activeKeyMatches(valid, 'user', 'occ'), true);
  assert.equal(activeKeyMatches({ ...valid, actorId: 'other' }, 'user', 'occ'), false);
  assert.equal(activeKeyMatches({ ...valid, bookingId: '' }, 'user', 'occ'), false);
});
