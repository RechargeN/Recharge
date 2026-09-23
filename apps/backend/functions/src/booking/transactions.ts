import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

export const bookingCollections = Object.freeze({
  eventProjections: 'bookingEventProjections',
  bookings: 'bookings',
  poolLedgers: 'bookingPoolLedgers',
  userUsage: 'bookingUserUsage',
  activeKeys: 'bookingActiveKeys',
  idempotency: 'bookingIdempotency',
  audit: 'bookingAudit',
  outbox: 'bookingOutbox',
  featureFlags: 'bookingFeatureFlags',
});

export const exactBookingCollectionNames = Object.freeze(Object.values(bookingCollections));

export function runBookingTransaction<T>(
  firestore: Firestore,
  operation: (transaction: Transaction) => Promise<T>,
): Promise<T> {
  return firestore.runTransaction(operation, { maxAttempts: 8 });
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
