import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { cancelInternalBooking } from '../../src/booking/cancel_internal_booking.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import {
  consumeEventForBookingProjection,
  type EventBookingProjectionEvent,
} from '../../src/booking/event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from '../../src/booking/occurrence_lifecycle.js';
import { reconfirmInternalBooking } from '../../src/booking/reconfirm_internal_booking.js';
import { runReconfirmationDeadlineWorker } from '../../src/booking/reconfirmation_deadline_worker.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { NotificationEffectConsumer } from '../../src/modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from '../../src/modules/notifications/application/notification_reconciler.js';
import { FirestoreBookingOutboxSource } from '../../src/modules/notifications/infrastructure/firestore_notification_sources.js';
import { FirestoreNotificationsStore } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { bookingNotificationFlagIds } from '../../src/shared/feature_flags.js';
import { bookingInvariantProblems } from '../support/booking_invariants.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import {
  createCommand,
  finiteEvent,
  fixedNow,
  reconfirmCommand,
} from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupNotifications,
  setLocalFlag,
  setRecipientAccount,
} from '../support/notifications_world.js';

/**
 * F2 §6: concurrent confirm/cancel/reschedule actions, overlapping in time on
 * the Emulator, judged by the final stored invariants — allocation and usage
 * released at most once, an old material revision never confirms a newer
 * reschedule, and one outbox record and at most one inbox record per Booking
 * revision — not by the command answers alone. Each race runs several rounds.
 */
const firestore = emulatorFirestore();
const actorId = 'f2-race-actor';
const bookingId = '01JF2RACEBOOKING0000000001';
const rounds = 3;

beforeEach(async () => {
  await reset();
});
after(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
});

async function reset(): Promise<void> {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
  await setBookingFlags(true, firestore);
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  await setRecipientAccount(firestore, actorId, 'active');
  await setRecipientAccount(firestore, 'f2-race-second', 'active');
}

function event(): BookingEventProjection {
  return finiteEvent({
    occurrenceStartsAt: '2026-08-30T12:00:00.000Z',
    occurrenceEndsAt: '2026-08-30T14:00:00.000Z',
  });
}

const clock = new FakeClock(fixedNow);

async function book(id = bookingId, actor = actorId): Promise<void> {
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => id },
    actor,
    createCommand({ requestId: `req_${id}`, idempotencyKey: `idem_${id}` }),
  );
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
}

function reschedule(materialRevision: number, startsAt: string): EventBookingProjectionEvent {
  const projection = event();
  return {
    kind: 'EventMateriallyRescheduled',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    publicationRevision: materialRevision,
    materialRevision,
    occurredAt: clock.now().toISOString(),
    projection: {
      ...projection,
      materialRevision,
      occurrenceStartsAt: startsAt,
      occurrenceEndsAt: new Date(Date.parse(startsAt) + 2 * 3_600_000).toISOString(),
    },
  };
}

async function applyChange(change: EventBookingProjectionEvent): Promise<void> {
  await consumeEventForBookingProjection(firestore, change);
  await applyOccurrenceLifecycleEffects(firestore, change);
}

function reconfirm(materialRevision: number, key: string, expectedBookingRevision = 2) {
  return reconfirmInternalBooking(
    { firestore, clock },
    actorId,
    reconfirmCommand(bookingId, {
      requestId: `req_${key}`,
      idempotencyKey: key,
      expectedBookingRevision,
      payload: { bookingId, materialRevision },
    }),
  );
}

function cancel(expectedBookingRevision: number, key = 'idem_f2_race_cancel') {
  return cancelInternalBooking({ firestore, clock }, actorId, {
    schemaVersion: 1,
    commandType: 'cancelBooking',
    requestId: `req_${key}`,
    idempotencyKey: key,
    expectedBookingRevision,
    payload: { bookingId, reasonCode: 'user_request' },
  });
}

async function booking(id = bookingId): Promise<Record<string, unknown>> {
  return (await firestore.collection(bookingCollections.bookings).doc(id).get()).data()!;
}

/** Delivers every obligation twice over (redelivery), then checks invariants. */
async function settle(): Promise<void> {
  const store = new FirestoreNotificationsStore(firestore);
  const consumer = new NotificationEffectConsumer({ store, clock });
  const reconciler = new NotificationReconciler(
    store,
    new FirestoreBookingOutboxSource(firestore),
    consumer,
    clock,
  );
  const outbox = await firestore.collection(bookingCollections.outbox).get();
  await Promise.all(outbox.docs.map((document) => consumer.consume(document.id, document.data())));
  const report = await reconciler.reconcile();
  assert.deepEqual(report.findings, []);
  await reconciler.reconcile();
  assert.deepEqual(await bookingInvariantProblems(firestore), []);
}

async function prepared(): Promise<void> {
  await reset();
  clock.set(fixedNow);
  await seedEvent(event(), firestore);
  await book();
  clock.set(new Date(fixedNow.getTime() + 60_000));
}

void test('reconfirm ∥ cancel: one wins, the seat is released at most once', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    await applyChange(reschedule(8, '2026-08-31T12:00:00.000Z'));
    await Promise.all([reconfirm(8, `idem_f2_rc_${String(round)}`), cancel(2)]);
    const final = await booking();
    assert.ok(
      (final.state === 'cancelled' && final.reconfirmationState === 'required') ||
        (final.state === 'confirmed' && final.reconfirmationState === 'confirmed'),
      JSON.stringify(final),
    );
    await settle();
  }
});

void test('reconfirm of revision N ∥ reschedule to N+1: the old answer never confirms N+1', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    await applyChange(reschedule(8, '2026-08-31T12:00:00.000Z'));
    clock.set(new Date(fixedNow.getTime() + 120_000));
    await Promise.all([
      reconfirm(8, `idem_f2_rr_${String(round)}`),
      applyChange(reschedule(9, '2026-09-01T12:00:00.000Z')),
    ]);
    const final = await booking();
    assert.equal(final.state, 'confirmed');
    assert.equal(final.reconfirmationState, 'required');
    assert.equal(final.reconfirmationRequiredForRevision, 9);
    // A stale reconfirmation answer for 8 is refused afterwards as well.
    const stale = await reconfirm(8, `idem_f2_rr_stale_${String(round)}`, Number(final.revision));
    assert.equal((stale as { code?: string }).code, 'material_revision_mismatch');
    await settle();
  }
});

void test('cancel ∥ reschedule: a cancelled Booking is never re-required, nothing released twice', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    await Promise.all([cancel(1), applyChange(reschedule(8, '2026-08-31T12:00:00.000Z'))]);
    const final = await booking();
    if (final.state === 'cancelled') assert.notEqual(final.reconfirmationState, 'required');
    else assert.equal(final.reconfirmationState, 'required');
    await settle();
  }
});

void test('create ∥ reschedule: a Booking against the old revision always ends required', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await reset();
    clock.set(fixedNow);
    await seedEvent(event(), firestore);
    await Promise.all([
      createInternalBooking(
        { firestore, clock, newBookingId: () => bookingId },
        actorId,
        createCommand({
          requestId: `req_f2_cr_${String(round)}`,
          idempotencyKey: `idem_f2_cr_${String(round)}`,
          occurredAgainstEventRevision: 7,
        }),
      ),
      applyChange(reschedule(8, '2026-08-31T12:00:00.000Z')),
    ]);
    const snapshot = await firestore.collection(bookingCollections.bookings).doc(bookingId).get();
    if (snapshot.exists) {
      assert.equal(snapshot.get('reconfirmationState'), 'required');
      assert.equal(snapshot.get('reconfirmationRequiredForRevision'), 8);
    }
    await settle();
  }
});

void test('two reconfirms with different keys: one transition, one outbox record', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    await applyChange(reschedule(8, '2026-08-31T12:00:00.000Z'));
    const answers = await Promise.all([
      reconfirm(8, `idem_f2_rx_a_${String(round)}`),
      reconfirm(8, `idem_f2_rx_b_${String(round)}`),
    ]);
    assert.equal(answers.filter((answer) => answer.kind === 'succeeded').length, 1);
    const final = await booking();
    assert.equal(final.revision, 3);
    assert.equal(final.reconfirmationState, 'confirmed');
    await settle();
  }
});

void test('reconfirm ∥ deadline worker ∥ cancel at the deadline: one terminal outcome', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    const deadline = '2026-08-29T14:00:00.000Z';
    await applyChange(reschedule(8, deadline));
    clock.set(new Date(deadline));
    await Promise.all([
      reconfirm(8, `idem_f2_rwc_${String(round)}`),
      runReconfirmationDeadlineWorker(firestore, deadline),
      cancel(2, `idem_f2_rwc_cancel_${String(round)}`),
    ]);
    const final = await booking();
    assert.equal(final.state, 'cancelled');
    assert.ok(
      final.terminalReason === 'missedReconfirmation' || final.terminalReason === 'userCancelled',
    );
    await settle();
  }
});

void test('cancel ∥ occurrence cancellation: released once, one cancellation fact', async () => {
  for (let round = 0; round < rounds; round += 1) {
    await prepared();
    await book('01JF2RACEBOOKINGSECOND0001', 'f2-race-second');
    const projection = event();
    const cancellation: EventBookingProjectionEvent = {
      kind: 'EventOccurrenceCancelled',
      eventId: projection.eventId,
      occurrenceId: projection.occurrenceId,
      publicationRevision: 9,
      materialRevision: 7,
      occurredAt: clock.now().toISOString(),
    };
    await Promise.all([cancel(1), applyChange(cancellation)]);
    assert.equal((await booking()).state, 'cancelled');
    assert.equal((await booking('01JF2RACEBOOKINGSECOND0001')).state, 'cancelled');
    const outbox = await firestore
      .collection(bookingCollections.outbox)
      .where('aggregateId', '==', bookingId)
      .get();
    assert.equal(
      outbox.docs.filter((document) => document.get('eventType') === 'booking.cancelled').length,
      1,
    );
    await settle();
  }
});
