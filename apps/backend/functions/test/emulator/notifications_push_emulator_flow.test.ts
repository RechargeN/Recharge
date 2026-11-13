import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import type { DocumentData } from 'firebase-admin/firestore';

import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { pushCollections } from '../../src/modules/notifications/infrastructure/firestore_push_store.js';
import {
  bookingNotificationFlagIds,
  notificationsFlagIds,
} from '../../src/shared/feature_flags.js';
import {
  callBookingFunction,
  cleanupBookingEmulator,
  createAuthorizedActor,
  emulatorFirestore,
  seedEvent,
  setBookingFlags,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import { cleanupNotifications, setLocalFlag } from '../support/notifications_world.js';

/**
 * N3c (2026-11-13) end to end on the Emulator: the device registers its token
 * through `pushDeviceCommandV1` (installation from the Session), Booking commits
 * an obligation, the trigger creates the inbox item and then exactly one push
 * attempt (fake provider: the Emulator never reaches FCM). Unregistering stops
 * further pushes; the token never appears in a client-readable answer.
 */
const firestore = emulatorFirestore();
const now = new Date();
const clock = new FakeClock(now);
const token = `fcm-emulator-token-${'c'.repeat(48)}`;

async function cleanupPush(): Promise<void> {
  for (const name of Object.values(pushCollections)) {
    const snapshot = await firestore.collection(name).limit(200).get();
    const batch = firestore.batch();
    for (const document of snapshot.docs) batch.delete(document.ref);
    await batch.commit();
  }
}

before(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
  await cleanupPush();
  await setBookingFlags(true, firestore);
  await setLocalFlag(firestore, bookingNotificationFlagIds.effects, true);
  await setLocalFlag(firestore, notificationsFlagIds.consumeBooking, true);
});
after(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupNotifications(firestore);
  await cleanupPush();
});

async function book(userId: string, bookingId: string, occurrenceId: string): Promise<void> {
  await seedEvent(
    finiteEvent({
      occurrenceId,
      occurrenceStartsAt: new Date(now.getTime() + 86_400_000).toISOString(),
      occurrenceEndsAt: new Date(now.getTime() + 90_000_000).toISOString(),
      registrationWindow: {
        opensAt: new Date(now.getTime() - 86_400_000).toISOString(),
        closesAt: new Date(now.getTime() + 43_200_000).toISOString(),
      },
      cancellationDeadline: new Date(now.getTime() + 43_200_000).toISOString(),
    }),
    firestore,
  );
  const created = await createInternalBooking(
    { firestore, clock, newBookingId: () => bookingId },
    userId,
    createCommand({
      requestId: `req_${bookingId}`,
      idempotencyKey: `idem_${bookingId}`,
      payload: {
        occurrenceId,
        inventoryPoolId: 'pool_general',
        channel: 'onsite',
        participantUnits: 1,
        namedGuests: [],
      },
    }),
  );
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
}

async function waitFor(
  collection: string,
  field: string,
  value: string,
  count: number,
): Promise<DocumentData[]> {
  const deadline = Date.now() + 30_000;
  for (;;) {
    const snapshot = await firestore.collection(collection).where(field, '==', value).get();
    if (snapshot.size >= count || Date.now() > deadline)
      return snapshot.docs.map((document) => document.data());
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

const push = (commandType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  requestId: `req-${commandType}`,
  commandType,
  payload,
});

void test('register, inbox item, then one push hint; unregister stops push', async () => {
  const owner = 'n3c-push-owner';
  const ownerToken = await createAuthorizedActor(owner);

  const refused = await callBookingFunction(
    'pushDeviceCommandV1',
    push('registerPushDevice', { platform: 'android', token }),
  );
  assert.equal((refused.body.result as Record<string, unknown>).code, 'unauthenticated');
  const invalid = await callBookingFunction(
    'pushDeviceCommandV1',
    push('registerPushDevice', { platform: 'ios', token }),
    ownerToken,
  );
  assert.equal((invalid.body.result as Record<string, unknown>).code, 'request_invalid');

  const registered = await callBookingFunction(
    'pushDeviceCommandV1',
    push('registerPushDevice', { platform: 'android', token }),
    ownerToken,
  );
  assert.deepEqual(registered.body.result, {
    schemaVersion: 1,
    requestId: 'req-registerPushDevice',
    kind: 'succeeded',
    registered: true,
  });
  assert.ok(!JSON.stringify(registered.body).includes(token));
  const [registration] = await waitFor(pushCollections.registrations, 'userId', owner, 1);
  assert.equal(registration?.state, 'active');

  await book(owner, '01JN3CPUSHFLOW00000000001', 'occ_01JN3CPUSHFLOW000000001');
  const items = await waitFor(notificationCollections.inboxItems, 'recipientId', owner, 1);
  assert.equal(items.length, 1, 'the inbox record comes first');
  const attempts = await waitFor(pushCollections.attempts, 'userId', owner, 1);
  assert.equal(attempts.length, 1);
  assert.equal(attempts[0]?.state, 'sent');
  assert.equal(attempts[0]?.notificationId, items[0]?.notificationId);

  const unregistered = await callBookingFunction(
    'pushDeviceCommandV1',
    push('unregisterPushDevice', {}),
    ownerToken,
  );
  assert.equal((unregistered.body.result as Record<string, unknown>).registered, false);
  await book(owner, '01JN3CPUSHFLOW00000000002', 'occ_01JN3CPUSHFLOW000000002');
  await waitFor(notificationCollections.inboxItems, 'recipientId', owner, 2);
  // Give the trigger a moment: still exactly one push attempt.
  await new Promise((resolve) => setTimeout(resolve, 1500));
  const after = await firestore
    .collection(pushCollections.attempts)
    .where('userId', '==', owner)
    .get();
  assert.equal(after.size, 1);
});
