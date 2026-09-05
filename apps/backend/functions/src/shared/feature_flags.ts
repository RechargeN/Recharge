import type { Firestore, Transaction } from 'firebase-admin/firestore';

export const bookingFlagIds = Object.freeze({
  create: 'demo-recharge__internal_booking_create_v1',
  cancel: 'demo-recharge__internal_booking_cancel_v1',
  read: 'demo-recharge__internal_booking_read_v1',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];

export async function isBookingFlagEnabled(
  firestore: Firestore,
  transaction: Transaction | undefined,
  flagId: BookingFlagId,
): Promise<boolean> {
  if (process.env.FUNCTIONS_EMULATOR !== 'true' || process.env.GCLOUD_PROJECT !== 'demo-recharge') {
    return false;
  }
  const reference = firestore.collection('bookingFeatureFlags').doc(flagId);
  try {
    const snapshot =
      transaction === undefined ? await reference.get() : await transaction.get(reference);
    const value = snapshot.data();
    return (
      value?.enabled === true && value?.environment === 'emulator' && value?.schemaVersion === 1
    );
  } catch {
    return false;
  }
}
