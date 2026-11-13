import {
  FieldPath,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type { PrivacyPolicyBlocker } from '../domain/privacy_domain_task.js';
import { privacyHoldApplies, type PrivacyLegalHold } from '../domain/privacy_legal_hold.js';
import type { PrivacyErasureRule } from '../domain/privacy_writer_registry.js';
import { privacyHoldCollections } from './firestore_privacy_legal_hold_service.js';
import { privacyOrchestrationCollections } from './firestore_privacy_orchestration_repository.js';

export const privacyProgressCollection = 'privacyTaskProgress';

/** What an owning module did with one record of the subject. */
export type PrivacyApplyOutcome =
  'erased' | 'unchanged' | { readonly blocked: PrivacyPolicyBlocker };

/** A decided effect; `write` runs after every read of the page transaction. */
export interface PrivacyPlannedEffect {
  readonly outcome: PrivacyApplyOutcome;
  readonly write?: () => void;
}

/**
 * The owning module's effect for one record. `inTransaction` reads and decides
 * inside the page transaction after the hold check; its write runs once all
 * reads of the page are done, so the effect and the checkpoint commit together.
 * `external` is for an owner protocol with transactions of its own (Media
 * deletion); the checkpoint then follows its confirmed result.
 */
export interface PrivacyApplier {
  inTransaction?(
    tx: Transaction,
    ref: DocumentReference,
    data: Record<string, unknown>,
  ): Promise<PrivacyPlannedEffect>;
  external?(id: string, data: Record<string, unknown>): Promise<PrivacyApplyOutcome | 'retry'>;
}

export interface PrivacySweepFamily {
  readonly collection: string;
  readonly subjectField: string;
  readonly rule: PrivacyErasureRule;
  readonly applier?: PrivacyApplier;
}

export type PrivacyFaultPoint = 'page' | 'before_checkpoint' | 'verify';

export type PrivacySweepResult =
  | {
      readonly kind: 'done';
      readonly recordCount: number;
      readonly erasedCount: number;
      readonly retainedCount: number;
      readonly blockedCodes: readonly PrivacyPolicyBlocker[];
    }
  | { readonly kind: 'progress' }
  | { readonly kind: 'retry' }
  | { readonly kind: 'lease_lost' };

interface Progress {
  readonly taskId: string;
  readonly domainId: string;
  readonly policyRevision: string;
  readonly mode: 'access' | 'erasure';
  readonly phase: 'sweep' | 'verify';
  readonly familyIndex: number;
  readonly cursor: string | null;
  readonly dirty: boolean;
  readonly recordCount: number;
  readonly erasedCount: number;
  readonly retainedCount: number;
  readonly blockedCodes: readonly PrivacyPolicyBlocker[];
  readonly updatedAtUtc: string;
}

class PrivacyLeaseLost extends Error {
  constructor() {
    super('privacy_lease_lost');
  }
}

/**
 * L1 paged sweep over one domain's registry families for one subject.
 *
 * Order is stable (document ID within each family). Each page is one
 * transaction that re-reads the task lease and the subject's active holds, so
 * a hold or a takeover that lands concurrently aborts the page before any
 * effect. The checkpoint commits only with (or after) the confirmed owner
 * effect; a failed write never advances it. After the sweep a verification
 * pass starts again from the first record of every family: a record inserted
 * behind the cursor, or missed by a concurrent change, is processed there, and
 * passes repeat until one makes no change. Work per run is bounded by
 * `maxPages`; the next run resumes from the stored checkpoint.
 */
export async function sweepPrivacySubject(input: {
  readonly db: Firestore;
  readonly taskId: string;
  readonly leaseOwner: string;
  readonly domainId: string;
  readonly subjectId: string;
  readonly mode: 'access' | 'erasure';
  readonly policyRevision: string;
  readonly nowUtc: string;
  readonly families: readonly PrivacySweepFamily[];
  readonly pageSize?: number;
  readonly maxPages?: number;
  readonly fault?: (point: PrivacyFaultPoint) => void;
}): Promise<PrivacySweepResult> {
  const { db } = input;
  const pageSize = input.pageSize ?? 100;
  const maxPages = input.maxPages ?? 50;
  const progressRef = db.collection(privacyProgressCollection).doc(input.taskId);
  const stored = (await progressRef.get()).data() as Progress | undefined;
  // A new policy revision or another mode starts the sweep over.
  let progress: Progress =
    stored !== undefined &&
    stored.policyRevision === input.policyRevision &&
    stored.mode === input.mode
      ? stored
      : fresh(input);
  for (let pages = 0; pages < maxPages; pages += 1) {
    if (progress.familyIndex >= input.families.length) {
      const next = advancePass(progress, input.mode);
      if (next === 'done') {
        return {
          kind: 'done',
          recordCount: progress.recordCount,
          erasedCount: progress.erasedCount,
          retainedCount: progress.retainedCount,
          blockedCodes: progress.blockedCodes,
        };
      }
      progress = { ...next, updatedAtUtc: input.nowUtc };
      const passStart = progress;
      try {
        await db.runTransaction(async (tx) => {
          await assertLease(db, tx, input);
          tx.set(progressRef, passStart);
        });
      } catch (error) {
        if (error instanceof PrivacyLeaseLost) return { kind: 'lease_lost' };
        throw error;
      }
      continue;
    }
    if (progress.phase === 'verify') input.fault?.('verify');
    const family = input.families[progress.familyIndex]!;
    const before = progress;
    let page: {
      readonly next: Progress;
      readonly external: readonly [string, Record<string, unknown>][];
    };
    try {
      page = await db.runTransaction(async (tx) => {
        await assertLease(db, tx, input);
        let query = db
          .collection(family.collection)
          .where(subjectPath(family.subjectField, input.subjectId), '==', input.subjectId)
          .orderBy(FieldPath.documentId())
          .limit(pageSize);
        if (before.cursor !== null) query = query.startAfter(before.cursor);
        const snapshot = await tx.get(query);
        const holds = input.mode === 'erasure' ? await activeHolds(db, tx, input.subjectId) : [];
        input.fault?.('page');
        let next: Progress = before;
        const external: [string, Record<string, unknown>][] = [];
        const writes: (() => void)[] = [];
        for (const document of snapshot.docs) {
          const data = document.data();
          const counting = before.phase === 'sweep';
          if (counting) next = { ...next, recordCount: next.recordCount + 1 };
          if (input.mode === 'access') continue;
          const held = holds.some((hold) =>
            privacyHoldApplies(hold, {
              domainId: input.domainId,
              collection: family.collection,
              recordId: document.id,
            }),
          );
          if (held) {
            if (counting) next = { ...next, retainedCount: next.retainedCount + 1 };
            continue;
          }
          const rule = family.rule;
          if (rule.kind === 'blocked') {
            next = withBlocked(next, rule.blocker);
            continue;
          }
          if (rule.kind !== 'delete' && rule.kind !== 'anonymize') continue;
          if (family.applier?.inTransaction !== undefined) {
            const planned = await family.applier.inTransaction(tx, document.ref, data);
            next = tally(next, planned.outcome);
            if (planned.write !== undefined) writes.push(planned.write);
          } else if (family.applier?.external !== undefined) {
            external.push([document.id, data]);
          } else {
            // A registered effect without an owner applier is never reported as done.
            next = withBlocked(next, 'PB-05');
          }
        }
        const lastId = snapshot.docs.at(-1)?.id ?? null;
        next =
          snapshot.size < pageSize
            ? { ...next, familyIndex: next.familyIndex + 1, cursor: null }
            : { ...next, cursor: lastId };
        next = { ...next, updatedAtUtc: input.nowUtc };
        for (const write of writes) write();
        if (external.length === 0) tx.set(progressRef, next);
        return { next, external };
      });
    } catch (error) {
      if (error instanceof PrivacyLeaseLost) return { kind: 'lease_lost' };
      throw error;
    }
    let next = page.next;
    if (page.external.length > 0) {
      for (const [id, data] of page.external) {
        // The external owner protocol runs outside the page transaction: the
        // subject's holds are read again immediately before its effect.
        const holds = await activeHolds(db, undefined, input.subjectId);
        if (
          holds.some((hold) =>
            privacyHoldApplies(hold, {
              domainId: input.domainId,
              collection: family.collection,
              recordId: id,
            }),
          )
        ) {
          if (before.phase === 'sweep') next = { ...next, retainedCount: next.retainedCount + 1 };
          continue;
        }
        const outcome = await family.applier!.external!(id, data);
        if (outcome === 'retry') return { kind: 'retry' };
        next = tally(next, outcome);
      }
      input.fault?.('before_checkpoint');
      const committed = next;
      try {
        await db.runTransaction(async (tx) => {
          await assertLease(db, tx, input);
          tx.set(progressRef, committed);
        });
      } catch (error) {
        if (error instanceof PrivacyLeaseLost) return { kind: 'lease_lost' };
        throw error;
      }
    }
    progress = next;
  }
  return { kind: 'progress' };
}

/** `$id` is the document ID; `{subject}` in a path is the subject's own map key. */
function subjectPath(field: string, subjectId: string): string | FieldPath {
  if (field === '$id') return FieldPath.documentId();
  if (!field.includes('{subject}')) return field;
  return new FieldPath(
    ...field.split('.').map((part) => (part === '{subject}' ? subjectId : part)),
  );
}

function fresh(input: {
  readonly taskId: string;
  readonly domainId: string;
  readonly policyRevision: string;
  readonly mode: 'access' | 'erasure';
  readonly nowUtc: string;
}): Progress {
  return {
    taskId: input.taskId,
    domainId: input.domainId,
    policyRevision: input.policyRevision,
    mode: input.mode,
    phase: 'sweep',
    familyIndex: 0,
    cursor: null,
    dirty: false,
    recordCount: 0,
    erasedCount: 0,
    retainedCount: 0,
    blockedCodes: [],
    updatedAtUtc: input.nowUtc,
  };
}

/** After the last family: start verification, repeat it while it changed something, or finish. */
function advancePass(progress: Progress, mode: 'access' | 'erasure'): Progress | 'done' {
  if (mode === 'access') return 'done';
  if (progress.phase === 'sweep' || progress.dirty)
    return { ...progress, phase: 'verify', familyIndex: 0, cursor: null, dirty: false };
  return 'done';
}

function tally(progress: Progress, outcome: PrivacyApplyOutcome): Progress {
  if (outcome === 'unchanged') return progress;
  if (outcome === 'erased')
    return {
      ...progress,
      erasedCount: progress.erasedCount + 1,
      // A change found during verification means another pass is needed.
      dirty: progress.phase === 'verify' ? true : progress.dirty,
    };
  return withBlocked(progress, outcome.blocked);
}

function withBlocked(progress: Progress, code: PrivacyPolicyBlocker): Progress {
  return progress.blockedCodes.includes(code)
    ? progress
    : { ...progress, blockedCodes: [...progress.blockedCodes, code].sort() };
}

async function assertLease(
  db: Firestore,
  tx: Transaction,
  input: { readonly taskId: string; readonly leaseOwner: string; readonly nowUtc: string },
): Promise<void> {
  const task = (
    await tx.get(db.collection(privacyOrchestrationCollections.tasks).doc(input.taskId))
  ).data();
  if (
    task?.status !== 'dispatched' ||
    task.leaseOwner !== input.leaseOwner ||
    typeof task.leaseExpiresAtUtc !== 'string' ||
    Date.parse(task.leaseExpiresAtUtc) <= Date.parse(input.nowUtc)
  )
    throw new PrivacyLeaseLost();
}

async function activeHolds(
  db: Firestore,
  tx: Transaction | undefined,
  subjectId: string,
): Promise<readonly PrivacyLegalHold[]> {
  const query = db
    .collection(privacyHoldCollections.holds)
    .where('subjectId', '==', subjectId)
    .where('status', '==', 'active');
  const snapshot = tx === undefined ? await query.get() : await tx.get(query);
  return snapshot.docs.map((document) => document.data() as PrivacyLegalHold);
}
