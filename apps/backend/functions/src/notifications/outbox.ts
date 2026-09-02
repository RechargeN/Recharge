export interface SuppressedBookingOutboxRecord {
  readonly schemaVersion: 1;
  readonly effectDisposition: 'suppressedPreActivation';
  readonly policyRevision: 1;
  readonly dispatchable: false;
  readonly replayable: false;
  readonly obligationType: 'booking_confirmation' | 'booking_cancellation';
  readonly bookingId: string;
  readonly actorId: string;
  readonly createdAt: string;
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
  };
}
