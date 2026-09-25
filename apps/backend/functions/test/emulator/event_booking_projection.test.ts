import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import {
  consumeEventForBookingProjection,
  rebuildBookingEventProjections,
  type EventBookingProjectionEvent,
} from '../../src/booking/event_projection_consumer.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { createCommand, finiteEvent, fixedNow } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();
const occurredAt = '2026-08-20T10:00:00.000Z';

function published(
  materialRevision = 7,
  publicationRevision = materialRevision,
  overrides: Partial<ReturnType<typeof finiteEvent>> = {},
): EventBookingProjectionEvent {
  const projection = finiteEvent({ materialRevision, ...overrides });
  return {
    kind: 'EventRevisionPublished',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    materialRevision,
    publicationRevision,
    occurredAt,
    projection,
  };
}

beforeEach(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

void test('consumer is idempotent and ignores out-of-order material revisions', async () => {
  assert.equal((await consumeEventForBookingProjection(firestore, published())).kind, 'applied');
  assert.equal(
    (await consumeEventForBookingProjection(firestore, published())).kind,
    'ignoredDuplicate',
  );
  assert.equal(
    (await consumeEventForBookingProjection(firestore, published(6, 8))).kind,
    'ignoredStale',
  );
});

void test('same revision with different operational payload is a conflict', async () => {
  await consumeEventForBookingProjection(firestore, published());
  assert.deepEqual(
    await consumeEventForBookingProjection(firestore, published(7, 7, { totalCapacity: 99 })),
    { kind: 'rejected', code: 'revision_conflict' },
  );
});

void test('missing occurrence fails closed without a projection write', async () => {
  const invalid = { ...published(), occurrenceId: '' };
  assert.deepEqual(await consumeEventForBookingProjection(firestore, invalid), {
    kind: 'rejected',
    code: 'missing_occurrence',
  });
  assert.equal((await firestore.collection(bookingCollections.eventProjections).get()).empty, true);
});

void test('unpublish and occurrence cancellation become typed non-bookable tombstones', async () => {
  await consumeEventForBookingProjection(firestore, published());
  for (const [kind, lifecycle] of [
    ['EventUnpublished', 'unpublished'],
    ['EventOccurrenceCancelled', 'occurrenceCancelled'],
  ] as const) {
    await consumeEventForBookingProjection(firestore, {
      kind,
      eventId: finiteEvent().eventId,
      occurrenceId: finiteEvent().occurrenceId,
      materialRevision: kind === 'EventUnpublished' ? 8 : 9,
      publicationRevision: kind === 'EventUnpublished' ? 8 : 9,
      occurredAt,
    });
    const stored = await firestore
      .collection(bookingCollections.eventProjections)
      .doc(finiteEvent().occurrenceId)
      .get();
    assert.equal(stored.get('lifecycle'), lifecycle);
    assert.equal(stored.get('bookingEnabled'), false);
  }
});

void test('material reschedule updates exact occurrence projection and create observes it', async () => {
  await consumeEventForBookingProjection(firestore, published());
  const projection = finiteEvent({ materialRevision: 8, totalCapacity: 12 });
  const reschedule: EventBookingProjectionEvent = {
    kind: 'EventMateriallyRescheduled',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    materialRevision: 8,
    publicationRevision: 8,
    occurredAt,
    projection,
  };
  assert.equal((await consumeEventForBookingProjection(firestore, reschedule)).kind, 'applied');
  const result = await createInternalBooking(
    {
      firestore,
      clock: new FakeClock(fixedNow),
      newBookingId: () => '01JPROJECTIONBOOKING00000000',
    },
    'actor-projection',
    createCommand({ occurredAgainstEventRevision: 8 }),
  );
  assert.equal(result.kind, 'succeeded');
});

void test('deterministic rebuild orders revisions and converges on the newest projection', async () => {
  const results = await rebuildBookingEventProjections(firestore, [
    published(9, 9),
    published(7, 7),
  ]);
  assert.deepEqual(
    results.map((result) => result.kind),
    ['applied', 'applied'],
  );
  const stored = await firestore
    .collection(bookingCollections.eventProjections)
    .doc(finiteEvent().occurrenceId)
    .get();
  assert.equal(stored.get('materialRevision'), 9);
});
