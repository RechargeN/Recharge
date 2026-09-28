import type { Firestore } from 'firebase-admin/firestore';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import type { ReconfirmBookingCommand } from '../contracts/booking_v1.js';
import { computeBookingSemanticHash } from '../contracts/booking_v1.js';
import { createSuppressedOutbox, suppressedOutboxId } from '../notifications/outbox.js';
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
import { auditExpiresAt, idempotencyExpiresAt } from './retention.js';
import { bookingCollections, runBookingTransaction } from './transactions.js';
import {
  assertBookingMutationAuthorized,
  type BookingMutationAuthorization,
} from './mutation_authorizer.js';

export interface ReconfirmBookingDependencies {
  readonly firestore: Firestore;
  readonly clock: ServerClock;
  readonly failureLogger?: FirestoreFailureLogger;
  readonly mutationAuthorization?: BookingMutationAuthorization;
}

export interface ReconfirmBookingOutput {
  readonly booking: BookingRecord;
  readonly outcome: 'reconfirmed';
  readonly replayed: boolean;
}

export async function reconfirmInternalBooking(
  dependencies: ReconfirmBookingDependencies,
  actorId: string,
  command: ReconfirmBookingCommand,
): Promise<BookingResult<ReconfirmBookingOutput>> {
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
      const bookingSnapshot = await transaction.get(bookingRef);
      const storedBooking = bookingSnapshot.data() as StoredBookingRecord | undefined;
      const eventRef = dependencies.firestore
        .collection(bookingCollections.eventProjections)
        .doc(storedBooking?.occurrenceId ?? 'missing');
      const [logicalSnapshot, attemptSnapshot, eventSnapshot] = await transaction.getAll(
        logicalRef,
        attemptRef,
        eventRef,
      );
      if (
        logicalSnapshot === undefined ||
        attemptSnapshot === undefined ||
        eventSnapshot === undefined
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

      const booking = storedBooking === undefined ? undefined : publicBookingRecord(storedBooking);
      if (booking === undefined || booking.userId !== actorId) {
        throw new BookingDomainRefusal('permission_denied');
      }
      if (booking.revision !== command.expectedBookingRevision || booking.state !== 'confirmed') {
        throw new BookingDomainRefusal('revision_conflict');
      }
      if (booking.reconfirmationState !== 'required') {
        throw new BookingDomainRefusal('reconfirmation_not_required');
      }
      if (
        booking.reconfirmationRequiredForRevision === undefined ||
        booking.reconfirmationDeadlineUtc === undefined
      ) {
        throw new Error('booking_reconfirmation_authority_inconsistent');
      }
      if (booking.reconfirmationRequiredForRevision !== command.payload.materialRevision) {
        throw new BookingDomainRefusal('material_revision_mismatch');
      }
      const event = eventSnapshot.data();
      if (
        event === undefined ||
        event.occurrenceId !== booking.occurrenceId ||
        event.eventId !== booking.eventId ||
        event.lifecycle !== 'published'
      ) {
        throw new BookingDomainRefusal('event_unavailable');
      }
      if (event.materialRevision !== command.payload.materialRevision) {
        throw new BookingDomainRefusal('material_revision_mismatch');
      }
      const deadline = new Date(booking.reconfirmationDeadlineUtc);
      if (!Number.isFinite(deadline.getTime())) {
        throw new Error('booking_reconfirmation_deadline_invalid');
      }
      const now = dependencies.clock.now();
      if (now >= deadline) {
        throw new BookingDomainRefusal('reconfirmation_deadline_passed');
      }
      const nowIso = now.toISOString();
      const nextBooking: BookingRecord = {
        ...booking,
        revision: booking.revision + 1,
        reconfirmationState: 'confirmed',
        updatedAt: nowIso,
      };
      const outcome = succeeded<ReconfirmBookingOutput>({
        booking: nextBooking,
        outcome: 'reconfirmed',
        replayed: false,
      });
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
      const audit: BookingAuditFact = {
        schemaVersion: 1,
        factType: 'booking_reconfirmed',
        bookingId: booking.id,
        actorId,
        eventId: booking.eventId,
        occurrenceId: booking.occurrenceId,
        bookingRevision: nextBooking.revision,
        occurredAt: nowIso,
        retentionClass: 'bookingAudit',
        legalHold: false,
        expiresAt: auditExpiresAt(nowIso),
      };
      transaction.set(bookingRef, {
        ...nextBooking,
        ...(storedBooking?.occurrenceEndSnapshot === undefined
          ? {}
          : { occurrenceEndSnapshot: storedBooking.occurrenceEndSnapshot }),
        retentionClass: 'bookingCore',
        legalHold: storedBooking?.legalHold ?? false,
        ...(storedBooking?.expiresAt === undefined ? {} : { expiresAt: storedBooking.expiresAt }),
      });
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
        createSuppressedOutbox('booking_reconfirmation', booking.id, actorId, nowIso),
      );
      return outcome;
    });
  } catch (error) {
    if (error instanceof BookingRetryableFailure) return retryable(error.code);
    if (error instanceof BookingDomainRefusal) return rejected(error.code);
    return classifyFirestoreFailure(error, {
      correlationId: command.requestId,
      operationName: 'reconfirm_internal_booking',
      ...(dependencies.failureLogger === undefined ? {} : { logger: dependencies.failureLogger }),
    });
  }
}

function replayOutcome(record: LogicalIdempotencyRecord): BookingResult<ReconfirmBookingOutput> {
  const outcome = record.outcome as BookingResult<ReconfirmBookingOutput>;
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
      attempt.commandType !== 'reconfirmBooking' ||
      attempt.semanticHash !== semanticHash ||
      attempt.logicalMutationId !== logicalId)
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
  if (
    logical !== undefined &&
    (logical.kind !== 'logicalMutation' ||
      logical.actorId !== actorId ||
      logical.commandType !== 'reconfirmBooking' ||
      logical.semanticHash !== semanticHash)
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
}
