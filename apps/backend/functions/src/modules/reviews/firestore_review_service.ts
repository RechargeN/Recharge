import { scopedStaffInTransaction } from '../moderation/infrastructure/scoped_staff_transaction.js';
import { relationEffects } from '../../shared/safety_visibility.js';
import { safetyRestricted } from '../../shared/safety_instruction.js';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FieldPath } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import { reviewBookingEvidence } from '../../booking/review_eligibility.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { digest, object, exact, fail, ok } from '../moderation/application/k1_workflows.js';
import type { StaffActor } from '../moderation/application/ports.js';
import type { K1Workflows } from '../moderation/application/k1_workflows.js';
import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import {
  reviewCollections as c,
  reviewPolicyRevision,
  ratingProjection,
  type ReviewRecord,
} from './review_policy.js';
import { reviewTarget } from './review_target.js';

export class FirestoreReviewService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }
  private async access(tx: Transaction, hint: BookingAccessHint) {
    const a = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
      tx,
      hint,
      this.clock.now(),
    );
    if (!a.allowed) return null;
    if (
      !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled('reviews.runtime', tx))
    )
      return null;
    return a.userId;
  }
  async command(hint: BookingAccessHint, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, [
        'schemaVersion',
        'requestId',
        'operation',
        'reviewId',
        'contentId',
        'expectedRevision',
        'idempotencyKey',
        'rating',
        'text',
      ]) ||
      p.schemaVersion !== 1 ||
      !isEntityId(p.requestId) ||
      !isEntityId(p.reviewId) ||
      !isEntityId(p.contentId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      Number(p.expectedRevision) < 0 ||
      typeof p.operation !== 'string' ||
      !['submit', 'edit', 'delete'].includes(p.operation) ||
      (p.operation !== 'delete' &&
        (!Number.isInteger(p.rating) ||
          Number(p.rating) < 1 ||
          Number(p.rating) > 5 ||
          (p.text !== undefined &&
            (typeof p.text !== 'string' ||
              [...p.text].length > 1000 ||
              // Line feeds are allowed; every other control character is refused.
              /[\u0000-\u0009\u000b-\u001f]/.test(p.text))))) ||
      (p.operation === 'delete' && (p.rating !== undefined || p.text !== undefined))
    )
      return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const actor = await this.access(tx, hint);
      if (!actor) return fail('access_denied');
      const receiptRef = this.db.collection(c.receipts).doc(digest([actor, p.idempotencyKey]));
      const receipt = (await tx.get(receiptRef)).data();
      const { requestId: _requestId, ...semantic } = p;
      void _requestId;
      if (receipt)
        return receipt.hash === digest(semantic)
          ? (receipt.result as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      const ref = this.db.collection(c.reviews).doc(p.reviewId as string);
      const old = (await tx.get(ref)).data() as ReviewRecord | undefined;
      if (old && (old.authorId !== actor || old.contentId !== p.contentId))
        return fail('target_not_found');
      if ((old?.revision ?? 0) !== p.expectedRevision) return fail('revision_conflict');
      const uniqueRef = this.db.collection(c.uniqueness).doc(digest([actor, p.contentId]));
      const unique = (await tx.get(uniqueRef)).data();
      if (unique && unique.reviewId !== p.reviewId) return fail('review_already_exists');
      if (p.operation === 'submit' && old && !old.deleted) return fail('review_already_exists');
      if (p.operation !== 'submit' && (!old || old.deleted)) return fail('target_not_found');
      let evidence = old?.evidence ?? null;
      let typeId = old?.typeId;
      if (p.operation !== 'delete') {
        if (await safetyRestricted(this.db, 'content', actor, this.clock.now(), undefined, tx))
          return fail('account_restricted');
        const target = await reviewTarget(
          this.db,
          tx,
          p.contentId as string,
          actor,
          this.clock.now(),
          p.operation === 'edit',
        );
        if (!target) return fail('target_unavailable');
        if (target.own) return fail('own_target');
        typeId = target.typeId;
        if (p.operation === 'submit') {
          evidence =
            typeId === 'place'
              ? { kind: 'unverifiedPublicPlace' }
              : await reviewBookingEvidence(
                  this.db,
                  tx,
                  actor,
                  p.contentId as string,
                  typeId,
                  this.clock.now(),
                );
          if (evidence === null) return fail('eligibility_unavailable');
        }
      }
      const projectionRef = this.db.collection(c.projections).doc(p.contentId as string);
      const projection = (await tx.get(projectionRef)).data();
      const now = this.clock.now().toISOString();
      const row: ReviewRecord = {
        schemaVersion: 1,
        reviewId: p.reviewId as string,
        authorId: actor,
        contentId: p.contentId as string,
        typeId: typeId!,
        marketId: 'LV',
        revision: (old?.revision ?? 0) + 1,
        rating: p.operation === 'delete' ? old!.rating : (p.rating as number),
        text: p.operation === 'delete' ? '' : ((p.text as string | undefined) ?? ''),
        edited: old?.edited === true || p.operation === 'edit',
        deleted: p.operation === 'delete',
        moderationHold: old?.moderationHold ?? null,
        policyRevision: reviewPolicyRevision,
        evidence,
        createdAtUtc: old?.createdAtUtc ?? now,
        updatedAtUtc: now,
        verified: false,
      };
      const next = this.delta(projection, old, row);
      const result = ok({ review: row });
      tx.set(ref, row);
      tx.set(uniqueRef, { reviewId: row.reviewId, authorId: actor, contentId: row.contentId });
      tx.set(projectionRef, next);
      tx.create(receiptRef, { hash: digest(semantic), result });
      tx.create(this.db.collection(c.audit).doc(digest([actor, p.idempotencyKey])), {
        reviewId: row.reviewId,
        revision: row.revision,
        operation: p.operation,
        actorId: actor,
        policyRevision: reviewPolicyRevision,
        atUtc: now,
      });
      return result;
    });
  }
  private delta(
    raw: Record<string, unknown> | undefined,
    old: ReviewRecord | undefined,
    row: ReviewRecord,
  ) {
    const distribution = (raw?.distribution as number[] | undefined)?.slice() ?? [0, 0, 0, 0, 0];
    for (const [r, sign] of [
      [old, -1],
      [row, 1],
    ] as const)
      if (r && !r.deleted && r.moderationHold === null)
        distribution[r.rating - 1] = distribution[r.rating - 1]! + sign;
    if (distribution.some((x) => !Number.isSafeInteger(x) || x < 0))
      throw new Error('projection_corrupt_rebuild_required');
    const count = distribution.reduce((a, b) => a + b, 0),
      sum = distribution.reduce((a, b, i) => a + b * (i + 1), 0);
    return {
      count,
      sum,
      distribution,
      averageScaled: count >= 3 ? Math.floor((sum * 1000) / count) : null,
      scaleFactor: 1000,
      sourceWatermark: Number(raw?.sourceWatermark ?? 0) + 1,
      policyRevision: reviewPolicyRevision,
    };
  }
  /** Trusted operator entry; not a client-provided authority or arbitrary DB mutation. */
  async rebuild(contentId: string) {
    if (!isEntityId(contentId)) return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection(c.projections).doc(contentId);
      const prior = (await tx.get(ref)).data();
      const rows = await tx.get(
        this.db.collection(c.reviews).where('contentId', '==', contentId).limit(2001),
      );
      if (rows.size > 2000) return fail('rebuild_capacity_exceeded');
      const result = {
        ...ratingProjection(rows.docs.map((d) => d.data() as ReviewRecord)),
        sourceWatermark: Number(prior?.sourceWatermark ?? 0),
      };
      tx.set(ref, result);
      return ok(result);
    });
  }
  async moderate(actor: StaffActor, workflows: K1Workflows, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, [
        'reviewId',
        'expectedRevision',
        'decisionId',
        'action',
        'reason',
        'idempotencyKey',
      ]) ||
      !isEntityId(p.reviewId) ||
      !isEntityId(p.decisionId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      typeof p.reason !== 'string' ||
      p.reason.length < 1 ||
      p.reason.length > 1000 ||
      typeof p.action !== 'string' ||
      !['hide', 'restore'].includes(p.action)
    )
      return fail('invalid_contract');
    const preview = (await this.db.collection(c.reviews).doc(p.reviewId).get()).data() as
      ReviewRecord | undefined;
    if (!preview) return fail('target_not_found');
    if (!(await workflows.allowed(actor, preview.marketId, preview.typeId, 'moderateReview')))
      return fail('staff_denied');
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection(c.reviews).doc(p.reviewId as string);
      const row = (await tx.get(ref)).data() as ReviewRecord | undefined;
      if (
        !row ||
        !(await scopedStaffInTransaction(
          this.db,
          tx,
          actor,
          row.typeId,
          'moderateReview',
          this.clock.now(),
        ))
      )
        return fail('staff_denied');
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'reviews.runtime',
          tx,
        ))
      )
        return fail('feature_disabled');
      const receiptRef = this.db
        .collection(c.receipts)
        .doc(digest(['staff', actor.userId, p.idempotencyKey]));
      const receipt = (await tx.get(receiptRef)).data();
      if (receipt)
        return receipt.hash === digest(p)
          ? (receipt.result as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (!row || row.revision !== p.expectedRevision || row.deleted)
        return fail('revision_conflict');
      if (p.action === 'restore' && row.moderationHold !== p.decisionId)
        return fail('decision_mismatch');
      if (p.action === 'hide' && row.moderationHold !== null) return fail('already_restricted');
      const projectionRef = this.db.collection(c.projections).doc(row.contentId);
      const projection = (await tx.get(projectionRef)).data();
      const next = {
        ...row,
        revision: row.revision + 1,
        moderationHold: p.action === 'hide' ? (p.decisionId as string) : null,
        updatedAtUtc: this.clock.now().toISOString(),
      };
      const result = ok({ reviewId: row.reviewId, revision: next.revision });
      tx.set(ref, next);
      tx.set(projectionRef, this.delta(projection, row, next));
      tx.create(receiptRef, { hash: digest(p), result });
      tx.create(
        this.db.collection(c.audit).doc(digest(['staff', actor.userId, p.idempotencyKey])),
        { ...p, actorId: actor.userId, atUtc: this.clock.now().toISOString() },
      );
      return result;
    });
  }
  async reportTarget(reviewId: string, expectedRevision: number) {
    const row = (await this.db.collection(c.reviews).doc(reviewId).get()).data() as
      ReviewRecord | undefined;
    return row && !row.deleted && row.revision === expectedRevision
      ? { marketId: row.marketId, typeId: row.typeId }
      : null;
  }
  async query(hint: BookingAccessHint, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['schemaVersion', 'requestId', 'contentId', 'after', 'expectedWatermark']) ||
      p.schemaVersion !== 1 ||
      !isEntityId(p.contentId) ||
      !isEntityId(p.requestId) ||
      (p.after !== undefined && !isEntityId(p.after))
    )
      return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const actor = await this.access(tx, hint);
      if (!actor) return fail('access_denied');
      if (!(await reviewTarget(this.db, tx, p.contentId as string, actor, this.clock.now())))
        return fail('target_unavailable');
      const projection = (
        await tx.get(this.db.collection(c.projections).doc(p.contentId as string))
      ).data();
      const watermark = Number(projection?.sourceWatermark ?? 0);
      if (p.expectedWatermark !== undefined && p.expectedWatermark !== watermark)
        return fail('projection_changed');
      if (p.after !== undefined && p.expectedWatermark === undefined)
        return fail('invalid_contract');
      let q = this.db
        .collection(c.reviews)
        .where('contentId', '==', p.contentId)
        .where('deleted', '==', false)
        .where('moderationHold', '==', null)
        .orderBy(FieldPath.documentId());
      if (p.after) q = q.startAfter(p.after);
      const page = await tx.get(q.limit(50));
      const visible = [];
      for (const d of page.docs) {
        const row = d.data() as ReviewRecord;
        const effects = await relationEffects(this.db, actor, row.authorId, tx);
        if (!effects.blocked && !effects.muted) visible.push(d);
      }
      return ok({
        // Internal author ids and eligibility evidence never leave the Reviews owner.
        reviews: visible.map((d) => {
          const { evidence, authorId, ...publicRow } = d.data() as ReviewRecord;
          void evidence;
          return { ...publicRow, own: authorId === actor };
        }),
        rating: projection ?? { ...ratingProjection([]), sourceWatermark: 0 },
        nextCursor: page.size === 50 ? page.docs.at(-1)!.id : null,
      });
    });
  }
}
