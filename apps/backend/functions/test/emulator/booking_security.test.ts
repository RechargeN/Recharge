import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { exactBookingCollectionNames } from '../../src/booking/transactions.js';
import {
  cleanupBookingEmulator,
  callBookingFunction,
  createAuthorizedActor,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { createBookingSchemaRegistry } from '../support/booking_schema_registry.js';

const firestore = emulatorFirestore();

before(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test('missing auth denies before disabled flag and performs no write', async () => {
  const response = await callBookingFunction('createInternalBookingV1', createCommand());
  assert.equal(response.status, 200);
  const result = response.body.result as Record<string, unknown>;
  assert.equal(result.kind, 'rejected');
  assert.equal((result.error as Record<string, unknown>).code, 'not_authenticated');
  assert.equal((await firestore.collection('bookings').get()).empty, true);
});

void test('inactive identity and missing flag fail closed', async () => {
  const inactiveToken = await createAuthorizedActor('inactive-actor', {
    accountState: 'inactive',
    capabilities: ['booking.self_service'],
  });
  const inactive = await callBookingFunction(
    'createInternalBookingV1',
    createCommand(),
    inactiveToken,
  );
  assert.equal(
    ((inactive.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'not_authorized',
  );
  const activeToken = await createAuthorizedActor('active-actor');
  const disabled = await callBookingFunction(
    'createInternalBookingV1',
    createCommand(),
    activeToken,
  );
  assert.equal(
    ((disabled.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'feature_disabled',
  );
});

void test('test-only flags enable exactly the real callable path in disposable emulator', async () => {
  const callableEvent = finiteEvent({
    registrationWindow: {
      opensAt: '2020-01-01T00:00:00.000Z',
      closesAt: '2099-01-01T00:00:00.000Z',
    },
    cancellationDeadline: '2099-01-01T00:00:00.000Z',
  });
  await seedEvent(callableEvent, firestore);
  await setBookingFlags(true, firestore);
  const token = await createAuthorizedActor('callable-actor');
  const response = await callBookingFunction('createInternalBookingV1', createCommand(), token);
  assert.equal(response.status, 200);
  const createResult = response.body.result as Record<string, unknown>;
  assert.equal(createResult.kind, 'succeeded', JSON.stringify(createResult));
  const registry = await createBookingSchemaRegistry();
  assert.equal(registry.validator('booking_result.schema.json')(createResult), true);
  const booking = createResult.booking as Record<string, unknown>;

  const cancellation = await callBookingFunction(
    'cancelInternalBookingV1',
    {
      schemaVersion: 1,
      commandType: 'cancelBooking',
      requestId: 'req_callable_cancel',
      idempotencyKey: 'idem_callable_cancel',
      expectedBookingRevision: booking.revision,
      payload: { bookingId: booking.id, reasonCode: 'user_cancelled' },
    },
    token,
  );
  assert.equal(registry.validator('booking_result.schema.json')(cancellation.body.result), true);

  const read = await callBookingFunction(
    'getMyBookingV1',
    {
      schemaVersion: 1,
      queryType: 'getMyBooking',
      requestId: 'req_callable_get',
      payload: { bookingId: booking.id },
    },
    token,
  );
  assert.equal(registry.validator('booking_read.schema.json')(read.body.result), true);

  const page = await callBookingFunction(
    'listMyBookingsV1',
    {
      schemaVersion: 1,
      queryType: 'listMyBookings',
      requestId: 'req_callable_list',
      payload: { pageSize: 20 },
    },
    token,
  );
  assert.equal(registry.validator('booking_page.schema.json')(page.body.result), true);

  const availability = await callBookingFunction(
    'getEventAvailabilityV1',
    {
      schemaVersion: 1,
      queryType: 'getEventAvailability',
      requestId: 'req_callable_availability',
      payload: {
        eventId: callableEvent.eventId,
        occurrenceId: callableEvent.occurrenceId,
        channel: 'onsite',
      },
    },
    token,
  );
  assert.equal(
    registry.validator('booking_availability.schema.json')(availability.body.result),
    true,
  );
});

void test('direct unauthenticated client reads and writes deny for all nine collections', async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host);
  for (const collectionName of exactBookingCollectionNames) {
    const read = await fetch(
      `http://${host}/v1/projects/demo-recharge/databases/(default)/documents/${collectionName}`,
    );
    assert.equal(read.status, 403, `read ${collectionName}`);
    const write = await fetch(
      `http://${host}/v1/projects/demo-recharge/databases/(default)/documents/${collectionName}/forbidden`,
      {
        method: 'PATCH',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ fields: { value: { stringValue: 'forbidden' } } }),
      },
    );
    assert.equal(write.status, 403, `write ${collectionName}`);
  }
});
