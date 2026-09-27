import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import {
  deliverEventBookingProjection,
  enqueueEventBookingProjection,
  eventBookingDeliveryCollections,
} from '../../src/booking/event_projection_delivery.js';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import {
  acceptedBookingRetentionPolicies,
  bookingRetentionCandidate,
  BookingRetentionPlanner,
} from '../../src/booking/retention.js';
import { bookingCollections, finitePoolLedgerId } from '../../src/booking/transactions.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import {
  FirestorePrivacyOrchestrationRepository,
  privacyOrchestrationCollections,
} from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { bookingIdentityCollections } from '../../src/booking/firestore_booking_access_authority.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import {
  callBookingFunction,
  cleanupBookingEmulator,
  createFirebaseActor,
  emulatorFirestore,
  registerSessionContext,
  setBookingFlags,
  setIdentitySessionFlag,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent, fixedNow } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();
const publishedAt = '2026-09-26T10:00:00.000Z';

beforeEach(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupPrivacy();
});

after(async () => {
  await cleanupBookingEmulator(firestore);
  await cleanupPrivacy();
});

void test(
  'Auth to Identity to Event to mobile callable Booking to Privacy is one reconcilable flow',
  { timeout: 120_000 },
  async () => {
    await setIdentitySessionFlag(true, firestore);
    await setBookingFlags(true, firestore);

    const event = futureEvent();
    const publication: EventBookingProjectionEvent = {
      kind: 'EventRevisionPublished',
      eventId: event.eventId,
      occurrenceId: event.occurrenceId,
      materialRevision: event.materialRevision,
      publicationRevision: event.materialRevision,
      occurredAt: publishedAt,
      projection: event,
    };
    assert.equal(
      await enqueueEventBookingProjection(firestore, {
        schemaVersion: 1,
        outboxId: 'stage8-publication-1',
        event: publication,
        createdAtUtc: publishedAt,
      }),
      'created',
    );
    assert.equal(
      await deliverEventBookingProjection(
        firestore,
        'stage8-publication-1',
        '2026-09-26T10:00:01.000Z',
      ),
      'delivered',
    );

    const firebaseUid = 'stage8-firebase-transport-user';
    const idToken = await createFirebaseActor(firebaseUid);
    const identity = await callBookingFunction(
      'establishIdentitySessionV1',
      {
        schemaVersion: 1,
        commandType: 'establishIdentitySession',
        requestId: 'stage8-identity-request',
        installationId: 'stage8-installation',
      },
      idToken,
    );
    const identityResult = identity.body.result as Record<string, unknown>;
    assert.equal(identityResult.kind, 'succeeded', JSON.stringify(identityResult));
    const identityData = identityResult.data as Record<string, unknown>;
    const issued = identityData.sessionContext as Record<string, string>;
    assert.match(issued.sessionHandle ?? '', /^[A-Za-z0-9_-]{43}$/u);
    assert.notEqual(issued.userId, firebaseUid);
    const domainUserId = requireString(issued.userId, 'Identity userId');
    const sessionId = requireString(issued.sessionId, 'Identity sessionId');
    const sessionHandle = requireString(issued.sessionHandle, 'Identity sessionHandle');
    const installationId = requireString(issued.installationId, 'Identity installationId');
    registerSessionContext(idToken, {
      sessionId,
      sessionHandle,
      installationId,
    });
    assert.equal(
      (await firestore.collection(bookingIdentityCollections.accounts).doc(domainUserId).get())
        .exists,
      true,
    );
    assert.equal(
      (await firestore.collection(bookingIdentityCollections.sessions).doc(sessionId).get()).get(
        'firebaseUid',
      ),
      firebaseUid,
    );

    const create = createCommand({
      requestId: 'stage8-create-request',
      idempotencyKey: 'stage8-create-idempotency',
    });
    const createdResponse = await callBookingFunction('createInternalBookingV1', create, idToken);
    const created = createdResponse.body.result as Record<string, unknown>;
    assert.equal(created.kind, 'succeeded', JSON.stringify(created));
    const booking = created.booking as Record<string, unknown>;
    const bookingId = String(booking.id);
    assert.equal(booking.userId, domainUserId);

    const replayResponse = await callBookingFunction('createInternalBookingV1', create, idToken);
    const replay = replayResponse.body.result as Record<string, unknown>;
    assert.equal(replay.kind, 'succeeded');
    assert.equal((replay.booking as Record<string, unknown>).id, bookingId);
    assert.equal(
      (
        await firestore
          .collection(bookingCollections.bookings)
          .where('userId', '==', domainUserId)
          .get()
      ).size,
      1,
    );

    const read = await callBookingFunction(
      'getMyBookingV1',
      {
        schemaVersion: 1,
        queryType: 'getMyBooking',
        requestId: 'stage8-read-request',
        payload: { bookingId },
      },
      idToken,
    );
    assert.equal((read.body.result as Record<string, unknown>).kind, 'found');
    const list = await callBookingFunction(
      'listMyBookingsV1',
      {
        schemaVersion: 1,
        queryType: 'listMyBookings',
        requestId: 'stage8-list-request',
        payload: { pageSize: 20 },
      },
      idToken,
    );
    assert.equal((list.body.result as Record<string, unknown>).kind, 'succeeded');
    const page = (list.body.result as Record<string, unknown>).page as Record<string, unknown>;
    assert.equal((page.items as unknown[]).length, 1);
    const availability = await callBookingFunction(
      'getEventAvailabilityV1',
      {
        schemaVersion: 1,
        queryType: 'getEventAvailability',
        requestId: 'stage8-availability-request',
        payload: {
          eventId: event.eventId,
          occurrenceId: event.occurrenceId,
          channel: event.channel,
        },
      },
      idToken,
    );
    const availabilityResult = availability.body.result as Record<string, unknown>;
    assert.equal(availabilityResult.kind, 'succeeded');
    assert.equal((availabilityResult.availability as Record<string, unknown>).status, 'available');

    const confirmationOutbox = await firestore
      .collection(bookingCollections.outbox)
      .where('bookingId', '==', bookingId)
      .get();
    assert.equal(confirmationOutbox.size, 1);
    assert.equal(confirmationOutbox.docs[0]!.get('obligationType'), 'booking_confirmation');

    const cancelledResponse = await callBookingFunction(
      'cancelInternalBookingV1',
      {
        schemaVersion: 1,
        commandType: 'cancelBooking',
        requestId: 'stage8-cancel-request',
        idempotencyKey: 'stage8-cancel-idempotency',
        expectedBookingRevision: booking.revision,
        payload: { bookingId, reasonCode: 'user_cancelled' },
      },
      idToken,
    );
    const cancelled = cancelledResponse.body.result as Record<string, unknown>;
    assert.equal(cancelled.kind, 'succeeded', JSON.stringify(cancelled));
    assert.equal((cancelled.booking as Record<string, unknown>).state, 'cancelled');
    const notificationOutbox = await firestore
      .collection(bookingCollections.outbox)
      .where('bookingId', '==', bookingId)
      .get();
    assert.deepEqual(
      notificationOutbox.docs.map((document) => String(document.get('obligationType'))).sort(),
      ['booking_cancellation', 'booking_confirmation'],
    );
    assert.equal(
      notificationOutbox.docs.every((document) => document.get('expiresAt') !== undefined),
      true,
    );

    const privacyRequestId = '87645f65-484e-4fd4-8451-106967ff7462';
    const privacyRepository = new FirestorePrivacyOrchestrationRepository(firestore);
    const privacy = new PrivacyOrchestrationService(
      privacyRepository,
      privacyRepository,
      privacyRepository,
    );
    assert.equal(
      (
        await privacy.submit({
          requestId: privacyRequestId,
          subjectId: domainUserId,
          requestType: 'erasure',
          idempotencyKey: 'stage8-privacy-erasure',
          semanticHash: `sha256:${'8'.repeat(64)}`,
          requiredDomainIds: ['booking'],
          occurredAtUtc: '2026-09-26T10:10:00.000Z',
        })
      ).ok,
      true,
    );
    assert.equal((await privacy.verify(privacyRequestId, 1, '2026-09-26T10:10:01.000Z')).ok, true);
    assert.equal(
      (
        await privacy.dispatch(
          privacyRequestId,
          2,
          [{ domainId: 'booking', marketId: 'LV', targetRevision: 1 }],
          '2026-09-26T10:10:02.000Z',
        )
      ).ok,
      true,
    );
    const taskId = privacyDomainTaskId(privacyRequestId, 'booking', 'LV', 1);
    const runner = new PrivacyDomainTaskRunner(firestore, privacyRepository, privacy);
    assert.equal(
      await runner.runBookingTask({
        requestId: privacyRequestId,
        taskId,
        nowUtc: '2026-09-26T10:10:03.000Z',
      }),
      'succeeded',
    );
    const reconciled = await privacy.reconcile(privacyRequestId, 3, '2026-09-26T10:10:04.000Z');
    assert.equal(reconciled.ok && reconciled.request.status, 'completed');
    assert.match(
      String(
        (await firestore.collection(bookingCollections.bookings).doc(bookingId).get()).get(
          'userId',
        ),
      ),
      /^anon_[0-9a-f]{64}$/u,
    );

    const retention = new BookingRetentionPlanner(acceptedBookingRetentionPolicies());
    const held = bookingRetentionCandidate({
      recordId: bookingId,
      retentionClass: 'core',
      createdAtUtc: '2026-09-26T10:00:00.000Z',
      terminalAtUtc: '2026-09-26T10:05:00.000Z',
      legalHold: true,
    });
    const farFuture = parseUtcInstant('2099-01-01T00:00:00.000Z');
    assert.equal(retention.plan(held, farFuture).action, 'retain_legal_hold');
    assert.equal(retention.planRestore(held, farFuture).action, 'restore_allowed_legal_hold');
  },
);

void test('Event projection retries a transient lifecycle inconsistency and converges', async () => {
  const event = finiteEvent();
  const publication: EventBookingProjectionEvent = {
    kind: 'EventRevisionPublished',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    materialRevision: event.materialRevision,
    publicationRevision: event.materialRevision,
    occurredAt: publishedAt,
    projection: event,
  };
  await enqueueEventBookingProjection(firestore, {
    schemaVersion: 1,
    outboxId: 'stage8-retry-publication',
    event: publication,
    createdAtUtc: publishedAt,
  });
  assert.equal(
    await deliverEventBookingProjection(
      firestore,
      'stage8-retry-publication',
      '2026-09-26T10:20:00.000Z',
    ),
    'delivered',
  );
  const created = await createInternalBooking(
    {
      firestore,
      clock: new FakeClock(fixedNow),
      newBookingId: () => '01JSTAGE8RETRYBOOKING000000',
    },
    'stage8-retry-user',
    createCommand({
      requestId: 'stage8-retry-create',
      idempotencyKey: 'stage8-retry-idempotency',
    }),
  );
  assert.equal(created.kind, 'succeeded');
  if (created.kind !== 'succeeded') return;

  const ledgerRef = firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(event.occurrenceId, event.poolId!, event.channel!));
  const ledger = await ledgerRef.get();
  assert.equal(ledger.exists, true);
  const ledgerData = ledger.data()!;
  await ledgerRef.delete();

  const cancelled: EventBookingProjectionEvent = {
    kind: 'EventOccurrenceCancelled',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    materialRevision: event.materialRevision + 1,
    publicationRevision: event.materialRevision + 1,
    occurredAt: '2026-09-26T10:21:00.000Z',
  };
  await enqueueEventBookingProjection(firestore, {
    schemaVersion: 1,
    outboxId: 'stage8-retry-cancellation',
    event: cancelled,
    createdAtUtc: cancelled.occurredAt,
  });
  assert.equal(
    await deliverEventBookingProjection(
      firestore,
      'stage8-retry-cancellation',
      '2026-09-26T10:21:01.000Z',
    ),
    'retry_scheduled',
  );
  assert.equal(
    (
      await firestore
        .collection(eventBookingDeliveryCollections.deliveries)
        .doc('stage8-retry-cancellation')
        .get()
    ).get('attempts'),
    1,
  );

  await ledgerRef.set(ledgerData);
  assert.equal(
    await deliverEventBookingProjection(
      firestore,
      'stage8-retry-cancellation',
      '2026-09-26T10:21:02.000Z',
    ),
    'delivered',
  );
  assert.equal(
    (
      await firestore.collection(bookingCollections.bookings).doc(created.data.booking.id).get()
    ).get('terminalReason'),
    'occurrenceCancelled',
  );
});

function futureEvent() {
  return finiteEvent({
    occurrenceStartsAt: '2098-08-29T11:00:00.000Z',
    occurrenceEndsAt: '2098-08-29T14:00:00.000Z',
    registrationWindow: {
      opensAt: '2020-01-01T00:00:00.000Z',
      closesAt: '2099-01-01T00:00:00.000Z',
    },
    cancellationDeadline: '2099-01-01T00:00:00.000Z',
  });
}

async function cleanupPrivacy(): Promise<void> {
  for (const collectionName of Object.values(privacyOrchestrationCollections)) {
    const snapshot = await firestore.collection(collectionName).get();
    if (snapshot.empty) continue;
    const batch = firestore.batch();
    snapshot.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }
}

function requireString(value: string | undefined, label: string): string {
  assert.equal(typeof value, 'string', label);
  assert.notEqual(value, '', label);
  return value!;
}
