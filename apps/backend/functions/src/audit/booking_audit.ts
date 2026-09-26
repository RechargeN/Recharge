export interface BookingAuditFact {
  readonly schemaVersion: 1;
  readonly factType: 'booking_created' | 'booking_cancelled' | 'booking_reconfirmation_required';
  readonly bookingId: string;
  readonly actorId: string;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly bookingRevision: number;
  readonly occurredAt: string;
  readonly retentionClass: 'bookingAudit';
  readonly legalHold: false;
  readonly expiresAt: Date;
}

export function bookingAuditId(bookingId: string, revision: number): string {
  return `${bookingId}__r${revision}`;
}
