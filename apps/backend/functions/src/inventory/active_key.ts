import { lengthPrefixedHash } from '../booking/idempotency.js';

export interface ActiveBookingKey {
  readonly schemaVersion: 1;
  readonly scopeVersion: 'booking_active_scope_v1';
  readonly actorId: string;
  readonly occurrenceId: string;
  readonly admissionTrackId: 'general';
  readonly bookingId: string;
  readonly bookingRevision: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export function activeBookingKeyId(actorId: string, occurrenceId: string): string {
  return lengthPrefixedHash('booking_active_scope_v1', actorId, occurrenceId, 'general');
}

export function activeKeyMatches(
  value: unknown,
  actorId: string,
  occurrenceId: string,
): value is ActiveBookingKey {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const record = value as Record<string, unknown>;
  return (
    record.schemaVersion === 1 &&
    record.scopeVersion === 'booking_active_scope_v1' &&
    record.actorId === actorId &&
    record.occurrenceId === occurrenceId &&
    record.admissionTrackId === 'general' &&
    typeof record.bookingId === 'string' &&
    record.bookingId.length > 0 &&
    Number.isSafeInteger(record.bookingRevision) &&
    Number(record.bookingRevision) >= 1
  );
}
