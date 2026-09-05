export interface BookingAuditFact {
  readonly schemaVersion: 1;
  readonly factType: 'booking_created' | 'booking_cancelled';
  readonly bookingId: string;
  readonly actorId: string;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly bookingRevision: number;
  readonly occurredAt: string;
}

export function bookingAuditId(bookingId: string, revision: number): string {
  return `${bookingId}__r${revision}`;
}
