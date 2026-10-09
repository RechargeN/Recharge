import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BookingRetentionPlanner,
  acceptedBookingRetentionPolicies,
  auditExpiresAt,
  bookingRetentionCandidate,
  bookingRetentionBaselineMarkets,
  bookingRetentionDecisionId,
  bookingRetentionDurationDays,
  bookingRetentionPolicyIds,
  idempotencyExpiresAt,
  notificationOutboxExpiresAt,
  outboxExpiresAt,
  unresolvedBookingRetentionPolicies,
} from '../../src/booking/retention.js';
import type { RetentionPolicy } from '../../src/security/retention_registry.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

void test('unaccepted Booking retention durations fail closed for every record family', () => {
  const planner = new BookingRetentionPlanner(unresolvedBookingRetentionPolicies());
  for (const retentionClass of ['core', 'idempotency', 'outbox', 'audit'] as const) {
    const decision = planner.plan(
      bookingRetentionCandidate({
        recordId: `record-${retentionClass}`,
        retentionClass,
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        ...(retentionClass === 'outbox'
          ? {
              deliveredAtUtc: '2026-01-01T00:00:00.000Z',
              reconciledAtUtc: '2026-01-01T00:00:00.000Z',
            }
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
      deliveredAtUtc: '2026-01-02T00:00:00.000Z',
    }),
    parseUtcInstant('2026-09-24T00:00:00.000Z'),
  );
  assert.deepEqual(decision, {
    action: 'retain_delivery_pending',
    policyId: bookingRetentionPolicyIds.outbox,
    recordId: 'outbox-1',
  });
});

void test('accepted owner decision fixes exact Baltics baseline durations', () => {
  assert.deepEqual(bookingRetentionBaselineMarkets, ['LV', 'EE', 'LT']);
  assert.deepEqual(bookingRetentionDurationDays, {
    core: 90,
    idempotency: 7,
    outbox: 30,
    audit: 365,
  });
  assert.deepEqual(
    acceptedBookingRetentionPolicies().map((policy) =>
      policy.status === 'accepted'
        ? [policy.policyId, policy.durationDays, policy.evidenceRevision]
        : [policy.policyId, policy.status],
    ),
    [
      [bookingRetentionPolicyIds.core, 90, bookingRetentionDecisionId],
      [bookingRetentionPolicyIds.idempotency, 7, bookingRetentionDecisionId],
      [bookingRetentionPolicyIds.outbox, 30, bookingRetentionDecisionId],
      [bookingRetentionPolicyIds.audit, 365, bookingRetentionDecisionId],
    ],
  );
});

void test('accepted policy derives idempotency, audit and completed-outbox TTL timestamps', () => {
  assert.equal(
    idempotencyExpiresAt('2026-09-24T10:00:00.000Z').toISOString(),
    '2026-10-01T10:00:00.000Z',
  );
  assert.equal(
    auditExpiresAt('2026-09-24T10:00:00.000Z').toISOString(),
    '2027-09-24T10:00:00.000Z',
  );
  assert.equal(
    outboxExpiresAt('2026-09-24T10:00:00.000Z', '2026-09-25T12:00:00.000Z', false)?.toISOString(),
    '2026-10-25T12:00:00.000Z',
  );
  assert.equal(outboxExpiresAt('2026-09-24T10:00:00.000Z', undefined, false), undefined);
  assert.equal(
    outboxExpiresAt('2026-09-24T10:00:00.000Z', '2026-09-25T12:00:00.000Z', true),
    undefined,
  );
});

void test('completed outbox expires from the later delivery/reconciliation timestamp', () => {
  const planner = new BookingRetentionPlanner(acceptedBookingRetentionPolicies());
  const decision = planner.plan(
    bookingRetentionCandidate({
      recordId: 'outbox-complete',
      retentionClass: 'outbox',
      createdAtUtc: '2025-01-01T00:00:00.000Z',
      deliveredAtUtc: '2026-01-02T00:00:00.000Z',
      reconciledAtUtc: '2026-01-03T00:00:00.000Z',
    }),
    parseUtcInstant('2026-02-03T00:00:00.000Z'),
  );
  assert.deepEqual(decision, {
    action: 'dispatch_deletion',
    policyId: bookingRetentionPolicyIds.outbox,
    recordId: 'outbox-complete',
    expiredAtUtc: '2026-02-02T00:00:00.000Z',
    physicalDeletionDueByUtc: '2026-02-05T00:00:00.000Z',
  });
});

void test('legal hold overrides cleanup while accepted test policies derive exact expiry', () => {
  const testDays = { core: 4, idempotency: 1, outbox: 2, audit: 3 } as const;
  const policies: readonly RetentionPolicy[] = Object.entries(bookingRetentionPolicyIds).map(
    ([retentionClass, policyId]) => ({
      policyId,
      status: 'accepted' as const,
      durationDays: testDays[retentionClass as keyof typeof testDays],
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

void test('backup restore preserves legal hold and blocks expired accepted records', () => {
  const planner = new BookingRetentionPlanner(acceptedBookingRetentionPolicies());
  assert.deepEqual(
    planner.planRestore(
      bookingRetentionCandidate({
        recordId: 'held-audit',
        retentionClass: 'audit',
        createdAtUtc: '2020-01-01T00:00:00.000Z',
        legalHold: true,
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    ),
    {
      action: 'restore_allowed_legal_hold',
      policyId: bookingRetentionPolicyIds.audit,
      recordId: 'held-audit',
    },
  );
  assert.deepEqual(
    planner.planRestore(
      bookingRetentionCandidate({
        recordId: 'expired-idempotency',
        retentionClass: 'idempotency',
        createdAtUtc: '2026-09-01T00:00:00.000Z',
      }),
      parseUtcInstant('2026-09-24T00:00:00.000Z'),
    ),
    {
      action: 'restore_blocked_expired',
      policyId: bookingRetentionPolicyIds.idempotency,
      recordId: 'expired-idempotency',
    },
  );
});

void test('F1: a suppressed, expired or erased notification outcome anchors outbox retention', () => {
  const planner = new BookingRetentionPlanner(acceptedBookingRetentionPolicies());
  for (const outcome of ['suppressed', 'expired', 'erased']) {
    const decision = planner.plan(
      bookingRetentionCandidate({
        recordId: `outbox-${outcome}`,
        retentionClass: 'outbox',
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        terminalAtUtc: '2026-01-02T00:00:00.000Z',
        reconciledAtUtc: '2026-01-03T00:00:00.000Z',
      }),
      parseUtcInstant('2026-02-03T00:00:00.000Z'),
    );
    assert.deepEqual(decision, {
      action: 'dispatch_deletion',
      policyId: bookingRetentionPolicyIds.outbox,
      recordId: `outbox-${outcome}`,
      expiredAtUtc: '2026-02-02T00:00:00.000Z',
      physicalDeletionDueByUtc: '2026-02-05T00:00:00.000Z',
    });
  }
  assert.deepEqual(
    planner.plan(
      bookingRetentionCandidate({
        recordId: 'outbox-terminal-unreconciled',
        retentionClass: 'outbox',
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        terminalAtUtc: '2026-01-02T00:00:00.000Z',
      }),
      parseUtcInstant('2026-02-03T00:00:00.000Z'),
    ).action,
    'retain_delivery_pending',
  );
});

void test('F1: a v2 obligation carries its expiry from the declared relevance deadline', () => {
  assert.equal(
    notificationOutboxExpiresAt('2026-09-05T12:00:00.000Z').toISOString(),
    '2026-10-05T12:00:00.000Z',
  );
});
