import assert from 'node:assert/strict';
import test from 'node:test';

import {
  abuseRulesFor,
  automaticRetryWindowDays,
  maximumActiveFiniteBookings,
  maximumActiveSessions,
  maximumActiveUnlimitedBookings,
  reconciliationScheduleSeconds,
} from '../../src/security/abuse_policy.js';

void test('BCK09 abuse baseline exposes exact independent caps and retry schedule', () => {
  assert.equal(maximumActiveFiniteBookings, 5);
  assert.equal(maximumActiveUnlimitedBookings, 50);
  assert.equal(maximumActiveSessions, 3);
  assert.equal(automaticRetryWindowDays, 7);
  assert.deepEqual(reconciliationScheduleSeconds, [0, 60, 300, 900, 3600, 21600]);
});

void test('cancel is independently limited and never depends on Booking caps or network risk', () => {
  const cancel = abuseRulesFor('booking.cancel');
  assert.deepEqual(
    cancel.map(({ subjectKind, windowSeconds, limit, enforcing }) => ({
      subjectKind,
      windowSeconds,
      limit,
      enforcing,
    })),
    [
      { subjectKind: 'actorInstallation', windowSeconds: 10, limit: 10, enforcing: true },
      { subjectKind: 'actorInstallation', windowSeconds: 60, limit: 20, enforcing: true },
      { subjectKind: 'account', windowSeconds: 60, limit: 40, enforcing: true },
      { subjectKind: 'installation', windowSeconds: 60, limit: 40, enforcing: true },
    ],
  );
});

void test('network thresholds are secondary non-enforcing signals', () => {
  for (const operation of ['booking.create', 'identity.session.issue'] as const) {
    const network = abuseRulesFor(operation).find((rule) => rule.subjectKind === 'networkRisk');
    assert.ok(network);
    assert.equal(network.enforcing, false);
  }
  assert.deepEqual(abuseRulesFor('booking.query'), [
    { subjectKind: 'account', windowSeconds: 60, limit: 240, enforcing: true },
  ]);
});
