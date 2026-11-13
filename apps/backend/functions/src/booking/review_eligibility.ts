import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { bookingCollections } from './transactions.js';
/** Booking-owned eligibility, never attendance verification. Unsupported Activity fails closed. */
export async function reviewBookingEvidence(
  db: Firestore,
  tx: Transaction,
  userId: string,
  contentId: string,
  typeId: string,
  now: Date,
): Promise<{ bookingId: string; occurrenceId: string } | null> {
  if (typeId !== 'event') return null;
  const bookings = await tx.get(
    db
      .collection(bookingCollections.bookings)
      .where('userId', '==', userId)
      .where('eventId', '==', contentId)
      .limit(101),
  );
  if (bookings.size > 100) return null;
  for (const doc of bookings.docs) {
    const b = doc.data();
    if (b.state !== 'confirmed' || b.reconfirmationState === 'missed') continue;
    const p = await tx.get(
      db.collection(bookingCollections.eventProjections).doc(b.occurrenceId as string),
    );
    const source = p.data();
    const start =
      typeof source?.occurrenceStartsAt === 'string' ? Date.parse(source.occurrenceStartsAt) : NaN;
    if (
      source?.eventId === contentId &&
      source.lifecycle === 'published' &&
      source.marketId === 'LV' &&
      Number.isFinite(start) &&
      start <= now.getTime()
    )
      return { bookingId: doc.id, occurrenceId: b.occurrenceId as string };
  }
  return null;
}
