import type { Firestore, Transaction } from 'firebase-admin/firestore';
import type { StaffActor } from '../application/ports.js';
import { moderationCollections } from './firestore_moderation_repository.js';
import { staffAuthoritySource } from './emulator_staff_authority.js';
import { identityAuthorityCollections as ids } from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { assertCurrentSession } from '../../identity_publisher/domain/session.js';
import { FirestoreFeatureFlagGate } from '../../../platform/config/firestore_feature_flag_gate.js';
export async function scopedStaffInTransaction(
  db: Firestore,
  tx: Transaction,
  actor: StaffActor,
  typeId: string,
  action: string,
  now: Date,
): Promise<boolean> {
  const [account, session, grant] = await tx.getAll(
    db.collection(ids.accounts).doc(actor.userId),
    db.collection(ids.sessions).doc(actor.sessionId),
    db.collection(moderationCollections.staffAuthority).doc(actor.userId),
  );
  try {
    assertCurrentSession(
      session!.data() as Parameters<typeof assertCurrentSession>[0],
      account!.data() as Parameters<typeof assertCurrentSession>[1],
      now.toISOString(),
    );
  } catch {
    return false;
  }
  const g = grant!.data();
  return (
    g?.userId === actor.userId &&
    g.scope === 'moderation' &&
    g.source === staffAuthoritySource &&
    typeof g.expiresAtUtc === 'string' &&
    Date.parse(g.expiresAtUtc) > now.getTime() &&
    Array.isArray(g.scopes) &&
    g.scopes.some((s: unknown) => {
      if (typeof s !== 'object' || s === null) return false;
      const p = s as Record<string, unknown>;
      return (
        p.marketId === 'LV' &&
        p.typeId === typeId &&
        Array.isArray(p.actions) &&
        p.actions.includes(action)
      );
    }) &&
    (await new FirestoreFeatureFlagGate(db, 'local', 'LV').isEnabled('moderation.staff', tx))
  );
}
