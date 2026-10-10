import type { Firestore } from 'firebase-admin/firestore';

import {
  contentMediaAvailability,
  deliverMediaEffects,
  reconcileMediaReferences,
} from '../../src/media_effects_entry.js';
import { FirestoreFeatureFlagGate } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';

/**
 * D2 stand command (`stand-seed.mjs media-reconcile`): what a returning worker
 * and the scheduled sweep would do, once — the Media fact consumer, the Content
 * fact verification, then R1 and R2. The stand has no retention policy, so R2
 * deletes nothing (`policy_unavailable`); only the D2 gate uses a test-only one.
 */
export async function runMediaReconcile(firestore: Firestore) {
  const flags = new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
  const mediaEffects = await deliverMediaEffects(firestore, { flags });
  const contentEffects = (await flags.isEnabled(contentFlagIds.mediaAvailability))
    ? await contentMediaAvailability(firestore).deliverContentEffects()
    : 'disabled';
  const sweeps = await reconcileMediaReferences(firestore, { flags });
  return { mediaEffects, contentEffects, ...sweeps };
}
