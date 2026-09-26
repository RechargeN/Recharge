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
