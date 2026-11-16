import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import {
  createDevBookingComposition,
  handleDevBooking,
  type DevBookingCallable,
} from '../../src/dev_booking_composition.js';
import {
  bookingSessionContextFor,
  cleanupBookingEmulator,
  createAuthorizedActor,
  emulatorFirestore,
  seedEvent,
} from '../support/booking_emulator.js';
import { finiteEvent } from '../support/booking_fixtures.js';

// N4c step 1: the cloud Booking composition (deploy-switch flags, reviewed
// project as the rate-limit environment) runs the same use cases as the
// Emulator entry. Exercised here against the Firestore Emulator.

const firestore = emulatorFirestore();
const project = 'recharge-staging-y9y2y' as const;
const day = 86_400_000;
const now = Date.now();
const event = finiteEvent({
  eventId: 'evt_n4c_pipeline',
  occurrenceId: 'occ_n4cload_pipeline',
  poolId: 'pool_n4c_pipeline',
  totalCapacity: 2,
  occurrenceStartsAt: new Date(now + 3 * day).toISOString(),
  occurrenceEndsAt: new Date(now + 3 * day + 3_600_000).toISOString(),
  registrationWindow: {
    opensAt: new Date(now - day).toISOString(),
    closesAt: new Date(now + 2 * day).toISOString(),
  },
  cancellationDeadline: new Date(now + 2 * day).toISOString(),
});

before(async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(event, firestore);
  for (const uid of ['n4cload0001', 'n4cload0002', 'n4cload0003']) await createAuthorizedActor(uid);
});
after(async () => cleanupBookingEmulator(firestore));

function call(
  callable: DevBookingCallable,
  uid: string,
  data: Record<string, unknown>,
  incidentDisabled = false,
) {
  const full = { ...data, sessionContext: bookingSessionContextFor(uid) };
  return handleDevBooking({
    callable,
    firebaseUid: uid,
    rawBody: Buffer.from(JSON.stringify({ data: full }), 'utf8'),
    data: full,
    firestore,
    projectId: project,
    composition: createDevBookingComposition(firestore, incidentDisabled),
  });
}

function create(uid: string, suffix: string) {
  return call('createInternalBookingV1', uid, {
    schemaVersion: 1,
    commandType: 'createBooking',
    requestId: `req_create_${suffix}`,
    idempotencyKey: `idem_create_${suffix}`,
    occurredAgainstEventRevision: event.materialRevision,
    payload: {
      occurrenceId: event.occurrenceId,
      inventoryPoolId: event.poolId,
      channel: 'onsite',
      participantUnits: 1,
      namedGuests: [],
    },
  });
}

void test('create, replay, read, cancel and sold-out through the cloud composition', async () => {
  const first = await create('n4cload0001', 'a');
  assert.equal(first.kind, 'succeeded', JSON.stringify(first));
  const booking = first.booking as { id: string; revision: number };

  // Unknown outcome: the client repeats the same idempotency key and gets the same Booking.
  const replay = await create('n4cload0001', 'a');
  assert.equal(replay.kind, 'succeeded', JSON.stringify(replay));
  assert.equal((replay.booking as { id: string }).id, booking.id);

  assert.equal((await create('n4cload0002', 'b')).kind, 'succeeded');
  const soldOut = await create('n4cload0003', 'c');
  assert.notEqual(soldOut.kind, 'succeeded', JSON.stringify(soldOut));

  const availability = await call('getEventAvailabilityV1', 'n4cload0003', {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_availability',
    payload: { eventId: event.eventId, occurrenceId: event.occurrenceId, channel: 'onsite' },
  });
  assert.equal(availability.kind, 'succeeded', JSON.stringify(availability));

  const own = await call('getMyBookingV1', 'n4cload0001', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_get_own',
    payload: { bookingId: booking.id },
  });
  assert.equal(own.kind, 'found', JSON.stringify(own));
  const foreign = await call('getMyBookingV1', 'n4cload0002', {
    schemaVersion: 1,
    queryType: 'getMyBooking',
    requestId: 'req_get_foreign',
    payload: { bookingId: booking.id },
  });
  assert.equal(foreign.kind, 'notFound', JSON.stringify(foreign));

  const cancelled = await call('cancelInternalBookingV1', 'n4cload0001', {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: 'req_cancel_a',
    idempotencyKey: 'idem_cancel_a',
    expectedBookingRevision: booking.revision,
    payload: { bookingId: booking.id, reasonCode: 'user_request' },
  });
  assert.equal(cancelled.kind, 'succeeded', JSON.stringify(cancelled));

  // The released seat is sellable again.
  assert.equal((await create('n4cload0003', 'd')).kind, 'succeeded');
});

void test('a foreign Session, the incident switch and a wrong flow are refused', async () => {
  const data = {
    schemaVersion: 1,
    queryType: 'listMyBookings',
    requestId: 'req_list',
    payload: { pageSize: 5 },
  };
  const listed = await call('listMyBookingsV1', 'n4cload0001', data);
  assert.equal(listed.kind, 'succeeded', JSON.stringify(listed));

  // Session of another actor: the transport identity does not match the Session.
  const stolen = { ...data, sessionContext: bookingSessionContextFor('n4cload0002') };
  const refused = await handleDevBooking({
    callable: 'listMyBookingsV1',
    firebaseUid: 'n4cload0001',
    rawBody: Buffer.from(JSON.stringify({ data: stolen }), 'utf8'),
    data: stolen,
    firestore,
    projectId: project,
    composition: createDevBookingComposition(firestore),
  });
  assert.equal(refused.kind, 'rejected', JSON.stringify(refused));

  const contained = await call('listMyBookingsV1', 'n4cload0001', data, true);
  assert.equal(contained.kind, 'rejected', JSON.stringify(contained));
  assert.equal((contained.error as { code: string }).code, 'feature_disabled');

  const wrongFlow = await call('getMyBookingV1', 'n4cload0001', data);
  assert.equal(wrongFlow.kind, 'unsupportedContract', JSON.stringify(wrongFlow));
});
