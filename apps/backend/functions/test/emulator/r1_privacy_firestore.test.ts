import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { bookingCollections } from '../../src/booking/transactions.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import {
  FirestorePrivacyOrchestrationRepository,
  privacyOrchestrationCollections,
} from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const requestId = '3d4f7b72-9465-4b1a-8d67-cfb7b1630c41';
const subjectId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';

before(cleanup);
after(cleanup);

void test('Firestore DSR dispatch and Booking erasure are atomic and reconcilable', async () => {
  await firestore.collection(bookingCollections.bookings).doc('booking-privacy-1').set({
    schemaVersion: 1,
    id: 'booking-privacy-1',
    revision: 2,
    userId: subjectId,
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    admissionMode: 'booking',
    confirmationMode: 'instant',
    state: 'cancelled',
    participantUnits: 1,
    reconfirmationState: 'notRequired',
    createdAt: '2026-09-20T00:00:00.000Z',
    updatedAt: '2026-09-21T00:00:00.000Z',
    confirmedAt: '2026-09-20T00:00:00.000Z',
    cancelledAt: '2026-09-21T00:00:00.000Z',
    terminalReason: 'userCancelled',
    retentionClass: 'bookingCore',
    legalHold: false,
  });
  const repository = new FirestorePrivacyOrchestrationRepository(firestore);
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  assert.equal(
    (
      await service.submit({
        requestId,
        subjectId,
        requestType: 'erasure',
        idempotencyKey: 'privacy-firestore-001',
        semanticHash: `sha256:${'a'.repeat(64)}`,
        requiredDomainIds: ['booking'],
        occurredAtUtc: '2026-09-25T10:00:00.000Z',
      })
    ).ok,
    true,
  );
  assert.equal((await service.verify(requestId, 1, '2026-09-25T10:01:00.000Z')).ok, true);
  assert.equal(
    (
      await service.dispatch(
        requestId,
        2,
        [{ domainId: 'booking', marketId: 'LV', targetRevision: 1 }],
        '2026-09-25T10:02:00.000Z',
      )
    ).ok,
    true,
  );
  const taskId = privacyDomainTaskId(requestId, 'booking', 'LV', 1);
  const runner = new PrivacyDomainTaskRunner(firestore, repository, service);
  assert.equal(
    await runner.runBookingTask({ requestId, taskId, nowUtc: '2026-09-25T10:03:00.000Z' }),
    'succeeded',
  );
  const reconciled = await service.reconcile(requestId, 3, '2026-09-25T10:04:00.000Z');
  assert.equal(reconciled.ok && reconciled.request.status, 'completed');
  assert.match(
    String(
      (await firestore.collection(bookingCollections.bookings).doc('booking-privacy-1').get()).get(
        'userId',
      ),
    ),
    /^anon_[0-9a-f]{64}$/u,
  );
});

async function cleanup(): Promise<void> {
  for (const collectionName of [
    ...Object.values(privacyOrchestrationCollections),
    bookingCollections.bookings,
  ]) {
    const snapshot = await firestore.collection(collectionName).get();
    if (snapshot.empty) continue;
    const batch = firestore.batch();
    snapshot.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }
}
