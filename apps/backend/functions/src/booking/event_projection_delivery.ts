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
    | {
        status?: string;
        attempts?: number;
        eventDigest?: string;
        lifecycleCursor?: string;
        lifecycleAffected?: number;
        lifecycleProcessed?: number;
      }
    | undefined;
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
    let lifecycleAffected = previous?.lifecycleAffected ?? 0;
    let lifecycleProcessed = previous?.lifecycleProcessed ?? 0;
    let lifecycleCursor = previous?.lifecycleCursor;
    if (projection.kind !== 'ignoredStale') {
      const lifecycle = await applyOccurrenceLifecycleEffects(firestore, record.event, {
        ...(lifecycleCursor === undefined ? {} : { startAfterBookingId: lifecycleCursor }),
        pageSize: 200,
        afterPage: async (progress) => {
          lifecycleCursor = progress.cursor;
          lifecycleAffected = (previous?.lifecycleAffected ?? 0) + progress.affected;
          lifecycleProcessed = (previous?.lifecycleProcessed ?? 0) + progress.processed;
          await deliveryRef.set(
            {
              schemaVersion: 1,
              outboxId,
              status: 'processing',
              attempts,
              lifecycleCursor,
              lifecycleAffected,
              lifecycleProcessed,
              updatedAtUtc: nowUtc,
            },
            { merge: true },
          );
        },
      });
      if (lifecycle.cursor !== undefined) lifecycleCursor = lifecycle.cursor;
    }
    await deliveryRef.set({
      schemaVersion: 1,
      outboxId,
      status: 'delivered',
      attempts,
      projectionResult: projection.kind,
      ...(lifecycleCursor === undefined ? {} : { lifecycleCursor }),
      lifecycleAffected,
      lifecycleProcessed,
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
      ...(!terminal
        ? { nextAttemptAtUtc: new Date(Date.parse(nowUtc) + retryDelayMs(attempts)).toISOString() }
        : {}),
      updatedAtUtc: nowUtc,
    });
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
}

function retryDelayMs(attempts: number): number {
  return [60_000, 5 * 60_000, 15 * 60_000, 60 * 60_000][Math.min(Math.max(attempts - 1, 0), 3)]!;
}

export async function replayDeadLetterEventBookingProjection(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
): Promise<'requeued' | 'not_found' | 'not_dead_letter'> {
  const ref = firestore.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return 'not_found' as const;
    if (snapshot.get('status') !== 'deadLetter') return 'not_dead_letter' as const;
    transaction.set(
      ref,
      {
        status: 'retryPending',
        attempts: 0,
        manualReplayRequestedAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return 'requeued' as const;
  });
}

function safeErrorType(error: unknown): string {
  if (error instanceof Error && /^[A-Za-z][A-Za-z0-9]*$/u.test(error.name)) return error.name;
  return 'UnknownError';
}
