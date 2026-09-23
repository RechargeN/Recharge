import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';
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

beforeEach(async () => {
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
  const own = await getMyBooking({ firestore, clock }, 'actor-q', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_get',
    payload: { bookingId: '01JRAWCQUERYBOOKING0000000' },
  });
  assert.equal(own.kind, 'succeeded');
  const other = await getMyBooking({ firestore, clock }, 'actor-other', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_other',
    payload: { bookingId: '01JRAWCQUERYBOOKING0000000' },
  });
  assert.deepEqual(other, { kind: 'rejected', code: 'permission_denied' });
  const page = await listMyBookings({ firestore, clock }, 'actor-q', {
    schemaVersion: 1,
    queryType: 'listMyBookings',
    requestId: 'req_list',
    payload: { pageSize: 1 },
  });
  assert.equal(page.kind, 'succeeded');
  if (page.kind === 'succeeded') {
    assert.equal(page.data.items.length, 1);
    assert.equal(page.data.asOf, fixedNow.toISOString());
  }
});

void test('availability reports registration window states using the injected clock', async () => {
  await cleanupBookingEmulator(firestore);
  const notOpen = finiteEvent({
    occurrenceId: 'occ_availability_not_open',
    registrationWindow: { opensAt: '2026-08-30T12:00:00.000Z' },
  });
  await seedEvent(notOpen, firestore);
  const notOpenResult = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability_not_open',
    payload: {
      eventId: notOpen.eventId,
      occurrenceId: notOpen.occurrenceId,
      channel: 'onsite',
    },
  });
  assert.equal(notOpenResult.kind, 'succeeded');
  if (notOpenResult.kind === 'succeeded') {
    assert.equal(notOpenResult.data.status, 'notOpen');
    assert.equal(notOpenResult.data.asOf, fixedNow.toISOString());
    assert.equal(notOpenResult.data.registrationOpensAt, '2026-08-30T12:00:00.000Z');
  }

  const closed = finiteEvent({
    occurrenceId: 'occ_availability_closed',
    registrationWindow: { closesAt: '2026-08-29T11:59:59.000Z' },
  });
  await seedEvent(closed, firestore);
  const closedResult = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability_closed',
    payload: {
      eventId: closed.eventId,
      occurrenceId: closed.occurrenceId,
      channel: 'onsite',
    },
  });
  assert.equal(closedResult.kind, 'succeeded');
  if (closedResult.kind === 'succeeded') {
    assert.equal(closedResult.data.status, 'closed');
    assert.equal(closedResult.data.registrationClosesAt, '2026-08-29T11:59:59.000Z');
  }
});

void test('availability rejects missing or unpublished event projections', async () => {
  await cleanupBookingEmulator(firestore);
  const missing = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability_missing',
    payload: {
      eventId: finiteEvent().eventId,
      occurrenceId: 'occ_missing',
      channel: 'onsite',
    },
  });
  assert.deepEqual(missing, { kind: 'rejected', code: 'event_unavailable' });

  const unpublished = finiteEvent({ occurrenceId: 'occ_unpublished' });
  await firestore
    .collection(bookingCollections.eventProjections)
    .doc(unpublished.occurrenceId)
    .set({ ...unpublished, lifecycle: 'draft' });
  const result = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability_unpublished',
    payload: {
      eventId: unpublished.eventId,
      occurrenceId: unpublished.occurrenceId,
      channel: 'onsite',
    },
  });
  assert.deepEqual(result, { kind: 'rejected', code: 'event_unavailable' });
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
