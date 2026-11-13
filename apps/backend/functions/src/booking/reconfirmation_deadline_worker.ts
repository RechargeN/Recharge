import { createHash, randomUUID } from 'node:crypto';
import {
  FieldPath,
  Timestamp,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import { activeBookingKeyId, activeKeyMatches } from '../inventory/active_key.js';
import { releaseUnits, type PoolLedger } from '../inventory/ledger.js';
import { suppressedOutboxId } from '../notifications/outbox.js';
import { emergencySwitchState } from '../modules/operations/emergency_switch.js';
import {
  appendFailure,
  type OperationsFailureClass,
  type OperationsFailureEntry,
  type OperationsReplayResult,
  type OperationsTaskView,
} from '../modules/operations/operations_ports.js';
import { FirestoreFeatureFlagGate } from '../platform/config/firestore_feature_flag_gate.js';
import { releaseBookingSlot, type UserUsage } from '../policy/concurrency.js';
import { bookingFlagIds, operationsEmergencySwitchIds } from '../shared/feature_flags.js';
import { auditExpiresAt, coreBookingExpiresAt } from './retention.js';
import { bookingNotificationEffectsEnabled, bookingOutboxRecord } from './notification_effects.js';
import type { StoredBookingRecord } from './domain.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
  runBookingTransaction,
} from './transactions.js';

type DeadlineJobStatus = 'pending' | 'retryPending' | 'processing' | 'delivered' | 'deadLetter';

interface DeadlineJobRecord {
  readonly schemaVersion: 1;
  readonly jobId: string;
  readonly bookingId: string;
  readonly materialRevision: number;
  readonly deadlineUtc: string;
  readonly sourceBookingRevision: number;
  readonly status: DeadlineJobStatus;
  readonly attempts: number;
  readonly attemptBudget?: number;
  readonly reason?: string;
  readonly failureClass?: OperationsFailureClass;
  readonly firstFailure?: OperationsFailureEntry;
  readonly failureHistory?: readonly OperationsFailureEntry[];
  readonly replayCount?: number;
  readonly nextAttemptAtUtc?: string;
  readonly leaseToken?: string | null;
  readonly leaseGeneration?: number;
  readonly leaseUntilUtc?: string | null;
}

interface AcquiredDeadlineJob {
  readonly jobId: string;
  readonly bookingId: string;
  readonly materialRevision: number;
  readonly deadlineUtc: string;
  readonly attempts: number;
  readonly attemptBudget: number;
  readonly leaseToken: string;
  readonly leaseGeneration: number;
}

export interface ReconfirmationDeadlineOperatorDecision {
  readonly decisionId: string;
  readonly actorId: string;
  readonly reason: string;
  readonly correlationId: string;
}

export type ReconfirmationDeadlineResult =
  | 'auto_cancelled'
  | 'superseded'
  | 'not_due'
  | 'replayed'
  | 'retry_scheduled'
  | 'dead_letter'
  | 'lease_held'
  | 'lease_lost'
  | 'not_found'
  /** L2: activation off or emergency switch on; the job stays queued, no attempt spent. */
  | 'contained';

const checkpointId = 'reconfirmation-deadline-v1';
const leaseDurationMs = 2 * 60_000;
const terminalJobRetentionMs = 90 * 86_400_000;
const operatorAuditRetentionMs = 180 * 86_400_000;
const maximumAttempts = 5;
const containedRetryMs = 60_000;
const switchId = operationsEmergencySwitchIds.reconfirmationDeadlineWorker;

export async function discoverReconfirmationDeadlineJobs(
  firestore: Firestore,
  nowUtc: string,
  limit = 100,
  afterPage?: () => Promise<void>,
): Promise<Readonly<{ examined: number; created: number; cycleCompleted: boolean }>> {
  assertInstant(nowUtc);
  assertLimit(limit, 100);
  const checkpointRef = firestore
    .collection(bookingCollections.reconfirmationDeadlineCheckpoints)
    .doc(checkpointId);
  const checkpoint = await checkpointRef.get();
  const lastDeadlineUtc: unknown = checkpoint.get('lastDeadlineUtc');
  const lastBookingId: unknown = checkpoint.get('lastBookingId');
  let query = firestore
    .collection(bookingCollections.bookings)
    .where('reconfirmationState', '==', 'required')
    .where('reconfirmationDeadlineUtc', '<=', nowUtc)
    .orderBy('reconfirmationDeadlineUtc')
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (typeof lastDeadlineUtc === 'string' && typeof lastBookingId === 'string') {
    query = query.startAfter(lastDeadlineUtc, lastBookingId);
  }
  const due = await query.get();
  let created = 0;
  for (const document of due.docs) {
    if (await ensureReconfirmationDeadlineJob(firestore, document.id, nowUtc)) created += 1;
  }
  await afterPage?.();
  const last = due.docs.at(-1);
  const cycleCompleted = due.size < limit;
  if (cycleCompleted || last === undefined) {
    await checkpointRef.delete();
  } else {
    const deadline: unknown = last.get('reconfirmationDeadlineUtc');
    if (typeof deadline !== 'string') throw new TypeError('reconfirmation_deadline_invalid');
    await checkpointRef.set({
      schemaVersion: 1,
      checkpointId,
      lastDeadlineUtc: deadline,
      lastBookingId: last.id,
      updatedAtUtc: nowUtc,
    });
  }
  return { examined: due.size, created, cycleCompleted };
}

export async function ensureReconfirmationDeadlineJob(
  firestore: Firestore,
  bookingId: string,
  nowUtc: string,
): Promise<boolean> {
  assertInstant(nowUtc);
  const bookingRef = firestore.collection(bookingCollections.bookings).doc(bookingId);
  return runBookingTransaction(firestore, async (transaction) => {
    const bookingSnapshot = await transaction.get(bookingRef);
    const booking = bookingSnapshot.data() as StoredBookingRecord | undefined;
    if (
      booking === undefined ||
      booking.state !== 'confirmed' ||
      booking.reconfirmationState !== 'required' ||
      booking.reconfirmationRequiredForRevision === undefined ||
      booking.reconfirmationDeadlineUtc === undefined ||
      booking.reconfirmationDeadlineUtc > nowUtc
    ) {
      return false;
    }
    assertInstant(booking.reconfirmationDeadlineUtc);
    const jobId = reconfirmationDeadlineJobId(
      booking.id,
      booking.reconfirmationRequiredForRevision,
    );
    const jobRef = firestore.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId);
    const jobSnapshot = await transaction.get(jobRef);
    if (jobSnapshot.exists) return false;
    transaction.create(jobRef, {
      schemaVersion: 1,
      jobId,
      bookingId: booking.id,
      materialRevision: booking.reconfirmationRequiredForRevision,
      deadlineUtc: booking.reconfirmationDeadlineUtc,
      sourceBookingRevision: booking.revision,
      status: 'pending',
      attempts: 0,
      nextAttemptAtUtc: booking.reconfirmationDeadlineUtc,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    });
    return true;
  });
}

export async function processReconfirmationDeadlineJob(
  firestore: Firestore,
  jobId: string,
  nowUtc: string,
  leaseOwner: string = randomUUID(),
  /** Test-only fault injection between dispatch and effect, never a client parameter. */
  testHooks: Readonly<{ afterLease?: () => Promise<void> }> = {},
): Promise<ReconfirmationDeadlineResult> {
  assertInstant(nowUtc);
  const acquired = await acquireLease(firestore, jobId, nowUtc, leaseOwner);
  if (acquired === 'not_found') return 'not_found';
  if (acquired === 'delivered') return 'replayed';
  if (acquired === 'deadLetter') return 'dead_letter';
  if (acquired === 'leaseHeld') return 'lease_held';
  if (acquired === 'notDue') return 'not_due';
  if (acquired === 'contained') return 'contained';
  try {
    await testHooks.afterLease?.();
    const result = await autoCancelMissedReconfirmation(firestore, acquired, nowUtc);
    return result === 'contained' ? await releaseContained(firestore, acquired, nowUtc) : result;
  } catch (error) {
    const failureClass = classify(error);
    const terminal = failureClass === 'permanent' || acquired.attempts >= acquired.attemptBudget;
    const saved = await finishFailedAttempt(
      firestore,
      acquired,
      nowUtc,
      error,
      failureClass,
      terminal,
    );
    if (!saved) return 'lease_lost';
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
}

/**
 * OPS-L2 3.3: an invalid job record cannot be fixed by a retry. Inventory
 * drift is transient: an approved repair may fix it. Any other error may have
 * happened at commit, so the next attempt reads the booking again.
 */
function classify(error: unknown): OperationsFailureClass {
  if (
    error instanceof TypeError &&
    (error.message === 'reconfirmation_deadline_job_invalid' ||
      error.message === 'utc_instant_invalid')
  )
    return 'permanent';
  if (error instanceof Error && error.message === 'booking_inventory_inconsistent')
    return 'transient';
  return 'unknown';
}

export async function runReconfirmationDeadlineWorker(
  firestore: Firestore,
  nowUtc: string,
  executionLimit = 20,
): Promise<Readonly<{ discovered: number; examined: number; attempted: number }>> {
  assertInstant(nowUtc);
  assertLimit(executionLimit, 100);
  const enabled = await new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
    bookingFlagIds.reconfirmationDeadlineWorker,
  );
  if (!enabled) return { discovered: 0, examined: 0, attempted: 0 };
  const discovery = await discoverReconfirmationDeadlineJobs(firestore, nowUtc, 100);
  const due = await firestore
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .where('status', 'in', ['pending', 'retryPending', 'processing'])
    .where('nextAttemptAtUtc', '<=', nowUtc)
    .orderBy('nextAttemptAtUtc')
    .orderBy(FieldPath.documentId())
    .limit(executionLimit)
    .get();
  let attempted = 0;
  for (const document of due.docs) {
    const result = await processReconfirmationDeadlineJob(
      firestore,
      document.id,
      nowUtc,
      `scheduler:${document.id}`,
    );
    if (result !== 'lease_held') attempted += 1;
  }
  return { discovered: discovery.created, examined: due.size, attempted };
}

export async function replayDeadLetterReconfirmationDeadline(
  firestore: Firestore,
  jobId: string,
  nowUtc: string,
  decision: ReconfirmationDeadlineOperatorDecision,
): Promise<Exclude<OperationsReplayResult, 'replay_exhausted' | 'expired' | 'payload_changed'>> {
  assertInstant(nowUtc);
  assertOperatorDecision(decision);
  const jobRef = firestore.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId);
  const auditRef = firestore
    .collection(bookingCollections.reconfirmationDeadlineOperatorAudit)
    .doc(decision.decisionId);
  return runBookingTransaction(firestore, async (transaction) => {
    const [jobSnapshot, auditSnapshot] = await transaction.getAll(jobRef, auditRef);
    if (jobSnapshot === undefined || auditSnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    if (auditSnapshot.exists) {
      return auditSnapshot.get('jobId') === jobId ? 'replayed' : 'decision_conflict';
    }
    if (!jobSnapshot.exists) return 'not_found';
    const job = jobSnapshot.data() as DeadlineJobRecord;
    if (job.status !== 'deadLetter') return 'not_dead_letter';
    if (job.failureClass === 'permanent') return 'permanent_rejection';
    if ((await emergencySwitchState(firestore, switchId, transaction)) === 'contained')
      return 'family_contained';
    transaction.create(auditRef, {
      schemaVersion: 1,
      decisionId: decision.decisionId,
      action: 'deadLetterReplay',
      jobId,
      actorId: decision.actorId,
      reason: decision.reason,
      correlationId: decision.correlationId,
      previousFailureClass: job.failureClass ?? null,
      previousCode: job.reason ?? null,
      previousAttempts: job.attempts,
      occurredAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + operatorAuditRetentionMs),
    });
    // The original failure, attempt count and history stay; five more attempts are granted.
    transaction.set(
      jobRef,
      {
        status: 'retryPending',
        attemptBudget: job.attempts + maximumAttempts,
        replayCount: (job.replayCount ?? 0) + 1,
        lastReplayDecisionId: decision.decisionId,
        nextAttemptAtUtc: nowUtc,
        leaseOwner: null,
        leaseToken: null,
        leaseUntilUtc: null,
        manualReplayRequestedAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return 'requeued';
  });
}

export function reconfirmationDeadlineJobId(bookingId: string, materialRevision: number): string {
  if (!Number.isSafeInteger(materialRevision) || materialRevision < 1) {
    throw new TypeError('material_revision_invalid');
  }
  const canonical = `${Buffer.byteLength(bookingId, 'utf8')}:${bookingId}|${materialRevision}`;
  return `brd1_${createHash('sha256').update(`booking_reconfirmation_deadline_v1|${canonical}`).digest('hex')}`;
}

async function acquireLease(
  firestore: Firestore,
  jobId: string,
  nowUtc: string,
  leaseOwner: string,
): Promise<
  | AcquiredDeadlineJob
  | 'not_found'
  | 'delivered'
  | 'deadLetter'
  | 'leaseHeld'
  | 'notDue'
  | 'contained'
> {
  const jobRef = firestore.collection(bookingCollections.reconfirmationDeadlineJobs).doc(jobId);
  const leaseToken = randomUUID();
  return runBookingTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!snapshot.exists) return 'not_found';
    const job = snapshot.data() as DeadlineJobRecord;
    if (job.status === 'delivered') return 'delivered';
    if (job.status === 'deadLetter') return 'deadLetter';
    if (typeof job.nextAttemptAtUtc === 'string' && job.nextAttemptAtUtc > nowUtc) {
      return 'notDue';
    }
    if (
      job.status === 'processing' &&
      typeof job.leaseUntilUtc === 'string' &&
      job.leaseUntilUtc > nowUtc
    ) {
      return 'leaseHeld';
    }
    if ((await emergencySwitchState(firestore, switchId, transaction)) === 'contained')
      return 'contained';
    try {
      assertJob(job, jobId);
    } catch {
      // OPS-L2 3.3: a malformed job can never run; it goes to the dead letter
      // at once instead of failing every scheduler run.
      const failure = {
        attempt: Number.isSafeInteger(job.attempts) ? job.attempts : 0,
        failureClass: 'permanent' as const,
        code: 'reconfirmation_deadline_job_invalid',
        atUtc: nowUtc,
      };
      transaction.set(
        jobRef,
        {
          status: 'deadLetter',
          reason: failure.code,
          failureClass: 'permanent',
          firstFailure: job.firstFailure ?? failure,
          failureHistory: appendFailure(job.failureHistory, failure),
          leaseOwner: null,
          leaseToken: null,
          leaseUntilUtc: null,
          updatedAtUtc: nowUtc,
        },
        { merge: true },
      );
      return 'deadLetter';
    }
    const attempts = job.attempts + 1;
    const leaseGeneration = (job.leaseGeneration ?? 0) + 1;
    const leaseUntilUtc = new Date(Date.parse(nowUtc) + leaseDurationMs).toISOString();
    transaction.set(
      jobRef,
      {
        status: 'processing',
        attempts,
        leaseOwner,
        leaseToken,
        leaseGeneration,
        leaseUntilUtc,
        nextAttemptAtUtc: leaseUntilUtc,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return {
      jobId,
      bookingId: job.bookingId,
      materialRevision: job.materialRevision,
      deadlineUtc: job.deadlineUtc,
      attempts,
      attemptBudget: job.attemptBudget ?? maximumAttempts,
      leaseToken,
      leaseGeneration,
    };
  });
}

async function autoCancelMissedReconfirmation(
  firestore: Firestore,
  acquired: AcquiredDeadlineJob,
  nowUtc: string,
): Promise<ReconfirmationDeadlineResult> {
  const notificationEffects = await bookingNotificationEffectsEnabled(firestore);
  return runBookingTransaction(firestore, async (transaction) => {
    const enabled = await new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
      bookingFlagIds.reconfirmationDeadlineWorker,
      transaction,
    );
    // Activation and the emergency switch are read in the effect transaction:
    // a worker contained after taking its lease cancels nothing.
    if (!enabled || (await emergencySwitchState(firestore, switchId, transaction)) === 'contained')
      return 'contained';
    const jobRef = firestore
      .collection(bookingCollections.reconfirmationDeadlineJobs)
      .doc(acquired.jobId);
    const bookingRef = firestore.collection(bookingCollections.bookings).doc(acquired.bookingId);
    const [jobSnapshot, bookingSnapshot] = await transaction.getAll(jobRef, bookingRef);
    if (jobSnapshot === undefined || bookingSnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    if (!ownsLease(jobSnapshot.data(), acquired)) return 'lease_lost';
    const booking = bookingSnapshot.data() as StoredBookingRecord | undefined;
    if (
      booking === undefined ||
      booking.state !== 'confirmed' ||
      booking.reconfirmationState !== 'required' ||
      booking.reconfirmationRequiredForRevision !== acquired.materialRevision ||
      booking.reconfirmationDeadlineUtc !== acquired.deadlineUtc
    ) {
      completeJob(transaction, jobRef, nowUtc, 'superseded');
      return 'superseded';
    }
    if (booking.reconfirmationDeadlineUtc > nowUtc) {
      transaction.set(
        jobRef,
        {
          status: 'retryPending',
          nextAttemptAtUtc: booking.reconfirmationDeadlineUtc,
          leaseOwner: null,
          leaseToken: null,
          leaseUntilUtc: null,
          updatedAtUtc: nowUtc,
        },
        { merge: true },
      );
      return 'not_due';
    }
    const activeRef = firestore
      .collection(bookingCollections.activeKeys)
      .doc(activeBookingKeyId(booking.userId, booking.occurrenceId));
    const usageRef = firestore
      .collection(bookingCollections.userUsage)
      .doc(bookingUserUsageId(booking.userId, booking.marketId));
    const finite = booking.inventoryPoolId !== undefined && booking.channel !== undefined;
    if ((booking.inventoryPoolId !== undefined) !== (booking.channel !== undefined)) {
      throw new Error('booking_inventory_inconsistent');
    }
    const ledgerRef = finite
      ? firestore
          .collection(bookingCollections.poolLedgers)
          .doc(finitePoolLedgerId(booking.occurrenceId, booking.inventoryPoolId, booking.channel))
      : undefined;
    const resourceSnapshots = await transaction.getAll(
      activeRef,
      usageRef,
      ...(ledgerRef === undefined ? [] : [ledgerRef]),
    );
    const active = resourceSnapshots[0]?.data();
    const usage = resourceSnapshots[1]?.data() as UserUsage | undefined;
    if (
      !activeKeyMatches(active, booking.userId, booking.occurrenceId) ||
      active.bookingId !== booking.id ||
      usage === undefined ||
      !usageContainsBooking(usage, booking.id, finite)
    ) {
      throw new Error('booking_inventory_inconsistent');
    }
    const ledger = resourceSnapshots[2]?.data() as PoolLedger | undefined;
    if (finite && ledger === undefined) throw new Error('booking_inventory_inconsistent');
    const nextLedger =
      ledger === undefined ? undefined : releaseUnits(ledger, booking.participantUnits, nowUtc);
    const nextUsage = releaseBookingSlot(
      usage,
      booking.userId,
      booking.marketId,
      finite ? 'finite' : 'unlimited',
      booking.id,
      nowUtc,
    );
    const {
      reconfirmationRequiredForRevision: requiredRevision,
      reconfirmationDeadlineUtc: deadline,
      expiresAt: previousExpiry,
      ...bookingBase
    } = booking;
    void requiredRevision;
    void deadline;
    void previousExpiry;
    const revision = booking.revision + 1;
    const expiresAt = coreBookingExpiresAt(
      booking.occurrenceEndSnapshot,
      nowUtc,
      booking.legalHold,
    );
    const nextBooking: StoredBookingRecord = {
      ...bookingBase,
      revision,
      state: 'cancelled',
      reconfirmationState: 'missed',
      updatedAt: nowUtc,
      cancelledAt: nowUtc,
      terminalReason: 'missedReconfirmation',
      ...(expiresAt === undefined ? {} : { expiresAt }),
    };
    const audit: BookingAuditFact = {
      schemaVersion: 1,
      factType: 'booking_reconfirmation_expired',
      bookingId: booking.id,
      actorId: booking.userId,
      eventId: booking.eventId,
      occurrenceId: booking.occurrenceId,
      bookingRevision: revision,
      occurredAt: nowUtc,
      retentionClass: 'bookingAudit',
      legalHold: false,
      expiresAt: auditExpiresAt(nowUtc),
    };
    transaction.set(bookingRef, nextBooking);
    transaction.delete(activeRef);
    transaction.set(usageRef, nextUsage);
    if (ledgerRef !== undefined && nextLedger !== undefined) transaction.set(ledgerRef, nextLedger);
    transaction.create(
      firestore.collection(bookingCollections.audit).doc(bookingAuditId(booking.id, revision)),
      audit,
    );
    transaction.create(
      firestore.collection(bookingCollections.outbox).doc(suppressedOutboxId(booking.id, revision)),
      bookingOutboxRecord(notificationEffects, {
        effect: { kind: 'cancelled', cause: 'missedReconfirmation' },
        booking,
        actorId: booking.userId,
        revision,
        occurredAt: nowUtc,
        correlationId: acquired.jobId,
      }),
    );
    completeJob(transaction, jobRef, nowUtc, 'autoCancelled');
    return 'auto_cancelled';
  });
}

function completeJob(
  transaction: Transaction,
  jobRef: DocumentReference,
  nowUtc: string,
  outcome: 'autoCancelled' | 'superseded',
): void {
  transaction.set(
    jobRef,
    {
      status: 'delivered',
      outcome,
      completedAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + terminalJobRetentionMs),
      leaseOwner: null,
      leaseToken: null,
      leaseUntilUtc: null,
      updatedAtUtc: nowUtc,
    },
    { merge: true },
  );
}

async function finishFailedAttempt(
  firestore: Firestore,
  acquired: AcquiredDeadlineJob,
  nowUtc: string,
  error: unknown,
  failureClass: OperationsFailureClass,
  terminal: boolean,
): Promise<boolean> {
  const jobRef = firestore
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(acquired.jobId);
  return runBookingTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    const job = snapshot.data() as DeadlineJobRecord | undefined;
    if (!ownsLease(job, acquired)) return false;
    const code = safeErrorType(error);
    const failure = { attempt: acquired.attempts, failureClass, code, atUtc: nowUtc };
    transaction.set(
      jobRef,
      {
        status: terminal ? 'deadLetter' : 'retryPending',
        reason: code,
        failureClass,
        firstFailure: job?.firstFailure ?? failure,
        failureHistory: appendFailure(job?.failureHistory, failure),
        ...(terminal
          ? {}
          : {
              nextAttemptAtUtc: new Date(
                Date.parse(nowUtc) + retryDelayMs(acquired.attempts),
              ).toISOString(),
            }),
        leaseOwner: null,
        leaseToken: null,
        leaseUntilUtc: null,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return true;
  });
}

/** A contained worker is not a failure: the attempt is given back and the job waits. */
async function releaseContained(
  firestore: Firestore,
  acquired: AcquiredDeadlineJob,
  nowUtc: string,
): Promise<'contained' | 'lease_lost'> {
  const jobRef = firestore
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(acquired.jobId);
  return runBookingTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!ownsLease(snapshot.data(), acquired)) return 'lease_lost';
    transaction.set(
      jobRef,
      {
        status: 'retryPending',
        attempts: acquired.attempts - 1,
        nextAttemptAtUtc: new Date(Date.parse(nowUtc) + containedRetryMs).toISOString(),
        leaseOwner: null,
        leaseToken: null,
        leaseUntilUtc: null,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return 'contained';
  });
}

/** Minimal operator view: codes, counters and the job ID; never the booking or its subject. */
export async function inspectReconfirmationDeadlineJob(
  firestore: Firestore,
  jobId: string,
  nowUtc: string,
): Promise<OperationsTaskView | undefined> {
  const snapshot = await firestore
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(jobId)
    .get();
  if (!snapshot.exists) return undefined;
  const job = snapshot.data() as DeadlineJobRecord;
  const state: OperationsTaskView['state'] =
    job.status === 'delivered'
      ? 'done'
      : job.status === 'deadLetter'
        ? 'dead_letter'
        : job.status === 'retryPending'
          ? 'retry_scheduled'
          : job.status === 'processing'
            ? typeof job.leaseUntilUtc === 'string' && job.leaseUntilUtc > nowUtc
              ? 'in_flight'
              : 'unknown'
            : 'pending';
  return {
    taskId: jobId,
    state,
    storedStatus: job.status,
    attempts: job.attempts,
    attemptBudget: job.attemptBudget ?? maximumAttempts,
    failureClass: job.failureClass ?? (job.reason === undefined ? null : 'unknown'),
    failureCode: job.reason ?? null,
    firstFailure: job.firstFailure ?? null,
    failureHistory: job.failureHistory ?? [],
    replayCount: job.replayCount ?? 0,
    nextAttemptAtUtc: job.nextAttemptAtUtc ?? null,
  };
}

function ownsLease(value: unknown, acquired: AcquiredDeadlineJob): boolean {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const job = value as Record<string, unknown>;
  return (
    job.status === 'processing' &&
    job.leaseToken === acquired.leaseToken &&
    job.leaseGeneration === acquired.leaseGeneration
  );
}

function usageContainsBooking(usage: UserUsage, bookingId: string, finite: boolean): boolean {
  const slots = finite ? usage.activeFiniteSlots : usage.activeUnlimitedSlots;
  return slots.filter((slot) => slot.bookingId === bookingId).length === 1;
}

function assertJob(job: DeadlineJobRecord, jobId: string): void {
  if (
    job.schemaVersion !== 1 ||
    job.jobId !== jobId ||
    typeof job.bookingId !== 'string' ||
    !Number.isSafeInteger(job.materialRevision) ||
    job.materialRevision < 1 ||
    !Number.isSafeInteger(job.sourceBookingRevision) ||
    job.sourceBookingRevision < 1 ||
    !Number.isSafeInteger(job.attempts) ||
    job.attempts < 0
  ) {
    throw new TypeError('reconfirmation_deadline_job_invalid');
  }
  assertInstant(job.deadlineUtc);
}

function assertOperatorDecision(decision: ReconfirmationDeadlineOperatorDecision): void {
  for (const value of [
    decision.decisionId,
    decision.actorId,
    decision.reason,
    decision.correlationId,
  ]) {
    if (value.trim().length < 1 || value.length > 256) {
      throw new TypeError('operator_decision_invalid');
    }
  }
}

function assertInstant(value: string): void {
  if (!value.endsWith('Z') || !Number.isFinite(Date.parse(value))) {
    throw new TypeError('utc_instant_invalid');
  }
}

function assertLimit(value: number, maximum: number): void {
  if (!Number.isSafeInteger(value) || value < 1 || value > maximum) {
    throw new TypeError('reconfirmation_deadline_limit_invalid');
  }
}

function retryDelayMs(attempts: number): number {
  return [60_000, 5 * 60_000, 15 * 60_000, 60 * 60_000][Math.min(Math.max(attempts - 1, 0), 3)]!;
}

function safeErrorType(error: unknown): string {
  if (error instanceof Error && error.name.length > 0) return error.name.slice(0, 80);
  return 'UnknownError';
}
