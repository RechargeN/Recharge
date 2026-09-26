import type { Firestore } from 'firebase-admin/firestore';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import { activeBookingKeyId } from '../inventory/active_key.js';
import { releaseUnits, type PoolLedger } from '../inventory/ledger.js';
import { createSuppressedOutbox, suppressedOutboxId } from '../notifications/outbox.js';
import { releaseFiniteSlot, type UserUsage } from '../policy/concurrency.js';
import { auditExpiresAt, coreBookingExpiresAt } from './retention.js';
import type { StoredBookingRecord } from './domain.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
  runBookingTransaction,
} from './transactions.js';
import type { EventBookingProjectionEvent } from './event_projection_consumer.js';

interface OccurrenceLifecycleEvent {
  readonly kind: 'EventOccurrenceCancelled' | 'EventMateriallyRescheduled';
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly materialRevision: number;
  readonly publicationRevision: number;
  readonly occurredAt: string;
}

export async function applyOccurrenceLifecycleEffects(
  firestore: Firestore,
  event: EventBookingProjectionEvent,
): Promise<Readonly<{ affected: number }>> {
  if (event.kind !== 'EventOccurrenceCancelled' && event.kind !== 'EventMateriallyRescheduled') {
    return { affected: 0 };
  }
  const lifecycleEvent: OccurrenceLifecycleEvent = {
    kind: event.kind,
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    materialRevision: event.materialRevision,
    publicationRevision: event.publicationRevision,
    occurredAt: event.occurredAt,
  };
  const snapshot = await firestore
    .collection(bookingCollections.bookings)
    .where('occurrenceId', '==', event.occurrenceId)
    .get();
  let affected = 0;
  for (const document of snapshot.docs.sort((left, right) => left.id.localeCompare(right.id))) {
    const changed = await applyOne(firestore, document.id, lifecycleEvent);
    if (changed) affected += 1;
  }
  return { affected };
}

async function applyOne(
  firestore: Firestore,
  bookingId: string,
  event: OccurrenceLifecycleEvent,
): Promise<boolean> {
  return runBookingTransaction(firestore, async (transaction) => {
    const bookingRef = firestore.collection(bookingCollections.bookings).doc(bookingId);
    const bookingSnapshot = await transaction.get(bookingRef);
    const booking = bookingSnapshot.data() as StoredBookingRecord | undefined;
    if (
      booking === undefined ||
      booking.occurrenceId !== event.occurrenceId ||
      booking.state !== 'confirmed'
    ) {
      return false;
    }
    if (event.kind === 'EventMateriallyRescheduled' && booking.reconfirmationState === 'required') {
      return false;
    }

    const activeRef = firestore
      .collection(bookingCollections.activeKeys)
      .doc(activeBookingKeyId(booking.userId, booking.occurrenceId));
    let ledgerRef;
    let usageRef;
    let nextLedger: PoolLedger | undefined;
    let nextUsage: UserUsage | undefined;
    if (
      event.kind === 'EventOccurrenceCancelled' &&
      booking.inventoryPoolId !== undefined &&
      booking.channel !== undefined
    ) {
      ledgerRef = firestore
        .collection(bookingCollections.poolLedgers)
        .doc(finitePoolLedgerId(booking.occurrenceId, booking.inventoryPoolId, booking.channel));
      usageRef = firestore
        .collection(bookingCollections.userUsage)
        .doc(bookingUserUsageId(booking.userId));
      const [ledgerSnapshot, usageSnapshot] = await transaction.getAll(ledgerRef, usageRef);
      const ledger = ledgerSnapshot?.data() as PoolLedger | undefined;
      const usage = usageSnapshot?.data() as UserUsage | undefined;
      if (ledger === undefined || usage === undefined)
        throw new Error('booking_inventory_inconsistent');
      nextLedger = releaseUnits(ledger, booking.participantUnits, event.occurredAt);
      nextUsage = releaseFiniteSlot(usage, booking.userId, event.occurredAt);
    }

    const revision = booking.revision + 1;
    const next =
      event.kind === 'EventOccurrenceCancelled'
        ? {
            ...booking,
            revision,
            state: 'cancelled',
            updatedAt: event.occurredAt,
            cancelledAt: event.occurredAt,
            terminalReason: 'occurrenceCancelled',
            ...(coreBookingExpiresAt(
              booking.occurrenceEndSnapshot,
              event.occurredAt,
              booking.legalHold,
            ) === undefined
              ? {}
              : {
                  expiresAt: coreBookingExpiresAt(
                    booking.occurrenceEndSnapshot,
                    event.occurredAt,
                    booking.legalHold,
                  ),
                }),
          }
        : {
            ...booking,
            revision,
            updatedAt: event.occurredAt,
            reconfirmationState: 'required',
          };
    const audit: BookingAuditFact = {
      schemaVersion: 1,
      factType:
        event.kind === 'EventOccurrenceCancelled'
          ? 'booking_cancelled'
          : 'booking_reconfirmation_required',
      bookingId,
      actorId: booking.userId,
      eventId: booking.eventId,
      occurrenceId: booking.occurrenceId,
      bookingRevision: revision,
      occurredAt: event.occurredAt,
      retentionClass: 'bookingAudit',
      legalHold: false,
      expiresAt: auditExpiresAt(event.occurredAt),
    };
    transaction.set(bookingRef, next);
    if (event.kind === 'EventOccurrenceCancelled') transaction.delete(activeRef);
    if (ledgerRef !== undefined && nextLedger !== undefined) transaction.set(ledgerRef, nextLedger);
    if (usageRef !== undefined && nextUsage !== undefined) transaction.set(usageRef, nextUsage);
    transaction.create(
      firestore.collection(bookingCollections.audit).doc(bookingAuditId(bookingId, revision)),
      audit,
    );
    transaction.create(
      firestore.collection(bookingCollections.outbox).doc(suppressedOutboxId(bookingId, revision)),
      createSuppressedOutbox(
        event.kind === 'EventOccurrenceCancelled'
          ? 'booking_cancellation'
          : 'booking_reconfirmation',
        bookingId,
        booking.userId,
        event.occurredAt,
      ),
    );
    return true;
  });
}
