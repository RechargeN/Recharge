import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import {
  deliverEventBookingProjection,
  ensureEventBookingDelivery,
  eventBookingDeliveryCollections,
  replayDeadLetterEventBookingProjection,
} from '../../src/booking/event_projection_delivery.js';
import { runPendingEventBookingDeliveries } from '../../src/booking/event_projection_runtime.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  setBookingFlags,
} from '../support/booking_emulator.js';
import { seedEventBookingOutbox } from '../support/event_outbox_seed.js';
import { finiteEvent } from '../support/booking_fixtures.js';

const firestore = emulatorFirestore();
// Keep scheduler time strictly after the server-owned source timestamp so a
// delayed Emulator trigger cannot turn deterministic discovery into not-due work.
const nowUtc = '2099-09-27T23:00:00.000Z';

function event(revision: number): EventBookingProjectionEvent {
  const projection = finiteEvent({ materialRevision: revision });
  return {
    kind: 'EventRevisionPublished',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    publicationRevision: revision,
    materialRevision: revision,
    occurredAt: nowUtc,
    projection,
  };
}

beforeEach(async () => {
  await cleanupBookingEmulator(firestore);
  await setBookingFlags(false, firestore);
});
after(async () => cleanupBookingEmulator(firestore));

void test('scheduler reaches pending work after more than twenty delivered source facts', async () => {
  for (let index = 1; index <= 26; index += 1) {
    const outboxId = `scheduler-source-${String(index).padStart(2, '0')}`;
    await seedEventBookingOutbox(firestore, { outboxId, event: event(index) });
    if (index <= 25) {
      await firestore.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId).set({
        schemaVersion: 1,
        outboxId,
        status: 'delivered',
        attempts: 1,
        nextAttemptAtUtc: nowUtc,
        deliveredAtUtc: nowUtc,
      });
    }
  }
  await setBookingFlags(true, firestore);
  const result = await runPendingEventBookingDeliveries(firestore, nowUtc, 20);
  assert.equal(result.discovered, 1);
  assert.equal(
    (
      await firestore
        .collection(eventBookingDeliveryCollections.deliveries)
        .doc('scheduler-source-26')
        .get()
    ).get('status'),
    'delivered',
  );
});

void test('discovery repairs a source fact that never received a trigger delivery', async () => {
  await seedEventBookingOutbox(firestore, { outboxId: 'missed-trigger', event: event(1) });
  assert.equal(
    (
      await firestore
        .collection(eventBookingDeliveryCollections.deliveries)
        .doc('missed-trigger')
        .get()
    ).exists,
    false,
  );
  await setBookingFlags(true, firestore);
  const result = await runPendingEventBookingDeliveries(firestore, nowUtc, 20);
  assert.equal(result.discovered, 1);
  assert.equal(
    (
      await firestore
        .collection(eventBookingDeliveryCollections.deliveries)
        .doc('missed-trigger')
        .get()
    ).get('status'),
    'delivered',
  );
});

void test('parallel delivery acquires one fenced lease and counts one attempt', async () => {
  await seedEventBookingOutbox(firestore, { outboxId: 'parallel-delivery', event: event(1) });
  await ensureEventBookingDelivery(firestore, 'parallel-delivery', nowUtc);
  const results = await Promise.all([
    deliverEventBookingProjection(firestore, 'parallel-delivery', nowUtc, 'worker-a'),
    deliverEventBookingProjection(firestore, 'parallel-delivery', nowUtc, 'worker-b'),
  ]);
  assert.ok(results.includes('delivered'));
  assert.ok(results.includes('lease_held') || results.includes('replayed'));
  const stored = await firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('parallel-delivery')
    .get();
  assert.equal(stored.get('attempts'), 1);
  assert.equal(stored.get('status'), 'delivered');
  assert.ok(stored.get('expiresAt') instanceof Timestamp);
});

void test('expired processing lease is recovered and increments attempts once', async () => {
  await seedEventBookingOutbox(firestore, { outboxId: 'expired-lease', event: event(1) });
  await ensureEventBookingDelivery(firestore, 'expired-lease', nowUtc);
  await firestore.collection(eventBookingDeliveryCollections.deliveries).doc('expired-lease').set(
    {
      status: 'processing',
      attempts: 1,
      leaseOwner: 'dead-worker',
      leaseToken: 'dead-token',
      leaseGeneration: 1,
      leaseUntilUtc: '2026-09-27T22:59:00.000Z',
      nextAttemptAtUtc: '2026-09-27T22:59:00.000Z',
    },
    { merge: true },
  );
  assert.equal(
    await deliverEventBookingProjection(firestore, 'expired-lease', nowUtc, 'recovery-worker'),
    'delivered',
  );
  const stored = await firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('expired-lease')
    .get();
  assert.equal(stored.get('attempts'), 2);
  assert.equal(stored.get('leaseToken'), null);
});

void test('manual replay makes dead-letter due without assigning premature TTL', async () => {
  await seedEventBookingOutbox(firestore, { outboxId: 'manual-replay', event: event(1) });
  await ensureEventBookingDelivery(firestore, 'manual-replay', nowUtc);
  const ref = firestore.collection(eventBookingDeliveryCollections.deliveries).doc('manual-replay');
  await ref.set({ status: 'deadLetter', attempts: 5, reason: 'SyntheticError' }, { merge: true });
  assert.equal((await ref.get()).get('expiresAt'), undefined);
  assert.equal(
    await replayDeadLetterEventBookingProjection(firestore, 'manual-replay', nowUtc, {
      decisionId: 'replay-decision-1',
      actorId: 'operator-1',
      reason: 'verified_transient_failure',
      correlationId: 'correlation-replay-1',
    }),
    'requeued',
  );
  assert.equal(
    await replayDeadLetterEventBookingProjection(firestore, 'manual-replay', nowUtc, {
      decisionId: 'replay-decision-1',
      actorId: 'operator-1',
      reason: 'verified_transient_failure',
      correlationId: 'correlation-replay-1',
    }),
    'replayed',
  );
  const audit = await firestore
    .collection(eventBookingDeliveryCollections.operatorAudit)
    .doc('replay-decision-1')
    .get();
  assert.equal(audit.get('outboxId'), 'manual-replay');
  assert.ok(audit.get('expiresAt') instanceof Timestamp);
  assert.equal((await ref.get()).get('nextAttemptAtUtc'), nowUtc);
  assert.equal(
    await deliverEventBookingProjection(firestore, 'manual-replay', nowUtc, 'manual-worker'),
    'delivered',
  );
  assert.ok((await ref.get()).get('expiresAt') instanceof Timestamp);
});

void test('source record with caller-owned timestamp is quarantined', async () => {
  await firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc('invalid-created-at')
    .set({
      schemaVersion: 1,
      outboxId: 'invalid-created-at',
      event: event(1),
      createdAt: nowUtc,
    });
  assert.equal(
    await ensureEventBookingDelivery(firestore, 'invalid-created-at', nowUtc),
    'invalid_source',
  );
  const delivery = await firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('invalid-created-at')
    .get();
  assert.equal(delivery.get('status'), 'deadLetter');
  assert.equal(delivery.get('expiresAt'), undefined);
});
