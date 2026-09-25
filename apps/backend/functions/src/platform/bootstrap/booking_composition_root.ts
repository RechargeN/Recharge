import type { Firestore } from 'firebase-admin/firestore';

import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../config/firestore_feature_flag_gate.js';

export function createEmulatorBookingCompositionRoot(firestore: Firestore) {
  if (process.env.FUNCTIONS_EMULATOR !== 'true' || process.env.GCLOUD_PROJECT !== 'demo-recharge') {
    throw new Error('booking_emulator_composition_unavailable');
  }
  return Object.freeze({
    accessAuthority: new FirestoreBookingAccessAuthority(firestore),
    featureFlags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
  });
}
