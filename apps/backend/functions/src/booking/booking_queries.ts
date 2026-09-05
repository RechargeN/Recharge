import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import type { GetMyBookingQuery, ListMyBookingsQuery } from '../contracts/booking_v1.js';
import { rejected, retryable, succeeded, type BookingResult } from '../shared/failures.js';
import type { BookingRecord } from './domain.js';
import { bookingCollections } from './transactions.js';

export async function getMyBooking(
  firestore: Firestore,
  actorId: string,
  query: GetMyBookingQuery,
): Promise<BookingResult<Readonly<{ booking: BookingRecord }>>> {
  try {
    const snapshot = await firestore
      .collection(bookingCollections.bookings)
      .doc(query.payload.bookingId)
      .get();
    const booking = snapshot.data() as BookingRecord | undefined;
    if (booking === undefined || booking.userId !== actorId) return rejected('permission_denied');
    return succeeded({ booking });
  } catch {
    return retryable('temporarily_unavailable');
  }
}

export interface BookingPage {
  readonly items: readonly BookingRecord[];
  readonly nextCursor?: string;
  readonly asOf: string;
  readonly sort: 'createdAtDescIdDesc';
  readonly consistency: 'liveKeyset';
}

export async function listMyBookings(
  firestore: Firestore,
  actorId: string,
  query: ListMyBookingsQuery,
): Promise<BookingResult<BookingPage>> {
  try {
    const size = query.payload.pageSize ?? 20;
    let builder = firestore
      .collection(bookingCollections.bookings)
      .where('userId', '==', actorId)
      .orderBy('createdAt', 'desc')
      .orderBy(FieldPath.documentId(), 'desc');
    if (query.payload.stateFilter !== undefined) {
      builder = builder.where('state', '==', query.payload.stateFilter);
    }
    if (query.payload.cursor !== undefined) {
      const cursor = decodeCursor(query.payload.cursor);
      if (cursor === undefined) return rejected('invalid_contract');
      builder = builder.startAfter(cursor.createdAt, cursor.id);
    }
    const snapshot = await builder.limit(size + 1).get();
    const page = snapshot.docs.slice(0, size);
    const items = page.map((document) => document.data() as BookingRecord);
    const hasMore = snapshot.size > size;
    const last = page.at(-1);
    return succeeded({
      items,
      asOf: new Date().toISOString(),
      sort: 'createdAtDescIdDesc',
      consistency: 'liveKeyset',
      ...(hasMore && last !== undefined
        ? { nextCursor: encodeCursor(String(last.get('createdAt')), last.id) }
        : {}),
    });
  } catch {
    return retryable('temporarily_unavailable');
  }
}

function encodeCursor(createdAt: string, id: string): string {
  return Buffer.from(JSON.stringify({ createdAt, id }), 'utf8').toString('base64url');
}

function decodeCursor(value: string): Readonly<{ createdAt: string; id: string }> | undefined {
  try {
    const parsed = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as unknown;
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return undefined;
    const record = parsed as Record<string, unknown>;
    if (typeof record.createdAt !== 'string' || typeof record.id !== 'string') return undefined;
    if (record.createdAt.length > 64 || record.id.length < 1 || record.id.length > 128)
      return undefined;
    return { createdAt: record.createdAt, id: record.id };
  } catch {
    return undefined;
  }
}
