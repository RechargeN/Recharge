import type { Firestore, Query, DocumentReference } from 'firebase-admin/firestore';
import type { BookingPrivacyRecordStore } from './booking_privacy_task_handler.js';
import type { BookingIdentityBearingRecord } from './privacy.js';
import { bookingCollections, runBookingTransaction } from './transactions.js';

interface LocatedRecord {
  readonly ref: DocumentReference;
  readonly record: BookingIdentityBearingRecord;
}

export class FirestoreBookingPrivacyRecordStore implements BookingPrivacyRecordStore {
  constructor(
    private readonly firestore: Firestore,
    private readonly subjectId: string,
  ) {}

  runAtomic<T>(operation: (records: BookingIdentityBearingRecord[]) => T): Promise<T> {
    return runBookingTransaction(this.firestore, async (transaction) => {
      const queries: readonly Query[] = [
        this.firestore
          .collection(bookingCollections.bookings)
          .where('userId', '==', this.subjectId),
        this.firestore
          .collection(bookingCollections.idempotency)
          .where('actorId', '==', this.subjectId),
        this.firestore.collection(bookingCollections.audit).where('actorId', '==', this.subjectId),
        this.firestore.collection(bookingCollections.outbox).where('actorId', '==', this.subjectId),
      ];
      const located: LocatedRecord[] = [];
      for (const query of queries) {
        const snapshot = await transaction.get(query);
        for (const document of snapshot.docs) {
          located.push({
            ref: document.ref,
            record: document.data() as BookingIdentityBearingRecord,
          });
        }
      }
      const working = located.map(({ record }) => ({
        ...record,
      })) as BookingIdentityBearingRecord[];
      const result = operation(working);
      working.forEach((record, index) => transaction.set(located[index]!.ref, record));
      return result;
    });
  }
}
