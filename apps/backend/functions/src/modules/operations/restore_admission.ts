import { createHash } from 'node:crypto';
import { FieldPath, type Firestore } from 'firebase-admin/firestore';

import type { ServerClock } from '../../shared/server_clock.js';
import { privacyDomainTaskId } from '../privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyDomainTaskRunner } from '../privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from '../privacy_orchestration/application/privacy_orchestration_service.js';
import {
  FirestorePrivacyOrchestrationRepository,
  privacyOrchestrationCollections,
} from '../privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';

/**
 * L2 restore admission gate (OPS-L2 §6). It does not restore anything: there is
 * no accepted backup runtime (OB-04). Given a copy already placed in an isolated
 * named database, it re-applies every erasure and restriction decision of the
 * deletion authority through the L1 owner runner bound to that copy, and only
 * then may the copy be admitted. When the authority is unavailable, older than
 * the restore, or any decision cannot be re-applied, the copy stays closed.
 */
export interface DeletionAuthorityDecision {
  readonly requestId: string;
  readonly subjectId: string;
  readonly requestType: 'erasure' | 'restriction';
}

export interface DeletionAuthoritySnapshot {
  /** The moment the authority answered for; must not precede the restore. */
  readonly asOfUtc: string;
  readonly decisions: readonly DeletionAuthorityDecision[];
}

export interface DeletionAuthorityPort {
  snapshot(): Promise<DeletionAuthoritySnapshot>;
}

export type ReapplyOutcome = 'completed' | 'retained' | 'failed';

export interface RedeletionPort {
  reapply(decision: DeletionAuthorityDecision, nowUtc: string): Promise<ReapplyOutcome>;
}

export type RestoreAdmission =
  | {
      readonly state: 'closed';
      readonly reason: 'not_isolated' | 'deletion_authority_unavailable' | 'redeletion_failed';
      readonly decisions: number;
      readonly failed: number;
    }
  /** Every decision re-applied, but L1 keeps blocked or held records (PB codes). */
  | { readonly state: 'incomplete'; readonly decisions: number; readonly retained: number }
  | { readonly state: 'admitted'; readonly decisions: number };

export async function admitRestoredCopy(input: {
  readonly restored: Firestore;
  readonly liveDatabaseId: string;
  readonly restoreStartedAtUtc: string;
  readonly authority: DeletionAuthorityPort;
  readonly redeletion: RedeletionPort;
  readonly clock: ServerClock;
}): Promise<RestoreAdmission> {
  const databaseId = input.restored.databaseId;
  if (databaseId === '(default)' || databaseId === input.liveDatabaseId)
    return { state: 'closed', reason: 'not_isolated', decisions: 0, failed: 0 };
  let snapshot: DeletionAuthoritySnapshot;
  try {
    snapshot = await input.authority.snapshot();
  } catch {
    return { state: 'closed', reason: 'deletion_authority_unavailable', decisions: 0, failed: 0 };
  }
  if (
    !Number.isFinite(Date.parse(snapshot.asOfUtc)) ||
    Date.parse(snapshot.asOfUtc) < Date.parse(input.restoreStartedAtUtc)
  )
    return { state: 'closed', reason: 'deletion_authority_unavailable', decisions: 0, failed: 0 };
  let failed = 0;
  let retained = 0;
  for (const decision of snapshot.decisions) {
    let outcome: ReapplyOutcome;
    try {
      outcome = await input.redeletion.reapply(decision, input.clock.now().toISOString());
    } catch {
      outcome = 'failed';
    }
    if (outcome === 'failed') failed += 1;
    if (outcome === 'retained') retained += 1;
  }
  const decisions = snapshot.decisions.length;
  if (failed > 0) return { state: 'closed', reason: 'redeletion_failed', decisions, failed };
  if (retained > 0) return { state: 'incomplete', decisions, retained };
  return { state: 'admitted', decisions };
}

const decidedStatuses = new Set([
  'verified',
  'dispatched',
  'partially_completed',
  'completed',
  'completedWithRetention',
  'failed',
]);

/**
 * Local deletion authority: verified erasure and restriction requests of the
 * live database, read in bounded pages. In production this would have to be a
 * ledger that survives the restore of the live database itself (PB-15, OB-04).
 */
export class FirestoreDeletionAuthority implements DeletionAuthorityPort {
  constructor(
    private readonly live: Firestore,
    private readonly clock: ServerClock,
    private readonly pageSize = 200,
  ) {}

  async snapshot(): Promise<DeletionAuthoritySnapshot> {
    const decisions: DeletionAuthorityDecision[] = [];
    let after: string | undefined;
    for (;;) {
      let query = this.live
        .collection(privacyOrchestrationCollections.requests)
        .orderBy(FieldPath.documentId())
        .limit(this.pageSize);
      if (after !== undefined) query = query.startAfter(after);
      const page = await query.get();
      for (const document of page.docs) {
        const value = document.data() as Readonly<Record<string, unknown>>;
        if (
          (value.requestType === 'erasure' || value.requestType === 'restriction') &&
          decidedStatuses.has(String(value.status)) &&
          typeof value.subjectId === 'string'
        )
          decisions.push({
            requestId: document.id,
            subjectId: value.subjectId,
            requestType: value.requestType,
          });
      }
      if (page.size < this.pageSize) break;
      after = page.docs.at(-1)!.id;
    }
    return { asOfUtc: this.clock.now().toISOString(), decisions };
  }
}

/**
 * Re-applies one decision inside the isolated copy with the same L1 runner and
 * owner handlers, under a request ID derived from the original, so a repeated
 * admission re-uses the same request instead of creating another.
 */
export class PrivacyRunnerRedeletion implements RedeletionPort {
  constructor(
    private readonly restored: Firestore,
    private readonly clock: ServerClock,
    private readonly domainIds: readonly string[],
  ) {}

  async reapply(decision: DeletionAuthorityDecision, nowUtc: string): Promise<ReapplyOutcome> {
    const repository = new FirestorePrivacyOrchestrationRepository(this.restored);
    const service = new PrivacyOrchestrationService(repository, repository, repository);
    const requestId = restoreRequestId(decision.requestId);
    const submitted = await service.submit({
      requestId,
      subjectId: decision.subjectId,
      requestType: decision.requestType,
      idempotencyKey: `restore-${decision.requestId}`,
      semanticHash: `sha256:${createHash('sha256').update(decision.requestId).digest('hex')}`,
      requiredDomainIds: this.domainIds,
      occurredAtUtc: nowUtc,
    });
    if (!submitted.ok) return 'failed';
    let request = submitted.request;
    // A repeated admission of the same isolated copy finds its own earlier request.
    if (request.status === 'completed') return 'completed';
    if (request.status === 'completedWithRetention') return 'retained';
    if (request.status === 'failed' || request.status === 'cancelled') return 'failed';
    if (request.status === 'submitted') {
      const verified = await service.verify(requestId, request.revision, nowUtc);
      if (!verified.ok) return 'failed';
      request = verified.request;
    }
    if (request.status === 'verified') {
      const dispatched = await service.dispatch(
        requestId,
        request.revision,
        this.domainIds.map((domainId) => ({ domainId, marketId: 'LV', targetRevision: 1 })),
        nowUtc,
      );
      if (!dispatched.ok) return 'failed';
    }
    const runner = new PrivacyDomainTaskRunner(this.restored, repository, service, {
      leaseOwner: `restore:${requestId.slice(0, 8)}`,
      clock: this.clock,
    });
    for (const domainId of this.domainIds) {
      for (let run = 0; run < 50; run += 1) {
        const outcome = await runner.runTask({
          requestId,
          taskId: privacyDomainTaskId(requestId, domainId, 'LV', 1),
          nowUtc,
        });
        if (outcome !== 'progress') break;
      }
    }
    const current = await repository.get(requestId);
    if (current === null) return 'failed';
    const reconciled = await service.reconcile(requestId, current.revision, nowUtc);
    if (!reconciled.ok) return 'failed';
    switch (reconciled.request.status) {
      case 'completed':
        return 'completed';
      case 'completedWithRetention':
      case 'partially_completed':
        return 'retained';
      default:
        return 'failed';
    }
  }
}

/** A UUID-shaped ID derived from the original request, stable across admissions. */
export function restoreRequestId(originalRequestId: string): string {
  const hex = createHash('sha256').update(`l2-restore|${originalRequestId}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}
