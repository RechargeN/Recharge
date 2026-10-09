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
import { FirestoreFeatureFlagGate } from '../platform/config/firestore_feature_flag_gate.js';
import { releaseBookingSlot, type UserUsage } from '../policy/concurrency.js';
import { bookingFlagIds } from '../shared/feature_flags.js';
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
  | 'not_found';

const checkpointId = 'reconfirmation-deadline-v1';
const leaseDurationMs = 2 * 60_000;
const terminalJobRetentionMs = 90 * 86_400_000;
const operatorAuditRetentionMs = 180 * 86_400_000;
const maximumAttempts = 5;

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
): Promise<ReconfirmationDeadlineResult> {
  assertInstant(nowUtc);
  const acquired = await acquireLease(firestore, jobId, nowUtc, leaseOwner);
  if (acquired === 'not_found') return 'not_found';
  if (acquired === 'delivered') return 'replayed';
  if (acquired === 'deadLetter') return 'dead_letter';
  if (acquired === 'leaseHeld') return 'lease_held';
  if (acquired === 'notDue') return 'not_due';
  try {
    return await autoCancelMissedReconfirmation(firestore, acquired, nowUtc);
  } catch (error) {
    const terminal = acquired.attempts >= maximumAttempts;
    const saved = await finishFailedAttempt(firestore, acquired, nowUtc, error, terminal);
    if (!saved) return 'lease_lost';
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
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
): Promise<'requeued' | 'replayed' | 'not_found' | 'not_dead_letter'> {
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
      return auditSnapshot.get('jobId') === jobId ? 'replayed' : 'not_dead_letter';
    }
    if (!jobSnapshot.exists) return 'not_found';
    if (jobSnapshot.get('status') !== 'deadLetter') return 'not_dead_letter';
    transaction.create(auditRef, {
      schemaVersion: 1,
      decisionId: decision.decisionId,
      action: 'deadLetterReplay',
      jobId,
      actorId: decision.actorId,
      reason: decision.reason,
      correlationId: decision.correlationId,
      occurredAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + operatorAuditRetentionMs),
    });
    transaction.set(
      jobRef,
      {
        status: 'retryPending',
        attempts: 0,
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
  AcquiredDeadlineJob | 'not_found' | 'delivered' | 'deadLetter' | 'leaseHeld' | 'notDue'
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
    assertJob(job, jobId);
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
    if (!enabled) throw new Error('reconfirmation_deadline_worker_disabled');
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
  terminal: boolean,
): Promise<boolean> {
  const jobRef = firestore
    .collection(bookingCollections.reconfirmationDeadlineJobs)
    .doc(acquired.jobId);
  return runBookingTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!ownsLease(snapshot.data(), acquired)) return false;
    transaction.set(
      jobRef,
      {
        status: terminal ? 'deadLetter' : 'retryPending',
        reason: safeErrorType(error),
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
