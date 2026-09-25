import type { Firestore, Transaction } from 'firebase-admin/firestore';

import type { EnvironmentId } from '../../config/environment.js';
import type { MarketId } from '../../config/market_capability.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from './feature_flag_repository.js';

export class FirestoreFeatureFlagGate {
  constructor(
    private readonly firestore: Firestore,
    private readonly environmentId: EnvironmentId,
    private readonly marketId: MarketId,
  ) {}

  async isEnabled(capabilityId: string, transaction?: Transaction): Promise<boolean> {
    if (
      process.env.FUNCTIONS_EMULATOR !== 'true' ||
      process.env.GCLOUD_PROJECT !== 'demo-recharge' ||
      this.environmentId !== 'local'
    ) {
      return false;
    }
    const key = featureFlagKey(this.environmentId, this.marketId, capabilityId);
    const pointerRef = this.firestore.collection(featureFlagPointerCollection).doc(key);
    try {
      const pointerSnapshot =
        transaction === undefined ? await pointerRef.get() : await transaction.get(pointerRef);
      const pointer = pointerSnapshot.data();
      if (
        pointer?.key !== key ||
        !Number.isSafeInteger(pointer.activeRevision) ||
        Number(pointer.activeRevision) < 1
      ) {
        return false;
      }
      const revisionRef = this.firestore
        .collection(featureFlagRevisionCollection)
        .doc(featureFlagRevisionDocumentId(key, Number(pointer.activeRevision)));
      const revisionSnapshot =
        transaction === undefined ? await revisionRef.get() : await transaction.get(revisionRef);
      const revision = revisionSnapshot.data();
      return (
        revision?.schemaVersion === 1 &&
        revision.environmentId === this.environmentId &&
        revision.marketId === this.marketId &&
        revision.capabilityId === capabilityId &&
        revision.revision === pointer.activeRevision &&
        revision.enabled === true
      );
    } catch {
      return false;
    }
  }
}

export function featureFlagRevisionDocumentId(key: string, revision: number): string {
  return `${key}:${revision}`;
}
