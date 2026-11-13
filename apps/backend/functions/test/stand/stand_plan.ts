/**
 * Deterministic A2 seed plan for the managed local Emulator stand.
 *
 * Only synthetic values live here. Every identifier is fixed so a repeated
 * seed produces the same logical state; server-generated identifiers
 * (Account, Session and Booking ids) are labelled in the digest instead.
 */
export const standProject = 'demo-recharge';
export const standEmulatorPassword = 'emulator-only-password-123';

export const standUsers = Object.freeze([
  Object.freeze({
    label: 'creator',
    firebaseUid: 'stand-user-creator',
    installationId: 'stand-installation-creator',
  }),
  Object.freeze({
    label: 'viewer',
    firebaseUid: 'stand-user-viewer',
    installationId: 'stand-installation-viewer',
  }),
  Object.freeze({
    label: 'staff',
    firebaseUid: 'stand-user-staff',
    installationId: 'stand-installation-staff',
  }),
] as const);

export type StandUserLabel = (typeof standUsers)[number]['label'];

export const standPages = Object.freeze([
  Object.freeze({
    label: 'studio',
    pageId: '5d1e0000-0000-4000-8000-00000000a001',
    membershipId: '5d1e0000-0000-4000-8000-00000000b001',
  }),
  Object.freeze({
    label: 'gallery',
    pageId: '5d1e0000-0000-4000-8000-00000000a002',
    membershipId: '5d1e0000-0000-4000-8000-00000000b002',
  }),
] as const);

export const standCreatorVerification = Object.freeze({
  verificationId: '5d1e0000-0000-4000-8000-00000000c001',
  evidenceRefIds: Object.freeze(['5d1e0000-0000-4000-8000-00000000d001']),
});

export const standMarketId = 'LV';
export const standMaximumOwnedPages = 2;

/**
 * Booking-test fixture only: an explicit synthetic Event-outbox Event that the
 * Booking checks book against. It is not evidence of Content publication: the
 * stand's Event is created through the Content path (`stand_content_event.ts`),
 * and Content publication never makes an Event bookable by itself.
 */
export const standEvent = Object.freeze({
  outboxId: 'stand-event-outbox-riga-open-air-1',
  eventId: 'evt_01JSTANDEVENTRIGAOPEN001',
  occurrenceId: 'occ_01JSTANDOCCURRENCE000001',
  materialRevision: 1,
  publishedAt: '2026-10-01T00:00:00.000Z',
  occurrenceStartsAt: '2035-06-01T16:00:00.000Z',
  occurrenceEndsAt: '2035-06-01T19:00:00.000Z',
  registrationOpensAt: '2026-01-01T00:00:00.000Z',
  registrationClosesAt: '2035-05-31T00:00:00.000Z',
  cancellationDeadline: '2035-05-30T00:00:00.000Z',
  poolId: 'pool_general',
  channel: 'onsite',
  totalCapacity: 10,
  publisherPageLabel: 'studio',
} as const);

export const standBookings = Object.freeze([
  Object.freeze({
    label: 'viewer-two-seats',
    user: 'viewer',
    participantUnits: 2,
    requestId: 'stand-booking-viewer-request',
    idempotencyKey: 'stand-booking-viewer-idempotency',
    cancelAfterCreate: false,
  }),
  Object.freeze({
    label: 'creator-one-seat',
    user: 'creator',
    participantUnits: 1,
    requestId: 'stand-booking-creator-request',
    idempotencyKey: 'stand-booking-creator-idempotency',
    cancelAfterCreate: false,
  }),
  Object.freeze({
    label: 'staff-cancelled',
    user: 'staff',
    participantUnits: 1,
    requestId: 'stand-booking-staff-request',
    idempotencyKey: 'stand-booking-staff-idempotency',
    cancelAfterCreate: true,
  }),
] as const);

/** Flags the stand needs. Reconfirmation and its worker stay disabled. */
export const standEnabledBookingFlags = Object.freeze([
  'booking.create',
  'booking.cancel',
  'booking.read',
  'booking.eventProjection.delivery',
] as const);
