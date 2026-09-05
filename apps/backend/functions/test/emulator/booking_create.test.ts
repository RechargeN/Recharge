import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections, finitePoolLedgerId } from '../../src/booking/transactions.js';
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
import { createBookingSchemaRegistry } from '../support/booking_schema_registry.js';

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

before(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test('finite create atomically writes booking, key, ledger, usage, audit, outbox and idempotency', async () => {
  await seedEvent(finiteEvent(), firestore);
  const result = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCFINITEBOOKING0000000' },
    'actor-a',
    createCommand(),
  );
  assert.equal(result.kind, 'succeeded');
  if (result.kind === 'succeeded') {
    const registry = await createBookingSchemaRegistry();
    assert.equal(registry.validator('booking.schema.json')(result.data.booking), true);
  }
  const ledger = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(finiteEvent().occurrenceId, 'pool_general', 'onsite'))
    .get();
  assert.equal(ledger.get('confirmedUnits'), 1);
  assert.equal(
    (await firestore.collection(bookingCollections.userUsage).doc('actor-a').get()).get(
      'activeFiniteBookings',
    ),
    1,
  );
  assert.equal(
    (await firestore.collection(bookingCollections.outbox).limit(1).get()).docs[0]?.get(
      'effectDisposition',
    ),
    'suppressedPreActivation',
  );
});

void test('idempotent replay returns the original booking without a second allocation', async () => {
  const replay = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCNEVERUSED000000000' },
    'actor-a',
    createCommand({ requestId: 'req_replay' }),
  );
  assert.equal(replay.kind, 'succeeded');
  if (replay.kind === 'succeeded') {
    assert.equal(replay.data.replayed, true);
    assert.equal(replay.data.booking.id, '01JRAWCFINITEBOOKING0000000');
  }
  const bookings = await firestore.collection(bookingCollections.bookings).get();
  assert.equal(bookings.size, 1);
});

void test('explicit unlimited creates no ledger or usage allocation', async () => {
  await cleanupBookingEmulator(firestore);
  const event = unlimitedEvent();
  await seedEvent(event, firestore);
  const command = createCommand({
    payload: { occurrenceId: event.occurrenceId, participantUnits: 1, namedGuests: [] },
  });
  const result = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCUNLIMITED000000000' },
    'actor-u',
    command,
  );
  assert.equal(result.kind, 'succeeded');
  assert.equal((await firestore.collection(bookingCollections.poolLedgers).get()).empty, true);
  assert.equal((await firestore.collection(bookingCollections.userUsage).get()).empty, true);
});

void test('unknown capacity refuses without partial mutation', async () => {
  await cleanupBookingEmulator(firestore);
  await firestore
    .collection(bookingCollections.eventProjections)
    .doc(finiteEvent().occurrenceId)
    .set({ ...finiteEvent(), capacityMode: 'unknown' });
  const result = await createInternalBooking({ firestore, clock }, 'actor-x', createCommand());
  assert.deepEqual(result, { kind: 'rejected', code: 'event_unavailable' });
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).empty, true);
  assert.equal((await firestore.collection(bookingCollections.idempotency).get()).empty, true);
});
