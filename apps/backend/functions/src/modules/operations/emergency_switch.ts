import type { Firestore, Transaction } from 'firebase-admin/firestore';

import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../platform/config/firestore_feature_flag_gate.js';

export type EmergencySwitchState = 'open' | 'contained';

/**
 * L2 emergency switch read (OPS-L2 §5). Unlike an activation flag it fails
 * closed: no pointer means open; a pointer whose revision is missing, foreign
 * or malformed, a read error, or any runtime outside the local Emulator means
 * contained. Read it inside the effect transaction when there is one.
 */
export async function emergencySwitchState(
  firestore: Firestore,
  switchId: string,
  transaction?: Transaction,
): Promise<EmergencySwitchState> {
  if (process.env.FUNCTIONS_EMULATOR !== 'true' || process.env.GCLOUD_PROJECT !== 'demo-recharge')
    return 'contained';
  try {
    const key = featureFlagKey('local', 'LV', switchId);
    const pointerRef = firestore.collection(featureFlagPointerCollection).doc(key);
    const pointer = (
      transaction === undefined ? await pointerRef.get() : await transaction.get(pointerRef)
    ).data();
    if (pointer === undefined) return 'open';
    const activeRevision: unknown = pointer.activeRevision;
    if (
      pointer.key !== key ||
      typeof activeRevision !== 'number' ||
      !Number.isSafeInteger(activeRevision) ||
      activeRevision < 1
    )
      return 'contained';
    const revisionRef = firestore
      .collection(featureFlagRevisionCollection)
      .doc(featureFlagRevisionDocumentId(key, activeRevision));
    const revision = (
      transaction === undefined ? await revisionRef.get() : await transaction.get(revisionRef)
    ).data();
    if (
      revision?.schemaVersion !== 1 ||
      revision.environmentId !== 'local' ||
      revision.marketId !== 'LV' ||
      revision.capabilityId !== switchId ||
      revision.revision !== activeRevision ||
      typeof revision.enabled !== 'boolean'
    )
      return 'contained';
    return revision.enabled ? 'contained' : 'open';
  } catch {
    return 'contained';
  }
}
