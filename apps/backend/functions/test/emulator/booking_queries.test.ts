import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { getEventAvailability } from '../../src/booking/availability_query.js';
import { getMyBooking, listMyBookings } from '../../src/booking/booking_queries.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent, fixedNow } from '../support/booking_fixtures.js';

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

before(async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent(), firestore);
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCQUERYBOOKING0000000' },
    'actor-q',
    createCommand(),
  );
});
after(async () => cleanupBookingEmulator(firestore));

void test('get and list expose owner records only', async () => {
  const own = await getMyBooking(firestore, 'actor-q', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_get',
    payload: { bookingId: '01JRAWCQUERYBOOKING0000000' },
  });
  assert.equal(own.kind, 'succeeded');
  const other = await getMyBooking(firestore, 'actor-other', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_other',
    payload: { bookingId: '01JRAWCQUERYBOOKING0000000' },
  });
  assert.deepEqual(other, { kind: 'rejected', code: 'permission_denied' });
  const page = await listMyBookings(firestore, 'actor-q', {
    schemaVersion: 1,
    queryType: 'listMyBookings',
    requestId: 'req_list',
    payload: { pageSize: 1 },
  });
  assert.equal(page.kind, 'succeeded');
  if (page.kind === 'succeeded') assert.equal(page.data.items.length, 1);
});

void test('availability is non-reserving', async () => {
  const beforeCount = (await firestore.collection(bookingCollections.bookings).get()).size;
  const result = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability',
    payload: {
      eventId: finiteEvent().eventId,
      occurrenceId: finiteEvent().occurrenceId,
      channel: 'onsite',
    },
  });
  assert.equal(result.kind, 'succeeded');
  if (result.kind === 'succeeded') assert.equal(result.data.availableUnits, 9);
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).size, beforeCount);
});
