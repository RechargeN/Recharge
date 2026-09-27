import type { BookingAuditFact } from '../audit/booking_audit.js';
import type { SuppressedBookingOutboxRecord } from '../notifications/outbox.js';
import type { BookingRecord } from './domain.js';
import type { IdempotencyRecord } from './idempotency.js';

/**
 * Persistence-facing Booking shape used by privacy processing. Older local
 * Emulator fixtures may predate the hold field, so its absence is treated as
 * `false`; authoritative writers always persist the field explicitly.
 */
export type PrivacyBookingRecord = BookingRecord & {
  readonly occurrenceEndSnapshot?: string;
  readonly legalHold?: boolean;
};

export type BookingIdentityBearingRecord =
  PrivacyBookingRecord | IdempotencyRecord | BookingAuditFact | SuppressedBookingOutboxRecord;

const pseudonymousActorIdPattern = /^anon_[0-9a-f]{64}$/u;

/**
 * Removes the direct account identifier while preserving the minimum record
 * needed for integrity, reconciliation and the record's existing retention
 * deadline. The privacy orchestrator supplies a scoped pseudonym; this module
 * never derives one from a raw account ID or embeds a secret.
 */
export function pseudonymizeBookingIdentity<T extends BookingIdentityBearingRecord>(
  record: T,
  pseudonymousActorId: string,
): T {
  if (!pseudonymousActorIdPattern.test(pseudonymousActorId)) {
    throw new TypeError('booking_pseudonymous_actor_id_invalid');
  }
  if ('userId' in record) return { ...record, userId: pseudonymousActorId };
  return { ...record, actorId: pseudonymousActorId };
}

export interface BookingLegalHoldPatch {
  readonly legalHold: boolean;
  readonly deletionPending: boolean;
  /** `true` means the persistence adapter must delete the TTL field. */
  readonly removeExpiresAt: boolean;
  readonly expiresAt?: Date;
}

export function applyBookingLegalHold(): BookingLegalHoldPatch {
  return { legalHold: true, deletionPending: false, removeExpiresAt: true };
}

export function releaseBookingLegalHold(): BookingLegalHoldPatch {
  return { legalHold: false, deletionPending: true, removeExpiresAt: true };
}

export function completeBookingLegalHoldRelease(expiresAt: Date): BookingLegalHoldPatch {
  if (!Number.isFinite(expiresAt.getTime())) throw new TypeError('booking_expires_at_invalid');
  return { legalHold: false, deletionPending: false, removeExpiresAt: false, expiresAt };
}
