import { createHash, randomUUID } from 'node:crypto';
import { Timestamp, type DocumentSnapshot, type Firestore } from 'firebase-admin/firestore';
import {
  consumeEventForBookingProjection,
  type EventBookingProjectionEvent,
} from './event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from './occurrence_lifecycle.js';

export const eventBookingDeliveryCollections = Object.freeze({
  sourceOutbox: 'eventBookingOutbox',
  deliveries: 'bookingProjectionDeliveries',
  discoveryCheckpoints: 'bookingProjectionDiscoveryCheckpoints',
  operatorAudit: 'bookingProjectionOperatorAudit',
});

export interface StoredEventBookingOutboxRecord {
  readonly schemaVersion: 1;
  readonly outboxId: string;
  readonly event: EventBookingProjectionEvent;
  readonly createdAt: Timestamp;
}

type DeliveryResult =
  | 'delivered'
  | 'replayed'
  | 'retry_scheduled'
  | 'dead_letter'
  | 'not_found'
  | 'lease_held'
  | 'lease_lost';

interface DeliveryRecord {
  readonly status?: string;
  readonly attempts?: number;
  readonly lifecycleCursor?: string;
  readonly lifecycleAffected?: number;
  readonly lifecycleProcessed?: number;
  readonly leaseToken?: string | null;
  readonly leaseGeneration?: number;
  readonly leaseUntilUtc?: string | null;
}

interface AcquiredDelivery {
  readonly kind: 'acquired';
  readonly record: StoredEventBookingOutboxRecord;
  readonly leaseToken: string;
  readonly leaseGeneration: number;
  readonly attempts: number;
  readonly lifecycleCursor?: string;
  readonly lifecycleAffected: number;
  readonly lifecycleProcessed: number;
}

interface EventProjectionOperatorDecision {
  readonly decisionId: string;
  readonly actorId: string;
  readonly reason: string;
  readonly correlationId: string;
}

const leaseDurationMs = 2 * 60_000;
const deliveredRetentionMs = 90 * 86_400_000;
const operatorAuditRetentionMs = 180 * 86_400_000;

export async function ensureEventBookingDelivery(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
): Promise<'created' | 'replayed' | 'invalid_source' | 'not_found'> {
  assertInstant(nowUtc);
  const sourceRef = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(outboxId);
  const deliveryRef = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(sourceRef, deliveryRef);
    const sourceSnapshot = snapshots[0];
    const deliverySnapshot = snapshots[1];
    if (sourceSnapshot === undefined || deliverySnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    if (!sourceSnapshot.exists) return 'not_found' as const;
    if (deliverySnapshot.exists) return 'replayed' as const;
    const source = parseSourceRecord(sourceSnapshot);
    if (source === undefined) {
      transaction.create(deliveryRef, {
        schemaVersion: 1,
        outboxId,
        status: 'deadLetter',
        attempts: 0,
        reason: 'invalid_source_record',
        updatedAtUtc: nowUtc,
      });
      return 'invalid_source' as const;
    }
    transaction.create(deliveryRef, {
      schemaVersion: 1,
      outboxId,
      status: 'pending',
      attempts: 0,
      eventDigest: eventDigest(source.event),
      nextAttemptAtUtc: source.createdAt.toDate().toISOString(),
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    });
    return 'created' as const;
  });
}

export async function deliverEventBookingProjection(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  leaseOwner: string = randomUUID(),
  leaseClock: () => string = () => new Date().toISOString(),
): Promise<DeliveryResult> {
  assertInstant(nowUtc);
  const ensured = await ensureEventBookingDelivery(firestore, outboxId, nowUtc);
  if (ensured === 'not_found') return 'not_found';
  if (ensured === 'invalid_source') return 'dead_letter';
  const acquired = await acquireDeliveryLease(firestore, outboxId, nowUtc, leaseOwner);
  if (acquired === 'delivered') return 'replayed';
  if (acquired === 'deadLetter') return 'dead_letter';
  if (acquired === 'leaseHeld') return 'lease_held';

  const baseAffected = acquired.lifecycleAffected;
  const baseProcessed = acquired.lifecycleProcessed;
  let lifecycleCursor = acquired.lifecycleCursor;
  let lifecycleAffected = baseAffected;
  let lifecycleProcessed = baseProcessed;
  try {
    const projection = await consumeEventForBookingProjection(firestore, acquired.record.event);
    if (projection.kind === 'rejected') {
      return (await finishDelivery(firestore, acquired, nowUtc, {
        status: 'deadLetter',
        reason: projection.code,
      }))
        ? 'dead_letter'
        : 'lease_lost';
    }
    // An exact duplicate is a retry of the same source fact and must resume
    // lifecycle work. An older stale fact must never affect newer state.
    if (projection.kind !== 'ignoredStale') {
      const lifecycle = await applyOccurrenceLifecycleEffects(firestore, acquired.record.event, {
        ...(lifecycleCursor === undefined ? {} : { startAfterBookingId: lifecycleCursor }),
        pageSize: 200,
        afterPage: async (progress) => {
          lifecycleCursor = progress.cursor;
          lifecycleAffected = baseAffected + progress.affected;
          lifecycleProcessed = baseProcessed + progress.processed;
          const leaseNowUtc = leaseClock();
          assertInstant(leaseNowUtc);
          const renewed = await checkpointDelivery(firestore, acquired, leaseNowUtc, {
            lifecycleCursor,
            lifecycleAffected,
            lifecycleProcessed,
          });
          if (!renewed) throw new DeliveryLeaseLostError();
        },
      });
      if (lifecycle.cursor !== undefined) lifecycleCursor = lifecycle.cursor;
      lifecycleAffected = baseAffected + lifecycle.affected;
      lifecycleProcessed = baseProcessed + lifecycle.processed;
    }
    return (await finishDelivery(firestore, acquired, nowUtc, {
      status: 'delivered',
      projectionResult: projection.kind,
      ...(lifecycleCursor === undefined ? {} : { lifecycleCursor }),
      lifecycleAffected,
      lifecycleProcessed,
      deliveredAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + deliveredRetentionMs),
    }))
      ? 'delivered'
      : 'lease_lost';
  } catch (error) {
    if (error instanceof DeliveryLeaseLostError) return 'lease_lost';
    const terminal = acquired.attempts >= 5;
    const saved = await finishDelivery(firestore, acquired, nowUtc, {
      status: terminal ? 'deadLetter' : 'retryPending',
      reason: safeErrorType(error),
      ...(!terminal
        ? {
            nextAttemptAtUtc: new Date(
              Date.parse(nowUtc) + retryDelayMs(acquired.attempts),
            ).toISOString(),
          }
        : {}),
    });
    if (!saved) return 'lease_lost';
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
}

async function acquireDeliveryLease(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  leaseOwner: string,
): Promise<AcquiredDelivery | 'delivered' | 'deadLetter' | 'leaseHeld'> {
  const sourceRef = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(outboxId);
  const deliveryRef = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(outboxId);
  const leaseToken = randomUUID();
  return firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(sourceRef, deliveryRef);
    const sourceSnapshot = snapshots[0];
    const deliverySnapshot = snapshots[1];
    if (sourceSnapshot === undefined || deliverySnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    const previous = (deliverySnapshot.data() ?? {}) as DeliveryRecord;
    if (previous.status === 'delivered') return 'delivered' as const;
    if (previous.status === 'deadLetter') return 'deadLetter' as const;
    if (
      previous.status === 'processing' &&
      typeof previous.leaseUntilUtc === 'string' &&
      Date.parse(previous.leaseUntilUtc) > Date.parse(nowUtc)
    ) {
      return 'leaseHeld' as const;
    }
    const source = parseSourceRecord(sourceSnapshot);
    if (source === undefined) {
      transaction.set(
        deliveryRef,
        {
          schemaVersion: 1,
          outboxId,
          status: 'deadLetter',
          attempts: previous.attempts ?? 0,
          reason: 'invalid_source_record',
          leaseOwner: null,
          leaseToken: null,
          leaseUntilUtc: null,
          updatedAtUtc: nowUtc,
        },
        { merge: true },
      );
      return 'deadLetter' as const;
    }
    const leaseGeneration = (previous.leaseGeneration ?? 0) + 1;
    const attempts = (previous.attempts ?? 0) + 1;
    const leaseUntilUtc = new Date(Date.parse(nowUtc) + leaseDurationMs).toISOString();
    transaction.set(
      deliveryRef,
      {
        schemaVersion: 1,
        outboxId,
        status: 'processing',
        attempts,
        eventDigest: eventDigest(source.event),
        leaseOwner,
        leaseToken,
        leaseGeneration,
        leaseUntilUtc,
        nextAttemptAtUtc: leaseUntilUtc,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return {
      kind: 'acquired',
      record: source,
      leaseToken,
      leaseGeneration,
      attempts,
      ...(previous.lifecycleCursor === undefined
        ? {}
        : { lifecycleCursor: previous.lifecycleCursor }),
      lifecycleAffected: previous.lifecycleAffected ?? 0,
      lifecycleProcessed: previous.lifecycleProcessed ?? 0,
    } as const;
  });
}

async function checkpointDelivery(
  firestore: Firestore,
  acquired: AcquiredDelivery,
  nowUtc: string,
  progress: Readonly<{
    lifecycleCursor: string;
    lifecycleAffected: number;
    lifecycleProcessed: number;
  }>,
): Promise<boolean> {
  const ref = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(acquired.record.outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!ownsLease(snapshot.data(), acquired)) return false;
    const leaseUntilUtc = new Date(Date.parse(nowUtc) + leaseDurationMs).toISOString();
    transaction.set(
      ref,
      {
        ...progress,
        leaseUntilUtc,
        nextAttemptAtUtc: leaseUntilUtc,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return true;
  });
}

async function finishDelivery(
  firestore: Firestore,
  acquired: AcquiredDelivery,
  nowUtc: string,
  result: Readonly<Record<string, unknown>>,
): Promise<boolean> {
  const ref = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(acquired.record.outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!ownsLease(snapshot.data(), acquired)) return false;
    transaction.set(
      ref,
      {
        ...result,
        leaseOwner: null,
        leaseToken: null,
        leaseUntilUtc: null,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return true;
  });
}

function ownsLease(record: DeliveryRecord | undefined, acquired: AcquiredDelivery): boolean {
  return (
    record?.status === 'processing' &&
    record.leaseToken === acquired.leaseToken &&
    record.leaseGeneration === acquired.leaseGeneration
  );
}

function parseSourceRecord(snapshot: DocumentSnapshot): StoredEventBookingOutboxRecord | undefined {
  if (!snapshot.exists) return undefined;
  const value = snapshot.data() as Record<string, unknown> | undefined;
  if (
    value?.schemaVersion !== 1 ||
    value.outboxId !== snapshot.id ||
    !(value.createdAt instanceof Timestamp) ||
    typeof value.event !== 'object' ||
    value.event === null
  ) {
    return undefined;
  }
  return value as unknown as StoredEventBookingOutboxRecord;
}

function eventDigest(event: EventBookingProjectionEvent): string {
  return createHash('sha256').update(JSON.stringify(event), 'utf8').digest('hex');
}

function retryDelayMs(attempts: number): number {
  return [60_000, 5 * 60_000, 15 * 60_000, 60 * 60_000][Math.min(Math.max(attempts - 1, 0), 3)]!;
}

export async function replayDeadLetterEventBookingProjection(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  decision: EventProjectionOperatorDecision,
): Promise<'requeued' | 'replayed' | 'not_found' | 'not_dead_letter'> {
  assertInstant(nowUtc);
  assertOperatorDecision(decision);
  const ref = firestore.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId);
  const auditRef = firestore
    .collection(eventBookingDeliveryCollections.operatorAudit)
    .doc(decision.decisionId);
  return firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(ref, auditRef);
    const snapshot = snapshots[0];
    const audit = snapshots[1];
    if (snapshot === undefined || audit === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    if (audit.exists) {
      return audit.get('outboxId') === outboxId
        ? ('replayed' as const)
        : ('not_dead_letter' as const);
    }
    if (!snapshot.exists) return 'not_found' as const;
    if (snapshot.get('status') !== 'deadLetter') return 'not_dead_letter' as const;
    transaction.create(auditRef, {
      schemaVersion: 1,
      decisionId: decision.decisionId,
      action: 'deadLetterReplay',
      outboxId,
      actorId: decision.actorId,
      reason: decision.reason,
      correlationId: decision.correlationId,
      occurredAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + operatorAuditRetentionMs),
    });
    transaction.set(
      ref,
      {
        status: 'retryPending',
        attempts: 0,
        nextAttemptAtUtc: nowUtc,
        manualReplayRequestedAtUtc: nowUtc,
        leaseOwner: null,
        leaseToken: null,
        leaseUntilUtc: null,
        updatedAtUtc: nowUtc,
      },
      { merge: true },
    );
    return 'requeued' as const;
  });
}

function assertOperatorDecision(decision: EventProjectionOperatorDecision): void {
  if (!/^[A-Za-z0-9_-]{1,128}$/u.test(decision.decisionId)) {
    throw new TypeError('event_delivery_decision_id_invalid');
  }
  if (!/^[A-Za-z0-9_-]{1,128}$/u.test(decision.actorId)) {
    throw new TypeError('event_delivery_actor_id_invalid');
  }
  if (!/^[a-z][a-z0-9._-]{2,95}$/u.test(decision.reason)) {
    throw new TypeError('event_delivery_reason_invalid');
  }
  if (decision.correlationId.length < 8 || decision.correlationId.length > 128) {
    throw new TypeError('event_delivery_correlation_id_invalid');
  }
}

function assertInstant(value: string): void {
  if (!Number.isFinite(Date.parse(value))) throw new TypeError('event_delivery_instant_invalid');
}

function safeErrorType(error: unknown): string {
  if (error instanceof Error && /^[A-Za-z][A-Za-z0-9]*$/u.test(error.name)) return error.name;
  return 'UnknownError';
}

class DeliveryLeaseLostError extends Error {
  constructor() {
    super('event_delivery_lease_lost');
    this.name = 'DeliveryLeaseLostError';
  }
}
