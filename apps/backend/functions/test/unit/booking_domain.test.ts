import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assertBookingEventProjection,
  assertGuestPolicy,
  assertSupportedEvent,
} from '../../src/booking/domain.js';
import { allocateUnits, reconcileCapacity, releaseUnits } from '../../src/inventory/ledger.js';
import { acquireBookingSlot, releaseBookingSlot } from '../../src/policy/concurrency.js';
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

void test('availability projection validation does not apply registration-window admission', () => {
  const future = finiteEvent({
    registrationWindow: { opensAt: '2026-09-01T00:00:00.000Z' },
  });
  assert.equal(
    assertBookingEventProjection(future, future.occurrenceId, future.poolId, future.channel)
      .eventId,
    future.eventId,
  );
  assert.throws(
    () =>
      assertSupportedEvent(future, fixedNow, future.occurrenceId, future.poolId, future.channel),
    /registration_not_open/u,
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

void test('capacity changes preserve ledger identity and existing confirmed units', () => {
  const original = {
    eventId: 'event',
    occurrenceId: 'occ',
    poolId: 'pool',
    channel: 'onsite',
    totalCapacity: 2,
  };
  const full = allocateUnits(undefined, original, 2, fixedNow.toISOString());
  const increased = allocateUnits(
    full,
    { ...original, totalCapacity: 3 },
    1,
    fixedNow.toISOString(),
  );
  assert.equal(increased.totalCapacity, 3);
  assert.equal(increased.confirmedUnits, 3);

  const decreased = reconcileCapacity(
    increased,
    { ...original, totalCapacity: 1 },
    fixedNow.toISOString(),
  );
  assert.equal(decreased.totalCapacity, 1);
  assert.equal(decreased.confirmedUnits, 3);
  assert.throws(
    () => allocateUnits(decreased, { ...original, totalCapacity: 1 }, 1, fixedNow.toISOString()),
    /sold_out/u,
  );
  assert.equal(releaseUnits(decreased, 2, fixedNow.toISOString()).confirmedUnits, 1);
});

void test('finite and unlimited user usage are independent, market-scoped and bounded', () => {
  const expiry = '2026-08-29T16:00:00.000Z';
  let usage = acquireBookingSlot(
    undefined,
    'user',
    'LV',
    'finite',
    'booking-finite-0',
    expiry,
    fixedNow.toISOString(),
  );
  for (let index = 1; index < 5; index += 1) {
    usage = acquireBookingSlot(
      usage,
      'user',
      'LV',
      'finite',
      `booking-finite-${index}`,
      expiry,
      fixedNow.toISOString(),
    );
  }
  assert.equal(usage.activeFiniteBookings, 5);
  assert.throws(
    () =>
      acquireBookingSlot(
        usage,
        'user',
        'LV',
        'finite',
        'booking-finite-5',
        expiry,
        fixedNow.toISOString(),
      ),
    /active_booking_limit_reached/u,
  );
  assert.equal(
    releaseBookingSlot(usage, 'user', 'LV', 'finite', 'booking-finite-0', fixedNow.toISOString())
      .activeFiniteBookings,
    4,
  );

  let unlimited = acquireBookingSlot(
    undefined,
    'user',
    'LV',
    'unlimited',
    'booking-unlimited-0',
    expiry,
    fixedNow.toISOString(),
  );
  for (let index = 1; index < 50; index += 1) {
    unlimited = acquireBookingSlot(
      unlimited,
      'user',
      'LV',
      'unlimited',
      `booking-unlimited-${index}`,
      expiry,
      fixedNow.toISOString(),
    );
  }
  assert.equal(unlimited.activeUnlimitedBookings, 50);
  assert.throws(
    () =>
      acquireBookingSlot(
        unlimited,
        'user',
        'LV',
        'unlimited',
        'booking-unlimited-50',
        expiry,
        fixedNow.toISOString(),
      ),
    /active_booking_limit_reached/u,
  );
  assert.throws(
    () =>
      releaseBookingSlot(
        unlimited,
        'user',
        'EE',
        'unlimited',
        'booking-unlimited-0',
        fixedNow.toISOString(),
      ),
    /event_unavailable/u,
  );

  const pruned = acquireBookingSlot(
    unlimited,
    'user',
    'LV',
    'unlimited',
    'booking-after-grace',
    '2026-08-29T20:00:00.000Z',
    '2026-08-29T17:00:00.000Z',
  );
  assert.equal(pruned.activeUnlimitedBookings, 1);
});
