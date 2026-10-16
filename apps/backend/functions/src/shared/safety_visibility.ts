import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { digest } from '../modules/moderation/application/k1_workflows.js';
import { safetyCollections as c } from '../modules/trust_safety/safety_policy.js';
export async function relationEffects(
  db: Firestore,
  viewer: string,
  other: string,
  tx?: Transaction,
) {
  const refs = [
    ['block', viewer, other],
    ['block', other, viewer],
    ['mute', viewer, other],
  ].map(([k, a, b]) => db.collection(c.relations).doc(digest([a, b, k])));
  const rows = tx ? await tx.getAll(...refs) : await db.getAll(...refs);
  return {
    blocked: rows[0]!.get('active') === true || rows[1]!.get('active') === true,
    muted: rows[2]!.get('active') === true,
  };
}
export async function publisherUser(db: Firestore, p: { type: string; id: string }) {
  if (p.type === 'user') return p.id;
  if (p.type !== 'page') return null;
  const owner = (await db.collection('identityManagedPages').doc(p.id).get()).get(
    'ownerUserId',
  ) as unknown;
  return typeof owner === 'string' ? owner : null;
}
/** Reserved owner-facing policy: never expose incoming block records to the client. */
export async function interactionAllowed(db: Firestore, viewer: string, other: string) {
  return !(await relationEffects(db, viewer, other)).blocked;
}
