import type { Firestore } from 'firebase-admin/firestore';

import { runPendingEventBookingDeliveries } from '../../src/booking/event_projection_runtime.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';

/**
 * Stand commands for the Event → Booking handoff (E2.0). Every action goes
 * through the handoff application layer or the existing Booking delivery
 * runtime; this file never writes an outbox record or a projection itself.
 */
export async function runHandoff(firestore: Firestore, args: readonly string[]): Promise<unknown> {
  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  const [action, first] = args;
  if (action === 'deliver') return handoff.deliver();
  if (action === 'reconcile') return handoff.reconcile();
  if (action === 'status') return repository.transact((tx) => tx.status());
  if (action === 'state' && first !== undefined)
    return repository.transact((tx) => tx.state(first));
  if (action === 'repair' && first !== undefined) return handoff.repairContent(first);
  throw new Error(
    'usage: handoff deliver | reconcile | status | state <contentId> | repair <contentId>',
  );
}

/**
 * Resumes Booking's own pending or retrying deliveries (the Emulator does not
 * run the retry schedule by itself). Delivery records stay Booking's.
 */
export function runBookingDeliver(firestore: Firestore): Promise<unknown> {
  return runPendingEventBookingDeliveries(firestore, new Date().toISOString(), 20);
}
