import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { digest } from '../moderation/application/k1_workflows.js';
import { safetyCollections as c, safetyPolicyRevision } from './safety_policy.js';
/** T&S-owned configurable attempt budget; no automatic enforcement or client authority. */
export async function safetyBudget(
  db: Firestore,
  tx: Transaction,
  actor: string,
  family: string,
  now: Date,
) {
  const bucket = Math.floor(now.getTime() / 60000);
  const ref = db.collection(c.limits).doc(digest([actor, family]));
  const prior = (await tx.get(ref)).data();
  const policy = (await tx.get(db.collection(c.authority).doc('abusePolicy'))).data();
  const cap: unknown = policy?.maxPerMinute;
  const count = prior?.bucket === bucket ? Number(prior.count) : 0;
  return {
    allowed:
      policy?.policyRevision === safetyPolicyRevision &&
      Number.isSafeInteger(cap) &&
      Number(cap) > 0 &&
      Number(cap) <= 1000 &&
      count < Number(cap),
    ref,
    value: { bucket, count: count + 1 },
  };
}
