import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { digest, fail, ok } from '../modules/moderation/application/k1_workflows.js';
export interface SafetyInstruction {
  sanctionId: string;
  revision: number;
  policyRevision: string;
  subjectUserId: string;
  contentId: string | null;
  family: 'warning' | 'contentHide' | 'temporarySuspend' | 'permanentBan';
  desired: 'active' | 'revoked' | 'expired';
  untilUtc: string | null;
  reason: string;
}
/** Owning services receive an immutable, source-verified instruction, never staff collection patches. */
export interface SafetyInstructionVerifier {
  verify(tx: Transaction, input: SafetyInstruction): Promise<boolean>;
}
export async function applyOwnerSafety(
  db: Firestore,
  owner: 'content' | 'catalog' | 'booking',
  verifier: SafetyInstructionVerifier,
  input: SafetyInstruction,
) {
  return db.runTransaction(async (tx) => {
    if (!(await verifier.verify(tx, input))) return fail('instruction_stale');
    const ref = db.collection(owner + 'SafetyHolds').doc(input.sanctionId);
    const old = (await tx.get(ref)).data();
    if (old && Number(old.revision) > input.revision) return fail('instruction_stale');
    if (old && Number(old.revision) === input.revision)
      return old.hash === digest(input)
        ? ok({ owner, revision: input.revision })
        : fail('idempotency_conflict');
    tx.set(ref, { ...input, hash: digest(input) });
    return ok({ owner, revision: input.revision });
  });
}
export async function safetyRestricted(
  db: Firestore,
  owner: 'content' | 'catalog' | 'booking',
  subjectUserId: string,
  now: Date,
  contentId?: string,
  tx?: Transaction,
): Promise<boolean> {
  const queries = [
    db
      .collection(owner + 'SafetyHolds')
      .where('subjectUserId', '==', subjectUserId)
      .where('desired', '==', 'active'),
  ];
  if (contentId)
    queries.push(
      db
        .collection(owner + 'SafetyHolds')
        .where('contentId', '==', contentId)
        .where('desired', '==', 'active'),
    );
  for (const q of queries) {
    const rows = tx ? await tx.get(q.limit(101)) : await q.limit(101).get();
    if (rows.size > 100) return true;
    if (
      rows.docs.some((d) => {
        const h = d.data() as SafetyInstruction;
        if (
          h.desired !== 'active' ||
          h.family === 'warning' ||
          (h.untilUtc !== null && Date.parse(h.untilUtc) <= now.getTime())
        )
          return false;
        return h.family !== 'contentHide' || h.contentId === contentId;
      })
    )
      return true;
  }
  return false;
}
