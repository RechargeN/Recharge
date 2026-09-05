import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import type { CancelBookingCommand } from '../../src/contracts/booking_v1.js';
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
});
after(async () => cleanupBookingEmulator(firestore));

void test('cancel atomically changes state and releases key ledger and usage exactly once', async () => {
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCANCELBOOKING000000' },
    'actor-c',
    createCommand(),
  );
  const command: CancelBookingCommand = {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_cancel',
    idempotencyKey: 'idem_cancel',
    expectedBookingRevision: 1,
    payload: { bookingId: '01JRAWCCANCELBOOKING000000', reasonCode: 'user_request' },
  };
  const result = await cancelInternalBooking({ firestore, clock }, 'actor-c', command);
  assert.equal(result.kind, 'succeeded');
  assert.equal(
    (
      await firestore.collection(bookingCollections.bookings).doc(command.payload.bookingId).get()
    ).get('state'),
    'cancelled',
  );
  assert.equal((await firestore.collection(bookingCollections.activeKeys).get()).empty, true);
  assert.equal(
    (await firestore.collection(bookingCollections.userUsage).doc('actor-c').get()).get(
      'activeFiniteBookings',
    ),
    0,
  );
  const replay = await cancelInternalBooking({ firestore, clock }, 'actor-c', {
    ...command,
    requestId: 'req_cancel_replay',
  });
  assert.equal(replay.kind, 'succeeded');
  const terminalReplay = await cancelInternalBooking({ firestore, clock }, 'actor-c', {
    ...command,
    requestId: 'req_cancel_terminal',
    idempotencyKey: 'idem_cancel_terminal',
    expectedBookingRevision: 2,
  });
  assert.equal(terminalReplay.kind, 'succeeded');
  assert.equal((await firestore.collection(bookingCollections.audit).get()).size, 2);
});

void test('wrong owner cannot infer or cancel the booking', async () => {
  const command: CancelBookingCommand = {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_wrong_owner',
    idempotencyKey: 'idem_wrong_owner',
    expectedBookingRevision: 2,
    payload: { bookingId: '01JRAWCCANCELBOOKING000000' },
  };
  assert.deepEqual(await cancelInternalBooking({ firestore, clock }, 'other', command), {
    kind: 'rejected',
    code: 'permission_denied',
  });
});
