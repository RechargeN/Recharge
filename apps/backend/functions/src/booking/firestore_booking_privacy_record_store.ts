import {
  FieldPath,
  type DocumentReference,
  type Firestore,
  type Query,
} from 'firebase-admin/firestore';
import type { BookingPrivacyRecordStore } from './booking_privacy_task_handler.js';
import type { BookingIdentityBearingRecord } from './privacy.js';
import { bookingCollections, runBookingTransaction } from './transactions.js';
import { cancelBookingForPrivacyErasure } from './occurrence_lifecycle.js';

interface LocatedRecord {
  readonly ref: DocumentReference;
  readonly record: BookingIdentityBearingRecord;
}

export class FirestoreBookingPrivacyRecordStore implements BookingPrivacyRecordStore {
  constructor(
    private readonly firestore: Firestore,
    private readonly subjectId: string,
    private readonly taskId = `legacy-${subjectId}`,
  ) {}

  async runPagedErasure(input: {
    readonly pseudonymousActorId: string;
    readonly nowUtc: string;
  }): Promise<
    Readonly<{
      recordCount: number;
      pseudonymizedCount: number;
      activeFutureBookingCount: number;
      legalHoldCount: number;
    }>
  > {
    if (!/^anon_[0-9a-f]{64}$/u.test(input.pseudonymousActorId)) {
      throw new TypeError('booking_pseudonymous_actor_id_invalid');
    }
    const descriptors = [
      [bookingCollections.bookings, 'userId'],
      [bookingCollections.activeKeys, 'actorId'],
      [bookingCollections.userUsage, 'actorId'],
      [bookingCollections.idempotency, 'actorId'],
      [bookingCollections.audit, 'actorId'],
      [bookingCollections.outbox, 'actorId'],
    ] as const;
    const progressRef = this.firestore.collection('bookingPrivacyProgress').doc(this.taskId);
    const prior = await progressRef.get();
    let collectionIndex = Number(prior.get('collectionIndex') ?? 0);
    let cursor = typeof prior.get('cursor') === 'string' ? String(prior.get('cursor')) : undefined;
    let recordCount = Number(prior.get('recordCount') ?? 0);
    let pseudonymizedCount = Number(prior.get('pseudonymizedCount') ?? 0);
    let activeFutureBookingCount = 0;
    let legalHoldCount = Number(prior.get('legalHoldCount') ?? 0);
    while (collectionIndex < descriptors.length) {
      const [collectionName, identityField] = descriptors[collectionIndex]!;
      let query = this.firestore
        .collection(collectionName)
        .where(identityField, '==', this.subjectId)
        .orderBy(FieldPath.documentId())
        .limit(200);
      if (cursor !== undefined) query = query.startAfter(cursor);
      const snapshot = await query.get();
      if (snapshot.empty) {
        collectionIndex += 1;
        cursor = undefined;
        await progressRef.set(
          progressRecord(
            collectionIndex,
            cursor,
            recordCount,
            pseudonymizedCount,
            activeFutureBookingCount,
            legalHoldCount,
            input.nowUtc,
          ),
        );
        continue;
      }
      if (collectionName === bookingCollections.bookings) {
        const activeFuture = snapshot.docs.filter((document) => {
          const record = document.data();
          return (
            record.state === 'confirmed' &&
            (typeof record.occurrenceEndSnapshot !== 'string' ||
              Date.parse(record.occurrenceEndSnapshot) > Date.parse(input.nowUtc))
          );
        });
        if (activeFuture.length > 0) {
          for (const booking of activeFuture) {
            if (!(await cancelBookingForPrivacyErasure(this.firestore, booking.id, input.nowUtc))) {
              activeFutureBookingCount += 1;
            }
          }
          if (activeFutureBookingCount > 0) {
            await progressRef.set(
              progressRecord(
                collectionIndex,
                cursor,
                recordCount,
                pseudonymizedCount,
                activeFutureBookingCount,
                legalHoldCount,
                input.nowUtc,
              ),
            );
            return {
              recordCount,
              pseudonymizedCount,
              activeFutureBookingCount,
              legalHoldCount,
            };
          }
          continue;
        }
      }
      const batch = this.firestore.batch();
      for (const document of snapshot.docs) {
        const record = document.data() as Record<string, unknown>;
        recordCount += 1;
        if (record.legalHold === true) {
          legalHoldCount += 1;
          continue;
        }
        batch.update(document.ref, { [identityField]: input.pseudonymousActorId });
        pseudonymizedCount += 1;
      }
      cursor = snapshot.docs.at(-1)!.id;
      batch.set(
        progressRef,
        progressRecord(
          collectionIndex,
          cursor,
          recordCount,
          pseudonymizedCount,
          activeFutureBookingCount,
          legalHoldCount,
          input.nowUtc,
        ),
      );
      await batch.commit();
      if (snapshot.size < 200) {
        collectionIndex += 1;
        cursor = undefined;
        await progressRef.set(
          progressRecord(
            collectionIndex,
            cursor,
            recordCount,
            pseudonymizedCount,
            activeFutureBookingCount,
            legalHoldCount,
            input.nowUtc,
          ),
        );
      }
    }
    return { recordCount, pseudonymizedCount, activeFutureBookingCount, legalHoldCount };
  }

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

function progressRecord(
  collectionIndex: number,
  cursor: string | undefined,
  recordCount: number,
  pseudonymizedCount: number,
  activeFutureBookingCount: number,
  legalHoldCount: number,
  updatedAtUtc: string,
) {
  return {
    schemaVersion: 1,
    collectionIndex,
    ...(cursor === undefined ? {} : { cursor }),
    recordCount,
    pseudonymizedCount,
    activeFutureBookingCount,
    legalHoldCount,
    updatedAtUtc,
  };
}
