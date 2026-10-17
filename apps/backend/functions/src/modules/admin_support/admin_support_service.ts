import { randomUUID } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import type { ServerClock } from '../../shared/server_clock.js';
import type { StaffActor, ContentModerationPort } from '../moderation/application/ports.js';
import type { ModerationService } from '../moderation/application/moderation_service.js';
import { scopedStaffInTransaction } from '../moderation/infrastructure/scoped_staff_transaction.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { digest, exact, object } from '../moderation/application/k1_workflows.js';
import { isEntityId } from '../../shared/ids.js';

export const adminCollections = Object.freeze({
  cases: 'adminSupportCases',
  proposals: 'adminRepairProposals',
  approvals: 'adminRepairApprovals',
  executions: 'adminRepairExecutions',
  audit: 'adminReadAudit',
});
export const adminActions = Object.freeze({
  read: 'adminRead',
  propose: 'adminPropose',
  approve: 'adminApprove',
  execute: 'adminExecute',
});
interface Target {
  contentId: string;
  expectedRevision: number;
  action: 'restrict' | 'restore';
  restoresDecisionId?: string;
}
interface Proposal {
  proposalId: string;
  revision: number;
  caseId: string;
  reason: string;
  targets: Target[];
  proposer: StaffActor;
  caseHash: string;
  hash: string;
  createdAtUtc: string;
}
interface Approval {
  proposalHash: string;
  approver: StaffActor;
  expiresAtUtc: string;
}
interface Step {
  state: 'pending' | 'unknown' | 'completed' | 'refused';
  receiptId?: string;
  pointerRevision?: number | null;
  code?: string;
}
interface Execution {
  executor: StaffActor;
  steps: Step[];
}
interface Case {
  status: string;
  marketId: string;
  typeId: string;
  contentIds: string[];
  members: Record<string, string[]>;
  approvalTtlMs: number;
  policy: string;
}
const denied = (code: string) => ({ kind: 'rejected' as const, code });
const success = <T>(data: T) => ({ kind: 'succeeded' as const, data });
const key = (id: string, revision: number) => digest([id, revision]);
const validRevision = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0;
function parse(
  raw: unknown,
): Pick<Proposal, 'proposalId' | 'revision' | 'caseId' | 'reason' | 'targets'> | null {
  const p = object(raw);
  if (
    !p ||
    !exact(p, ['proposalId', 'revision', 'caseId', 'reason', 'targets']) ||
    !isEntityId(p.proposalId) ||
    !isEntityId(p.caseId) ||
    !validRevision(p.revision) ||
    typeof p.reason !== 'string' ||
    p.reason.length < 3 ||
    p.reason.length > 500 ||
    !Array.isArray(p.targets) ||
    p.targets.length < 1 ||
    p.targets.length > 10
  )
    return null;
  const seen = new Set<string>();
  for (const raw of p.targets) {
    const t = object(raw);
    if (
      !t ||
      !exact(t, ['contentId', 'expectedRevision', 'action', 'restoresDecisionId']) ||
      !isEntityId(t.contentId) ||
      !validRevision(t.expectedRevision) ||
      !['restrict', 'restore'].includes(String(t.action)) ||
      seen.has(t.contentId) ||
      (t.action === 'restore'
        ? !isEntityId(t.restoresDecisionId)
        : t.restoresDecisionId !== undefined)
    )
      return null;
    seen.add(t.contentId);
  }
  return structuredClone(p) as ReturnType<typeof parse>;
}

/** Local-only K3 orchestration. No HTTP export, default policy, generic patch or domain storage writes. */
export class AdminSupportService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    private readonly owner: ModerationService,
    private readonly content: ContentModerationPort,
    /** Test-only crash injection, never a client parameter. */
    private readonly afterOwner: () => void = () => {},
  ) {
    assertContentEmulatorContext(db);
  }

  private async access(
    tx: Transaction,
    actor: StaffActor,
    caseId: string,
    action: string,
    targets: readonly string[],
  ) {
    const c = (await tx.get(this.db.collection(adminCollections.cases).doc(caseId))).data() as
      Case | undefined;
    if (
      !c ||
      c.policy !== 'test-only-k3-two-person-v1' ||
      c.status !== 'active' ||
      c.marketId !== 'LV' ||
      typeof c.typeId !== 'string' ||
      !Array.isArray(c.contentIds) ||
      !targets.every((id) => c.contentIds.includes(id)) ||
      !Array.isArray(c.members?.[actor.userId]) ||
      !c.members[actor.userId]!.includes(action) ||
      !Number.isSafeInteger(c.approvalTtlMs) ||
      c.approvalTtlMs <= 0 ||
      c.approvalTtlMs > 3600000 ||
      !(await scopedStaffInTransaction(this.db, tx, actor, c.typeId, action, this.clock.now()))
    )
      return null;
    return c;
  }
  private audit(
    tx: Transaction,
    actor: StaffActor,
    caseId: string,
    operation: string,
    refs: string[],
    outcome: 'allow' | 'deny' = 'allow',
  ) {
    tx.create(this.db.collection(adminCollections.audit).doc(randomUUID()), {
      outcome,
      actorId: actor.userId,
      sessionId: actor.sessionId,
      caseId,
      operation,
      refs,
      fieldProfile: 'k3-publication-state-v1',
      atUtc: this.clock.now().toISOString(),
      environment: 'local',
      purpose: 'local-repair-validation',
      policy: 'test-only-k3-two-person-v1',
    });
  }
  async reveal(actor: StaffActor, caseId: string, contentId: string) {
    if (!isEntityId(caseId) || !isEntityId(contentId)) return denied('invalid_contract');
    try {
      return await this.db.runTransaction(async (tx) => {
        const c = await this.access(tx, actor, caseId, adminActions.read, [contentId]);
        if (!c) {
          this.audit(tx, actor, caseId, 'reveal', [contentId], 'deny');
          return denied('access_denied');
        }
        const publication = await this.content.publication(contentId);
        if (publication?.marketId !== c.marketId || publication?.typeId !== c.typeId)
          return denied('target_unavailable');
        if (!publication) return denied('target_unavailable');
        this.audit(tx, actor, caseId, 'reveal', [contentId]);
        return success({
          contentId,
          revision: publication.pointerRevision,
          visibility: publication.visibility,
        });
      });
    } catch {
      return denied('audit_or_source_unavailable');
    }
  }
  async propose(actor: StaffActor, raw: unknown) {
    const p = parse(raw);
    if (!p) return denied('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const c = await this.access(
        tx,
        actor,
        p.caseId,
        adminActions.propose,
        p.targets.map((t) => t.contentId),
      );
      if (!c) return denied('access_denied');
      const ref = this.db.collection(adminCollections.proposals).doc(key(p.proposalId, p.revision));
      const prior = (await tx.get(ref)).data() as Proposal | undefined;
      const frozen = { ...p, proposer: actor, caseHash: digest(c) };
      const hash = digest(frozen);
      if (prior)
        return prior.hash === hash
          ? success({ proposalId: p.proposalId, revision: p.revision, hash })
          : denied('immutable_conflict');
      tx.create(ref, { ...frozen, hash, createdAtUtc: this.clock.now().toISOString() });
      this.audit(
        tx,
        actor,
        p.caseId,
        'propose',
        p.targets.map((t) => t.contentId),
      );
      return success({ proposalId: p.proposalId, revision: p.revision, hash });
    });
  }
  private valid(p: Proposal) {
    const { hash, createdAtUtc: _at, ...body } = p;
    void _at;
    return (
      digest(body) === hash &&
      parse({
        proposalId: p.proposalId,
        revision: p.revision,
        caseId: p.caseId,
        reason: p.reason,
        targets: p.targets,
      }) !== null
    );
  }
  async approve(actor: StaffActor, proposalId: string, revision: number) {
    if (!isEntityId(proposalId) || !validRevision(revision)) return denied('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const id = key(proposalId, revision);
      const p = (await tx.get(this.db.collection(adminCollections.proposals).doc(id))).data() as
        Proposal | undefined;
      if (!p || !this.valid(p)) return denied('proposal_invalid');
      const c = await this.access(
        tx,
        actor,
        p.caseId,
        adminActions.approve,
        p.targets.map((t) => t.contentId),
      );
      if (!c || digest(c) !== p.caseHash) return denied('access_denied');
      if (p.proposer.userId === actor.userId) return denied('self_approval');
      const ref = this.db.collection(adminCollections.approvals).doc(id);
      const prior = (await tx.get(ref)).data() as Approval | undefined;
      if (prior)
        return prior.proposalHash === p.hash && prior.approver.userId === actor.userId
          ? success({ proposalId, revision })
          : denied('approval_conflict');
      tx.create(ref, {
        proposalHash: p.hash,
        approver: actor,
        expiresAtUtc: new Date(this.clock.now().getTime() + c.approvalTtlMs).toISOString(),
      });
      this.audit(tx, actor, p.caseId, 'approve', [proposalId]);
      return success({ proposalId, revision });
    });
  }
  private async authorizedExecution(tx: Transaction, actor: StaffActor, id: string) {
    const [proposal, approval, execution] = await tx.getAll(
      this.db.collection(adminCollections.proposals).doc(id),
      this.db.collection(adminCollections.approvals).doc(id),
      this.db.collection(adminCollections.executions).doc(id),
    );
    const p = proposal!.data() as Proposal | undefined;
    const a = approval!.data() as Approval | undefined;
    const e = execution!.data() as Execution | undefined;
    if (
      !p ||
      !this.valid(p) ||
      !a ||
      a.proposalHash !== p.hash ||
      a.approver.userId === p.proposer.userId ||
      !Number.isFinite(Date.parse(a.expiresAtUtc)) ||
      Date.parse(a.expiresAtUtc) <= this.clock.now().getTime()
    )
      return null;
    const targets = p.targets.map((t) => t.contentId);
    const c = await this.access(tx, actor, p.caseId, adminActions.execute, targets);
    if (
      !c ||
      digest(c) !== p.caseHash ||
      !(await this.access(tx, a.approver, p.caseId, adminActions.approve, targets)) ||
      (e && digest(e.executor) !== digest(actor))
    )
      return null;
    for (const target of p.targets) {
      if (
        !(await scopedStaffInTransaction(
          this.db,
          tx,
          actor,
          c.typeId,
          target.action,
          this.clock.now(),
        ))
      )
        return null;
    }
    return { p, e };
  }
  async execute(actor: StaffActor, proposalId: string, revision: number) {
    if (!isEntityId(proposalId) || !validRevision(revision)) return denied('invalid_contract');
    const id = key(proposalId, revision);
    const ref = this.db.collection(adminCollections.executions).doc(id);
    const start = await this.db.runTransaction(async (tx) => {
      const current = await this.authorizedExecution(tx, actor, id);
      if (!current) return null;
      if (!current.e) {
        tx.create(ref, {
          executor: actor,
          steps: current.p.targets.map(() => ({ state: 'pending' })),
          status: 'pending',
        });
        this.audit(tx, actor, current.p.caseId, 'execute', [proposalId]);
      }
      return current.p;
    });
    if (!start) return denied('execution_denied');
    for (let i = 0; i < start.targets.length; i++) {
      const ready = await this.db.runTransaction(async (tx) => {
        const current = await this.authorizedExecution(tx, actor, id);
        if (!current?.e) return null;
        if (current.e.steps[i]?.state === 'completed') return { skip: true, p: current.p };
        tx.update(ref, {
          status: 'partiallyCompleted',
          steps: current.e.steps.map((s, j) => (j === i ? { state: 'unknown' } : s)),
        });
        return { skip: false, p: current.p };
      });
      if (!ready) return denied('execution_denied');
      if (ready.skip) continue;
      const t = ready.p.targets[i]!;
      let step: Step;
      try {
        const result = await this.owner.decide(actor, {
          schemaVersion: 1,
          action: t.action,
          reason: ready.p.reason,
          target: { contentId: t.contentId, expectedRevision: t.expectedRevision },
          idempotencyKey: `k3-${id}-${i}`,
          ...(t.restoresDecisionId ? { restoresDecisionId: t.restoresDecisionId } : {}),
        });
        this.afterOwner();
        step =
          result.kind === 'succeeded' && result.data.receipt.outcome !== 'refused'
            ? {
                state: 'completed',
                receiptId: result.data.receipt.receiptId,
                pointerRevision: result.data.receipt.pointerRevision,
              }
            : {
                state:
                  result.kind === 'rejected' && result.code === 'unknown_outcome'
                    ? 'unknown'
                    : 'refused',
                code: result.kind === 'rejected' ? result.code : 'owner_refused',
              };
      } catch {
        return this.state(actor, proposalId, revision);
      }
      await this.db.runTransaction(async (tx) => {
        const row = (await tx.get(ref)).data() as Execution;
        // Concurrent retries cannot downgrade a completed step or overwrite another target.
        if (row.steps[i]?.state === 'completed') return;
        const steps = row.steps.map((s, j) => (j === i ? step : s));
        tx.update(ref, {
          steps,
          status: steps.every((s) => s.state === 'completed') ? 'completed' : 'partiallyCompleted',
        });
      });
      if (step.state !== 'completed') break;
    }
    return this.state(actor, proposalId, revision);
  }
  async state(actor: StaffActor, proposalId: string, revision: number) {
    if (!isEntityId(proposalId) || !validRevision(revision)) return denied('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const id = key(proposalId, revision);
      const p = (await tx.get(this.db.collection(adminCollections.proposals).doc(id))).data() as
        Proposal | undefined;
      if (
        !p ||
        !(await this.access(
          tx,
          actor,
          p.caseId,
          adminActions.read,
          p.targets.map((t) => t.contentId),
        ))
      )
        return denied('access_denied');
      const e = (await tx.get(this.db.collection(adminCollections.executions).doc(id))).data() as
        Execution | undefined;
      this.audit(tx, actor, p.caseId, 'executionState', [proposalId]);
      const steps = e?.steps ?? p.targets.map((): Step => ({ state: 'pending' }));
      const status = steps.every((s) => s.state === 'completed')
        ? 'completed'
        : 'partiallyCompleted';
      return status === 'completed'
        ? success({ status, steps })
        : { kind: 'pending' as const, data: { status, steps } };
    });
  }
}
