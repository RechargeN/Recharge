import type { Firestore } from 'firebase-admin/firestore';
import type { CancelBookingCommand } from '../contracts/booking_v1.js';
import { computeBookingSemanticHash } from '../contracts/booking_v1.js';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import { activeBookingKeyId } from '../inventory/active_key.js';
import { releaseUnits, type PoolLedger } from '../inventory/ledger.js';
import { createSuppressedOutbox, suppressedOutboxId } from '../notifications/outbox.js';
import { releaseBookingSlot, type UserUsage } from '../policy/concurrency.js';
import {
  BookingDomainRefusal,
  BookingRetryableFailure,
  rejected,
  retryable,
  succeeded,
  type BookingResult,
} from '../shared/failures.js';
import {
  classifyFirestoreFailure,
  type FirestoreFailureLogger,
} from '../shared/firestore_failure.js';
import type { ServerClock } from '../shared/server_clock.js';
import { publicBookingRecord, type BookingRecord, type StoredBookingRecord } from './domain.js';
import {
  logicalMutationId,
  requestAttemptId,
  toRequestAttemptRecord,
  type IdempotencyRecord,
  type LogicalIdempotencyRecord,
} from './idempotency.js';
import { auditExpiresAt, coreBookingExpiresAt, idempotencyExpiresAt } from './retention.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
  runBookingTransaction,
} from './transactions.js';
import {
  assertBookingMutationAuthorized,
  type BookingMutationAuthorization,
} from './mutation_authorizer.js';

export interface CancelBookingDependencies {
  readonly firestore: Firestore;
  readonly clock: ServerClock;
  readonly failureLogger?: FirestoreFailureLogger;
  readonly mutationAuthorization?: BookingMutationAuthorization;
}

export interface CancelBookingOutput {
  readonly booking: BookingRecord;
  readonly replayed: boolean;
}

export async function cancelInternalBooking(
  dependencies: CancelBookingDependencies,
  actorId: string,
  command: CancelBookingCommand,
): Promise<BookingResult<CancelBookingOutput>> {
  const semanticHash = computeBookingSemanticHash(command, actorId);
  const logicalId = logicalMutationId(actorId, command.commandType, command.idempotencyKey);
  const attemptId = requestAttemptId(actorId, command.requestId);
  try {
    return await runBookingTransaction(dependencies.firestore, async (transaction) => {
      if (dependencies.mutationAuthorization !== undefined) {
        await assertBookingMutationAuthorized(
          transaction,
          dependencies.mutationAuthorization,
          dependencies.clock.now(),
        );
      }
      const logicalRef = dependencies.firestore
        .collection(bookingCollections.idempotency)
        .doc(logicalId);
      const attemptRef = dependencies.firestore
        .collection(bookingCollections.idempotency)
        .doc(attemptId);
      const bookingRef = dependencies.firestore
        .collection(bookingCollections.bookings)
        .doc(command.payload.bookingId);
      const [logicalSnapshot, attemptSnapshot, bookingSnapshot] = await transaction.getAll(
        logicalRef,
        attemptRef,
        bookingRef,
      );
      if (
        logicalSnapshot === undefined ||
        attemptSnapshot === undefined ||
        bookingSnapshot === undefined
      ) {
        throw new Error('firestore_snapshot_count_mismatch');
      }
      const logical = logicalSnapshot.data() as IdempotencyRecord | undefined;
      const attempt = attemptSnapshot.data() as IdempotencyRecord | undefined;
      assertIdempotency(attempt, logical, actorId, semanticHash, logicalId);
      if (attempt !== undefined) {
        if (logical === undefined || logical.kind !== 'logicalMutation') {
          throw new BookingRetryableFailure('temporarily_unavailable');
        }
        return replayOutcome(logical);
      }
      if (logical !== undefined) {
        if (logical.kind !== 'logicalMutation') {
          throw new BookingDomainRefusal('idempotency_conflict');
        }
        const replay = replayOutcome(logical);
        transaction.create(attemptRef, toRequestAttemptRecord(logical, attemptId));
        return replay;
      }
      const storedBooking = bookingSnapshot.data() as StoredBookingRecord | undefined;
      const booking = storedBooking === undefined ? undefined : publicBookingRecord(storedBooking);
      if (booking === undefined || booking.userId !== actorId)
        throw new BookingDomainRefusal('permission_denied');
      if (booking.state === 'cancelled') {
        const nowIso = dependencies.clock.now().toISOString();
        const outcome = succeeded<CancelBookingOutput>({ booking, replayed: false });
        const idempotency: LogicalIdempotencyRecord = {
          schemaVersion: 1,
          kind: 'logicalMutation',
          actorId,
          commandType: command.commandType,
          semanticHash,
          logicalMutationId: logicalId,
          requestAttemptId: attemptId,
          bookingId: booking.id,
          outcome,
          createdAt: nowIso,
          retentionClass: 'bookingIdempotency',
          legalHold: false,
          expiresAt: idempotencyExpiresAt(nowIso),
        };
        transaction.create(logicalRef, idempotency);
        transaction.create(attemptRef, toRequestAttemptRecord(idempotency, attemptId));
        return outcome;
      }
      if (booking.revision !== command.expectedBookingRevision || booking.state !== 'confirmed') {
        throw new BookingDomainRefusal('revision_conflict');
      }

      const activeRef = dependencies.firestore
        .collection(bookingCollections.activeKeys)
        .doc(activeBookingKeyId(actorId, booking.occurrenceId));
      const now = dependencies.clock.now();
      if (typeof booking.cancellationDeadlineSnapshot === 'string') {
        const cancellationDeadline = new Date(booking.cancellationDeadlineSnapshot);
        if (!Number.isFinite(cancellationDeadline.getTime())) {
          throw new BookingDomainRefusal('event_unavailable');
        }
        if (now >= cancellationDeadline) {
          throw new BookingDomainRefusal('cancellation_deadline_passed');
        }
      }
      let ledgerRef;
      let nextLedger: PoolLedger | undefined;
      const usageRef = dependencies.firestore
        .collection(bookingCollections.userUsage)
        .doc(bookingUserUsageId(actorId, booking.marketId));
      let usageSnapshot;
      const hasPool = booking.inventoryPoolId !== undefined;
      const hasChannel = booking.channel !== undefined;
      if (hasPool !== hasChannel) throw new BookingDomainRefusal('event_unavailable');
      if (hasPool && hasChannel) {
        ledgerRef = dependencies.firestore
          .collection(bookingCollections.poolLedgers)
          .doc(finitePoolLedgerId(booking.occurrenceId, booking.inventoryPoolId, booking.channel));
        const snapshots = await transaction.getAll(ledgerRef, usageRef);
        const ledgerSnapshot = snapshots[0];
        usageSnapshot = snapshots[1];
        if (ledgerSnapshot === undefined || usageSnapshot === undefined) {
          throw new Error('firestore_snapshot_count_mismatch');
        }
        const ledger = ledgerSnapshot.data() as PoolLedger | undefined;
        const usage = usageSnapshot.data() as UserUsage | undefined;
        if (ledger === undefined || usage === undefined)
          throw new BookingDomainRefusal('event_unavailable');
        nextLedger = releaseUnits(ledger, booking.participantUnits, now.toISOString());
      } else {
        usageSnapshot = await transaction.get(usageRef);
      }
      const usage = usageSnapshot.data() as UserUsage | undefined;
      if (usage === undefined) throw new BookingDomainRefusal('event_unavailable');
      const nextUsage = releaseBookingSlot(
        usage,
        actorId,
        booking.marketId,
        hasPool ? 'finite' : 'unlimited',
        booking.id,
        now.toISOString(),
      );

      const nextBooking: BookingRecord = {
        ...booking,
        revision: booking.revision + 1,
        state: 'cancelled',
        updatedAt: now.toISOString(),
        cancelledAt: now.toISOString(),
        terminalReason: 'userCancelled',
      };
      const outcome = succeeded<CancelBookingOutput>({ booking: nextBooking, replayed: false });
      const idempotency: LogicalIdempotencyRecord = {
        schemaVersion: 1,
        kind: 'logicalMutation',
        actorId,
        commandType: command.commandType,
        semanticHash,
        logicalMutationId: logicalId,
        requestAttemptId: attemptId,
        bookingId: booking.id,
        outcome,
        createdAt: now.toISOString(),
        retentionClass: 'bookingIdempotency',
        legalHold: false,
        expiresAt: idempotencyExpiresAt(now.toISOString()),
      };
      const audit: BookingAuditFact = {
        schemaVersion: 1,
        factType: 'booking_cancelled',
        bookingId: booking.id,
        actorId,
        eventId: booking.eventId,
        occurrenceId: booking.occurrenceId,
        bookingRevision: nextBooking.revision,
        occurredAt: now.toISOString(),
        retentionClass: 'bookingAudit',
        legalHold: false,
        expiresAt: auditExpiresAt(now.toISOString()),
      };
      const expiresAt = coreBookingExpiresAt(
        storedBooking?.occurrenceEndSnapshot,
        now.toISOString(),
        storedBooking?.legalHold ?? false,
      );
      transaction.set(bookingRef, {
        ...nextBooking,
        ...(storedBooking?.occurrenceEndSnapshot === undefined
          ? {}
          : { occurrenceEndSnapshot: storedBooking.occurrenceEndSnapshot }),
        retentionClass: 'bookingCore',
        legalHold: storedBooking?.legalHold ?? false,
        ...(expiresAt === undefined ? {} : { expiresAt }),
      });
      transaction.delete(activeRef);
      if (ledgerRef !== undefined && nextLedger !== undefined)
        transaction.set(ledgerRef, nextLedger);
      transaction.set(usageRef, nextUsage);
      transaction.create(logicalRef, idempotency);
      transaction.create(attemptRef, toRequestAttemptRecord(idempotency, attemptId));
      transaction.create(
        dependencies.firestore
          .collection(bookingCollections.audit)
          .doc(bookingAuditId(booking.id, nextBooking.revision)),
        audit,
      );
      transaction.create(
        dependencies.firestore
          .collection(bookingCollections.outbox)
          .doc(suppressedOutboxId(booking.id, nextBooking.revision)),
        createSuppressedOutbox('booking_cancellation', booking.id, actorId, now.toISOString()),
      );
      return outcome;
    });
  } catch (error) {
    if (error instanceof BookingRetryableFailure) return retryable(error.code);
    if (error instanceof BookingDomainRefusal) return rejected(error.code);
    return classifyFirestoreFailure(error, {
      correlationId: command.requestId,
      operationName: 'cancel_internal_booking',
      ...(dependencies.failureLogger === undefined ? {} : { logger: dependencies.failureLogger }),
    });
  }
}

function replayOutcome(record: LogicalIdempotencyRecord): BookingResult<CancelBookingOutput> {
  const outcome = record.outcome as BookingResult<CancelBookingOutput>;
  if (outcome.kind !== 'succeeded') return outcome;
  return succeeded({ ...outcome.data, replayed: true });
}

function assertIdempotency(
  attempt: IdempotencyRecord | undefined,
  logical: IdempotencyRecord | undefined,
  actorId: string,
  semanticHash: string,
  logicalId: string,
): void {
  if (
    attempt !== undefined &&
    (attempt.kind !== 'requestAttempt' ||
      attempt.actorId !== actorId ||
      attempt.commandType !== 'cancelBooking' ||
      attempt.semanticHash !== semanticHash ||
      attempt.logicalMutationId !== logicalId)
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
  if (
    logical !== undefined &&
    (logical.kind !== 'logicalMutation' ||
      logical.actorId !== actorId ||
      logical.commandType !== 'cancelBooking' ||
      logical.semanticHash !== semanticHash)
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
}
