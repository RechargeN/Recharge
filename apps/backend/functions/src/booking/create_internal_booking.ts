import { randomBytes } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import type { CreateBookingCommand } from '../contracts/booking_v1.js';
import { computeBookingSemanticHash } from '../contracts/booking_v1.js';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import {
  activeBookingKeyId,
  activeKeyMatches,
  type ActiveBookingKey,
} from '../inventory/active_key.js';
import { allocateUnits, type PoolLedger } from '../inventory/ledger.js';
import { createSuppressedOutbox, suppressedOutboxId } from '../notifications/outbox.js';
import { acquireFiniteSlot, type UserUsage } from '../policy/concurrency.js';
import {
  BookingDomainRefusal,
  rejected,
  retryable,
  succeeded,
  unsupported,
  type BookingResult,
} from '../shared/failures.js';
import type { ServerClock } from '../shared/server_clock.js';
import {
  assertGuestPolicy,
  assertSupportedEvent,
  eventProjectionId,
  type BookingRecord,
} from './domain.js';
import {
  logicalMutationId,
  requestAttemptId,
  toRequestAttemptRecord,
  type IdempotencyRecord,
  type LogicalIdempotencyRecord,
} from './idempotency.js';
import { bookingCollections, finitePoolLedgerId, runBookingTransaction } from './transactions.js';

export interface CreateBookingDependencies {
  readonly firestore: Firestore;
  readonly clock: ServerClock;
  readonly newBookingId?: () => string;
}

export interface CreateBookingOutput {
  readonly booking: BookingRecord;
  readonly replayed: boolean;
}

export async function createInternalBooking(
  dependencies: CreateBookingDependencies,
  actorId: string,
  command: CreateBookingCommand,
): Promise<BookingResult<CreateBookingOutput>> {
  if (
    (command.payload.namedGuests?.length ?? 0) > 0 ||
    command.payload.auxiliaryTrackId !== undefined ||
    command.payload.applicationFields !== undefined
  ) {
    return unsupported('unsupported_flow');
  }
  const bookingId = (dependencies.newBookingId ?? generateUlid)();
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
      const eventRef = dependencies.firestore
        .collection(bookingCollections.eventProjections)
        .doc(eventProjectionId(command.payload.occurrenceId));
      const activeRef = dependencies.firestore
        .collection(bookingCollections.activeKeys)
        .doc(activeBookingKeyId(actorId, command.payload.occurrenceId));
      const [logicalSnapshot, attemptSnapshot, eventSnapshot, activeSnapshot] =
        await transaction.getAll(logicalRef, attemptRef, eventRef, activeRef);
      if (
        logicalSnapshot === undefined ||
        attemptSnapshot === undefined ||
        eventSnapshot === undefined ||
        activeSnapshot === undefined
      ) {
        throw new Error('firestore_snapshot_count_mismatch');
      }
      const logical = logicalSnapshot.data() as IdempotencyRecord | undefined;
      const attempt = attemptSnapshot.data() as IdempotencyRecord | undefined;
      assertAttemptCompatible(attempt, actorId, command.commandType, semanticHash, logicalId);
      if (attempt !== undefined) {
        if (logical === undefined) throw new BookingDomainRefusal('temporarily_unavailable');
        assertLogicalCompatible(logical, actorId, command.commandType, semanticHash);
        return replayOutcome(logical);
      }
      if (logical !== undefined) {
        assertLogicalCompatible(logical, actorId, command.commandType, semanticHash);
        const replay = replayOutcome(logical);
        transaction.create(attemptRef, toRequestAttemptRecord(logical, attemptId));
        return replay;
      }

      const now = dependencies.clock.now();
      const nowIso = now.toISOString();
      const event = assertSupportedEvent(
        eventSnapshot.data(),
        now,
        command.payload.occurrenceId,
        command.payload.inventoryPoolId,
        command.payload.channel,
      );
      if (
        command.occurredAgainstEventRevision !== undefined &&
        command.occurredAgainstEventRevision !== event.materialRevision
      ) {
        throw new BookingDomainRefusal('revision_conflict');
      }
      assertGuestPolicy(event, command.payload.participantUnits, command.payload.namedGuests);
      if (activeSnapshot.exists) {
        if (!activeKeyMatches(activeSnapshot.data(), actorId, event.occurrenceId)) {
          throw new BookingDomainRefusal('event_unavailable');
        }
        throw new BookingDomainRefusal('already_active');
      }

      let ledgerRef;
      let nextLedger: PoolLedger | undefined;
      let usageRef;
      let nextUsage: UserUsage | undefined;
      if (event.capacityMode === 'finite') {
        const poolId = event.poolId;
        const channel = event.channel;
        if (poolId === undefined || channel === undefined || event.totalCapacity === undefined) {
          throw new BookingDomainRefusal('event_unavailable');
        }
        ledgerRef = dependencies.firestore
          .collection(bookingCollections.poolLedgers)
          .doc(finitePoolLedgerId(event.occurrenceId, poolId, channel));
        usageRef = dependencies.firestore.collection(bookingCollections.userUsage).doc(actorId);
        const [ledgerSnapshot, usageSnapshot] = await transaction.getAll(ledgerRef, usageRef);
        if (ledgerSnapshot === undefined || usageSnapshot === undefined) {
          throw new Error('firestore_snapshot_count_mismatch');
        }
        nextLedger = allocateUnits(
          ledgerSnapshot.data() as PoolLedger | undefined,
          {
            eventId: event.eventId,
            occurrenceId: event.occurrenceId,
            poolId,
            channel,
            totalCapacity: event.totalCapacity,
          },
          command.payload.participantUnits,
          nowIso,
        );
        nextUsage = acquireFiniteSlot(
          usageSnapshot.data() as UserUsage | undefined,
          actorId,
          nowIso,
        );
      }

      const booking: BookingRecord = {
        schemaVersion: 1,
        id: bookingId,
        revision: 1,
        userId: actorId,
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        ...(event.poolId === undefined ? {} : { inventoryPoolId: event.poolId }),
        ...(event.channel === undefined ? {} : { channel: event.channel }),
        admissionMode: 'booking',
        confirmationMode: 'instant',
        state: 'confirmed',
        participantUnits: command.payload.participantUnits,
        reconfirmationState: 'notRequired',
        createdAt: nowIso,
        updatedAt: nowIso,
        confirmedAt: nowIso,
      };
      const outcome = succeeded<CreateBookingOutput>({ booking, replayed: false });
      const idempotency: LogicalIdempotencyRecord = {
        schemaVersion: 1,
        kind: 'logicalMutation',
        actorId,
        commandType: command.commandType,
        semanticHash,
        logicalMutationId: logicalId,
        requestAttemptId: attemptId,
        bookingId,
        outcome,
        createdAt: nowIso,
      };
      const activeKey: ActiveBookingKey = {
        schemaVersion: 1,
        scopeVersion: 'booking_active_scope_v1',
        actorId,
        occurrenceId: event.occurrenceId,
        admissionTrackId: 'general',
        bookingId,
        bookingRevision: 1,
        createdAt: nowIso,
        updatedAt: nowIso,
      };
      const audit: BookingAuditFact = {
        schemaVersion: 1,
        factType: 'booking_created',
        bookingId,
        actorId,
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        bookingRevision: 1,
        occurredAt: nowIso,
      };
      transaction.create(
        dependencies.firestore.collection(bookingCollections.bookings).doc(bookingId),
        booking,
      );
      transaction.create(activeRef, activeKey);
      if (ledgerRef !== undefined && nextLedger !== undefined)
        transaction.set(ledgerRef, nextLedger);
      if (usageRef !== undefined && nextUsage !== undefined) transaction.set(usageRef, nextUsage);
      transaction.create(logicalRef, idempotency);
      transaction.create(attemptRef, toRequestAttemptRecord(idempotency, attemptId));
      transaction.create(
        dependencies.firestore
          .collection(bookingCollections.audit)
          .doc(bookingAuditId(bookingId, 1)),
        audit,
      );
      transaction.create(
        dependencies.firestore
          .collection(bookingCollections.outbox)
          .doc(suppressedOutboxId(bookingId, 1)),
        createSuppressedOutbox('booking_confirmation', bookingId, actorId, nowIso),
      );
      return outcome;
    });
  } catch (error) {
    if (error instanceof BookingDomainRefusal) return rejected(error.code);
    return retryable('contention');
  }
}

function replayOutcome(record: LogicalIdempotencyRecord): BookingResult<CreateBookingOutput> {
  const outcome = record.outcome as BookingResult<CreateBookingOutput>;
  if (outcome.kind !== 'succeeded') return outcome;
  return succeeded({ ...outcome.data, replayed: true });
}

function assertAttemptCompatible(
  record: IdempotencyRecord | undefined,
  actorId: string,
  commandType: IdempotencyRecord['commandType'],
  semanticHash: string,
  logicalId: string,
): void {
  if (
    record !== undefined &&
    (record.kind !== 'requestAttempt' ||
      record.actorId !== actorId ||
      record.commandType !== commandType ||
      record.semanticHash !== semanticHash ||
      record.logicalMutationId !== logicalId)
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
}

function assertLogicalCompatible(
  record: IdempotencyRecord,
  actorId: string,
  commandType: IdempotencyRecord['commandType'],
  semanticHash: string,
): asserts record is LogicalIdempotencyRecord {
  if (
    record.kind !== 'logicalMutation' ||
    record.actorId !== actorId ||
    record.commandType !== commandType ||
    record.semanticHash !== semanticHash
  ) {
    throw new BookingDomainRefusal('idempotency_conflict');
  }
}

function generateUlid(now = Date.now()): string {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  let time = now;
  let encodedTime = '';
  for (let index = 0; index < 10; index += 1) {
    encodedTime = alphabet[time % 32] + encodedTime;
    time = Math.floor(time / 32);
  }
  let encodedRandom = '';
  for (const byte of randomBytes(16)) encodedRandom += alphabet[byte & 31];
  return encodedTime + encodedRandom.slice(0, 16);
}
