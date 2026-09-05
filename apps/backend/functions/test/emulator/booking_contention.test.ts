import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections } from '../../src/booking/transactions.js';
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

for (const capacityMode of ['finite', 'unlimited'] as const) {
  void test(
    `100 parallel same-scope ${capacityMode} creates commit one active booking`,
    { timeout: 120_000 },
    async () => {
      await cleanupBookingEmulator(firestore);
      const event =
        capacityMode === 'finite' ? finiteEvent({ totalCapacity: 200 }) : unlimitedEvent();
      await seedEvent(event, firestore);
      const results = await Promise.all(
        Array.from({ length: 100 }, (_, index) => {
          const command = createCommand({
            requestId: `req_parallel_${capacityMode}_${index}`,
            idempotencyKey: `idem_parallel_${capacityMode}_${index}`,
            payload: {
              occurrenceId: event.occurrenceId,
              ...(event.poolId === undefined ? {} : { inventoryPoolId: event.poolId }),
              ...(event.channel === undefined ? {} : { channel: event.channel }),
              participantUnits: 1,
              namedGuests: [],
            },
          });
          return createInternalBooking(
            {
              firestore,
              clock,
              newBookingId: () =>
                `01JRAWC${capacityMode.toUpperCase()}${String(index).padStart(12, '0')}`,
            },
            'same-actor',
            command,
          );
        }),
      );
      assert.equal(results.filter((result) => result.kind === 'succeeded').length, 1);
      assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, 1);
      assert.equal((await firestore.collection(bookingCollections.activeKeys).get()).size, 1);
    },
  );
}

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
  assert.equal(results.filter((result) => result.kind === 'succeeded').length, 3);
  const ledger = (await firestore.collection(bookingCollections.poolLedgers).limit(1).get())
    .docs[0];
  assert.equal(ledger?.get('confirmedUnits'), 3);
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, 3);
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
  assert.deepEqual(results.at(-1), { kind: 'rejected', code: 'concurrency_cap_reached' });
});
