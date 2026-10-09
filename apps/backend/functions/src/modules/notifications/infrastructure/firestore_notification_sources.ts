import { FieldPath, type Firestore } from 'firebase-admin/firestore';

import type {
  NotificationEffectSource,
  SourcePosition,
  SourceRecord,
} from '../domain/repositories.js';

/**
 * Read-only view of the producer-owned Booking outbox (F1 §7). Notifications
 * never writes this collection; Booking stays its single writer.
 */
export const bookingOutboxCollection = 'bookingOutbox';

function sourceRecord(id: string, data: Record<string, unknown>): SourceRecord {
  return { id, createdAt: typeof data.createdAt === 'string' ? data.createdAt : '', data };
}

export class FirestoreBookingOutboxSource implements NotificationEffectSource {
  constructor(private readonly firestore: Firestore) {}

  async page(after: SourcePosition | null, limit: number): Promise<readonly SourceRecord[]> {
    let query = this.firestore
      .collection(bookingOutboxCollection)
      .orderBy('createdAt')
      .orderBy(FieldPath.documentId());
    if (after !== null) query = query.startAfter(after.createdAt, after.id);
    const snapshot = await query.limit(limit).get();
    return snapshot.docs.map((document) => sourceRecord(document.id, document.data()));
  }

  async get(eventId: string): Promise<SourceRecord | undefined> {
    const snapshot = await this.firestore.collection(bookingOutboxCollection).doc(eventId).get();
    return snapshot.exists ? sourceRecord(snapshot.id, snapshot.data()!) : undefined;
  }
}
