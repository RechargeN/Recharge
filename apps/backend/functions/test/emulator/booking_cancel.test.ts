import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { logicalMutationId, requestAttemptId } from '../../src/booking/idempotency.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import {
  computeBookingSemanticHash,
  type CancelBookingCommand,
} from '../../src/contracts/booking_v1.js';
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

void test('cancel atomically changes state and releases key ledger and usage exactly once', async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent(), firestore);
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCANCELBOOKING000000' },
    'actor-c',
    createCommand(),
  );
  const storedBooking = await firestore
    .collection(bookingCollections.bookings)
    .doc('01JRAWCCANCELBOOKING000000')
    .get();
  assert.equal(
    storedBooking.get('cancellationDeadlineSnapshot'),
    finiteEvent().cancellationDeadline,
  );
  await firestore
    .collection(bookingCollections.eventProjections)
    .doc(finiteEvent().occurrenceId)
    .delete();
  const activeKeys = await firestore.collection(bookingCollections.activeKeys).get();
  const [activeKey] = activeKeys.docs;
  assert.ok(activeKey);
  await activeKey.ref.delete();
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
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent(), firestore);
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCWRONGOWNER000000000' },
    'actor-owner',
    createCommand({
      idempotencyKey: 'idem_wrong_owner_create',
      requestId: 'req_wrong_owner_create',
    }),
  );
  const command: CancelBookingCommand = {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_wrong_owner',
    idempotencyKey: 'idem_wrong_owner',
    expectedBookingRevision: 1,
    payload: { bookingId: '01JRAWCWRONGOWNER000000000' },
  };
  assert.deepEqual(await cancelInternalBooking({ firestore, clock }, 'other', command), {
    kind: 'rejected',
    code: 'permission_denied',
  });
});

void test('cancellation deadline uses immutable Booking snapshot', async () => {
  await cleanupBookingEmulator(firestore);
  const event = finiteEvent({ cancellationDeadline: fixedNow.toISOString() });
  await seedEvent(event, firestore);
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCDEADLINE0000000000' },
    'actor-deadline',
    createCommand({ idempotencyKey: 'idem_deadline_create', requestId: 'req_deadline_create' }),
  );
  await seedEvent({ ...event, cancellationDeadline: '2099-01-01T00:00:00.000Z' }, firestore);
  const result = await cancelInternalBooking({ firestore, clock }, 'actor-deadline', {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_deadline_cancel',
    idempotencyKey: 'idem_deadline_cancel',
    expectedBookingRevision: 1,
    payload: { bookingId: '01JRAWCDEADLINE0000000000' },
  });
  assert.deepEqual(result, { kind: 'rejected', code: 'cancellation_deadline_passed' });
});

void test('unlimited booking cancels after event removal without ledger or usage', async () => {
  await cleanupBookingEmulator(firestore);
  const event = unlimitedEvent();
  await seedEvent(event, firestore);
  const bookingId = '01JRAWCUNLIMITEDCANCEL00000';
  await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    'actor-unlimited-cancel',
    createCommand({
      requestId: 'req_unlimited_create',
      idempotencyKey: 'idem_unlimited_create',
      payload: { occurrenceId: event.occurrenceId, participantUnits: 1, namedGuests: [] },
    }),
  );
  await firestore.collection(bookingCollections.eventProjections).doc(event.occurrenceId).delete();
  const result = await cancelInternalBooking({ firestore, clock }, 'actor-unlimited-cancel', {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_unlimited_cancel',
    idempotencyKey: 'idem_unlimited_cancel',
    expectedBookingRevision: 1,
    payload: { bookingId },
  });
  assert.equal(result.kind, 'succeeded');
  assert.equal((await firestore.collection(bookingCollections.poolLedgers).get()).empty, true);
  assert.equal((await firestore.collection(bookingCollections.userUsage).get()).empty, true);
});

void test('dangling cancellation attempt returns retryable temporary failure', async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent(), firestore);
  const actorId = 'actor-cancel-damaged';
  const bookingId = '01JRAWCCANCELDAMAGED000000';
  await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    actorId,
    createCommand({ requestId: 'req_cancel_seed', idempotencyKey: 'idem_cancel_seed' }),
  );
  const command: CancelBookingCommand = {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_cancel_damaged',
    idempotencyKey: 'idem_cancel_damaged',
    expectedBookingRevision: 1,
    payload: { bookingId },
  };
  const logicalId = logicalMutationId(actorId, command.commandType, command.idempotencyKey);
  const attemptId = requestAttemptId(actorId, command.requestId);
  await firestore
    .collection(bookingCollections.idempotency)
    .doc(attemptId)
    .set({
      schemaVersion: 1,
      kind: 'requestAttempt',
      actorId,
      commandType: command.commandType,
      semanticHash: computeBookingSemanticHash(command, actorId),
      logicalMutationId: logicalId,
      requestAttemptId: attemptId,
      bookingId,
      createdAt: fixedNow.toISOString(),
    });
  assert.deepEqual(await cancelInternalBooking({ firestore, clock }, actorId, command), {
    kind: 'retryableFailure',
    code: 'temporarily_unavailable',
  });
});
