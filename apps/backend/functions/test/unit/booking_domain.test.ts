import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assertGuestPolicy, assertSupportedEvent } from '../../src/booking/domain.js';
import { allocateUnits, releaseUnits } from '../../src/inventory/ledger.js';
import { acquireFiniteSlot, releaseFiniteSlot } from '../../src/policy/concurrency.js';
import { finiteEvent, fixedNow, unlimitedEvent } from '../support/booking_fixtures.js';

void test('accepts only finite or explicit unlimited internal free instant events', () => {
  assert.equal(
    assertSupportedEvent(
      finiteEvent(),
      fixedNow,
      finiteEvent().occurrenceId,
      'pool_general',
      'onsite',
    ).capacityMode,
    'finite',
  );
  assert.equal(
    assertSupportedEvent(
      unlimitedEvent(),
      fixedNow,
      finiteEvent().occurrenceId,
      undefined,
      undefined,
    ).capacityMode,
    'unlimited',
  );
  assert.throws(
    () =>
      assertSupportedEvent(
        { ...finiteEvent(), capacityMode: 'unknown' },
        fixedNow,
        finiteEvent().occurrenceId,
        'pool_general',
        'onsite',
      ),
    /event_unavailable/u,
  );
});

void test('enforces registration and guest policy fail closed', () => {
  assert.throws(
    () =>
      assertSupportedEvent(
        finiteEvent(),
        new Date('2026-07-01T00:00:00Z'),
        finiteEvent().occurrenceId,
        'pool_general',
        'onsite',
      ),
    /registration_not_open/u,
  );
  assert.doesNotThrow(() => assertGuestPolicy(finiteEvent(), 2, []));
  assert.throws(
    () => assertGuestPolicy(finiteEvent(), 2, [{ displayName: 'Guest' }]),
    /unsupported_flow/u,
  );
});

void test('finite ledger never oversells and release is exact', () => {
  const identity = {
    eventId: 'event',
    occurrenceId: 'occ',
    poolId: 'pool',
    channel: 'onsite',
    totalCapacity: 2,
  };
  const allocated = allocateUnits(undefined, identity, 2, fixedNow.toISOString());
  assert.equal(allocated.confirmedUnits, 2);
  assert.throws(() => allocateUnits(allocated, identity, 1, fixedNow.toISOString()), /sold_out/u);
  assert.equal(releaseUnits(allocated, 2, fixedNow.toISOString()).confirmedUnits, 0);
});

void test('finite user usage is capped at five and released once', () => {
  let usage = acquireFiniteSlot(undefined, 'user', fixedNow.toISOString());
  for (let index = 1; index < 5; index += 1)
    usage = acquireFiniteSlot(usage, 'user', fixedNow.toISOString());
  assert.equal(usage.activeFiniteBookings, 5);
  assert.throws(
    () => acquireFiniteSlot(usage, 'user', fixedNow.toISOString()),
    /concurrency_cap_reached/u,
  );
  assert.equal(releaseFiniteSlot(usage, 'user', fixedNow.toISOString()).activeFiniteBookings, 4);
});
