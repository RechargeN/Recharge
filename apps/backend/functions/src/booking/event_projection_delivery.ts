import { createHash, randomUUID } from 'node:crypto';
import {
  FieldPath,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
} from 'firebase-admin/firestore';
import { emergencySwitchState } from '../modules/operations/emergency_switch.js';
import {
  appendFailure,
  type OperationsFailureClass,
  type OperationsFailureEntry,
  type OperationsReconcileFinding,
  type OperationsReconcileReport,
  type OperationsReplayResult,
  type OperationsTaskView,
} from '../modules/operations/operations_ports.js';
import { operationsEmergencySwitchIds } from '../shared/feature_flags.js';
import {
  consumeEventForBookingProjection,
  projectionEventDigest,
  type EventBookingProjectionEvent,
} from './event_projection_consumer.js';
import { applyOccurrenceLifecycleEffects } from './occurrence_lifecycle.js';
import { bookingCollections } from './transactions.js';

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
  | 'lease_lost'
  /** L2: the family's emergency switch is on; the delivery stays queued. */
  | 'contained';

interface DeliveryRecord {
  readonly status?: string;
  readonly attempts?: number;
  readonly attemptBudget?: number;
  readonly eventDigest?: string;
  readonly reason?: string;
  readonly failureClass?: OperationsFailureClass;
  readonly firstFailure?: OperationsFailureEntry;
  readonly failureHistory?: readonly OperationsFailureEntry[];
  readonly replayCount?: number;
  readonly nextAttemptAtUtc?: string;
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
  readonly attemptBudget: number;
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
const containedRetryMs = 60_000;
const deliveredRetentionMs = 90 * 86_400_000;
const operatorAuditRetentionMs = 180 * 86_400_000;
/** BCK-05 v0.2.41: five attempts; an operator replay grants five more. */
const attemptBudgetPerGrant = 5;
const switchId = operationsEmergencySwitchIds.eventProjectionDelivery;
/** Consumer refusals that a retry cannot change (OPS-L2 §3.3). */
const permanentCodes: readonly string[] = [
  'invalid_source_record',
  'missing_occurrence',
  'invalid_event',
  'revision_conflict',
];

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
      const failure = failureEntry(0, 'permanent', 'invalid_source_record', nowUtc);
      transaction.create(deliveryRef, {
        schemaVersion: 1,
        outboxId,
        status: 'deadLetter',
        attempts: 0,
        reason: 'invalid_source_record',
        failureClass: 'permanent',
        firstFailure: failure,
        failureHistory: [failure],
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
  /**
   * Test-only fault injection, never a client parameter: between dispatch and
   * effect, after the owner effect before any record, and before a failure is
   * recorded.
   */
  testHooks: Readonly<{
    afterLease?: () => Promise<void>;
    afterEffect?: () => Promise<void>;
    beforeFailureRecord?: () => Promise<void>;
  }> = {},
): Promise<DeliveryResult> {
  assertInstant(nowUtc);
  const ensured = await ensureEventBookingDelivery(firestore, outboxId, nowUtc);
  if (ensured === 'not_found') return 'not_found';
  if (ensured === 'invalid_source') return 'dead_letter';
  const acquired = await acquireDeliveryLease(firestore, outboxId, nowUtc, leaseOwner);
  if (acquired === 'delivered') return 'replayed';
  if (acquired === 'deadLetter') return 'dead_letter';
  if (acquired === 'leaseHeld') return 'lease_held';
  if (acquired === 'contained') return 'contained';

  const baseAffected = acquired.lifecycleAffected;
  const baseProcessed = acquired.lifecycleProcessed;
  let lifecycleCursor = acquired.lifecycleCursor;
  let lifecycleAffected = baseAffected;
  let lifecycleProcessed = baseProcessed;
  try {
    await testHooks.afterLease?.();
    // The switch is read again inside the projection transaction, so a family
    // contained after the lease was taken writes no projection.
    const projection = await consumeEventForBookingProjection(firestore, acquired.record.event, {
      effectAllowed: async (transaction) =>
        (await emergencySwitchState(firestore, switchId, transaction)) === 'open',
    });
    if (projection.kind === 'contained') return releaseContained(firestore, acquired, nowUtc);
    await testHooks.afterEffect?.();
    if (projection.kind === 'rejected') {
      return (await finishFailure(firestore, acquired, nowUtc, 'permanent', projection.code, true))
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
          // A page already committed stays; the next page waits for re-enable.
          if ((await emergencySwitchState(firestore, switchId)) === 'contained')
            throw new DeliveryContainedError();
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
    if (error instanceof DeliveryContainedError)
      return releaseContained(firestore, acquired, nowUtc);
    // The owner transaction may have committed before the error reached us:
    // the outcome is unknown until the next attempt reads the projection.
    await testHooks.beforeFailureRecord?.();
    const terminal = acquired.attempts >= acquired.attemptBudget;
    const saved = await finishFailure(
      firestore,
      acquired,
      nowUtc,
      'unknown',
      safeErrorType(error),
      terminal,
    );
    if (!saved) return 'lease_lost';
    return terminal ? 'dead_letter' : 'retry_scheduled';
  }
}

async function acquireDeliveryLease(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  leaseOwner: string,
): Promise<AcquiredDelivery | 'delivered' | 'deadLetter' | 'leaseHeld' | 'contained'> {
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
    if ((await emergencySwitchState(firestore, switchId, transaction)) === 'contained')
      return 'contained' as const;
    const source = parseSourceRecord(sourceSnapshot);
    if (source === undefined) {
      const failure = failureEntry(
        previous.attempts ?? 0,
        'permanent',
        'invalid_source_record',
        nowUtc,
      );
      transaction.set(
        deliveryRef,
        {
          schemaVersion: 1,
          outboxId,
          status: 'deadLetter',
          attempts: previous.attempts ?? 0,
          reason: 'invalid_source_record',
          failureClass: 'permanent',
          firstFailure: previous.firstFailure ?? failure,
          failureHistory: appendFailure(previous.failureHistory, failure),
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
      attemptBudget: previous.attemptBudget ?? attemptBudgetPerGrant,
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

/** Records one failed attempt; the first failure and the rolling history are never replaced. */
async function finishFailure(
  firestore: Firestore,
  acquired: AcquiredDelivery,
  nowUtc: string,
  failureClass: OperationsFailureClass,
  code: string,
  terminal: boolean,
): Promise<boolean> {
  const ref = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(acquired.record.outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const record = snapshot.data() as DeliveryRecord | undefined;
    if (!ownsLease(record, acquired)) return false;
    const failure = failureEntry(acquired.attempts, failureClass, code, nowUtc);
    transaction.set(
      ref,
      {
        status: terminal ? 'deadLetter' : 'retryPending',
        reason: code,
        failureClass,
        firstFailure: record?.firstFailure ?? failure,
        failureHistory: appendFailure(record?.failureHistory, failure),
        ...(!terminal
          ? {
              nextAttemptAtUtc: new Date(
                Date.parse(nowUtc) + retryDelayMs(acquired.attempts),
              ).toISOString(),
            }
          : {}),
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

/** A contained family is not a failure: the attempt is given back and the work waits. */
async function releaseContained(
  firestore: Firestore,
  acquired: AcquiredDelivery,
  nowUtc: string,
): Promise<'contained' | 'lease_lost'> {
  return (await finishDelivery(firestore, acquired, nowUtc, {
    status: 'retryPending',
    attempts: acquired.attempts - 1,
    nextAttemptAtUtc: new Date(Date.parse(nowUtc) + containedRetryMs).toISOString(),
  }))
    ? 'contained'
    : 'lease_lost';
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

function failureEntry(
  attempt: number,
  failureClass: OperationsFailureClass,
  code: string,
  atUtc: string,
): OperationsFailureEntry {
  return { attempt, failureClass, code, atUtc };
}

function storedFailureClass(record: DeliveryRecord): OperationsFailureClass | null {
  if (record.failureClass !== undefined) return record.failureClass;
  if (record.reason === undefined) return null;
  // Records written before L2 carry only the code.
  return permanentCodes.includes(record.reason) ? 'permanent' : 'unknown';
}

/**
 * Audited operator replay of one dead letter (OPS-L2 §4). The original failure,
 * attempt count and history stay; a fresh budget of five attempts is granted.
 * A permanent rejection, a source that no longer matches the delivery's digest
 * or a contained family is refused. Current Event revisions are checked by the
 * consumer when the delivery runs, never assumed here.
 */
export async function replayDeadLetterEventBookingProjection(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  decision: EventProjectionOperatorDecision,
): Promise<Exclude<OperationsReplayResult, 'replay_exhausted' | 'expired'>> {
  assertInstant(nowUtc);
  assertOperatorDecision(decision);
  const ref = firestore.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId);
  const sourceRef = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(outboxId);
  const auditRef = firestore
    .collection(eventBookingDeliveryCollections.operatorAudit)
    .doc(decision.decisionId);
  return firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(ref, auditRef, sourceRef);
    const snapshot = snapshots[0];
    const audit = snapshots[1];
    const sourceSnapshot = snapshots[2];
    if (snapshot === undefined || audit === undefined || sourceSnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    if (audit.exists) {
      return audit.get('outboxId') === outboxId
        ? ('replayed' as const)
        : ('decision_conflict' as const);
    }
    if (!snapshot.exists) return 'not_found' as const;
    const record = snapshot.data() as DeliveryRecord;
    if (record.status !== 'deadLetter') return 'not_dead_letter' as const;
    const failureClass = storedFailureClass(record);
    if (failureClass === 'permanent') return 'permanent_rejection' as const;
    const source = parseSourceRecord(sourceSnapshot);
    if (source === undefined || eventDigest(source.event) !== record.eventDigest)
      return 'payload_changed' as const;
    if ((await emergencySwitchState(firestore, switchId, transaction)) === 'contained')
      return 'family_contained' as const;
    const attempts = record.attempts ?? 0;
    transaction.create(auditRef, {
      schemaVersion: 1,
      decisionId: decision.decisionId,
      action: 'deadLetterReplay',
      outboxId,
      actorId: decision.actorId,
      reason: decision.reason,
      correlationId: decision.correlationId,
      previousFailureClass: failureClass,
      previousCode: record.reason ?? null,
      previousAttempts: attempts,
      occurredAtUtc: nowUtc,
      expiresAt: Timestamp.fromMillis(Date.parse(nowUtc) + operatorAuditRetentionMs),
    });
    transaction.set(
      ref,
      {
        status: 'retryPending',
        attemptBudget: attempts + attemptBudgetPerGrant,
        replayCount: (record.replayCount ?? 0) + 1,
        lastReplayDecisionId: decision.decisionId,
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

/** Minimal operator view: codes, counters and the task ID; never the event payload. */
export async function inspectEventBookingDelivery(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
): Promise<OperationsTaskView | undefined> {
  const snapshot = await firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(outboxId)
    .get();
  if (!snapshot.exists) return undefined;
  const record = snapshot.data() as DeliveryRecord;
  return {
    taskId: outboxId,
    state: derivedState(record, nowUtc),
    storedStatus: record.status ?? 'unknown',
    attempts: record.attempts ?? 0,
    attemptBudget: record.attemptBudget ?? attemptBudgetPerGrant,
    failureClass: storedFailureClass(record),
    failureCode: record.reason ?? null,
    firstFailure: record.firstFailure ?? null,
    failureHistory: record.failureHistory ?? [],
    replayCount: record.replayCount ?? 0,
    nextAttemptAtUtc: record.nextAttemptAtUtc ?? null,
  };
}

function derivedState(record: DeliveryRecord, nowUtc: string): OperationsTaskView['state'] {
  switch (record.status) {
    case 'delivered':
      return 'done';
    case 'deadLetter':
      return 'dead_letter';
    case 'retryPending':
      return 'retry_scheduled';
    case 'processing':
      return typeof record.leaseUntilUtc === 'string' &&
        Date.parse(record.leaseUntilUtc) > Date.parse(nowUtc)
        ? 'in_flight'
        : 'unknown';
    default:
      return 'pending';
  }
}

const reconcileCheckpointId = 'reconcile-v1';

/**
 * Bounded reconciliation of TF-01 (OPS-L2 §4.7): pages the immutable source
 * outbox by `(createdAt, id)` from its own checkpoint and compares each fact
 * with its delivery and with the Booking projection, which is the receipt. A
 * `delivered` mark whose projection does not cover the fact, a lease that
 * expired without a result, or a missing delivery is handed back to the
 * owner's delivery path; the consumer ignores what it already applied, so a
 * second pass converges without new effects. Dead letters are only reported.
 * A fact committed behind the cursor during a cycle is seen by the next cycle.
 */
export async function reconcileEventBookingDeliveries(
  firestore: Firestore,
  nowUtc: string,
  options: Readonly<{ pageSize?: number; maxPages?: number }> = {},
): Promise<OperationsReconcileReport & Readonly<{ cycleCompleted: boolean }>> {
  assertInstant(nowUtc);
  const pageSize = options.pageSize ?? 50;
  const maxPages = options.maxPages ?? 10;
  if (!Number.isSafeInteger(pageSize) || pageSize < 1 || pageSize > 100)
    throw new TypeError('event_delivery_limit_invalid');
  const checkpointRef = firestore
    .collection(eventBookingDeliveryCollections.discoveryCheckpoints)
    .doc(reconcileCheckpointId);
  const findings: OperationsReconcileFinding[] = [];
  const repaired: OperationsReconcileFinding[] = [];
  let scanned = 0;
  let redispatched = 0;
  let cycleCompleted = false;
  for (let page = 0; page < maxPages; page += 1) {
    const checkpoint = await checkpointRef.get();
    const lastCreatedAt: unknown = checkpoint.get('lastCreatedAt');
    const lastDocumentId: unknown = checkpoint.get('lastDocumentId');
    let query = firestore
      .collection(eventBookingDeliveryCollections.sourceOutbox)
      .orderBy('createdAt')
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (lastCreatedAt instanceof Timestamp && typeof lastDocumentId === 'string')
      query = query.startAfter(lastCreatedAt, lastDocumentId);
    const source = await query.get();
    for (const document of source.docs) {
      scanned += 1;
      const finding = await reconcileOne(firestore, document, nowUtc);
      if (finding.redispatched) redispatched += 1;
      if (finding.code !== null) findings.push({ code: finding.code, ref: document.id });
      if (finding.repaired !== null) repaired.push({ code: finding.repaired, ref: document.id });
    }
    const last = source.docs.at(-1);
    if (source.size < pageSize || last === undefined) {
      await checkpointRef.delete();
      cycleCompleted = true;
      break;
    }
    const createdAt: unknown = last.get('createdAt');
    if (!(createdAt instanceof Timestamp)) {
      // Caller-owned timestamps sort after every server timestamp and cannot be
      // a cursor; the cycle restarts and stays incomplete.
      findings.push({ code: 'source_order_invalid', ref: last.id });
      await checkpointRef.delete();
      break;
    }
    await checkpointRef.set({
      schemaVersion: 1,
      checkpointId: reconcileCheckpointId,
      lastCreatedAt: createdAt,
      lastDocumentId: last.id,
      updatedAtUtc: nowUtc,
    });
  }
  return {
    complete: cycleCompleted && findings.length === 0,
    scanned,
    redispatched,
    findings,
    repaired,
    cycleCompleted,
  };
}

async function reconcileOne(
  firestore: Firestore,
  document: DocumentSnapshot,
  nowUtc: string,
): Promise<Readonly<{ code: string | null; repaired: string | null; redispatched: boolean }>> {
  const source = parseSourceRecord(document);
  const deliveryRef = firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .doc(document.id);
  const delivery = (await deliveryRef.get()).data() as DeliveryRecord | undefined;
  if (source === undefined) {
    if (delivery === undefined) await ensureEventBookingDelivery(firestore, document.id, nowUtc);
    return { code: 'dead_letter', repaired: null, redispatched: false };
  }
  let reason: string | null = null;
  if (delivery === undefined) reason = 'delivery_missing';
  else if (delivery.status === 'deadLetter')
    return { code: 'dead_letter', repaired: null, redispatched: false };
  else if (delivery.status === 'delivered') {
    if (await receiptCovers(firestore, source.event))
      return { code: null, repaired: null, redispatched: false };
    // A `delivered` mark is not proof: the projection must show the fact.
    reason = 'receipt_missing';
    await firestore.runTransaction(async (transaction) => {
      const current = (await transaction.get(deliveryRef)).data() as DeliveryRecord | undefined;
      if (current?.status !== 'delivered') return;
      transaction.set(
        deliveryRef,
        {
          status: 'retryPending',
          attemptBudget: Math.max(
            current.attemptBudget ?? attemptBudgetPerGrant,
            (current.attempts ?? 0) + 1,
          ),
          nextAttemptAtUtc: nowUtc,
          reconciledReason: 'receipt_missing',
          deliveredAtUtc: null,
          expiresAt: null,
          updatedAtUtc: nowUtc,
        },
        { merge: true },
      );
    });
  } else if (derivedState(delivery, nowUtc) === 'in_flight')
    return { code: 'in_flight', repaired: null, redispatched: false };
  else if (derivedState(delivery, nowUtc) === 'unknown') reason = 'outcome_unknown';
  else if (
    typeof delivery.nextAttemptAtUtc === 'string' &&
    Date.parse(delivery.nextAttemptAtUtc) > Date.parse(nowUtc)
  )
    return { code: 'retry_scheduled', repaired: null, redispatched: false };
  const result = await deliverEventBookingProjection(
    firestore,
    document.id,
    nowUtc,
    `reconcile:${document.id}`,
  );
  const resolved = result === 'delivered' || result === 'replayed';
  return {
    code: resolved ? null : `${reason ?? 'due'}:${result}`,
    repaired: resolved ? (reason ?? 'due') : null,
    redispatched: true,
  };
}

/** The projection is the receipt: it shows this fact or a newer one of the same Event. */
async function receiptCovers(
  firestore: Firestore,
  event: EventBookingProjectionEvent,
): Promise<boolean> {
  const projection = (
    await firestore.collection(bookingCollections.eventProjections).doc(event.occurrenceId).get()
  ).data();
  if (projection?.eventId !== event.eventId) return false;
  const material = Number(projection.materialRevision ?? -1);
  const publication = Number(projection.publicationRevision ?? -1);
  if (material !== event.materialRevision) return material > event.materialRevision;
  if (publication !== event.publicationRevision) return publication > event.publicationRevision;
  return (
    projection.sourceEventKind === event.kind &&
    (projection.sourceEventDigest === undefined ||
      projection.sourceEventDigest === projectionEventDigest(event))
  );
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

class DeliveryContainedError extends Error {
  constructor() {
    super('event_delivery_contained');
    this.name = 'DeliveryContainedError';
  }
}
