import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { getEventAvailability } from '../../src/booking/availability_query.js';
import { logicalMutationId, requestAttemptId } from '../../src/booking/idempotency.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
} from '../../src/booking/transactions.js';
import { computeBookingSemanticHash } from '../../src/contracts/booking_v1.js';
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
  const storedBooking = (await firestore.collection(bookingCollections.bookings).limit(1).get())
    .docs[0];
  assert.ok(storedBooking);
  assert.equal(storedBooking.get('retentionClass'), 'bookingCore');
  const coreExpiresAt = storedBooking.get('expiresAt') as unknown;
  assert.ok(coreExpiresAt instanceof Timestamp);
  assert.equal(coreExpiresAt.toDate().toISOString(), '2026-11-27T14:00:00.000Z');
  const ledger = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(finiteEvent().occurrenceId, 'pool_general', 'onsite'))
    .get();
  assert.equal(ledger.get('confirmedUnits'), 1);
  assert.equal(
    (
      await firestore
        .collection(bookingCollections.userUsage)
        .doc(bookingUserUsageId('actor-a', 'LV'))
        .get()
    ).get('activeFiniteBookings'),
    1,
  );
  assert.equal(
    (await firestore.collection(bookingCollections.outbox).limit(1).get()).docs[0]?.get(
      'effectDisposition',
    ),
    'suppressedPreActivation',
  );
  const idempotencyRecords = await firestore.collection(bookingCollections.idempotency).get();
  assert.equal(idempotencyRecords.size, 2);
  for (const record of idempotencyRecords.docs) {
    assert.equal(record.get('retentionClass'), 'bookingIdempotency');
    const expiresAt = record.get('expiresAt') as unknown;
    assert.ok(expiresAt instanceof Timestamp);
    assert.equal(expiresAt.toDate().toISOString(), '2026-09-05T12:00:00.000Z');
  }
  const auditRecord = (await firestore.collection(bookingCollections.audit).limit(1).get()).docs[0];
  assert.ok(auditRecord);
  assert.equal(auditRecord.get('retentionClass'), 'bookingAudit');
  const auditExpiresAt = auditRecord.get('expiresAt') as unknown;
  assert.ok(auditExpiresAt instanceof Timestamp);
  assert.equal(auditExpiresAt.toDate().toISOString(), '2027-08-29T12:00:00.000Z');
  const outboxRecord = (await firestore.collection(bookingCollections.outbox).limit(1).get())
    .docs[0];
  assert.ok(outboxRecord);
  assert.equal(outboxRecord.get('retentionClass'), 'bookingOutbox');
  assert.ok(outboxRecord.get('expiresAt') instanceof Timestamp);
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

void test('explicit unlimited creates no inventory ledger but reserves an unlimited usage slot', async () => {
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
  const usage = await firestore.collection(bookingCollections.userUsage).limit(1).get();
  assert.equal(usage.size, 1);
  assert.equal(usage.docs[0]?.get('activeFiniteBookings'), 0);
  assert.equal(usage.docs[0]?.get('activeUnlimitedBookings'), 1);
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

void test('capacity decrease persists overbooked ledger and blocks new allocation', async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent({ totalCapacity: 2 }), firestore);
  const first = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCAPACITYFIRST000000' },
    'actor-capacity-a',
    createCommand({
      idempotencyKey: 'idem_capacity_first',
      requestId: 'req_capacity_first',
      payload: { ...createCommand().payload, participantUnits: 2 },
    }),
  );
  assert.equal(first.kind, 'succeeded');
  await seedEvent(finiteEvent({ materialRevision: 8, totalCapacity: 1 }), firestore);
  const blocked = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCAPACITYBLOCK000000' },
    'actor-capacity-b',
    createCommand({
      occurredAgainstEventRevision: 8,
      idempotencyKey: 'idem_capacity_blocked',
      requestId: 'req_capacity_blocked',
    }),
  );
  assert.deepEqual(blocked, { kind: 'rejected', code: 'sold_out' });
  const ledger = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(finiteEvent().occurrenceId, 'pool_general', 'onsite'))
    .get();
  assert.equal(ledger.get('totalCapacity'), 1);
  assert.equal(ledger.get('confirmedUnits'), 2);
  const availability = await getEventAvailability(firestore, clock, {
    schemaVersion: 1,
    queryType: 'getEventAvailability',
    requestId: 'req_capacity_availability',
    payload: {
      eventId: finiteEvent().eventId,
      occurrenceId: finiteEvent().occurrenceId,
      channel: 'onsite',
    },
  });
  assert.equal(availability.kind, 'succeeded');
  if (availability.kind === 'succeeded') {
    assert.equal(availability.data.status, 'soldOut');
    assert.equal(availability.data.availableUnits, 0);
  }
});

void test('capacity increase reuses the same ledger and permits the new units', async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent({ totalCapacity: 2 }), firestore);
  await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCAPACITYBASE0000000' },
    'actor-increase-a',
    createCommand({
      idempotencyKey: 'idem_increase_base',
      requestId: 'req_increase_base',
      payload: { ...createCommand().payload, participantUnits: 2 },
    }),
  );
  await seedEvent(finiteEvent({ materialRevision: 8, totalCapacity: 3 }), firestore);
  const result = await createInternalBooking(
    { firestore, clock, newBookingId: () => '01JRAWCCAPACITYPLUS0000000' },
    'actor-increase-b',
    createCommand({
      occurredAgainstEventRevision: 8,
      idempotencyKey: 'idem_increase_plus',
      requestId: 'req_increase_plus',
    }),
  );
  assert.equal(result.kind, 'succeeded');
  const ledger = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(finiteEvent().occurrenceId, 'pool_general', 'onsite'))
    .get();
  assert.equal(ledger.get('totalCapacity'), 3);
  assert.equal(ledger.get('confirmedUnits'), 3);
});

void test('dangling request attempt returns retryable temporary failure', async () => {
  await cleanupBookingEmulator(firestore);
  await seedEvent(finiteEvent(), firestore);
  const actorId = 'actor-damaged-attempt';
  const command = createCommand({
    requestId: 'req_damaged_attempt',
    idempotencyKey: 'idem_damaged_attempt',
  });
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
      bookingId: '01JRAWCUNCOMMITTED00000000',
      createdAt: fixedNow.toISOString(),
    });
  assert.deepEqual(await createInternalBooking({ firestore, clock }, actorId, command), {
    kind: 'retryableFailure',
    code: 'temporarily_unavailable',
  });
  assert.equal((await firestore.collection(bookingCollections.bookings).get()).empty, true);
});
