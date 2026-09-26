import type { Firestore } from 'firebase-admin/firestore';
import {
  consumeEventForBookingProjection,
  type EventBookingProjectionEvent,
} from './event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from './occurrence_lifecycle.js';

export const eventBookingDeliveryCollections = Object.freeze({
  sourceOutbox: 'eventBookingOutbox',
  deliveries: 'bookingProjectionDeliveries',
});

export interface EventBookingOutboxRecord {
  readonly schemaVersion: 1;
  readonly outboxId: string;
  readonly event: EventBookingProjectionEvent;
  readonly createdAtUtc: string;
}

export async function enqueueEventBookingProjection(
  firestore: Firestore,
  record: EventBookingOutboxRecord,
): Promise<'created' | 'replayed' | 'conflict'> {
  const ref = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(record.outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      return JSON.stringify(snapshot.data()) === JSON.stringify(record)
        ? ('replayed' as const)
        : ('conflict' as const);
    }
    transaction.create(ref, record);
    return 'created' as const;
  });
}

export async function deliverEventBookingProjection(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
): Promise<'delivered' | 'replayed' | 'retry_scheduled' | 'dead_letter' | 'not_found'> {
  const sourceRef = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(outboxId);
  const deliveryRef = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(outboxId);
  const [sourceSnapshot, deliverySnapshot] = await firestore.getAll(sourceRef, deliveryRef);
  if (sourceSnapshot === undefined || deliverySnapshot === undefined) {
    throw new Error('firestore_snapshot_count_mismatch');
  }
  if (!sourceSnapshot.exists) return 'not_found';
  const previous = deliverySnapshot.data() as
    { status?: string; attempts?: number; eventDigest?: string } | undefined;
  if (previous?.status === 'delivered') return 'replayed';
  if (previous?.status === 'deadLetter') return 'dead_letter';
  const record = sourceSnapshot.data() as EventBookingOutboxRecord;
  const attempts = (previous?.attempts ?? 0) + 1;
  try {
    const projection = await consumeEventForBookingProjection(firestore, record.event);
    if (projection.kind === 'rejected') {
      await deliveryRef.set({
        schemaVersion: 1,
        outboxId,
        status: 'deadLetter',
        attempts,
        reason: projection.code,
        updatedAtUtc: nowUtc,
      });
      return 'dead_letter';
    }
    if (projection.kind !== 'ignoredStale') {
      await applyOccurrenceLifecycleEffects(firestore, record.event);
    }
    await deliveryRef.set({
      schemaVersion: 1,
      outboxId,
      status: 'delivered',
      attempts,
      projectionResult: projection.kind,
      deliveredAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    });
    return 'delivered';
  } catch (error) {
    const terminal = attempts >= 5;
    await deliveryRef.set({
      schemaVersion: 1,
      outboxId,
      status: terminal ? 'deadLetter' : 'retryPending',
      attempts,
      reason: safeErrorType(error),
      updatedAtUtc: nowUtc,
    });
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
}

function safeErrorType(error: unknown): string {
  if (error instanceof Error && /^[A-Za-z][A-Za-z0-9]*$/u.test(error.name)) return error.name;
  return 'UnknownError';
}
