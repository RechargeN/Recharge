import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { exactBookingCollectionNames } from '../../src/booking/transactions.js';
import {
  bookingIdentityCollections,
  FirestoreBookingAccessAuthority,
} from '../../src/booking/firestore_booking_access_authority.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { bookingFlagIds } from '../../src/shared/feature_flags.js';
import { FirestoreFeatureFlagGate } from '../../src/platform/config/firestore_feature_flag_gate.js';
import {
  bookingSessionContextFor,
  cleanupBookingEmulator,
  callBookingFunction,
  createAuthorizedActor,
  createFirebaseActor,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
  setIdentitySessionFlag,
  registerSessionContext,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { createBookingSchemaRegistry } from '../support/booking_schema_registry.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();

before(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test('missing auth denies before disabled flag and performs no write', async () => {
  const response = await callBookingFunction('createInternalBookingV1', {
    schemaVersion: 1,
    commandType: 'createBooking',
    requestId: 'req_auth_first',
    idempotencyKey: 'idem_auth_first',
    payload: { occurrenceId: 'bad/path' },
  });
  assert.equal(response.status, 200);
  const result = response.body.result as Record<string, unknown>;
  assert.equal(result.kind, 'rejected');
  assert.equal((result.error as Record<string, unknown>).code, 'not_authenticated');
  assert.equal((await firestore.collection('bookings').get()).empty, true);
});

void test('inactive identity and missing flag fail closed', async () => {
  await setBookingFlags(true, firestore);
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
  await setBookingFlags(false, firestore);
  const activeToken = await createAuthorizedActor('active-actor');
  const disabled = await callBookingFunction(
    'createInternalBookingV1',
    {
      schemaVersion: 1,
      commandType: 'createBooking',
      requestId: 'req_flag_first',
      idempotencyKey: 'idem_flag_first',
      payload: { occurrenceId: 'bad/path' },
    },
    activeToken,
  );
  assert.equal(
    ((disabled.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'feature_disabled',
  );
  const queryDisabled = await callBookingFunction(
    'listMyBookingsV1',
    {
      schemaVersion: 1,
      queryType: 'listMyBookings',
      requestId: 'req_query_disabled',
      payload: {},
    },
    activeToken,
  );
  const queryResult = queryDisabled.body.result as Record<string, unknown>;
  assert.equal(queryResult.kind, 'rejected');
  assert.equal((queryResult.error as Record<string, unknown>).code, 'feature_disabled');
  const registry = await createBookingSchemaRegistry();
  assert.equal(registry.validator('booking_page.schema.json')(queryResult), true);
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
  const invalid = await callBookingFunction(
    'createInternalBookingV1',
    {
      schemaVersion: 1,
      commandType: 'createBooking',
      requestId: 'req_invalid_after_auth',
      idempotencyKey: 'idem_invalid_after_auth',
      payload: { occurrenceId: 'bad/path' },
    },
    token,
  );
  assert.equal(
    ((invalid.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'invalid_contract',
  );
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

void test('Firebase UID resolves through Session to a distinct domain User id', async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  await seedEvent(
    finiteEvent({
      registrationWindow: {
        opensAt: '2020-01-01T00:00:00.000Z',
        closesAt: '2099-01-01T00:00:00.000Z',
      },
      cancellationDeadline: '2099-01-01T00:00:00.000Z',
    }),
    firestore,
  );
  const firebaseUid = 'firebase-transport-user';
  const domainUserId = '018F4Z6M7N8P9Q0R1S2T3V4W5X';
  const token = await createAuthorizedActor(firebaseUid, undefined, domainUserId);
  const response = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_uid_bridge', idempotencyKey: 'idem_uid_bridge' }),
    token,
  );
  const result = response.body.result as Record<string, unknown>;
  assert.equal(result.kind, 'succeeded');
  const booking = result.booking as Record<string, unknown>;
  assert.equal(booking.userId, domainUserId);
  assert.notEqual(booking.userId, firebaseUid);
});

void test('Emulator Identity callable issues an opaque Session used by Booking', async () => {
  await cleanupBookingEmulator(firestore);
  await setIdentitySessionFlag(true, firestore);
  await setBookingFlags(true, firestore);
  await seedEvent(
    finiteEvent({
      registrationWindow: {
        opensAt: '2020-01-01T00:00:00.000Z',
        closesAt: '2099-01-01T00:00:00.000Z',
      },
      cancellationDeadline: '2099-01-01T00:00:00.000Z',
    }),
    firestore,
  );
  const token = await createFirebaseActor('firebase-session-callable-user');
  const identityResponse = await callBookingFunction(
    'establishIdentitySessionV1',
    {
      schemaVersion: 1,
      commandType: 'establishIdentitySession',
      requestId: 'req_establish_session',
      installationId: 'install-callable-1',
    },
    token,
  );
  const identityResult = identityResponse.body.result as Record<string, unknown>;
  assert.equal(identityResult.kind, 'succeeded');
  const identityData = identityResult.data as Record<string, unknown>;
  const sessionContext = identityData.sessionContext as Record<string, string>;
  assert.equal(typeof sessionContext.sessionId, 'string');
  assert.equal(typeof sessionContext.sessionHandle, 'string');
  assert.equal(typeof sessionContext.installationId, 'string');
  assert.equal(typeof sessionContext.userId, 'string');
  assert.notEqual(sessionContext.userId, 'firebase-session-callable-user');
  registerSessionContext(token, {
    sessionId: sessionContext.sessionId!,
    sessionHandle: sessionContext.sessionHandle!,
    installationId: sessionContext.installationId!,
  });
  const bookingResponse = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_session_booking', idempotencyKey: 'idem_session_booking' }),
    token,
  );
  const bookingResult = bookingResponse.body.result as Record<string, unknown>;
  assert.equal(bookingResult.kind, 'succeeded');
  const booking = bookingResult.booking as Record<string, unknown>;
  assert.equal(booking.userId, sessionContext.userId);
});

void test('server authority immediately rejects revoked sessions and stale capability snapshots', async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  const event = finiteEvent({
    registrationWindow: {
      opensAt: '2020-01-01T00:00:00.000Z',
      closesAt: '2099-01-01T00:00:00.000Z',
    },
  });
  await seedEvent(event, firestore);
  const uid = 'revoked-actor';
  const sessionId = `session-${uid}`;
  const token = await createAuthorizedActor(uid);
  const sessionRef = firestore.collection(bookingIdentityCollections.sessions).doc(sessionId);
  await sessionRef.update({ status: 'revoked', revision: 2 });
  const revoked = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_revoked', idempotencyKey: 'idem_revoked' }),
    token,
  );
  assert.equal(
    ((revoked.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'not_authorized',
  );

  await sessionRef.update({ status: 'active' });
  const stale = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_stale_access', idempotencyKey: 'idem_stale_access' }),
    token,
  );
  assert.equal(
    ((stale.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'not_authorized',
  );

  await firestore
    .collection(bookingIdentityCollections.accessSnapshots)
    .doc(sessionId)
    .update({ sessionRevision: 2, capabilityIds: [] });
  const deniedCapability = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_capability_denied', idempotencyKey: 'idem_capability_denied' }),
    token,
  );
  assert.equal(
    ((deniedCapability.body.result as Record<string, unknown>).error as Record<string, unknown>)
      .code,
    'not_authorized',
  );

  await firestore
    .collection(bookingIdentityCollections.accessSnapshots)
    .doc(sessionId)
    .update({ capabilityIds: ['booking.self_service'] });
  await sessionRef.update({ firebaseUid: 'different-firebase-uid' });
  const uidMismatch = await callBookingFunction(
    'createInternalBookingV1',
    createCommand({ requestId: 'req_uid_mismatch', idempotencyKey: 'idem_uid_mismatch' }),
    token,
  );
  assert.equal(
    ((uidMismatch.body.result as Record<string, unknown>).error as Record<string, unknown>).code,
    'not_authorized',
  );
});

void test('direct unauthenticated client reads and writes deny for all Booking collections', async () => {
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

void test('create and account revocation are serialized by one authority transaction', async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  const event = finiteEvent();
  await seedEvent(event, firestore);
  const uid = 'racing-create-actor';
  await createAuthorizedActor(uid);
  const accessHint = { firebaseUid: uid, ...bookingSessionContextFor(uid) };
  const createPromise = createInternalBooking(
    {
      firestore,
      clock: new FakeClock(new Date('2026-08-29T12:00:00.000Z')),
      mutationAuthorization: {
        hint: accessHint,
        expectedUserId: uid,
        flagId: bookingFlagIds.create,
        authority: new FirestoreBookingAccessAuthority(firestore),
        featureFlags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
      },
    },
    uid,
    createCommand(),
  );
  const revokePromise = firestore.runTransaction(async (transaction) => {
    const accountRef = firestore.collection(bookingIdentityCollections.accounts).doc(uid);
    const account = await transaction.get(accountRef);
    assert.equal(account.exists, true);
    transaction.update(accountRef, {
      status: 'blocked',
      revision: 2,
      securityRevision: 2,
      revokeBeforeSecurityRevision: 2,
    });
  });
  const [result] = await Promise.all([createPromise, revokePromise]);
  const bookings = await firestore.collection('bookings').get();
  if (result.kind === 'succeeded') {
    assert.equal(bookings.size, 1);
  } else {
    assert.deepEqual(result, { kind: 'rejected', code: 'permission_denied' });
    assert.equal(bookings.empty, true);
  }
  assert.equal(
    (await firestore.collection(bookingIdentityCollections.accounts).doc(uid).get()).get('status'),
    'blocked',
  );
});

void test('cancel and session revocation are serialized by one authority transaction', async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  const event = finiteEvent();
  await seedEvent(event, firestore);
  const uid = 'racing-cancel-actor';
  await createAuthorizedActor(uid);
  const created = await createInternalBooking(
    { firestore, clock: new FakeClock(new Date('2026-08-29T12:00:00.000Z')) },
    uid,
    createCommand(),
  );
  assert.equal(created.kind, 'succeeded');
  if (created.kind !== 'succeeded') return;
  const accessHint = { firebaseUid: uid, ...bookingSessionContextFor(uid) };
  const cancelPromise = cancelInternalBooking(
    {
      firestore,
      clock: new FakeClock(new Date('2026-08-29T12:01:00.000Z')),
      mutationAuthorization: {
        hint: accessHint,
        expectedUserId: uid,
        flagId: bookingFlagIds.cancel,
        authority: new FirestoreBookingAccessAuthority(firestore),
        featureFlags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
      },
    },
    uid,
    {
      schemaVersion: 1,
      commandType: 'cancelBooking',
      requestId: 'req-racing-cancel',
      idempotencyKey: 'idem-racing-cancel',
      expectedBookingRevision: created.data.booking.revision,
      payload: { bookingId: created.data.booking.id },
    },
  );
  const revokePromise = firestore.runTransaction(async (transaction) => {
    const sessionRef = firestore
      .collection(bookingIdentityCollections.sessions)
      .doc(accessHint.sessionId);
    const session = await transaction.get(sessionRef);
    assert.equal(session.exists, true);
    transaction.update(sessionRef, { status: 'revoked', revision: 2 });
  });
  const [result] = await Promise.all([cancelPromise, revokePromise]);
  const booking = await firestore.collection('bookings').doc(created.data.booking.id).get();
  if (result.kind === 'succeeded') {
    assert.equal(booking.get('state'), 'cancelled');
  } else {
    assert.deepEqual(result, { kind: 'rejected', code: 'permission_denied' });
    assert.equal(booking.get('state'), 'confirmed');
  }
});

void test('feature disable and mutation are serialized without a stale-authority commit', async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(true, firestore);
  await seedEvent(finiteEvent(), firestore);
  const uid = 'racing-flag-actor';
  await createAuthorizedActor(uid);
  const createPromise = createInternalBooking(
    {
      firestore,
      clock: new FakeClock(new Date('2026-08-29T12:00:00.000Z')),
      mutationAuthorization: {
        hint: { firebaseUid: uid, ...bookingSessionContextFor(uid) },
        expectedUserId: uid,
        flagId: bookingFlagIds.create,
        authority: new FirestoreBookingAccessAuthority(firestore),
        featureFlags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
      },
    },
    uid,
    createCommand({ requestId: 'req-racing-flag', idempotencyKey: 'idem-racing-flag' }),
  );
  const key = `local:LV:${bookingFlagIds.create}`;
  const disablePromise = firestore.runTransaction(async (transaction) => {
    const revisionRef = firestore.collection('platformFeatureFlagRevisions').doc(`${key}:1`);
    const revision = await transaction.get(revisionRef);
    assert.equal(revision.exists, true);
    transaction.update(revisionRef, { enabled: false });
  });
  const [result] = await Promise.all([createPromise, disablePromise]);
  const bookings = await firestore.collection('bookings').get();
  if (result.kind === 'succeeded') {
    assert.equal(bookings.size, 1);
  } else {
    assert.equal(result.kind, 'rejected');
    assert.equal(result.code, 'feature_disabled');
    assert.equal(bookings.empty, true);
  }
  assert.equal(
    (await firestore.collection('platformFeatureFlagRevisions').doc(`${key}:1`).get()).get(
      'enabled',
    ),
    false,
  );
});
