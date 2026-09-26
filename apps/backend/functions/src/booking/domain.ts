import { BookingDomainRefusal } from '../shared/failures.js';

export type Channel = 'onsite' | 'online' | 'any';
export type BookingState = 'confirmed' | 'cancelled';

export interface BookingEventProjection {
  readonly schemaVersion: 1;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly publisherRef: Readonly<{ type: 'user' | 'page'; id: string }>;
  readonly materialRevision: number;
  readonly publicationRevision?: number;
  readonly occurrenceStartsAt?: string;
  readonly occurrenceEndsAt?: string;
  readonly lifecycle: 'published';
  readonly bookingEnabled: true;
  readonly registrationMode: 'internal';
  readonly pricingMode: 'free';
  readonly paymentCollectionMode: 'none';
  readonly confirmationMode: 'instant';
  readonly inventoryAuthority: 'internal';
  readonly inventoryShape: 'general';
  readonly capacityMode: 'finite' | 'unlimited' | 'unknown';
  readonly totalCapacity?: number;
  readonly poolId?: string;
  readonly channel?: Channel;
  readonly registrationWindow: Readonly<{ opensAt?: string; closesAt?: string }>;
  readonly cancellationDeadline?: string;
  readonly guestPolicy: Readonly<{
    mode: 'selfOnly' | 'partyWithoutNames';
    maximumParticipantUnits: number;
  }>;
  readonly eligibilityMode: 'open';
}

export interface BookingRecord {
  readonly schemaVersion: 1;
  readonly id: string;
  readonly revision: number;
  readonly userId: string;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly inventoryPoolId?: string;
  readonly channel?: Channel;
  readonly admissionMode: 'booking';
  readonly confirmationMode: 'instant';
  readonly state: BookingState;
  readonly participantUnits: number;
  readonly cancellationDeadlineSnapshot?: string;
  readonly reconfirmationState: 'notRequired' | 'required';
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly confirmedAt: string;
  readonly cancelledAt?: string;
  readonly terminalReason?: 'userCancelled' | 'occurrenceCancelled';
}

export interface StoredBookingRecord extends BookingRecord {
  readonly occurrenceEndSnapshot?: string;
  readonly retentionClass: 'bookingCore';
  readonly legalHold: boolean;
  readonly expiresAt?: Date;
}

export function publicBookingRecord(record: StoredBookingRecord): BookingRecord {
  const booking = { ...record } as Record<string, unknown>;
  delete booking.occurrenceEndSnapshot;
  delete booking.retentionClass;
  delete booking.legalHold;
  delete booking.expiresAt;
  return booking as unknown as BookingRecord;
}

export function assertSupportedEvent(
  value: unknown,
  now: Date,
  occurrenceId: string,
  poolId: string | undefined,
  channel: Channel | undefined,
): BookingEventProjection {
  const event = assertBookingEventProjection(value, occurrenceId, poolId, channel);
  if (
    typeof event.registrationWindow.opensAt === 'string' &&
    now < parseInstant(event.registrationWindow.opensAt)
  ) {
    throw new BookingDomainRefusal('registration_not_open');
  }
  if (
    typeof event.registrationWindow.closesAt === 'string' &&
    now >= parseInstant(event.registrationWindow.closesAt)
  ) {
    throw new BookingDomainRefusal('registration_closed');
  }
  return event;
}

export function assertBookingEventProjection(
  value: unknown,
  occurrenceId: string,
  poolId: string | undefined,
  channel: Channel | undefined,
): BookingEventProjection {
  if (!isRecord(value)) throw new BookingDomainRefusal('event_unavailable');
  if (
    value.schemaVersion !== 1 ||
    value.occurrenceId !== occurrenceId ||
    value.lifecycle !== 'published' ||
    value.bookingEnabled !== true ||
    value.registrationMode !== 'internal' ||
    value.pricingMode !== 'free' ||
    value.paymentCollectionMode !== 'none' ||
    value.confirmationMode !== 'instant' ||
    value.inventoryAuthority !== 'internal' ||
    value.inventoryShape !== 'general' ||
    value.eligibilityMode !== 'open' ||
    !isPublisherRef(value.publisherRef) ||
    !isRecord(value.registrationWindow) ||
    !isGuestPolicy(value.guestPolicy)
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  if (!['finite', 'unlimited'].includes(String(value.capacityMode))) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  if (
    value.capacityMode === 'finite' &&
    (!Number.isSafeInteger(value.totalCapacity) || Number(value.totalCapacity) < 1)
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  if (value.poolId !== poolId || value.channel !== channel) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  assertOptionalInstant(value.registrationWindow.opensAt);
  assertOptionalInstant(value.registrationWindow.closesAt);
  assertOptionalInstant(value.cancellationDeadline);
  assertOptionalInstant(value.occurrenceStartsAt);
  assertOptionalInstant(value.occurrenceEndsAt);
  return value as unknown as BookingEventProjection;
}

export function assertGuestPolicy(
  event: BookingEventProjection,
  participantUnits: number,
  namedGuests: readonly Readonly<{ displayName: string }>[] | undefined,
): void {
  if ((namedGuests?.length ?? 0) > 0) throw new BookingDomainRefusal('unsupported_flow');
  if (participantUnits > event.guestPolicy.maximumParticipantUnits) {
    throw new BookingDomainRefusal('invalid_contract');
  }
  if (event.guestPolicy.mode === 'selfOnly' && participantUnits !== 1) {
    throw new BookingDomainRefusal('invalid_contract');
  }
}

export function eventProjectionId(occurrenceId: string): string {
  return occurrenceId;
}

function parseInstant(value: string): Date {
  const instant = new Date(value);
  if (!Number.isFinite(instant.getTime())) throw new BookingDomainRefusal('event_unavailable');
  return instant;
}

function assertOptionalInstant(value: unknown): void {
  if (value === undefined) return;
  if (typeof value !== 'string') throw new BookingDomainRefusal('event_unavailable');
  parseInstant(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isPublisherRef(value: unknown): boolean {
  return (
    isRecord(value) &&
    (value.type === 'user' || value.type === 'page') &&
    typeof value.id === 'string' &&
    value.id.length > 0
  );
}

function isGuestPolicy(value: unknown): boolean {
  return (
    isRecord(value) &&
    (value.mode === 'selfOnly' || value.mode === 'partyWithoutNames') &&
    Number.isSafeInteger(value.maximumParticipantUnits) &&
    Number(value.maximumParticipantUnits) >= 1 &&
    Number(value.maximumParticipantUnits) <= 21
  );
}
