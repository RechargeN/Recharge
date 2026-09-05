import type { BookingEventProjection } from '../../src/booking/domain.js';
import type { CreateBookingCommand } from '../../src/contracts/booking_v1.js';

export const fixedNow = new Date('2026-08-29T12:00:00.000Z');

export function finiteEvent(
  overrides: Partial<BookingEventProjection> = {},
): BookingEventProjection {
  return {
    schemaVersion: 1,
    eventId: 'evt_01JTESTEVENT0000000000000',
    occurrenceId: 'occ_01JTESTOCCURRENCE0000000',
    publisherRef: { type: 'page', id: 'page_01JTESTPUBLISHER00000000' },
    materialRevision: 7,
    lifecycle: 'published',
    bookingEnabled: true,
    registrationMode: 'internal',
    pricingMode: 'free',
    paymentCollectionMode: 'none',
    confirmationMode: 'instant',
    inventoryAuthority: 'internal',
    inventoryShape: 'general',
    capacityMode: 'finite',
    totalCapacity: 10,
    poolId: 'pool_general',
    channel: 'onsite',
    registrationWindow: {
      opensAt: '2026-08-01T00:00:00.000Z',
      closesAt: '2026-09-01T00:00:00.000Z',
    },
    cancellationDeadline: '2026-08-31T00:00:00.000Z',
    guestPolicy: { mode: 'partyWithoutNames', maximumParticipantUnits: 21 },
    eligibilityMode: 'open',
    ...overrides,
  };
}

export function unlimitedEvent(
  overrides: Partial<BookingEventProjection> = {},
): BookingEventProjection {
  const value = finiteEvent({ capacityMode: 'unlimited', ...overrides });
  const withoutFiniteInventory: Record<string, unknown> = { ...value };
  delete withoutFiniteInventory.totalCapacity;
  delete withoutFiniteInventory.poolId;
  delete withoutFiniteInventory.channel;
  return withoutFiniteInventory as unknown as BookingEventProjection;
}

export function createCommand(overrides: Partial<CreateBookingCommand> = {}): CreateBookingCommand {
  return {
    schemaVersion: 1,
    commandType: 'createBooking',
    requestId: 'req_01JTESTREQUEST00000000000',
    idempotencyKey: 'idem_01JTESTKEY000000000000',
    occurredAgainstEventRevision: 7,
    payload: {
      occurrenceId: 'occ_01JTESTOCCURRENCE0000000',
      inventoryPoolId: 'pool_general',
      channel: 'onsite',
      participantUnits: 1,
      namedGuests: [],
    },
    ...overrides,
  };
}
