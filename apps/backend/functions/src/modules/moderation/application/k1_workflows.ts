import { createHash } from 'node:crypto';
import { validReason } from '../domain/moderation.js';
import type { Firestore } from 'firebase-admin/firestore';
import { FieldPath } from 'firebase-admin/firestore';
import { isEntityId, isIdempotencyKey } from '../../../shared/ids.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import { canonicalJson } from '../../content/domain/published_revision.js';
import type { ContentModerationPort, StaffActor, StaffAuthorityPort } from './ports.js';
import type { ModerationService } from './moderation_service.js';

export const k1Collections = Object.freeze({
  reviews: 'moderationRemoderationQueue',
  workflowReceipts: 'moderationWorkflowReceipts',
  reports: 'trustSafetyReports',
  reportReceipts: 'trustSafetyReportReceipts',
  routes: 'trustSafetyInbox',
});
export const object = (v: unknown): Record<string, unknown> | null =>
  typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
export const exact = (v: Record<string, unknown>, keys: readonly string[]) =>
  Object.keys(v).every((k) => keys.includes(k));
export const fail = (code: string) => ({ kind: 'rejected' as const, code });
export const ok = (data: Record<string, unknown>) => ({ kind: 'succeeded' as const, data });
export const digest = (v: unknown) => createHash('sha256').update(canonicalJson(v)).digest('hex');

/** Re-review owns its queue/receipts only. Any domain effect is a ModerationService owner command. */
export class K1Workflows {
  constructor(
    private readonly db: Firestore,
    private readonly content: ContentModerationPort,
    private readonly staff: StaffAuthorityPort,
    private readonly moderation: ModerationService,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }

  async allowed(actor: StaffActor, marketId: string, typeId: string, action: string) {
    return (
      await this.staff.evaluate({
        actor,
        nowUtc: this.clock.now().toISOString(),
        scope: { marketId, typeId, action },
      })
    ).allowed;
  }

  async queue(actor: StaffActor, marketId: string, typeId: string, after?: string) {
    if (!(await this.allowed(actor, marketId, typeId, 'queue'))) return fail('staff_denied');
    let q = this.db
      .collection(k1Collections.reviews)
      .where('marketId', '==', marketId)
      .where('typeId', '==', typeId)
      .orderBy(FieldPath.documentId());
    if (after !== undefined) q = q.startAfter(after);
    const page = await q.limit(50).get();
    return ok({
      items: page.docs.map((d) => d.data()),
      nextCursor: page.size === 50 ? page.docs.at(-1)!.id : null,
    });
  }

  async request(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['queueItemId', 'contentId', 'expectedRevision', 'reason', 'idempotencyKey']) ||
      !isEntityId(p.queueItemId) ||
      !isEntityId(p.contentId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      Number(p.expectedRevision) < 1 ||
      !validReason(p.reason)
    )
      return fail('invalid_contract');
    const receiptRef = this.db
      .collection(k1Collections.workflowReceipts)
      .doc(digest([actor.userId, p.idempotencyKey]));
    const prior = (await receiptRef.get()).data();
    if (prior) {
      if (
        !(await this.allowed(
          actor,
          String(prior.marketId),
          String(prior.typeId),
          'requestRemoderation',
        ))
      )
        return fail('staff_denied');
      return prior.hash === digest(p)
        ? (prior.result as ReturnType<typeof ok>)
        : fail('idempotency_conflict');
    }
    const source = await this.content.publication(p.contentId);
    if (!source?.marketId || !source.typeId || !source.currentPublishedRevisionId)
      return fail('target_not_found');
    if (!(await this.allowed(actor, source.marketId, source.typeId, 'requestRemoderation')))
      return fail('staff_denied');
    if (source.pointerRevision !== p.expectedRevision) return fail('target_stale');
    const entry = {
      queueItemId: p.queueItemId,
      contentId: p.contentId,
      marketId: source.marketId,
      typeId: source.typeId,
      publishedRevisionId: source.currentPublishedRevisionId,
      pointerRevision: source.pointerRevision,
      revision: 1,
      status: 'pending',
      requestedBy: actor.userId,
      reason: p.reason,
      createdAtUtc: this.clock.now().toISOString(),
    };
    return this.db.runTransaction(async (tx) => {
      const [r, q] = await tx.getAll(
        receiptRef,
        this.db.collection(k1Collections.reviews).doc(p.queueItemId as string),
      );
      if (r!.exists)
        return r!.get('hash') === digest(p)
          ? (r!.get('result') as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (q!.exists) return fail('duplicate_id');
      const result = ok(entry);
      tx.create(q!.ref, entry);
      tx.create(receiptRef, {
        hash: digest(p),
        result,
        marketId: source.marketId,
        typeId: source.typeId,
      });
      return result;
    });
  }

  async review(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['queueItemId', 'expectedRevision', 'outcome', 'reason', 'idempotencyKey']) ||
      !isEntityId(p.queueItemId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      Number(p.expectedRevision) < 1 ||
      !['noAction', 'restrict', 'withdraw'].includes(String(p.outcome)) ||
      !validReason(p.reason)
    )
      return fail('invalid_contract');
    const ref = this.db.collection(k1Collections.reviews).doc(p.queueItemId);
    const receiptRef = this.db
      .collection(k1Collections.workflowReceipts)
      .doc(digest([actor.userId, p.idempotencyKey]));
    const prior = (await receiptRef.get()).data();
    const queue = object((await ref.get()).data());
    if (!queue) return fail('target_not_found');
    if (
      !(await this.allowed(
        actor,
        String(queue.marketId),
        String(queue.typeId),
        'reviewRemoderation',
      ))
    )
      return fail('staff_denied');
    if (prior)
      return prior.hash === digest(p)
        ? (prior.result as ReturnType<typeof ok>)
        : fail('idempotency_conflict');
    if (queue.revision !== p.expectedRevision || queue.status !== 'pending')
      return fail('revision_conflict');
    let decisionId: string | null = null;
    if (p.outcome === 'noAction') {
      const current = await this.content.publication(String(queue.contentId));
      if (
        !current ||
        current.pointerRevision !== queue.pointerRevision ||
        current.currentPublishedRevisionId !== queue.publishedRevisionId
      )
        return fail('target_stale');
    } else {
      const enforced = await this.moderation.decide(actor, {
        schemaVersion: 1,
        action: p.outcome,
        reason: p.reason,
        idempotencyKey: digest([actor.userId, p.idempotencyKey, 'remoderation']),
        target: { contentId: queue.contentId, expectedRevision: queue.pointerRevision },
      });
      if (enforced.kind !== 'succeeded') return enforced;
      if (enforced.data.receipt.outcome === 'refused') return fail('target_stale');
      decisionId = enforced.data.decision.decisionId;
    }
    return this.db.runTransaction(async (tx) => {
      const [current, receipt] = await tx.getAll(ref, receiptRef);
      if (receipt!.exists)
        return receipt!.get('hash') === digest(p)
          ? (receipt!.get('result') as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (current!.get('revision') !== p.expectedRevision || current!.get('status') !== 'pending')
        return fail('revision_conflict');
      const updated = {
        ...queue,
        revision: Number(p.expectedRevision) + 1,
        status: 'resolved',
        outcome: p.outcome,
        reviewReason: p.reason,
        reviewedBy: actor.userId,
        decisionId,
        reviewedAtUtc: this.clock.now().toISOString(),
      };
      const result = ok(updated);
      tx.set(ref, updated);
      tx.create(receiptRef, {
        hash: digest(p),
        result,
        marketId: queue.marketId,
        typeId: queue.typeId,
      });
      return result;
    });
  }
}
