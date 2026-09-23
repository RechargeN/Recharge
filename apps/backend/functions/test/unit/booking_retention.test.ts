import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BookingRetentionPlanner,
  bookingRetentionCandidate,
  bookingRetentionPolicyIds,
  unresolvedBookingRetentionPolicies,
} from '../../src/booking/retention.js';
import type { RetentionPolicy } from '../../src/security/retention_registry.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

void test('unaccepted Booking retention durations fail closed for every record family', () => {
  const planner = new BookingRetentionPlanner(unresolvedBookingRetentionPolicies());
  for (const retentionClass of ['idempotency', 'outbox', 'audit'] as const) {
    const decision = planner.plan(
      bookingRetentionCandidate({
        recordId: `record-${retentionClass}`,
        retentionClass,
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        ...(retentionClass === 'outbox'
          ? { deliveryCompleted: true, reconciliationCompleted: true }
          : {}),
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    );
    assert.deepEqual(decision, {
      action: 'policy_unavailable',
      policyId: bookingRetentionPolicyIds[retentionClass],
      recordId: `record-${retentionClass}`,
    });
  }
});

void test('outbox cannot expire before delivery and reconciliation complete', () => {
  const policies: readonly RetentionPolicy[] = [
    {
      policyId: bookingRetentionPolicyIds.outbox,
      status: 'accepted',
      durationDays: 1,
      legalHoldSupported: true,
      evidenceRevision: 'test-only-policy',
    },
  ];
  const planner = new BookingRetentionPlanner(policies);
  const decision = planner.plan(
    bookingRetentionCandidate({
      recordId: 'outbox-1',
      retentionClass: 'outbox',
      createdAtUtc: '2026-01-01T00:00:00.000Z',
      deliveryCompleted: true,
      reconciliationCompleted: false,
    }),
    parseUtcInstant('2026-09-24T00:00:00.000Z'),
  );
  assert.deepEqual(decision, {
    action: 'retain_delivery_pending',
    policyId: bookingRetentionPolicyIds.outbox,
    recordId: 'outbox-1',
  });
});

void test('legal hold overrides cleanup while accepted test policies derive exact expiry', () => {
  const policies: readonly RetentionPolicy[] = Object.entries(bookingRetentionPolicyIds).map(
    ([retentionClass, policyId], index) => ({
      policyId,
      status: 'accepted' as const,
      durationDays: index + 1,
      legalHoldSupported: true,
      evidenceRevision: `test-only-${retentionClass}`,
    }),
  );
  const planner = new BookingRetentionPlanner(policies);
  assert.deepEqual(
    planner.plan(
      bookingRetentionCandidate({
        recordId: 'audit-held',
        retentionClass: 'audit',
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        legalHold: true,
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    ),
    {
      action: 'retain_legal_hold',
      policyId: bookingRetentionPolicyIds.audit,
      recordId: 'audit-held',
    },
  );
  assert.deepEqual(
    planner.plan(
      bookingRetentionCandidate({
        recordId: 'idempotency-pending',
        retentionClass: 'idempotency',
        createdAtUtc: '2026-09-24T00:00:00.000Z',
      }),
      parseUtcInstant('2026-09-24T12:00:00.000Z'),
    ),
    {
      action: 'retain_until',
      policyId: bookingRetentionPolicyIds.idempotency,
      recordId: 'idempotency-pending',
      expiresAtUtc: '2026-09-25T00:00:00.000Z',
    },
  );
  assert.deepEqual(
    planner.planRestore(
      bookingRetentionCandidate({
        recordId: 'audit-expired-backup',
        retentionClass: 'audit',
        createdAtUtc: '2026-01-01T00:00:00.000Z',
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    ),
    {
      action: 'restore_blocked_expired',
      policyId: bookingRetentionPolicyIds.audit,
      recordId: 'audit-expired-backup',
    },
  );
});

void test('backup restore cannot bypass an unresolved retention policy', () => {
  const planner = new BookingRetentionPlanner(unresolvedBookingRetentionPolicies());
  assert.deepEqual(
    planner.planRestore(
      bookingRetentionCandidate({
        recordId: 'booking-from-backup',
        retentionClass: 'idempotency',
        createdAtUtc: '2026-01-01T00:00:00.000Z',
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    ),
    {
      action: 'restore_blocked_policy_unavailable',
      policyId: bookingRetentionPolicyIds.idempotency,
      recordId: 'booking-from-backup',
    },
  );
});
