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
  return `${occurrenceId}__${poolId}__${channel}`;
}
