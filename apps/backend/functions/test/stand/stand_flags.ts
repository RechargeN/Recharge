import type { Firestore } from 'firebase-admin/firestore';
import type { FeatureFlagRevision } from '../../src/config/feature_flags.js';
import type { UtcInstant } from '../../src/shared/utc_instant.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import {
  catalogFlagIds,
  contentFlagIds,
  identityFlagIds,
  mediaFlagIds,
} from '../../src/shared/feature_flags.js';
import { standEnabledBookingFlags, standMarketId } from './stand_plan.js';

/**
 * Local-only flag bootstrap. No Firestore FeatureFlagRepository exists yet, so
 * this writes the exact immutable revision and pointer shape that
 * FirestoreFeatureFlagGate reads. It never overwrites a different revision.
 */
export async function enableStandFlags(firestore: Firestore, nowUtc: string): Promise<void> {
  const capabilityIds = [
    identityFlagIds.establishSession,
    mediaFlagIds.upload,
    // C3: Emulator-only Event authoring through Content (stays off by default elsewhere).
    contentFlagIds.eventAuthoring,
    // E2: Emulator-only Discover read and Content → Catalog delivery trigger.
    catalogFlagIds.discoverRead,
    catalogFlagIds.delivery,
    // E2.0: the Event → Booking handoff behind the same trigger.
    contentFlagIds.eventBookingHandoff,
    // D2: delivery gate, Content's reaction and the sweeps (no retention policy on
    // the stand: R2 marks nothing for deletion and deletes nothing).
    mediaFlagIds.delivery,
    contentFlagIds.mediaAvailability,
    mediaFlagIds.reconcile,
    ...standEnabledBookingFlags,
  ];
  for (const capabilityId of capabilityIds) await enableStandFlag(firestore, capabilityId, nowUtc);
}

/**
 * One local flag revision and pointer, in the exact shape FirestoreFeatureFlagGate
 * reads. An existing enabled revision is kept; a different one is a conflict.
 */
export async function enableStandFlag(
  firestore: Firestore,
  capabilityId: string,
  nowUtc: string,
): Promise<void> {
  const key = featureFlagKey('local', standMarketId, capabilityId);
  // createFeatureFlag() rejects mixed-case ids such as booking.eventProjection.delivery,
  // which the Booking gate reads verbatim, so the exact shape is written here.
  const revision: FeatureFlagRevision = {
    schemaVersion: 1,
    revision: 1,
    environmentId: 'local',
    marketId: standMarketId,
    capabilityId,
    enabled: true,
    createdAtUtc: nowUtc as UtcInstant,
  };
  const revisionRef = firestore
    .collection(featureFlagRevisionCollection)
    .doc(featureFlagRevisionDocumentId(key, 1));
  const pointerRef = firestore.collection(featureFlagPointerCollection).doc(key);
  await firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(revisionRef);
    if (existing.exists) {
      if (existing.get('enabled') !== true) throw new Error(`flag_revision_conflict:${key}`);
      return;
    }
    transaction.create(revisionRef, { ...revision });
    transaction.set(pointerRef, { key, activeRevision: 1, pointerRevision: 1 });
  });
}
