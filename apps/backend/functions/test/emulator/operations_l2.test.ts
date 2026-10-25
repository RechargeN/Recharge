/**
 * L2 — operational recovery (OPERATIONS_L2_RECOVERY_AMENDMENT.md §8). Real owner
 * services over the Firestore Emulator with synthetic data: Booking delivery and
 * deadline worker, the F1 Notifications consumer, the L1 DSR runner and the L2
 * operations console. Background triggers stay off; every effect is driven here.
 * Every document this file creates is removed in `after` and the removal is
 * verified over every registered collection.
 */
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';
import { getApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, type Firestore } from 'firebase-admin/firestore';

import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import {
  deliverEventBookingProjection,
  ensureEventBookingDelivery,
  eventBookingDeliveryCollections,
  inspectEventBookingDelivery,
  reconcileEventBookingDeliveries,
} from '../../src/booking/event_projection_delivery.js';
import {
  processReconfirmationDeadlineJob,
  reconfirmationDeadlineJobId,
} from '../../src/booking/reconfirmation_deadline_worker.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { createAccount } from '../../src/modules/identity_publisher/domain/account.js';
import { createSession } from '../../src/modules/identity_publisher/domain/session.js';
import { identityAuthorityCollections as identity } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { libraryCollections } from '../../src/modules/library/library_contract.js';
import {
  notificationIdFor,
  notificationReceiptId,
} from '../../src/modules/notifications/domain/notification_effect.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import {
  grantOperationsAuthority,
  operationsCollections,
  type OperationsOperator,
} from '../../src/modules/operations/operations_console.js';
import {
  admitRestoredCopy,
  FirestoreDeletionAuthority,
  PrivacyRunnerRedeletion,
  restoreRequestId,
  type DeletionAuthorityPort,
} from '../../src/modules/operations/restore_admission.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { privacyWriterRegistry } from '../../src/modules/privacy_orchestration/domain/privacy_writer_registry.js';
import { FirestorePrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { bookingFlagIds, operationsEmergencySwitchIds } from '../../src/shared/feature_flags.js';
import { createEmulatorNotifications } from '../../src/notifications_entry.js';
import { createEmulatorOperationsConsole } from '../../src/operations_entry.js';
import { emulatorFirestore, seedEvent } from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { seedEventBookingOutbox } from '../support/event_outbox_seed.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  disableFunctionTriggers,
  enableFunctionTriggers,
} from '../support/functions_emulator_triggers.js';
import {
  bookingEffect,
  FaultyNotificationsStore,
  setLocalFlag,
} from '../support/notifications_world.js';
import { FirestoreNotificationsStore } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';

const db: Firestore = emulatorFirestore();
const T0 = '2099-10-25T10:00:00.000Z';
const at = (minutes: number) => new Date(Date.parse(T0) + minutes * 60_000).toISOString();
const clock = new FakeClock(new Date(T0));
const ops = createEmulatorOperationsConsole(db, { clock });
const notifications = createEmulatorNotifications(db, { clock });
const privacyRepository = new FirestorePrivacyOrchestrationRepository(db);
const privacy = new PrivacyOrchestrationService(
  privacyRepository,
  privacyRepository,
  privacyRepository,
);
const restoredDatabaseId = `l2-restore-${randomUUID().slice(0, 8)}`;
let startedAtMs = 0;

/** Synthetic 26-character ULID-shaped IDs. */
const id = (n: number) => `01JZ9${String(n).padStart(21, '0')}`;
const FULL = id(1);
const NARROW = id(2);
const NO_ENABLE = id(3);
const SUBJECT = id(10);
const RECIPIENT = id(11);
const RESTORE_SUBJECT = id(12);
const families = ['TF-01', 'TF-02', 'TF-03'] as const;
const allActions = ['ops.inspect', 'ops.replay', 'ops.reconcile', 'ops.disable', 'ops.enable'];
const operators = new Map<string, OperationsOperator>();
const switchKeys = Object.values(operationsEmergencySwitchIds).map((switchId) =>
  featureFlagKey('local', 'LV', switchId),
);
/** TF-02 runs only while its activation flag is on; its pointer is restored after. */
const deadlineActivationKey = featureFlagKey(
  'local',
  'LV',
  bookingFlagIds.reconfirmationDeadlineWorker,
);
let deadlineActivationBefore: Record<string, unknown> | undefined;

function operator(userId: string): OperationsOperator {
  return operators.get(userId)!;
}

let decisionCounter = 0;
function decision(reason = 'ops.verified-transient') {
  decisionCounter += 1;
  return {
    decisionId: `l2-decision-${String(decisionCounter).padStart(3, '0')}`,
    reason,
    correlationId: `l2-correlation-${String(decisionCounter)}`,
  };
}

async function seedOperator(
  userId: string,
  scopes: readonly { familyId: string; actions: readonly string[] }[],
): Promise<void> {
  const sessionId = randomUUID();
  await db
    .collection(identity.accounts)
    .doc(userId)
    .set({ ...createAccount(userId, T0) });
  await db
    .collection(identity.sessions)
    .doc(sessionId)
    .set({
      ...createSession({
        sessionId,
        userId,
        issuedAtUtc: T0,
        authzRevision: 1,
        firebaseUid: `l2-uid-${userId}`,
        installationId: `l2-install-${userId}`,
        sessionHandle: createHash('sha256').update(userId).digest('base64url').slice(0, 43),
      }),
    });
  await grantOperationsAuthority(db, {
    userId,
    scopes,
    grantedAtUtc: T0,
    expiresAtUtc: at(60 * 24),
  });
  operators.set(userId, { userId, sessionId });
}

async function setSwitch(familyIndex: 0 | 1 | 2, contained: boolean): Promise<void> {
  const result = await ops.setContainment(
    operator(FULL),
    families[familyIndex],
    contained,
    decision(contained ? 'ops.contain' : 'ops.reopen'),
  );
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
}

function publishedFact(
  occurrence: string,
  revision: number,
  overrides: Partial<Extract<EventBookingProjectionEvent, { projection: unknown }>> = {},
): EventBookingProjectionEvent {
  const projection = finiteEvent({
    eventId: `evt_${occurrence}`,
    occurrenceId: `occ_${occurrence}`,
    materialRevision: revision,
  });
  return {
    kind: 'EventRevisionPublished',
    eventId: projection.eventId,
    occurrenceId: projection.occurrenceId,
    publicationRevision: revision,
    materialRevision: revision,
    occurredAt: T0,
    projection,
    ...overrides,
  };
}

async function delivery(outboxId: string) {
  return (
    await db.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId).get()
  ).data();
}

async function projection(occurrence: string) {
  return (
    await db.collection(bookingCollections.eventProjections).doc(`occ_${occurrence}`).get()
  ).data();
}

/** One confirmed booking of SUBJECT on its own 2099 occurrence. */
const bookingNumbers: Readonly<Record<string, number>> = {
  lost: 501,
  crash: 502,
  stale: 503,
  partial: 504,
};

async function bookedOccurrence(tag: string): Promise<{ bookingId: string; occurrenceId: string }> {
  const occurrenceId = `occ_l2${tag}`;
  const event = finiteEvent({
    eventId: `evt_l2${tag}`,
    occurrenceId,
    occurrenceStartsAt: '2099-11-02T10:00:00.000Z',
    occurrenceEndsAt: '2099-11-02T12:00:00.000Z',
    registrationWindow: {
      opensAt: '2099-10-01T00:00:00.000Z',
      closesAt: '2099-11-01T00:00:00.000Z',
    },
    cancellationDeadline: '2099-11-01T00:00:00.000Z',
  });
  await seedEvent(event, db);
  const bookingId = id(bookingNumbers[tag]!);
  const created = await createInternalBooking(
    { firestore: db, clock: new FakeClock(new Date(T0)), newBookingId: () => bookingId },
    SUBJECT,
    createCommand({
      requestId: `l2-request-${tag}`,
      idempotencyKey: `l2-idem-${tag}`,
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
  return { bookingId, occurrenceId };
}

function cancellation(occurrenceId: string): EventBookingProjectionEvent {
  return {
    kind: 'EventOccurrenceCancelled',
    eventId: occurrenceId.replace('occ_', 'evt_'),
    occurrenceId,
    publicationRevision: 8,
    materialRevision: 7,
    occurredAt: T0,
  };
}

async function booking(bookingId: string) {
  return (await db.collection(bookingCollections.bookings).doc(bookingId).get()).data();
}

/** A verified, dispatched L1 erasure of `subjectId` over `domains`, driven to the end. */
async function erase(subjectId: string, domains: readonly string[], firestore = db) {
  const repository = new FirestorePrivacyOrchestrationRepository(firestore);
  const service =
    firestore === db
      ? privacy
      : new PrivacyOrchestrationService(repository, repository, repository);
  const requestId = randomUUID();
  const submitted = await service.submit({
    requestId,
    subjectId,
    requestType: 'erasure',
    idempotencyKey: `l2-${requestId}`,
    semanticHash: `sha256:${createHash('sha256').update(requestId).digest('hex')}`,
    requiredDomainIds: domains,
    occurredAtUtc: T0,
  });
  assert.ok(submitted.ok);
  assert.ok((await service.verify(requestId, 1, T0)).ok);
  assert.ok(
    (
      await service.dispatch(
        requestId,
        2,
        domains.map((domainId) => ({ domainId, marketId: 'LV', targetRevision: 1 })),
        T0,
      )
    ).ok,
  );
  const runner = new PrivacyDomainTaskRunner(firestore, repository, service, {
    leaseOwner: 'runner:l2',
    clock,
  });
  for (const domainId of domains)
    for (let run = 0; run < 50; run += 1)
      if (
        (await runner.runTask({
          requestId,
          taskId: privacyDomainTaskId(requestId, domainId, 'LV', 1),
          nowUtc: T0,
        })) !== 'progress'
      )
        break;
  const current = await repository.get(requestId);
  const reconciled = await service.reconcile(requestId, current!.revision, T0);
  assert.ok(reconciled.ok);
  return reconciled.request;
}

before(async () => {
  startedAtMs = Date.now();
  await disableFunctionTriggers();
  deadlineActivationBefore = (
    await db.collection(featureFlagPointerCollection).doc(deadlineActivationKey).get()
  ).data();
  for (const key of switchKeys)
    assert.equal(
      (await db.collection(featureFlagPointerCollection).doc(key).get()).exists,
      false,
      `emergency switch ${key} must start absent`,
    );
  await seedOperator(
    FULL,
    [...families, 'restore'].map((familyId) => ({
      familyId,
      actions: familyId === 'restore' ? ['ops.restore'] : allActions,
    })),
  );
  await seedOperator(NARROW, [{ familyId: 'TF-01', actions: ['ops.inspect'] }]);
  await seedOperator(NO_ENABLE, [{ familyId: 'TF-01', actions: ['ops.disable'] }]);
  await db
    .collection(identity.accounts)
    .doc(SUBJECT)
    .set({ ...createAccount(SUBJECT, T0) });
});

after(async () => {
  try {
    await cleanup();
  } finally {
    await enableFunctionTriggers();
  }
});

/**
 * Removes exactly what this file created: every document created since it
 * started in every registered collection, the isolated restore database and
 * the emergency switch pointers; then proves nothing created by it remains.
 */
async function cleanup(): Promise<void> {
  const collections = new Set([
    ...privacyWriterRegistry.map((entry) => entry.collection),
    ...Object.values(operationsCollections),
    featureFlagRevisionCollection,
    featureFlagPointerCollection,
  ]);
  const createdHere = async (name: string) =>
    (await db.collection(name).get()).docs.filter(
      (document) => document.createTime.toMillis() >= startedAtMs,
    );
  for (const name of collections)
    for (const document of await createdHere(name)) await document.ref.delete();
  if (deadlineActivationBefore !== undefined)
    await db
      .collection(featureFlagPointerCollection)
      .doc(deadlineActivationKey)
      .set(deadlineActivationBefore);
  const restored = getFirestore(getApp(), restoredDatabaseId);
  for (const collection of await restored.listCollections())
    await restored.recursiveDelete(collection);
  for (const name of collections)
    assert.deepEqual(
      (await createdHere(name)).map((document) => document.id),
      [],
      name,
    );
  for (const key of switchKeys)
    assert.equal((await db.collection(featureFlagPointerCollection).doc(key).get()).exists, false);
  assert.equal((await restored.listCollections()).length, 0);
}

// ------------------------------------------------------------------ 1: authority

void test('L2-T-AUTH: capability, scope, session, revoked grant and unavailable audit', async () => {
  await seedEventBookingOutbox(db, { outboxId: 'l2-auth', event: publishedFact('l2auth', 1) });
  await ensureEventBookingDelivery(db, 'l2-auth', T0);
  const ref = db.collection(eventBookingDeliveryCollections.deliveries).doc('l2-auth');
  await ref.set(
    { status: 'deadLetter', reason: 'SyntheticError', failureClass: 'transient' },
    { merge: true },
  );

  assert.equal((await ops.inspect(operator(NARROW), 'TF-01', 'l2-auth')).kind, 'succeeded');
  assert.deepEqual(await ops.replay(operator(NARROW), 'TF-01', 'l2-auth', decision()), {
    kind: 'rejected',
    code: 'access_denied',
  });
  assert.deepEqual(await ops.inspect(operator(NARROW), 'TF-02', 'any-job'), {
    kind: 'rejected',
    code: 'access_denied',
  });
  assert.deepEqual(await ops.inspect(operator(FULL), 'TF-04', 'x'), {
    kind: 'rejected',
    code: 'not_supported',
  });

  const session = db.collection(identity.sessions).doc(operator(FULL).sessionId);
  const original = (await session.get()).data()!;
  for (const patch of [
    { status: 'revoked' },
    { status: 'expired' },
    { idleExpiresAtUtc: at(-1) },
  ]) {
    await session.update(patch);
    assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-auth', decision()), {
      kind: 'rejected',
      code: 'access_denied',
    });
    await session.set(original);
  }
  const grant = db.collection(operationsCollections.authority).doc(FULL);
  const grantOriginal = (await grant.get()).data()!;
  for (const patch of [{ revoked: true }, { expiresAtUtc: at(-1) }]) {
    await grant.update(patch);
    assert.equal(
      (await ops.setContainment(operator(FULL), 'TF-01', true, decision())).kind,
      'rejected',
    );
    await grant.set(grantOriginal);
  }
  assert.equal((await delivery('l2-auth'))?.status, 'deadLetter');

  // Audit unavailable: nothing happens, for a replay and for a switch.
  const failing = createEmulatorOperationsConsole(db, {
    clock,
    beforeAudit: () => {
      throw new Error('audit unavailable');
    },
  });
  assert.deepEqual(await failing.replay(operator(FULL), 'TF-01', 'l2-auth', decision()), {
    kind: 'rejected',
    code: 'audit_or_authority_unavailable',
  });
  assert.deepEqual(await failing.setContainment(operator(FULL), 'TF-01', true, decision()), {
    kind: 'rejected',
    code: 'audit_or_authority_unavailable',
  });
  assert.equal((await delivery('l2-auth'))?.status, 'deadLetter');
  assert.equal(
    (await db.collection(featureFlagPointerCollection).doc(switchKeys[0]!).get()).exists,
    false,
  );
  const denies = (
    await db.collection(operationsCollections.audit).where('outcome', '==', 'deny').get()
  ).docs;
  assert.ok(denies.length >= 7);
});

// ---------------------------------------------------- 2: permanent / transient / unknown

void test('L2-T-CLASS: permanent, transient and unknown failures land in their states', async () => {
  // Permanent: the consumer refuses the fact; one attempt, dead letter, no replay.
  const broken = publishedFact('l2perm', 1);
  await seedEventBookingOutbox(db, {
    outboxId: 'l2-permanent',
    event: {
      ...broken,
      projection: { ...(broken as { projection: object }).projection, eventId: 'evt_other' },
    } as EventBookingProjectionEvent,
  });
  assert.equal(await deliverEventBookingProjection(db, 'l2-permanent', T0, 'w'), 'dead_letter');
  assert.equal((await delivery('l2-permanent'))?.failureClass, 'permanent');
  assert.equal((await delivery('l2-permanent'))?.attempts, 1);
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-permanent', decision()), {
    kind: 'succeeded',
    data: { result: 'permanent_rejection' },
  });

  // Permanent TF-02: a malformed job is dead-lettered at once instead of failing every run.
  const jobId = reconfirmationDeadlineJobId('l2-missing-booking', 3);
  await db.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId).set({
    schemaVersion: 1,
    jobId,
    bookingId: 'l2-missing-booking',
    deadlineUtc: T0,
    status: 'pending',
    attempts: 0,
    nextAttemptAtUtc: T0,
  });
  assert.equal(await processReconfirmationDeadlineJob(db, jobId, T0, 'w'), 'dead_letter');
  const job = await ops.inspect(operator(FULL), 'TF-02', jobId);
  assert.ok(job.kind === 'succeeded');
  assert.equal(job.data.failureClass, 'permanent');
  assert.equal(job.data.failureCode, 'reconfirmation_deadline_job_invalid');
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-02', jobId, decision()), {
    kind: 'succeeded',
    data: { result: 'permanent_rejection' },
  });

  // Unknown: the owner effect committed and the answer was lost.
  await seedEventBookingOutbox(db, { outboxId: 'l2-unknown', event: publishedFact('l2unk', 1) });
  assert.equal(
    await deliverEventBookingProjection(db, 'l2-unknown', T0, 'w', undefined, {
      afterEffect: () => Promise.reject(new Error('lost answer')),
    }),
    'retry_scheduled',
  );
  const unknown = await inspectEventBookingDelivery(db, 'l2-unknown', T0);
  assert.equal(unknown?.state, 'retry_scheduled');
  assert.equal(unknown?.failureClass, 'unknown');
  assert.ok((await projection('l2unk')) !== undefined, 'the effect itself committed');
  assert.equal(await deliverEventBookingProjection(db, 'l2-unknown', T0, 'w2'), 'delivered');
  assert.equal((await delivery('l2-unknown'))?.projectionResult, 'ignoredDuplicate');

  // Transient TF-03: the inbox store is down; the attempt is retried, not dead-lettered.
  await db
    .collection(identity.accounts)
    .doc(RECIPIENT)
    .set({ ...createAccount(RECIPIENT, T0) });
  const faulty = new FaultyNotificationsStore(new FirestoreNotificationsStore(db));
  faulty.faults.add('inbox_write');
  const consumer = createEmulatorNotifications(db, { clock, store: faulty }).consumer;
  const effect = bookingEffect({ bookingId: id(700), recipientId: RECIPIENT, occurredAt: T0 });
  assert.equal(await consumer.consume(effect.id, effect.data), 'retry_scheduled');
  const view = await ops.inspect(operator(FULL), 'TF-03', notificationReceiptId(effect.id));
  assert.ok(view.kind === 'succeeded');
  assert.equal(view.data.state, 'retry_scheduled');
  assert.equal(view.data.failureHistory[0]?.failureClass, 'transient');
});

// ----------------------------------------- 3: lost answer after the owner effect, replay

void test('L2-T-LOST: replay after a lost answer finds the receipt; no second effect', async () => {
  const { bookingId, occurrenceId } = await bookedOccurrence('lost');
  await seedEventBookingOutbox(db, { outboxId: 'l2-lost', event: cancellation(occurrenceId) });
  await ensureEventBookingDelivery(db, 'l2-lost', T0);
  await db
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('l2-lost')
    .set({ attemptBudget: 1 }, { merge: true });
  assert.equal(
    await deliverEventBookingProjection(db, 'l2-lost', T0, 'w', undefined, {
      afterEffect: () => Promise.reject(new Error('lost answer')),
    }),
    'dead_letter',
  );
  const projected = (
    await db.collection(bookingCollections.eventProjections).doc(occurrenceId).get()
  ).data();
  assert.equal(projected?.lifecycle, 'occurrenceCancelled');
  const replay = await ops.replay(operator(FULL), 'TF-01', 'l2-lost', decision());
  assert.deepEqual(replay, { kind: 'succeeded', data: { result: 'requeued' } });
  assert.equal(await deliverEventBookingProjection(db, 'l2-lost', T0, 'w2'), 'delivered');
  const stored = await delivery('l2-lost');
  assert.equal(stored?.projectionResult, 'ignoredDuplicate');
  assert.equal((stored?.firstFailure as { code: string } | undefined)?.code, 'Error');
  assert.equal((stored?.failureHistory as unknown[] | undefined)?.length, 1);
  const after = (
    await db.collection(bookingCollections.eventProjections).doc(occurrenceId).get()
  ).data();
  assert.equal(after?.projectedAt, projected?.projectedAt);
  const cancelled = await booking(bookingId);
  assert.equal(cancelled?.state, 'cancelled');
  assert.equal(cancelled?.revision, 2, 'one cancellation, not two');
});

// ----------------------------------- 4: crash before effect, before checkpoint, at dead letter

void test('L2-T-CRASH: before the effect, after it before the checkpoint, and at the dead letter', async () => {
  await seedEventBookingOutbox(db, { outboxId: 'l2-before', event: publishedFact('l2bef', 1) });
  assert.equal(
    await deliverEventBookingProjection(db, 'l2-before', T0, 'w', undefined, {
      afterLease: () => Promise.reject(new Error('crash before effect')),
    }),
    'retry_scheduled',
  );
  assert.equal(await projection('l2bef'), undefined);
  assert.equal(await deliverEventBookingProjection(db, 'l2-before', T0, 'w2'), 'delivered');
  assert.equal((await delivery('l2-before'))?.projectionResult, 'applied');

  // A lifecycle page commits and the worker dies before its checkpoint.
  const { bookingId, occurrenceId } = await bookedOccurrence('crash');
  await seedEventBookingOutbox(db, { outboxId: 'l2-page', event: cancellation(occurrenceId) });
  assert.equal(
    await deliverEventBookingProjection(db, 'l2-page', T0, 'w', () => {
      throw new Error('crash before checkpoint');
    }),
    'retry_scheduled',
  );
  assert.equal((await booking(bookingId))?.state, 'cancelled');
  assert.equal(await deliverEventBookingProjection(db, 'l2-page', T0, 'w2'), 'delivered');
  assert.equal((await booking(bookingId))?.revision, 2);

  // The worker dies while writing the failure: the record stays in flight until its
  // lease expires, then it is unknown and reconciliation resolves it from the receipt.
  await seedEventBookingOutbox(db, { outboxId: 'l2-deadwrite', event: publishedFact('l2dw', 1) });
  await assert.rejects(
    deliverEventBookingProjection(db, 'l2-deadwrite', T0, 'w', undefined, {
      afterEffect: () => Promise.reject(new Error('lost answer')),
      beforeFailureRecord: () => Promise.reject(new Error('dead-letter write failed')),
    }),
  );
  assert.equal((await inspectEventBookingDelivery(db, 'l2-deadwrite', T0))?.state, 'in_flight');
  assert.equal((await inspectEventBookingDelivery(db, 'l2-deadwrite', at(3)))?.state, 'unknown');
  const report = await reconcileEventBookingDeliveries(db, at(3));
  assert.ok(
    report.repaired?.some((item) => item.ref === 'l2-deadwrite' && item.code === 'outcome_unknown'),
  );
  assert.equal((await delivery('l2-deadwrite'))?.status, 'delivered');
  assert.equal((await delivery('l2-deadwrite'))?.projectionResult, 'ignoredDuplicate');
});

// ------------------------------------------------------- 5: two workers and a stale one

void test('L2-T-LEASE: parallel workers, lease expiry and a stale worker', async () => {
  await seedEventBookingOutbox(db, { outboxId: 'l2-parallel', event: publishedFact('l2par', 1) });
  const results = await Promise.all([
    deliverEventBookingProjection(db, 'l2-parallel', T0, 'a'),
    deliverEventBookingProjection(db, 'l2-parallel', T0, 'b'),
  ]);
  assert.ok(results.includes('delivered'));
  assert.equal((await delivery('l2-parallel'))?.attempts, 1);

  const { bookingId, occurrenceId } = await bookedOccurrence('stale');
  await seedEventBookingOutbox(db, { outboxId: 'l2-stale', event: cancellation(occurrenceId) });
  let newer: string | undefined;
  const stale = await deliverEventBookingProjection(
    db,
    'l2-stale',
    T0,
    'stale-worker',
    () => at(4),
    {
      // While the first worker stalls, its lease expires and a second worker finishes.
      afterLease: async () => {
        newer = await deliverEventBookingProjection(db, 'l2-stale', at(3), 'new-worker', () =>
          at(3),
        );
      },
    },
  );
  assert.equal(newer, 'delivered');
  assert.equal(stale, 'lease_lost');
  const stored = await delivery('l2-stale');
  assert.equal(stored?.status, 'delivered');
  assert.equal(stored?.attempts, 2);
  assert.equal(stored?.leaseToken, null);
  assert.equal((await booking(bookingId))?.revision, 2);
});

// ---------------------------------------- 6: changed payload, stale revision, revoked authority

void test('L2-T-REPLAY: changed payload, stale revision, revoked authority and decision reuse', async () => {
  await seedEventBookingOutbox(db, { outboxId: 'l2-payload', event: publishedFact('l2pay', 1) });
  await ensureEventBookingDelivery(db, 'l2-payload', T0);
  const ref = db.collection(eventBookingDeliveryCollections.deliveries).doc('l2-payload');
  await ref.set(
    { status: 'deadLetter', reason: 'SyntheticError', failureClass: 'transient', attempts: 5 },
    { merge: true },
  );
  await db
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc('l2-payload')
    .update({ 'event.publicationRevision': 2 });
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-payload', decision()), {
    kind: 'succeeded',
    data: { result: 'payload_changed' },
  });
  assert.equal((await delivery('l2-payload'))?.status, 'deadLetter');

  // A stale fact never overwrites a newer projection.
  await seedEventBookingOutbox(db, { outboxId: 'l2-new', event: publishedFact('l2rev', 3) });
  await seedEventBookingOutbox(db, { outboxId: 'l2-old', event: publishedFact('l2rev', 2) });
  assert.equal(await deliverEventBookingProjection(db, 'l2-new', T0, 'w'), 'delivered');
  assert.equal(await deliverEventBookingProjection(db, 'l2-old', T0, 'w'), 'delivered');
  assert.equal((await delivery('l2-old'))?.projectionResult, 'ignoredStale');
  assert.equal((await projection('l2rev'))?.materialRevision, 3);

  // Decision reuse and revoked authority.
  await seedEventBookingOutbox(db, { outboxId: 'l2-replay', event: publishedFact('l2rpl', 1) });
  await ensureEventBookingDelivery(db, 'l2-replay', T0);
  await db
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('l2-replay')
    .set(
      { status: 'deadLetter', reason: 'SyntheticError', failureClass: 'transient', attempts: 5 },
      { merge: true },
    );
  const first = decision();
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-replay', first), {
    kind: 'succeeded',
    data: { result: 'requeued' },
  });
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-replay', first), {
    kind: 'succeeded',
    data: { result: 'replayed' },
  });
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-payload', first), {
    kind: 'succeeded',
    data: { result: 'decision_conflict' },
  });
  assert.equal((await delivery('l2-replay'))?.attemptBudget, 10);
  assert.equal((await delivery('l2-replay'))?.attempts, 5);
  const grant = db.collection(operationsCollections.authority).doc(FULL);
  await grant.update({ revoked: true });
  assert.deepEqual(await ops.replay(operator(FULL), 'TF-01', 'l2-payload', decision()), {
    kind: 'rejected',
    code: 'access_denied',
  });
  await grant.update({ revoked: false });
});

// ---------------------------------------- 7: partial cross-domain, repeated reconciliation, pages

void test('L2-T-RECON: partial cross-domain effect, pagination, late insert and convergence', async () => {
  for (const n of [1, 2, 3, 4, 5]) {
    await seedEventBookingOutbox(db, {
      outboxId: `l2rc-${n}`,
      event: publishedFact(`l2rc${n}`, 1),
    });
    assert.equal(await deliverEventBookingProjection(db, `l2rc-${n}`, T0, 'w'), 'delivered');
  }
  // 2: delivered without a receipt; 3: lease expired without a result; 4: delivery lost.
  await db.collection(bookingCollections.eventProjections).doc('occ_l2rc2').delete();
  await db
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc('l2rc-3')
    .set(
      { status: 'processing', leaseToken: 'dead', leaseGeneration: 9, leaseUntilUtc: at(-10) },
      { merge: true },
    );
  await db.collection(bookingCollections.eventProjections).doc('occ_l2rc3').delete();
  await db.collection(eventBookingDeliveryCollections.deliveries).doc('l2rc-4').delete();
  await db.collection(bookingCollections.eventProjections).doc('occ_l2rc4').delete();

  // Partial cross-domain: Booking cancels one page, then the family is contained.
  const { bookingId, occurrenceId } = await bookedOccurrence('partial');
  await seedEventBookingOutbox(db, { outboxId: 'l2rc-partial', event: cancellation(occurrenceId) });
  // The switch turns on after the projection and before the lifecycle page: the
  // page already running completes, the delivery stops before the next one.
  assert.equal(
    await deliverEventBookingProjection(db, 'l2rc-partial', T0, 'w', undefined, {
      afterEffect: () => setSwitch(0, true),
    }),
    'contained',
  );
  assert.equal((await booking(bookingId))?.state, 'cancelled', 'the in-flight page completed');
  assert.equal((await delivery('l2rc-partial'))?.status, 'retryPending');
  await setSwitch(0, false);

  // Bounded passes of two records resume from their checkpoint; a fact committed
  // behind the cursor mid-cycle is seen by the next cycle.
  const repaired: string[] = [];
  const findings: string[] = [];
  let lateInserted = false;
  for (let pass = 0; pass < 200; pass += 1) {
    const report = await reconcileEventBookingDeliveries(db, T0, { pageSize: 2, maxPages: 1 });
    for (const item of report.repaired ?? []) repaired.push(`${item.ref}:${item.code}`);
    for (const item of report.findings) findings.push(`${item.ref}:${item.code}`);
    if (!lateInserted) {
      lateInserted = true;
      await db
        .collection(eventBookingDeliveryCollections.sourceOutbox)
        .doc('l2rc-late')
        .set({
          schemaVersion: 1,
          outboxId: 'l2rc-late',
          event: publishedFact('l2rclate', 1),
          createdAt: Timestamp.fromMillis(Date.parse('2026-01-01T00:00:00.000Z')),
        });
    }
    if (
      report.cycleCompleted &&
      pass > 0 &&
      repaired.some((entry) => entry.startsWith('l2rc-late'))
    )
      break;
  }
  assert.ok(repaired.includes('l2rc-2:receipt_missing'), repaired.join());
  assert.ok(repaired.includes('l2rc-3:outcome_unknown'), repaired.join());
  assert.ok(repaired.includes('l2rc-4:delivery_missing'), repaired.join());
  assert.ok(
    repaired.some((entry) => entry.startsWith('l2rc-late:')),
    repaired.join(),
  );
  for (const n of [2, 3, 4]) assert.ok((await projection(`l2rc${n}`)) !== undefined);
  // Booking has cancelled, the delivery has not finished: visible until the owner confirms.
  assert.ok(findings.includes('l2rc-partial:retry_scheduled'), findings.join());

  // The partial delivery completes through the owner and stays single.
  assert.equal(await deliverEventBookingProjection(db, 'l2rc-partial', at(2), 'w'), 'delivered');
  assert.equal((await booking(bookingId))?.revision, 2);

  // A full repeated cycle converges: nothing of ours is redispatched again.
  const again = await reconcileEventBookingDeliveries(db, at(2), { pageSize: 100, maxPages: 20 });
  assert.ok(again.cycleCompleted);
  assert.deepEqual(
    (again.repaired ?? []).filter((item) => item.ref.startsWith('l2')),
    [],
  );
  assert.deepEqual(
    again.findings.filter((item) => item.ref.startsWith('l2rc')),
    [],
  );
  const viaConsole = await ops.reconcile(operator(FULL), 'TF-01');
  assert.equal(viaConsole.kind, 'succeeded');
});

// ------------------------------------------- 8: emergency disable and re-enable

void test('L2-T-DISABLE: before dispatch, between dispatch and effect, re-enable without loss', async () => {
  await seedEventBookingOutbox(db, { outboxId: 'l2-off', event: publishedFact('l2off', 1) });
  const jobId = reconfirmationDeadlineJobId(id(800), 2);
  await db
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(jobId)
    .set({
      schemaVersion: 1,
      jobId,
      bookingId: id(800),
      materialRevision: 2,
      deadlineUtc: T0,
      sourceBookingRevision: 1,
      status: 'pending',
      attempts: 0,
      nextAttemptAtUtc: T0,
    });
  const effect = bookingEffect({ bookingId: id(801), recipientId: RECIPIENT, occurredAt: T0 });
  const receiptId = notificationReceiptId(effect.id);
  // Activation on, so every `contained` below comes from the emergency switch.
  await setLocalFlag(db, bookingFlagIds.reconfirmationDeadlineWorker, true);

  // Before dispatch: nothing is claimed, no attempt is spent, the queue stays.
  assert.deepEqual(await ops.setContainment(operator(NO_ENABLE), 'TF-01', true, decision()), {
    kind: 'succeeded',
    data: { result: 'contained' },
  });
  await setSwitch(1, true);
  await setSwitch(2, true);
  assert.equal(await deliverEventBookingProjection(db, 'l2-off', T0, 'w'), 'contained');
  assert.equal((await delivery('l2-off'))?.attempts, 0);
  assert.equal(await processReconfirmationDeadlineJob(db, jobId, T0, 'w'), 'contained');
  assert.equal(
    (await db.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId).get()).get(
      'attempts',
    ),
    0,
  );
  assert.equal(await notifications.consumer.consume(effect.id, effect.data), 'contained');
  assert.equal(await notifications.store.receipt(receiptId), undefined);

  // Re-enable needs its own capability.
  assert.deepEqual(await ops.setContainment(operator(NO_ENABLE), 'TF-01', false, decision()), {
    kind: 'rejected',
    code: 'access_denied',
  });
  await setSwitch(0, false);
  await setSwitch(1, false);
  await setSwitch(2, false);

  // Between dispatch and effect: the switch turns on after the lease or claim.
  assert.equal(
    await deliverEventBookingProjection(db, 'l2-off', T0, 'w', undefined, {
      afterLease: () => setSwitch(0, true),
    }),
    'contained',
  );
  assert.equal(await projection('l2off'), undefined);
  assert.equal((await delivery('l2-off'))?.attempts, 0);
  assert.equal(
    await processReconfirmationDeadlineJob(db, jobId, T0, 'w', {
      afterLease: () => setSwitch(1, true),
    }),
    'contained',
  );
  const parkedJob = await db
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(jobId)
    .get();
  assert.equal(parkedJob.get('attempts'), 0, 'the contained attempt is given back');
  assert.equal(parkedJob.get('status'), 'retryPending');
  const claim = await notifications.consumer.claim(effect.id, effect.data);
  assert.equal(claim.kind, 'claimed');
  await setSwitch(2, true);
  if (claim.kind === 'claimed')
    assert.deepEqual(await notifications.consumer.complete(claim.claim), { kind: 'contained' });
  const parked = await notifications.store.receipt(receiptId);
  assert.ok(parked?.shape === 'live');
  assert.equal(parked.status, 'retry_scheduled');
  assert.equal(parked.attemptBudget, 6, 'the contained attempt is given back');

  // An unreadable switch fails closed.
  await setSwitch(0, false);
  const pointer = db.collection(featureFlagPointerCollection).doc(switchKeys[0]!);
  const healthy = (await pointer.get()).data()!;
  await pointer.set({ ...healthy, activeRevision: 999 });
  assert.equal(await deliverEventBookingProjection(db, 'l2-off', T0, 'w'), 'contained');
  await pointer.set(healthy);

  // Re-enable: the queue is intact and drains through the owners.
  await setSwitch(1, false);
  await setSwitch(2, false);
  assert.equal(await deliverEventBookingProjection(db, 'l2-off', at(2), 'w'), 'delivered');
  assert.equal(await processReconfirmationDeadlineJob(db, jobId, at(2), 'w'), 'superseded');
  clock.set(new Date(at(5)));
  try {
    assert.equal(await notifications.consumer.consume(effect.id, effect.data), 'created');
  } finally {
    clock.set(new Date(T0));
  }
  const repeat = decision();
  const firstResult = await ops.setContainment(operator(FULL), 'TF-01', true, repeat);
  assert.deepEqual(await ops.setContainment(operator(FULL), 'TF-01', true, repeat), firstResult);
  await setSwitch(0, false);
});

// --------------------------------------- 9: erasure before replay and rebuild

void test('L2-T-RESURRECT: an erased recipient comes back through neither replay nor rebuild', async () => {
  const subject = id(20);
  await db
    .collection(identity.accounts)
    .doc(subject)
    .set({ ...createAccount(subject, T0) });
  const delivered = bookingEffect({ bookingId: id(900), recipientId: subject, occurredAt: T0 });
  const dead = bookingEffect({ bookingId: id(901), recipientId: subject, occurredAt: T0 });
  assert.equal(await notifications.consumer.consume(delivered.id, delivered.data), 'created');
  const deadReceipt = notificationReceiptId(dead.id);
  await db
    .collection(notificationCollections.inboxItems)
    .doc(notificationIdFor(deadReceipt))
    .set({ foreign: true });
  assert.equal(await notifications.consumer.consume(dead.id, dead.data), 'dead_lettered');
  await db
    .collection(notificationCollections.inboxItems)
    .doc(notificationIdFor(deadReceipt))
    .delete();

  const erased = await erase(subject, ['notifications']);
  assert.equal(erased.status, 'completed');
  const inbox = async () =>
    (
      await db
        .collection(notificationCollections.inboxItems)
        .where('recipientId', '==', subject)
        .get()
    ).size;
  assert.equal(await inbox(), 0);

  const replay = await ops.replay(operator(FULL), 'TF-03', deadReceipt, decision());
  assert.ok(replay.kind === 'succeeded');
  assert.notEqual(replay.data.result, 'requeued');
  // Re-reading the producer outbox (rebuild) meets the tombstones.
  assert.equal(await notifications.consumer.consume(delivered.id, delivered.data), 'duplicate');
  assert.equal(await notifications.consumer.consume(dead.id, dead.data), 'duplicate');
  assert.equal(await inbox(), 0);
});

// ------------------------------------------ 10: restore with newer tombstones

void test('L2-T-RESTORE: an older copy is admitted only after re-deletion; no authority keeps it closed', async () => {
  const restored = getFirestore(getApp(), restoredDatabaseId);
  const subjectDocs: [string, string, Record<string, unknown>][] = [
    [identity.accounts, RESTORE_SUBJECT, { ...createAccount(RESTORE_SUBJECT, T0) }],
    [
      libraryCollections.entries,
      'l2-restore-entry',
      { ownerId: RESTORE_SUBJECT, kind: 'favorite', objectId: 'x' },
    ],
    [
      'quickPlans',
      `${RESTORE_SUBJECT}:plan-private`,
      {
        ownerId: RESTORE_SUBJECT,
        planId: 'plan-private',
        revision: 3,
        status: 'active',
        plan: { id: 'plan-private', revision: 3, sourcePrompt: 'private evening', steps: [] },
        updatedAtUtc: T0,
      },
    ],
  ];
  for (const [collection, docId, data] of subjectDocs) {
    await db.collection(collection).doc(docId).set(data);
    // The synthetic "older snapshot": a copy taken before the erasure. Not a backup.
    await restored.collection(collection).doc(docId).set(data);
  }
  const domains = ['library', 'quick_plan'];
  const erased = await erase(RESTORE_SUBJECT, domains);
  assert.equal(erased.status, 'completed');
  assert.equal(
    (await db.collection(libraryCollections.entries).doc('l2-restore-entry').get()).exists,
    false,
  );
  assert.ok(
    (await restored.collection(libraryCollections.entries).doc('l2-restore-entry').get()).exists,
  );

  const redeletion = new PrivacyRunnerRedeletion(restored, clock, domains);
  const base = {
    restored,
    liveDatabaseId: '(default)',
    restoreStartedAtUtc: T0,
    redeletion,
  };
  const unavailable: DeletionAuthorityPort = {
    snapshot: () => Promise.reject(new Error('ledger unavailable')),
  };
  const stale: DeletionAuthorityPort = {
    snapshot: () => Promise.resolve({ asOfUtc: at(-60), decisions: [] }),
  };
  for (const authority of [unavailable, stale]) {
    const closed = await ops.admitRestore(operator(FULL), { ...base, authority });
    assert.deepEqual(closed, {
      kind: 'succeeded',
      data: { state: 'closed', reason: 'deletion_authority_unavailable', decisions: 0, failed: 0 },
    });
  }
  assert.ok(
    (await restored.collection(libraryCollections.entries).doc('l2-restore-entry').get()).exists,
  );
  assert.deepEqual(
    await admitRestoredCopy({ ...base, restored: db, authority: unavailable, clock }),
    { state: 'closed', reason: 'not_isolated', decisions: 0, failed: 0 },
  );
  assert.deepEqual(await ops.admitRestore(operator(NARROW), { ...base, authority: unavailable }), {
    kind: 'rejected',
    code: 'access_denied',
  });

  const authority = new FirestoreDeletionAuthority(db, clock);
  const admitted = await ops.admitRestore(operator(FULL), { ...base, authority });
  assert.ok(admitted.kind === 'succeeded');
  assert.equal(admitted.data.state, 'admitted', JSON.stringify(admitted.data));
  assert.equal(
    (await restored.collection(libraryCollections.entries).doc('l2-restore-entry').get()).exists,
    false,
  );
  const plan = (
    await restored.collection('quickPlans').doc(`${RESTORE_SUBJECT}:plan-private`).get()
  ).data();
  assert.equal(plan?.status, 'deleted');
  assert.equal(plan?.plan, undefined);
  // A repeated admission re-uses the same derived request.
  const again = await ops.admitRestore(operator(FULL), { ...base, authority });
  assert.ok(again.kind === 'succeeded' && again.data.state === 'admitted');
  const requests = await restored.collection('privacyRequests').get();
  const derived = requests.docs.filter(
    (document) => document.id === restoreRequestId(erased.requestId),
  );
  assert.equal(derived.length, 1);
});

// --------------------------------------- 11: original error, audit and no leaks

void test('L2-T-LEAK: views and audit keep codes and counters, never payload or subjects', async () => {
  const view = await ops.inspect(operator(FULL), 'TF-01', 'l2-lost');
  assert.ok(view.kind === 'succeeded');
  assert.deepEqual(Object.keys(view.data).sort(), [
    'attemptBudget',
    'attempts',
    'failureClass',
    'failureCode',
    'failureHistory',
    'firstFailure',
    'nextAttemptAtUtc',
    'replayCount',
    'state',
    'storedStatus',
    'taskId',
  ]);
  assert.equal(view.data.replayCount, 1);
  assert.equal(
    view.data.firstFailure?.failureClass,
    'unknown',
    'the original failure survives replay',
  );
  for (const entry of view.data.failureHistory)
    assert.deepEqual(Object.keys(entry).sort(), ['atUtc', 'attempt', 'code', 'failureClass']);

  const transientReceipt = notificationReceiptId(
    bookingEffect({ bookingId: id(700), recipientId: RECIPIENT, occurredAt: T0 }).id,
  );
  const notification = await ops.inspect(operator(FULL), 'TF-03', transientReceipt);
  assert.ok(notification.kind === 'succeeded');
  const serializedView = JSON.stringify(notification.data);
  assert.ok(!serializedView.includes(RECIPIENT));
  assert.ok(!serializedView.includes('eventContentId'));

  const audit = (await db.collection(operationsCollections.audit).get()).docs.map((document) =>
    document.data(),
  );
  assert.ok(audit.length > 0);
  const serializedAudit = JSON.stringify(audit);
  for (const subject of [SUBJECT, RECIPIENT, RESTORE_SUBJECT, id(20)])
    assert.ok(!serializedAudit.includes(subject), 'no data subject in the operator audit');
  for (const entry of audit) {
    assert.ok(['allow', 'deny'].includes(String(entry.outcome)));
    if (entry.reason !== undefined) assert.match(String(entry.reason), /^[a-z][a-z0-9._-]{2,95}$/u);
  }
  const replayDecision = (
    await db
      .collection(eventBookingDeliveryCollections.operatorAudit)
      .where('outboxId', '==', 'l2-lost')
      .get()
  ).docs[0]?.data();
  assert.equal(replayDecision?.previousFailureClass, 'unknown');
  assert.equal(replayDecision?.previousCode, 'Error');
});
