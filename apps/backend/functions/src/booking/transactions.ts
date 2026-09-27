import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

export const bookingCollections = Object.freeze({
  eventProjections: 'bookingEventProjections',
  bookings: 'bookings',
  holds: 'bookingHolds',
  poolLedgers: 'bookingPoolLedgers',
  userUsage: 'bookingUserUsage',
  activeKeys: 'bookingActiveKeys',
  idempotency: 'bookingIdempotency',
  audit: 'bookingAudit',
  outbox: 'bookingOutbox',
});

export const exactBookingCollectionNames = Object.freeze(Object.values(bookingCollections));

export function runBookingTransaction<T>(
  firestore: Firestore,
  operation: (transaction: Transaction) => Promise<T>,
): Promise<T> {
  // Same-scope dedupe and inventory allocation deliberately serialize on one
  // authoritative record. A bounded 100-way burst can exhaust Firestore's
  // small default retry budget before the winning commit becomes visible.
  return firestore.runTransaction(operation, { maxAttempts: 16 });
}

export function finitePoolLedgerId(occurrenceId: string, poolId: string, channel: string): string {
  const canonical = [occurrenceId, poolId, channel]
    .map((part) => `${Buffer.byteLength(part, 'utf8')}:${part}`)
    .join('|');
  const digest = createHash('sha256')
    .update(`booking_pool_ledger_v2|${canonical}`, 'utf8')
    .digest('hex');
  return `bpl2_${digest}`;
}

export function bookingUserUsageId(actorId: string, marketId: 'LV' | 'EE' | 'LT'): string {
  const canonical = [actorId, marketId]
    .map((part) => `${Buffer.byteLength(part, 'utf8')}:${part}`)
    .join('|');
  const digest = createHash('sha256')
    .update(`booking_user_usage_v2|${canonical}`, 'utf8')
    .digest('hex');
  return `buu2_${digest}`;
}
