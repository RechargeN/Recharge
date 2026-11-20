import { FieldPath, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { FirestoreFeatureFlagGate } from '../platform/config/firestore_feature_flag_gate.js';
import { emergencySwitchState } from '../modules/operations/emergency_switch.js';
import { bookingFlagIds, operationsEmergencySwitchIds } from '../shared/feature_flags.js';
import {
  deliverEventBookingProjection,
  ensureEventBookingDelivery,
  eventBookingDeliveryCollections,
} from './event_projection_delivery.js';

const discoveryCheckpointId = 'event-outbox-v1';

/**
 * Whether Event → Booking delivery is active. The Emulator reads the local
 * product flag; the cloud runtime passes its own gate (the Operations switch),
 * because product flags are Emulator-only and always off in the cloud.
 */
export type EventDeliveryGate = () => Promise<boolean>;

export function emulatorEventDeliveryGate(firestore: Firestore): EventDeliveryGate {
  return () =>
    new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
      bookingFlagIds.eventProjectionDelivery,
    );
}

/**
 * Product flags are Emulator-only (always off in the cloud), so the cloud
 * Event → Booking delivery is active exactly while its Operations emergency
 * switch is open (round 2.1: a missing switch is contained). A34 staging
 * 2026-11-19: with the Emulator flag the outbox trigger answered 200 and
 * delivered nothing.
 */
export function cloudEventDeliveryGate(firestore: Firestore): EventDeliveryGate {
  return async () =>
    (await emergencySwitchState(
      firestore,
      operationsEmergencySwitchIds.eventProjectionDelivery,
    )) === 'open';
}

export async function processEventBookingOutboxDocument(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
  gate: EventDeliveryGate = emulatorEventDeliveryGate(firestore),
): Promise<'disabled' | Awaited<ReturnType<typeof deliverEventBookingProjection>>> {
  const enabled = await gate();
  if (!enabled) return 'disabled';
  return deliverEventBookingProjection(firestore, outboxId, nowUtc);
}

export async function discoverEventBookingDeliveries(
  firestore: Firestore,
  nowUtc: string,
  limit = 100,
): Promise<Readonly<{ examined: number; created: number }>> {
  assertLimit(limit);
  const checkpointRef = firestore
    .collection(eventBookingDeliveryCollections.discoveryCheckpoints)
    .doc(discoveryCheckpointId);
  const checkpoint = await checkpointRef.get();
  const createdAtValue: unknown = checkpoint.get('lastCreatedAt');
  const documentIdValue: unknown = checkpoint.get('lastDocumentId');
  let query = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .orderBy('createdAt')
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (createdAtValue instanceof Timestamp && typeof documentIdValue === 'string') {
    query = query.startAfter(createdAtValue, documentIdValue);
  }
  const source = await query.get();
  let created = 0;
  for (const document of source.docs) {
    const result = await ensureEventBookingDelivery(firestore, document.id, nowUtc);
    if (result === 'created') created += 1;
  }
  const last = source.docs.at(-1);
  if (last !== undefined) {
    const lastCreatedAt: unknown = last.get('createdAt');
    if (!(lastCreatedAt instanceof Timestamp)) {
      throw new TypeError('event_outbox_created_at_invalid');
    }
    await checkpointRef.set({
      schemaVersion: 1,
      checkpointId: discoveryCheckpointId,
      lastCreatedAt,
      lastDocumentId: last.id,
      updatedAtUtc: nowUtc,
    });
  }
  return { examined: source.size, created };
}

export async function runPendingEventBookingDeliveries(
  firestore: Firestore,
  nowUtc: string,
  limit = 20,
  gate: EventDeliveryGate = emulatorEventDeliveryGate(firestore),
): Promise<Readonly<{ examined: number; attempted: number; discovered: number }>> {
  assertLimit(limit);
  const enabled = await gate();
  if (!enabled) return { examined: 0, attempted: 0, discovered: 0 };
  const discovery = await discoverEventBookingDeliveries(firestore, nowUtc, 100);
  const due = await firestore
    .collection(eventBookingDeliveryCollections.deliveries)
    .where('status', 'in', ['pending', 'retryPending', 'processing'])
    .where('nextAttemptAtUtc', '<=', nowUtc)
    .orderBy('nextAttemptAtUtc')
    .limit(limit)
    .get();
  let attempted = 0;
  for (const document of due.docs) {
    const result = await deliverEventBookingProjection(
      firestore,
      document.id,
      nowUtc,
      `scheduler:${document.id}`,
    );
    if (result !== 'lease_held') attempted += 1;
  }
  return { examined: due.size, attempted, discovered: discovery.created };
}

function assertLimit(limit: number): void {
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
    throw new TypeError('event_delivery_limit_invalid');
  }
}
