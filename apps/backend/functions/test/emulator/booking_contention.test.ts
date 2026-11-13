import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections, bookingUserUsageId } from '../../src/booking/transactions.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
} from '../support/booking_emulator.js';
import {
  createCommand,
  finiteEvent,
  fixedNow,
  unlimitedEvent,
} from '../support/booking_fixtures.js';

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

before(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test(
  '100-request same-scope contention regression commits one active booking',
  { timeout: 120_000 },
  async () => {
    await cleanupBookingEmulator(firestore);
    const event = finiteEvent({ totalCapacity: 200 });
    await seedEvent(event, firestore);
    const results = [];
    for (let wave = 0; wave < 10; wave += 1) {
      results.push(
        ...(await Promise.all(
          Array.from({ length: 10 }, (_, offset) => {
            const index = wave * 10 + offset;
            const command = createCommand({
              requestId: `req_parallel_finite_${index}`,
              idempotencyKey: `idem_parallel_finite_${index}`,
            });
            return createInternalBooking(
              {
                firestore,
                clock,
                newBookingId: () => `01JRAWCFINITE${String(index).padStart(12, '0')}`,
              },
              'same-actor',
              command,
            );
          }),
        )),
      );
    }
    assert.equal(results.filter((result) => result.kind === 'succeeded').length, 1);
    assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, 1);
    assert.equal((await firestore.collection(bookingCollections.activeKeys).get()).size, 1);
  },
);

void test('finite pool contention never exceeds capacity', { timeout: 120_000 }, async () => {
  await cleanupBookingEmulator(firestore);
  const event = finiteEvent({ totalCapacity: 3 });
  await seedEvent(event, firestore);
  const results = await Promise.all(
    Array.from({ length: 20 }, (_, index) =>
      createInternalBooking(
        { firestore, clock, newBookingId: () => `01JRAWCPOOL${String(index).padStart(16, '0')}` },
        `pool-actor-${index}`,
        createCommand({ requestId: `req_pool_${index}`, idempotencyKey: `idem_pool_${index}` }),
      ),
    ),
  );
  const succeeded = results.filter((result) => result.kind === 'succeeded').length;
  assert.ok(succeeded > 0);
  assert.ok(succeeded <= 3);
  const ledger = (await firestore.collection(bookingCollections.poolLedgers).limit(1).get())
    .docs[0];
  assert.equal(ledger?.get('confirmedUnits'), succeeded);
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, succeeded);
});

void test('five-active-finite policy is atomic across occurrences', async () => {
  await cleanupBookingEmulator(firestore);
  const actor = 'cap-actor';
  const results = [];
  for (let index = 0; index < 6; index += 1) {
    const occurrenceId = `occ_cap_${index}`;
    await seedEvent(finiteEvent({ occurrenceId, poolId: `pool_${index}` }), firestore);
    results.push(
      await createInternalBooking(
        { firestore, clock, newBookingId: () => `01JRAWCCAP${String(index).padStart(17, '0')}` },
        actor,
        createCommand({
          requestId: `req_cap_${index}`,
          idempotencyKey: `idem_cap_${index}`,
          payload: {
            occurrenceId,
            inventoryPoolId: `pool_${index}`,
            channel: 'onsite',
            participantUnits: 1,
            namedGuests: [],
          },
        }),
      ),
    );
  }
  assert.equal(results.filter((result) => result.kind === 'succeeded').length, 5);
  assert.deepEqual(results.at(-1), {
    kind: 'rejected',
    code: 'active_booking_limit_reached',
  });
});

void test('fifty-active-unlimited cap admits only one of two concurrent creates at 49/50', async () => {
  await cleanupBookingEmulator(firestore);
  const actor = 'unlimited-cap-actor';
  const expiresAtUtc = '2026-08-29T16:00:00.000Z';
  await firestore
    .collection(bookingCollections.userUsage)
    .doc(bookingUserUsageId(actor, 'LV'))
    .set({
      schemaVersion: 2,
      policyVersion: 2,
      actorId: actor,
      marketId: 'LV',
      activeFiniteBookings: 0,
      activeUnlimitedBookings: 49,
      activeFiniteSlots: [],
      activeUnlimitedSlots: Array.from({ length: 49 }, (_, index) => ({
        bookingId: `seed-unlimited-${index}`,
        expiresAtUtc,
      })),
      revision: 49,
      updatedAt: fixedNow.toISOString(),
    });
  const occurrenceIds = ['occ_unlimited_cap_a', 'occ_unlimited_cap_b'] as const;
  await Promise.all(
    occurrenceIds.map((occurrenceId) => seedEvent(unlimitedEvent({ occurrenceId }), firestore)),
  );
  const results = await Promise.all(
    occurrenceIds.map((occurrenceId, index) =>
      createInternalBooking(
        {
          firestore,
          clock,
          newBookingId: () => `01JRAWCUNCAP${String(index).padStart(16, '0')}`,
        },
        actor,
        createCommand({
          requestId: `req_unlimited_cap_${index}`,
          idempotencyKey: `idem_unlimited_cap_${index}`,
          payload: {
            occurrenceId,
            participantUnits: 1,
            namedGuests: [],
          },
        }),
      ),
    ),
  );
  assert.equal(results.filter((result) => result.kind === 'succeeded').length, 1);
  assert.equal(
    results.filter(
      (result) => result.kind === 'rejected' && result.code === 'active_booking_limit_reached',
    ).length,
    1,
  );
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, 1);
  const usage = await firestore.collection(bookingCollections.userUsage).limit(1).get();
  assert.equal(usage.size, 1);
  assert.equal(usage.docs[0]?.get('activeUnlimitedBookings'), 50);
});
