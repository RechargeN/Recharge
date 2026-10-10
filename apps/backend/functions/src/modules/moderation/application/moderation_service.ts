import { randomUUID } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import {
  attest,
  commandHash,
  isMediaAction,
  moderationActions,
  moderationIssuer,
  moderationPolicyRevision,
  moderationRejected,
  moderationSucceeded,
  validReason,
  type EnforcementReceipt,
  type ModerationAction,
  type ModerationDecision,
  type ModerationDecisionView,
  type ModerationResult,
  type ModerationTarget,
  type StaffModerationCommand,
} from '../domain/moderation.js';
import type { ModerationRepository } from '../domain/repositories.js';
import type {
  ContentModerationPort,
  EnforcementOutcome,
  MediaModerationPort,
  StaffActor,
  StaffAuthorityPort,
  SubmissionView,
} from './ports.js';

export interface ModerationServiceDependencies {
  readonly repository: ModerationRepository;
  readonly staff: StaffAuthorityPort;
  readonly content: ContentModerationPort;
  /** D2: Media actions; without it they find no target. */
  readonly media?: MediaModerationPort;
  readonly clock: ServerClock;
  readonly newId?: () => string;
}

const idPattern = /^[A-Za-z0-9._:-]{1,128}$/u;

/**
 * Minimal operator moderation: a review queue, approve/reject with a reason,
 * restrict/withdraw/restore of a published revision, an enforcement receipt and
 * an audit trail. Staff authority is re-evaluated on every command; the decision
 * is recorded first, then Content applies it through its own verified path, and
 * a retry with the same key resumes whatever step did not finish.
 */
export class ModerationService {
  readonly #deps: ModerationServiceDependencies;

  constructor(deps: ModerationServiceDependencies) {
    this.#deps = deps;
  }

  async queue(actor: StaffActor, limit = 50) {
    const denied = await this.#authorize(actor);
    if (denied !== undefined) return denied;
    return moderationSucceeded({
      pending: await this.#deps.content.reviewQueue(Math.min(Math.max(limit, 1), 100)),
      recent: await this.#deps.repository.recent(20),
    });
  }

  async receipt(
    actor: StaffActor,
    decisionId: string,
  ): Promise<ModerationResult<ModerationDecisionView>> {
    const denied = await this.#authorize(actor);
    if (denied !== undefined) return denied;
    if (!idPattern.test(decisionId)) return moderationRejected('invalid_contract');
    const view = await this.#deps.repository.transact(async (tx) => {
      const decision = await tx.decision(decisionId);
      const receipt = await tx.receipt(decisionId);
      return decision === null || receipt === null ? null : { decision, receipt };
    });
    return view === null ? moderationRejected('target_not_found') : moderationSucceeded(view);
  }

  async decide(
    actor: StaffActor,
    rawCommand: unknown,
  ): Promise<ModerationResult<ModerationDecisionView>> {
    const command = parseCommand(rawCommand);
    if (command === null) return moderationRejected('invalid_contract');
    const denied = await this.#authorize(actor);
    if (denied !== undefined) return denied;
    const semanticHash = commandHash(command);

    const prior = await this.#deps.repository.transact((tx) =>
      tx.idempotency(actor.userId, command.idempotencyKey),
    );
    if (prior !== null) {
      if (prior.semanticHash !== semanticHash) return moderationRejected('idempotency_conflict');
      return this.#resume(prior.decisionId);
    }

    const resolved = await this.#resolveTarget(command);
    if (resolved.kind === 'rejected') return resolved;

    const decidedAtUtc = this.#deps.clock.now().toISOString();
    const unsigned = {
      schemaVersion: 1 as const,
      decisionId: (this.#deps.newId ?? randomUUID)(),
      action: command.action,
      staffUserId: actor.userId,
      staffSessionId: actor.sessionId,
      reason: command.reason,
      reasonCategory: 'operator_decision' as const,
      target: resolved.data,
      ...(command.restoresDecisionId === undefined
        ? {}
        : { restoresDecisionId: command.restoresDecisionId }),
      policyRevision: moderationPolicyRevision,
      decidedAtUtc,
      idempotencyKey: command.idempotencyKey,
      semanticHash,
    };
    const decision: ModerationDecision = { ...unsigned, attestation: attest(unsigned) };

    const recorded = await this.#deps.repository.transact(async (tx) => {
      // A concurrent identical command may have recorded its decision first.
      const raced = await tx.idempotency(actor.userId, command.idempotencyKey);
      if (raced !== null)
        return { decisionId: raced.decisionId, conflict: raced.semanticHash !== semanticHash };
      tx.putDecision(decision);
      tx.putIdempotency({
        actorUserId: actor.userId,
        idempotencyKey: command.idempotencyKey,
        semanticHash,
        decisionId: decision.decisionId,
      });
      tx.appendAudit({
        auditId: `${decision.decisionId}:decision`,
        kind: 'moderation.decision.recorded',
        decisionId: decision.decisionId,
        actorUserId: actor.userId,
        action: decision.action,
        atUtc: decidedAtUtc,
      });
      return { decisionId: decision.decisionId, conflict: false };
    });
    if (recorded.conflict) return moderationRejected('idempotency_conflict');
    return this.#resume(recorded.decisionId);
  }

  /** Applies a recorded decision to Content (if no receipt yet) and returns the evidence. */
  async #resume(decisionId: string): Promise<ModerationResult<ModerationDecisionView>> {
    const stored = await this.#deps.repository.transact(async (tx) => ({
      decision: await tx.decision(decisionId),
      receipt: await tx.receipt(decisionId),
    }));
    if (stored.decision === null) return moderationRejected('unknown_outcome');
    const decision = stored.decision;
    if (stored.receipt !== null) return moderationSucceeded({ decision, receipt: stored.receipt });

    let enforcement: EnforcementOutcome;
    try {
      const media = this.#deps.media;
      if (isMediaAction(decision.action)) {
        if (media === undefined || decision.target.assetId === undefined)
          return moderationRejected('unknown_outcome');
        // Media verifies the recorded decision itself before it changes anything.
        enforcement = await media.enforce({
          decisionId: decision.decisionId,
          assetId: decision.target.assetId,
          restricted: decision.action === 'restrict_media',
        });
      } else
        enforcement = await this.#deps.content.enforce({
          instructionId: decision.decisionId,
          decisionId: decision.decisionId,
          policyRevision: decision.policyRevision,
          disposition: decision.action,
          target: instructionTarget(decision.target),
          reasonCategory: decision.reasonCategory,
          ...(decision.restoresDecisionId === undefined
            ? {}
            : { restoresDecisionId: decision.restoresDecisionId }),
          effectiveAtUtc: decision.decidedAtUtc,
          attestation: decision.attestation,
        });
    } catch {
      // The decision stays recorded; the same key resumes enforcement.
      return moderationRejected('unknown_outcome');
    }

    const recordedAtUtc = this.#deps.clock.now().toISOString();
    const receipt: EnforcementReceipt = {
      schemaVersion: 1,
      receiptId: decision.decisionId,
      decisionId: decision.decisionId,
      action: decision.action,
      outcome: enforcement.kind === 'applied' ? enforcement.outcome : 'refused',
      ...(enforcement.kind === 'refused' ? { refusalCode: enforcement.code } : {}),
      contentId: decision.target.contentId,
      pointerRevision: enforcement.kind === 'applied' ? enforcement.pointerRevision : null,
      staffUserId: decision.staffUserId,
      target: decision.target,
      reason: decision.reason,
      issuer: moderationIssuer,
      recordedAtUtc,
    };
    const written = await this.#deps.repository.transact(async (tx) => {
      const existing = await tx.receipt(decision.decisionId);
      if (existing !== null) return existing;
      tx.putReceipt(receipt);
      tx.appendAudit({
        auditId: `${decision.decisionId}:enforcement`,
        kind: 'moderation.enforcement.recorded',
        decisionId: decision.decisionId,
        actorUserId: decision.staffUserId,
        action: decision.action,
        outcome: receipt.outcome,
        atUtc: recordedAtUtc,
      });
      return receipt;
    });
    return moderationSucceeded({ decision, receipt: written });
  }

  async #authorize(actor: StaffActor): Promise<ModerationResult<never> | undefined> {
    const result = await this.#deps.staff.evaluate({
      actor,
      nowUtc: this.#deps.clock.now().toISOString(),
    });
    if (result.allowed) return undefined;
    return moderationRejected(
      result.reason === 'session_invalid' ? 'unauthenticated' : 'staff_denied',
    );
  }

  /** The exact submission or published revision the decision acts on, as it is now. */
  async #resolveTarget(
    command: StaffModerationCommand,
  ): Promise<ModerationResult<ModerationTarget>> {
    if (isMediaAction(command.action)) return this.#resolveMediaTarget(command);
    const { submissionId } = command.target;
    const contentId = command.target.contentId ?? '';
    if (command.action === 'approve' || command.action === 'reject') {
      if (submissionId === undefined) return moderationRejected('invalid_contract');
      const submission: SubmissionView | null = await this.#deps.content.submission(submissionId);
      if (submission === null) return moderationRejected('target_not_found');
      if (submission.contentId !== contentId || submission.state !== 'under_review')
        return moderationRejected('target_stale');
      return moderationSucceeded({
        contentId,
        submissionId,
        submissionRevision: submission.revision,
        draftRevision: submission.draftRevision,
      });
    }
    const publication = await this.#deps.content.publication(contentId);
    if (publication === null || publication.currentPublishedRevisionId === null)
      return moderationRejected('target_not_found');
    if (command.action === 'restore') {
      const restored = await this.#deps.repository.transact((tx) =>
        tx.decision(command.restoresDecisionId ?? ''),
      );
      if (
        restored === null ||
        restored.target.contentId !== contentId ||
        (restored.action !== 'restrict' && restored.action !== 'withdraw')
      )
        return moderationRejected('target_not_found');
    }
    return moderationSucceeded({
      contentId,
      publishedRevisionId: publication.currentPublishedRevisionId,
      pointerRevision: publication.pointerRevision,
    });
  }

  /**
   * D2: the asset as Media knows it now, bound to a Content. A restore names a
   * recorded `restrict_media` decision of the same asset; Media itself lifts only
   * the restriction that is still active.
   */
  async #resolveMediaTarget(
    command: StaffModerationCommand,
  ): Promise<ModerationResult<ModerationTarget>> {
    const assetId = command.target.assetId ?? '';
    const asset = await this.#deps.media?.asset(assetId);
    if (asset === undefined || asset === null || asset.contentId === null)
      return moderationRejected('target_not_found');
    if (command.action === 'restore_media') {
      const restored = await this.#deps.repository.transact((tx) =>
        tx.decision(command.restoresDecisionId ?? ''),
      );
      if (
        restored === null ||
        restored.action !== 'restrict_media' ||
        restored.target.assetId !== assetId
      )
        return moderationRejected('target_not_found');
    }
    return moderationSucceeded({
      contentId: asset.contentId,
      assetId,
      assetRevision: asset.assetRevision,
    });
  }
}

function instructionTarget(target: ModerationTarget) {
  return {
    contentId: target.contentId,
    ...(target.submissionId === undefined ? {} : { submissionId: target.submissionId }),
    ...(target.publishedRevisionId === undefined
      ? {}
      : { publishedRevisionId: target.publishedRevisionId }),
  };
}

function parseCommand(raw: unknown): StaffModerationCommand | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const value = raw as Record<string, unknown>;
  const target = value.target;
  if (
    value.schemaVersion !== 1 ||
    typeof value.action !== 'string' ||
    !moderationActions.includes(value.action as ModerationAction) ||
    typeof value.idempotencyKey !== 'string' ||
    !idPattern.test(value.idempotencyKey) ||
    value.idempotencyKey.length < 8 ||
    !validReason(value.reason) ||
    typeof target !== 'object' ||
    target === null
  )
    return null;
  const { contentId, submissionId, assetId } = target as Record<string, unknown>;
  const restoresDecisionId = value.restoresDecisionId;
  const action = value.action as ModerationAction;
  if (isMediaAction(action)) {
    // D2: a Media action names exactly one asset and nothing of Content.
    if (
      typeof assetId !== 'string' ||
      !idPattern.test(assetId) ||
      contentId !== undefined ||
      submissionId !== undefined
    )
      return null;
    if (
      restoresDecisionId !== undefined &&
      (typeof restoresDecisionId !== 'string' || !idPattern.test(restoresDecisionId))
    )
      return null;
    if ((action === 'restore_media') !== (typeof restoresDecisionId === 'string')) return null;
    return {
      schemaVersion: 1,
      action,
      idempotencyKey: value.idempotencyKey,
      reason: value.reason,
      target: { assetId },
      ...(typeof restoresDecisionId === 'string' ? { restoresDecisionId } : {}),
    };
  }
  if (assetId !== undefined) return null;
  if (typeof contentId !== 'string' || !idPattern.test(contentId)) return null;
  if (
    submissionId !== undefined &&
    (typeof submissionId !== 'string' || !idPattern.test(submissionId))
  )
    return null;
  if (
    restoresDecisionId !== undefined &&
    (typeof restoresDecisionId !== 'string' || !idPattern.test(restoresDecisionId))
  )
    return null;
  const review = action === 'approve' || action === 'reject';
  if (review !== (submissionId !== undefined)) return null;
  if ((action === 'restore') !== (restoresDecisionId !== undefined)) return null;
  return {
    schemaVersion: 1,
    action,
    idempotencyKey: value.idempotencyKey,
    reason: value.reason,
    target: { contentId, ...(submissionId === undefined ? {} : { submissionId }) },
    ...(restoresDecisionId === undefined ? {} : { restoresDecisionId }),
  };
}
