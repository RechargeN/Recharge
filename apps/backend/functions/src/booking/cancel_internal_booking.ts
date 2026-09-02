import type { Firestore } from 'firebase-admin/firestore';
import type { CancelBookingCommand } from '../contracts/booking_v1.js';
import { computeBookingSemanticHash } from '../contracts/booking_v1.js';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import { activeBookingKeyId, activeKeyMatches } from '../inventory/active_key.js';
import { releaseUnits, type PoolLedger } from '../inventory/ledger.js';
import { createSuppressedOutbox, suppressedOutboxId } from '../notifications/outbox.js';
import { releaseFiniteSlot, type UserUsage } from '../policy/concurrency.js';
import {
  BookingDomainRefusal,
  rejected,
  retryable,
  succeeded,
  type BookingResult,
} from '../shared/failures.js';
import type { ServerClock } from '../shared/server_clock.js';
import { assertSupportedEvent, type BookingRecord } from './domain.js';
import {
  logicalMutationId,
  requestAttemptId,
  toRequestAttemptRecord,
  type IdempotencyRecord,
  type LogicalIdempotencyRecord,
} from './idempotency.js';
import { bookingCollections, finitePoolLedgerId, runBookingTransaction } from './transactions.js';

export interface CancelBookingDependencies {
  readonly firestore: Firestore;
  readonly clock: ServerClock;
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
          throw new BookingDomainRefusal('temporarily_unavailable');
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
      const booking = bookingSnapshot.data() as BookingRecord | undefined;
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
        };
        transaction.create(logicalRef, idempotency);
        transaction.create(attemptRef, toRequestAttemptRecord(idempotency, attemptId));
        return outcome;
      }
      if (booking.revision !== command.expectedBookingRevision || booking.state !== 'confirmed') {
        throw new BookingDomainRefusal('revision_conflict');
      }

      const eventRef = dependencies.firestore
        .collection(bookingCollections.eventProjections)
        .doc(booking.occurrenceId);
      const activeRef = dependencies.firestore
        .collection(bookingCollections.activeKeys)
        .doc(activeBookingKeyId(actorId, booking.occurrenceId));
      const [eventSnapshot, activeSnapshot] = await transaction.getAll(eventRef, activeRef);
      if (eventSnapshot === undefined || activeSnapshot === undefined) {
        throw new Error('firestore_snapshot_count_mismatch');
      }
      const now = dependencies.clock.now();
      const event = assertSupportedEvent(
        eventSnapshot.data(),
        now,
        booking.occurrenceId,
        booking.inventoryPoolId,
        booking.channel,
      );
      if (typeof event.cancellationDeadline === 'string') {
        const cancellationDeadline = new Date(event.cancellationDeadline);
        if (!Number.isFinite(cancellationDeadline.getTime())) {
          throw new BookingDomainRefusal('event_unavailable');
        }
        if (now >= cancellationDeadline) {
          throw new BookingDomainRefusal('cancellation_deadline_passed');
        }
      }
      if (
        !activeKeyMatches(activeSnapshot.data(), actorId, booking.occurrenceId) ||
        activeSnapshot.data()?.bookingId !== booking.id
      ) {
        throw new BookingDomainRefusal('event_unavailable');
      }

      let ledgerRef;
      let nextLedger: PoolLedger | undefined;
      let usageRef;
      let nextUsage: UserUsage | undefined;
      if (event.capacityMode === 'finite') {
        if (booking.inventoryPoolId === undefined || booking.channel === undefined)
          throw new BookingDomainRefusal('event_unavailable');
        ledgerRef = dependencies.firestore
          .collection(bookingCollections.poolLedgers)
          .doc(finitePoolLedgerId(booking.occurrenceId, booking.inventoryPoolId, booking.channel));
        usageRef = dependencies.firestore.collection(bookingCollections.userUsage).doc(actorId);
        const [ledgerSnapshot, usageSnapshot] = await transaction.getAll(ledgerRef, usageRef);
        if (ledgerSnapshot === undefined || usageSnapshot === undefined) {
          throw new Error('firestore_snapshot_count_mismatch');
        }
        const ledger = ledgerSnapshot.data() as PoolLedger | undefined;
        const usage = usageSnapshot.data() as UserUsage | undefined;
        if (ledger === undefined || usage === undefined)
          throw new BookingDomainRefusal('event_unavailable');
        nextLedger = releaseUnits(ledger, booking.participantUnits, now.toISOString());
        nextUsage = releaseFiniteSlot(usage, actorId, now.toISOString());
      }

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
      };
      transaction.set(bookingRef, nextBooking);
      transaction.delete(activeRef);
      if (ledgerRef !== undefined && nextLedger !== undefined)
        transaction.set(ledgerRef, nextLedger);
      if (usageRef !== undefined && nextUsage !== undefined) transaction.set(usageRef, nextUsage);
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
    if (error instanceof BookingDomainRefusal) return rejected(error.code);
    return retryable('contention');
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
