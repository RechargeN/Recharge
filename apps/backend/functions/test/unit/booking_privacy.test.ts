import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { BookingAuditFact } from '../../src/audit/booking_audit.js';
import {
  applyBookingLegalHold,
  pseudonymizeBookingIdentity,
  releaseBookingLegalHold,
} from '../../src/booking/privacy.js';

void test('account deletion pseudonymizes direct actor identity but preserves minimal audit TTL', () => {
  const expiresAt = new Date('2027-09-24T00:00:00.000Z');
  const fact: BookingAuditFact = {
    schemaVersion: 1,
    factType: 'booking_cancelled',
    bookingId: 'booking-1',
    actorId: 'account-direct-id',
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    bookingRevision: 2,
    occurredAt: '2026-09-24T00:00:00.000Z',
    retentionClass: 'bookingAudit',
    legalHold: false,
    expiresAt,
  };
  const pseudonymized = pseudonymizeBookingIdentity(fact, `anon_${'a'.repeat(64)}`);
  assert.equal(pseudonymized.actorId, `anon_${'a'.repeat(64)}`);
  assert.equal(pseudonymized.bookingId, fact.bookingId);
  assert.equal(pseudonymized.expiresAt, expiresAt);
  assert.equal(fact.actorId, 'account-direct-id');
});

void test('legal hold patch removes TTL and explicit release restores an exact expiry', () => {
  assert.deepEqual(applyBookingLegalHold(), { legalHold: true, removeExpiresAt: true });
  const expiresAt = new Date('2027-09-24T00:00:00.000Z');
  assert.deepEqual(releaseBookingLegalHold(expiresAt), {
    legalHold: false,
    removeExpiresAt: false,
    expiresAt,
  });
  assert.throws(() => releaseBookingLegalHold(new Date(Number.NaN)), /booking_expires_at_invalid/u);
});

void test('pseudonymization rejects raw or malformed replacement identifiers', () => {
  const fact = {
    schemaVersion: 1 as const,
    factType: 'booking_created' as const,
    bookingId: 'booking-1',
    actorId: 'account-direct-id',
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    bookingRevision: 1,
    occurredAt: '2026-09-24T00:00:00.000Z',
    retentionClass: 'bookingAudit' as const,
    legalHold: false as const,
    expiresAt: new Date('2027-09-24T00:00:00.000Z'),
  };
  assert.throws(
    () => pseudonymizeBookingIdentity(fact, 'another-direct-account-id'),
    /booking_pseudonymous_actor_id_invalid/u,
  );
});
