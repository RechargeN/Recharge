import type { ServerClock } from '../../shared/server_clock.js';
import type { PrivacyApplier } from '../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import { relationRecord } from './safety_policy.js';

/**
 * L1 erasure (PB-00): the subject's own block and mute relations end through
 * the owner command's own effect, an inactive relation at the next revision.
 * The row stays as that command leaves it; relations of other people that name
 * the subject are their data and are not touched here (registry: PB-09).
 */
export function safetyPrivacyAppliers(clock: ServerClock): Record<string, PrivacyApplier> {
  return {
    'safetyRelations:ownerId': {
      inTransaction(tx, ref, data) {
        if (data.active !== true) return Promise.resolve({ outcome: 'unchanged' });
        const row = relationRecord({
          ownerId: String(data.ownerId),
          targetUserId: String(data.targetUserId),
          kind: String(data.kind),
          active: false,
          revision: Number(data.revision ?? 0) + 1,
          nowUtc: clock.now().toISOString(),
        });
        return Promise.resolve({ outcome: 'erased', write: () => tx.set(ref, row) });
      },
    },
  };
}
