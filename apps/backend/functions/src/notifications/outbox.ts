import { suppressedOutboxExpiresAt } from '../booking/retention.js';

export interface SuppressedBookingOutboxRecord {
  readonly schemaVersion: 1;
  readonly effectDisposition: 'suppressedPreActivation';
  readonly policyRevision: 1;
  readonly dispatchable: false;
  readonly replayable: false;
  readonly obligationType:
    'booking_confirmation' | 'booking_cancellation' | 'booking_reconfirmation';
  readonly bookingId: string;
  readonly actorId: string;
  readonly createdAt: string;
  readonly suppressedAt: string;
  readonly retentionClass: 'bookingOutbox';
  readonly legalHold: false;
  readonly expiresAt: Date;
}

export type BookingNotificationEventType =
  | 'booking.confirmed'
  | 'booking.cancelled'
  | 'booking.reconfirmationRequired'
  | 'booking.reconfirmed';

export type BookingCancellationCause =
  'userCancelled' | 'occurrenceCancelled' | 'missedReconfirmation' | 'privacyErasure';

/**
 * F1: the Booking-owned notification obligation in the accepted OD-09 envelope
 * (BCK-03). Written atomically with the Booking transition, only while the
 * local `booking.notification.effects` flag is on; otherwise the v1 record above
 * is written unchanged. The recipient is the Booking subject in `actorId`, the
 * identity field Booking erasure already pseudonymizes; the payload carries no
 * person identifier. The document id is the OD-09 `eventId`.
 */
export interface BookingNotificationEffectRecord {
  readonly schemaVersion: 2;
  readonly effectDisposition: 'pending';
  readonly dispatchable: true;
  readonly replayable: true;
  readonly eventId: string;
  readonly eventType: BookingNotificationEventType;
  readonly eventVersion: 1;
  readonly producer: 'booking';
  readonly aggregateType: 'booking';
  readonly aggregateId: string;
  readonly aggregateRevision: number;
  readonly occurredAt: string;
  readonly correlationId: string;
  readonly marketId: 'LV' | 'EE' | 'LT';
  readonly dataClass: 'personal';
  readonly payload: Readonly<{
    schemaVersion: 1;
    eventContentId: string;
    occurrenceId: string;
    cause?: BookingCancellationCause;
    reconfirmationDeadlineUtc?: string;
    deliverUntilUtc: string;
  }>;
  readonly actorId: string;
  readonly createdAt: string;
  readonly retentionClass: 'bookingOutbox';
  readonly legalHold: false;
  readonly expiresAt: Date;
}

export type BookingOutboxRecord = SuppressedBookingOutboxRecord | BookingNotificationEffectRecord;

export function suppressedOutboxId(bookingId: string, revision: number): string {
  return `${bookingId}__r${revision}`;
}

export function createSuppressedOutbox(
  obligationType: SuppressedBookingOutboxRecord['obligationType'],
  bookingId: string,
  actorId: string,
  createdAt: string,
): SuppressedBookingOutboxRecord {
  const expiresAt = suppressedOutboxExpiresAt(createdAt, false);
  if (expiresAt === undefined) throw new TypeError('suppressed_outbox_expiry_missing');
  return {
    schemaVersion: 1,
    effectDisposition: 'suppressedPreActivation',
    policyRevision: 1,
    dispatchable: false,
    replayable: false,
    obligationType,
    bookingId,
    actorId,
    createdAt,
    suppressedAt: createdAt,
    retentionClass: 'bookingOutbox',
    legalHold: false,
    expiresAt,
  };
}
