import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import { bookingAuditId, type BookingAuditFact } from '../audit/booking_audit.js';
import { activeBookingKeyId } from '../inventory/active_key.js';
import { releaseUnits, type PoolLedger } from '../inventory/ledger.js';
import { suppressedOutboxId } from '../notifications/outbox.js';
import { releaseBookingSlot, type UserUsage } from '../policy/concurrency.js';
import { auditExpiresAt, coreBookingExpiresAt } from './retention.js';
import {
  bookingNotificationEffectsEnabled,
  bookingOutboxRecord,
  systemCorrelationId,
  type BookingNotificationEffect,
} from './notification_effects.js';
import type { StoredBookingRecord } from './domain.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
  runBookingTransaction,
} from './transactions.js';
import type { EventBookingProjectionEvent } from './event_projection_consumer.js';

interface OccurrenceLifecycleEvent {
  readonly kind:
    'EventOccurrenceCancelled' | 'EventMateriallyRescheduled' | 'PrivacyErasureCancellation';
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly materialRevision: number;
  readonly publicationRevision: number;
  readonly occurredAt: string;
  readonly reconfirmationDeadlineUtc?: string;
}

export async function cancelBookingForPrivacyErasure(
  firestore: Firestore,
  bookingId: string,
  occurredAt: string,
): Promise<boolean> {
  const snapshot = await firestore.collection(bookingCollections.bookings).doc(bookingId).get();
  const booking = snapshot.data() as StoredBookingRecord | undefined;
  if (booking === undefined || booking.state !== 'confirmed') return false;
  return applyOne(firestore, bookingId, {
    kind: 'PrivacyErasureCancellation',
    eventId: booking.eventId,
    occurrenceId: booking.occurrenceId,
    materialRevision: 1,
    publicationRevision: 1,
    occurredAt,
  });
}

export async function applyOccurrenceLifecycleEffects(
  firestore: Firestore,
  event: EventBookingProjectionEvent,
  options: Readonly<{
    startAfterBookingId?: string;
    pageSize?: number;
    afterPage?: (
      progress: Readonly<{
        cursor: string;
        affected: number;
        processed: number;
      }>,
    ) => Promise<void>;
  }> = {},
): Promise<Readonly<{ affected: number; processed: number; cursor?: string }>> {
  if (event.kind !== 'EventOccurrenceCancelled' && event.kind !== 'EventMateriallyRescheduled') {
    return { affected: 0, processed: 0 };
  }
  const lifecycleEvent: OccurrenceLifecycleEvent = {
    kind: event.kind,
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    materialRevision: event.materialRevision,
    publicationRevision: event.publicationRevision,
    occurredAt: event.occurredAt,
    ...(event.kind === 'EventMateriallyRescheduled'
      ? {
          reconfirmationDeadlineUtc: requireReconfirmationDeadline(
            event.projection.occurrenceStartsAt,
          ),
        }
      : {}),
  };
  const pageSize = options.pageSize ?? 200;
  if (!Number.isSafeInteger(pageSize) || pageSize < 1 || pageSize > 200) {
    throw new TypeError('occurrence_lifecycle_page_size_invalid');
  }
  let affected = 0;
  let processed = 0;
  let cursor = options.startAfterBookingId;
  while (true) {
    let query = firestore
      .collection(bookingCollections.bookings)
      .where('occurrenceId', '==', event.occurrenceId)
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (cursor !== undefined) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    for (const document of snapshot.docs) {
      const changed = await applyOne(firestore, document.id, lifecycleEvent);
      if (changed) affected += 1;
      processed += 1;
    }
    cursor = snapshot.docs.at(-1)!.id;
    await options.afterPage?.({ cursor, affected, processed });
    if (snapshot.size < pageSize) break;
  }
  return { affected, processed, ...(cursor === undefined ? {} : { cursor }) };
}

async function applyOne(
  firestore: Firestore,
  bookingId: string,
  event: OccurrenceLifecycleEvent,
): Promise<boolean> {
  const notificationEffects = await bookingNotificationEffectsEnabled(firestore);
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
    if (
      event.kind === 'EventMateriallyRescheduled' &&
      booking.reconfirmationRequiredForRevision !== undefined &&
      booking.reconfirmationRequiredForRevision >= event.materialRevision
    )
      return false;

    const activeRef = firestore
      .collection(bookingCollections.activeKeys)
      .doc(activeBookingKeyId(booking.userId, booking.occurrenceId));
    let ledgerRef;
    let usageRef;
    let nextLedger: PoolLedger | undefined;
    let nextUsage: UserUsage | undefined;
    if (event.kind !== 'EventMateriallyRescheduled') {
      usageRef = firestore
        .collection(bookingCollections.userUsage)
        .doc(bookingUserUsageId(booking.userId, booking.marketId));
      const finite = booking.inventoryPoolId !== undefined && booking.channel !== undefined;
      let usageSnapshot;
      if (finite) {
        ledgerRef = firestore
          .collection(bookingCollections.poolLedgers)
          .doc(finitePoolLedgerId(booking.occurrenceId, booking.inventoryPoolId, booking.channel));
        const snapshots = await transaction.getAll(ledgerRef, usageRef);
        const ledgerSnapshot = snapshots[0];
        usageSnapshot = snapshots[1];
        const ledger = ledgerSnapshot?.data() as PoolLedger | undefined;
        if (ledger === undefined) throw new Error('booking_inventory_inconsistent');
        nextLedger = releaseUnits(ledger, booking.participantUnits, event.occurredAt);
      } else {
        usageSnapshot = await transaction.get(usageRef);
      }
      const usage = usageSnapshot?.data() as UserUsage | undefined;
      if (usage === undefined) throw new Error('booking_inventory_inconsistent');
      nextUsage = releaseBookingSlot(
        usage,
        booking.userId,
        booking.marketId,
        finite ? 'finite' : 'unlimited',
        booking.id,
        event.occurredAt,
      );
    }

    const revision = booking.revision + 1;
    const next =
      event.kind !== 'EventMateriallyRescheduled'
        ? {
            ...booking,
            revision,
            state: 'cancelled',
            updatedAt: event.occurredAt,
            cancelledAt: event.occurredAt,
            terminalReason:
              event.kind === 'PrivacyErasureCancellation'
                ? 'privacyErasure'
                : 'occurrenceCancelled',
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
            reconfirmationRequiredForRevision: event.materialRevision,
            reconfirmationDeadlineUtc: event.reconfirmationDeadlineUtc!,
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
    if (event.kind !== 'EventMateriallyRescheduled') transaction.delete(activeRef);
    if (ledgerRef !== undefined && nextLedger !== undefined) transaction.set(ledgerRef, nextLedger);
    if (usageRef !== undefined && nextUsage !== undefined) transaction.set(usageRef, nextUsage);
    transaction.create(
      firestore.collection(bookingCollections.audit).doc(bookingAuditId(bookingId, revision)),
      audit,
    );
    transaction.create(
      firestore.collection(bookingCollections.outbox).doc(suppressedOutboxId(bookingId, revision)),
      bookingOutboxRecord(notificationEffects, {
        effect: lifecycleNotificationEffect(event),
        booking,
        actorId: booking.userId,
        revision,
        occurredAt: event.occurredAt,
        correlationId:
          event.kind === 'PrivacyErasureCancellation'
            ? systemCorrelationId('prv', [bookingId, event.occurredAt])
            : systemCorrelationId('occ', [
                event.kind,
                event.eventId,
                event.occurrenceId,
                String(event.publicationRevision),
                String(event.materialRevision),
              ]),
      }),
    );
    return true;
  });
}

function lifecycleNotificationEffect(event: OccurrenceLifecycleEvent): BookingNotificationEffect {
  if (event.kind === 'EventMateriallyRescheduled')
    return {
      kind: 'reconfirmationRequired',
      reconfirmationDeadlineUtc: requireReconfirmationDeadline(event.reconfirmationDeadlineUtc),
    };
  return {
    kind: 'cancelled',
    cause: event.kind === 'PrivacyErasureCancellation' ? 'privacyErasure' : 'occurrenceCancelled',
  };
}

function requireReconfirmationDeadline(value: string | undefined): string {
  if (value === undefined || !value.endsWith('Z') || !Number.isFinite(Date.parse(value))) {
    throw new TypeError('reconfirmation_deadline_unavailable');
  }
  return value;
}
