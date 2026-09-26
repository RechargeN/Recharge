import assert from 'node:assert/strict';
import test from 'node:test';
import {
  BookingPrivacyTaskHandler,
  InMemoryBookingPrivacyRecordStore,
} from '../../src/booking/booking_privacy_task_handler.js';
import type { BookingRecord } from '../../src/booking/domain.js';

const booking: BookingRecord & { readonly occurrenceEndSnapshot: string } = {
  schemaVersion: 1,
  id: 'booking-1',
  revision: 1,
  userId: 'user-1',
  eventId: 'event-1',
  occurrenceId: 'occurrence-1',
  admissionMode: 'booking',
  confirmationMode: 'instant',
  state: 'confirmed',
  participantUnits: 1,
  reconfirmationState: 'notRequired',
  createdAt: '2026-09-25T00:00:00.000Z',
  updatedAt: '2026-09-25T00:00:00.000Z',
  confirmedAt: '2026-09-25T00:00:00.000Z',
  occurrenceEndSnapshot: '2026-10-01T00:00:00.000Z',
};

void test('access succeeds while erasure waits for future Booking cancellation', async () => {
  const store = new InMemoryBookingPrivacyRecordStore([booking]);
  const handler = new BookingPrivacyTaskHandler(store);
  assert.equal(
    (
      await handler.handle({
        taskType: 'access',
        subjectId: 'user-1',
        nowUtc: '2026-09-25T00:00:00.000Z',
      })
    ).kind,
    'succeeded',
  );
  assert.deepEqual(
    await handler.handle({
      taskType: 'erasure',
      subjectId: 'user-1',
      pseudonymousActorId: `anon_${'a'.repeat(64)}`,
      nowUtc: '2026-09-25T00:00:00.000Z',
    }),
    { kind: 'retryableFailure', code: 'active_future_booking_cancellation_required' },
  );
});

void test('erasure pseudonymizes terminal Booking atomically', async () => {
  const store = new InMemoryBookingPrivacyRecordStore([
    { ...booking, state: 'cancelled', cancelledAt: '2026-09-25T00:00:00.000Z' },
  ]);
  const result = await new BookingPrivacyTaskHandler(store).handle({
    taskType: 'erasure',
    subjectId: 'user-1',
    pseudonymousActorId: `anon_${'b'.repeat(64)}`,
    nowUtc: '2026-09-25T00:00:00.000Z',
  });
  assert.deepEqual(result, {
    kind: 'succeeded',
    evidence: { recordCount: 1, pseudonymizedCount: 1 },
  });
  assert.equal('userId' in store.snapshot()[0]!, true);
  assert.equal((store.snapshot()[0] as BookingRecord).userId, `anon_${'b'.repeat(64)}`);
});
