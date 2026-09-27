import type { Firestore } from 'firebase-admin/firestore';
import { FirestoreFeatureFlagGate } from '../platform/config/firestore_feature_flag_gate.js';
import { bookingFlagIds } from '../shared/feature_flags.js';
import {
  deliverEventBookingProjection,
  eventBookingDeliveryCollections,
} from './event_projection_delivery.js';

export async function processEventBookingOutboxDocument(
  firestore: Firestore,
  outboxId: string,
  nowUtc: string,
): Promise<'disabled' | Awaited<ReturnType<typeof deliverEventBookingProjection>>> {
  const enabled = await new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
    bookingFlagIds.eventProjectionDelivery,
  );
  if (!enabled) return 'disabled';
  return deliverEventBookingProjection(firestore, outboxId, nowUtc);
}

export async function runPendingEventBookingDeliveries(
  firestore: Firestore,
  nowUtc: string,
  limit = 20,
): Promise<Readonly<{ examined: number; attempted: number }>> {
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
    throw new TypeError('event_delivery_limit_invalid');
  }
  const enabled = await new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
    bookingFlagIds.eventProjectionDelivery,
  );
  if (!enabled) return { examined: 0, attempted: 0 };
  const source = await firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .orderBy('createdAtUtc')
    .limit(limit)
    .get();
  let attempted = 0;
  for (const document of source.docs) {
    const delivery = await firestore
      .collection(eventBookingDeliveryCollections.deliveries)
      .doc(document.id)
      .get();
    const status = delivery.get('status');
    const nextAttemptAtUtc = delivery.get('nextAttemptAtUtc');
    if (status === 'delivered' || status === 'deadLetter') continue;
    if (
      typeof nextAttemptAtUtc === 'string' &&
      Number.isFinite(Date.parse(nextAttemptAtUtc)) &&
      Date.parse(nextAttemptAtUtc) > Date.parse(nowUtc)
    ) {
      continue;
    }
    attempted += 1;
    await deliverEventBookingProjection(firestore, document.id, nowUtc);
  }
  return { examined: source.size, attempted };
}
