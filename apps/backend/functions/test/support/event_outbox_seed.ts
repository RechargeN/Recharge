import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import { eventBookingDeliveryCollections } from '../../src/booking/event_projection_delivery.js';

export async function seedEventBookingOutbox(
  firestore: Firestore,
  input: Readonly<{
    outboxId: string;
    event: EventBookingProjectionEvent;
  }>,
): Promise<'created' | 'replayed' | 'conflict'> {
  const ref = firestore
    .collection(eventBookingDeliveryCollections.sourceOutbox)
    .doc(input.outboxId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      const existingEvent: unknown = snapshot.get('event');
      return JSON.stringify(existingEvent) === JSON.stringify(input.event)
        ? ('replayed' as const)
        : ('conflict' as const);
    }
    transaction.create(ref, {
      schemaVersion: 1,
      outboxId: input.outboxId,
      event: input.event,
      createdAt: FieldValue.serverTimestamp(),
    });
    return 'created' as const;
  });
}
