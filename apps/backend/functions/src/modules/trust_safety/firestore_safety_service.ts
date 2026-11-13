import { safetyBudget } from './safety_abuse.js';
import { scopedStaffInTransaction } from '../moderation/infrastructure/scoped_staff_transaction.js';
import { randomUUID } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import type { ServerClock } from '../../shared/server_clock.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import {
  assertContentEmulatorContext,
  contentCollections,
} from '../content/infrastructure/firestore_content_repository.js';
import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import {
  digest,
  object,
  exact,
  ok,
  fail,
  type K1Workflows,
} from '../moderation/application/k1_workflows.js';
import type { StaffActor } from '../moderation/application/ports.js';
import { identityAuthorityCollections as ids } from '../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { applyContentSafety } from '../content/infrastructure/content_safety_commands.js';
import { applyCatalogSafety } from '../catalog/infrastructure/catalog_safety_commands.js';
import { applyBookingSafety } from '../../booking/booking_safety_commands.js';
import {
  sanctionReasonLabels,
  safetyPolicyRevision,
  appealDeadline,
  relationRecord,
  safetyCollections as c,
} from './safety_policy.js';
import type {
  SafetyInstruction,
  SafetyInstructionVerifier,
} from '../../shared/safety_instruction.js';

interface Sanction {
  sanctionId: string;
  revision: number;
  policyRevision: string;
  subjectUserId: string;
  contentId: string | null;
  marketId: string;
  typeId: string;
  family: SafetyInstruction['family'];
  desired: SafetyInstruction['desired'];
  untilUtc: string | null;
  reason: string;
  reasonCode: keyof typeof sanctionReasonLabels;
  issuedBy: string;
  issuedAtUtc: string;
  appealDeadlineUtc: string;
  status: 'pending' | 'active' | 'revoked' | 'expired';
  acks: Record<string, number>;
}
const instr = (s: Sanction): SafetyInstruction => ({
  sanctionId: s.sanctionId,
  revision: s.revision,
  policyRevision: s.policyRevision,
  subjectUserId: s.subjectUserId,
  contentId: s.contentId,
  family: s.family,
  desired: s.desired,
  untilUtc: s.untilUtc,
  reason: s.reasonCode,
});
export class FirestoreSafetyService implements SafetyInstructionVerifier {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    private readonly staff: K1Workflows,
  ) {
    assertContentEmulatorContext(db);
  }
  async verify(tx: Transaction, input: SafetyInstruction) {
    const s = (await tx.get(this.db.collection(c.sanctions).doc(input.sanctionId))).data() as
      Sanction | undefined;
    return !!s && digest(instr(s)) === digest(input);
  }
  private async actor(tx: Transaction, h: BookingAccessHint) {
    const a = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
      tx,
      h,
      this.clock.now(),
    );
    if (!a.allowed) return null;
    if (
      !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
        'trustSafety.runtime',
        tx,
      ))
    )
      return null;
    return a.userId;
  }
  /** Server-configured local safety budget; missing policy fails closed. No automatic sanctions. */
  private async budget(tx: Transaction, actor: string, family: string) {
    return safetyBudget(this.db, tx, actor, family, this.clock.now());
  }
  private async isOwner(tx: Transaction, actor: StaffActor) {
    return (
      (await tx.get(this.db.collection(c.authority).doc('owner'))).get('userId') === actor.userId
    );
  }
  async relation(h: BookingAccessHint, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, [
        'schemaVersion',
        'requestId',
        'targetUserId',
        'kind',
        'active',
        'expectedRevision',
        'idempotencyKey',
      ]) ||
      p.schemaVersion !== 1 ||
      !isEntityId(p.requestId) ||
      !isEntityId(p.targetUserId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      typeof p.kind !== 'string' ||
      !['block', 'mute'].includes(p.kind) ||
      typeof p.active !== 'boolean' ||
      !Number.isSafeInteger(p.expectedRevision) ||
      Number(p.expectedRevision) < 0
    )
      return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const user = await this.actor(tx, h);
      if (!user) return fail('access_denied');
      if (user === p.targetUserId) return fail('self_target');
      const receiptRef = this.db.collection(c.receipts).doc(digest([user, p.idempotencyKey]));
      const receipt = (await tx.get(receiptRef)).data();
      const { requestId: _r, ...sem } = p;
      void _r;
      if (receipt)
        return receipt.hash === digest(sem)
          ? (receipt.result as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      const target = await tx.get(this.db.collection(ids.accounts).doc(p.targetUserId as string));
      if (!target.exists) return fail('target_unavailable');
      const ref = this.db.collection(c.relations).doc(digest([user, p.targetUserId, p.kind]));
      const prior = (await tx.get(ref)).data();
      if (Number(prior?.revision ?? 0) !== p.expectedRevision) return fail('revision_conflict');
      const budget = await this.budget(tx, user, 'relation');
      if (!budget.allowed) return fail('rate_limited');
      const row = relationRecord({
        ownerId: user,
        targetUserId: p.targetUserId as string,
        kind: p.kind as string,
        active: p.active as boolean,
        revision: Number(p.expectedRevision) + 1,
        nowUtc: this.clock.now().toISOString(),
      });
      const result = ok(row);
      tx.set(ref, row);
      tx.create(receiptRef, { hash: digest(sem), result });
      tx.set(budget.ref, budget.value);
      tx.create(this.db.collection(c.audit).doc(digest([user, p.idempotencyKey])), {
        ...row,
        operation: 'relation',
      });
      return result;
    });
  }
  async relations(user: string, other: string, tx?: Transaction) {
    const refs = [
      ['block', user, other],
      ['block', other, user],
      ['mute', user, other],
    ].map(([kind, a, b]) => this.db.collection(c.relations).doc(digest([a, b, kind])));
    const rows = tx ? await tx.getAll(...refs) : await this.db.getAll(...refs);
    return {
      blocked: rows[0]!.get('active') === true || rows[1]!.get('active') === true,
      muted: rows[2]!.get('active') === true,
    };
  }
  async query(h: BookingAccessHint) {
    return this.db.runTransaction(async (tx) => {
      const user = await this.actor(tx, h);
      if (!user) return fail('access_denied');
      const relations = await tx.get(
        this.db.collection(c.relations).where('ownerId', '==', user).limit(101),
      );
      const notices = await tx.get(
        this.db.collection(c.notices).where('subjectUserId', '==', user).limit(101),
      );
      const appeals = await tx.get(
        this.db.collection(c.appeals).where('subjectUserId', '==', user).limit(101),
      );
      if (relations.size > 100 || notices.size > 100) return fail('query_too_broad');
      return ok({
        relations: relations.docs.map((d) => d.data()),
        notices: notices.docs.map((d) => d.data()),
        appeals: appeals.docs.map((d) => ({
          appealId: d.get('appealId') as unknown,
          sanctionId: d.id,
          status: d.get('status') as unknown,
          outcome: (d.get('outcome') as unknown) ?? null,
          responseTargetUtc: d.get('responseTargetUtc') as unknown,
        })),
      });
    });
  }
  async issue(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, [
        'sanctionId',
        'subjectUserId',
        'contentId',
        'typeId',
        'family',
        'durationDays',
        'reasonCode',
        'reason',
        'idempotencyKey',
      ]) ||
      !isEntityId(p.sanctionId) ||
      typeof p.reasonCode !== 'string' ||
      !Object.hasOwn(sanctionReasonLabels, p.reasonCode) ||
      !isEntityId(p.subjectUserId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      typeof p.reason !== 'string' ||
      p.reason.trim().length < 1 ||
      p.reason.length > 1000 ||
      typeof p.family !== 'string' ||
      !['warning', 'contentHide', 'temporarySuspend', 'permanentBan'].includes(p.family) ||
      (p.family === 'temporarySuspend' && p.durationDays !== 7 && p.durationDays !== 30) ||
      (p.family !== 'temporarySuspend' && p.durationDays !== undefined) ||
      (p.family === 'contentHide' &&
        (!isEntityId(p.contentId) ||
          typeof p.typeId !== 'string' ||
          !['event', 'place', 'activity', 'rental', 'collection'].includes(p.typeId))) ||
      (p.family !== 'contentHide' && (p.contentId !== undefined || p.typeId !== undefined))
    )
      return fail('invalid_contract');
    const typeId = p.family === 'contentHide' ? (p.typeId as string) : 'user';
    if (!(await this.staff.allowed(actor, 'LV', typeId, 'sanction'))) return fail('staff_denied');
    if (p.family === 'permanentBan') {
      const owner = await this.db.collection(c.authority).doc('owner').get();
      if (owner.get('userId') !== actor.userId) return fail('owner_required');
    }
    return this.db.runTransaction(async (tx) => {
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'trustSafety.runtime',
          tx,
        ))
      )
        return fail('feature_disabled');
      if (
        !(await scopedStaffInTransaction(this.db, tx, actor, typeId, 'sanction', this.clock.now()))
      )
        return fail('staff_denied');
      if (
        p.family === 'permanentBan' &&
        (await tx.get(this.db.collection(c.authority).doc('owner'))).get('userId') !== actor.userId
      )
        return fail('owner_required');
      const ref = this.db.collection(c.sanctions).doc(p.sanctionId as string);
      const existing = (await tx.get(ref)).data() as Sanction | undefined;
      const receiptRef = this.db
        .collection(c.receipts)
        .doc(digest(['sanction', actor.userId, p.idempotencyKey]));
      const receipt = (await tx.get(receiptRef)).data();
      if (receipt)
        return receipt.hash === digest(p)
          ? (receipt.result as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (existing) return fail('duplicate_id');
      const target = await tx.get(this.db.collection(ids.accounts).doc(p.subjectUserId as string));
      if (!target.exists) return fail('target_unavailable');
      if (p.family === 'contentHide') {
        const pointer = (
          await tx.get(this.db.collection(contentCollections.pointers).doc(p.contentId as string))
        ).data();
        if (typeof pointer?.currentPublishedRevisionId !== 'string')
          return fail('target_unavailable');
        const pub = (
          await tx.get(
            this.db
              .collection(contentCollections.publishedRevisions)
              .doc(pointer.currentPublishedRevisionId),
          )
        ).data();
        if (!pub || pub.marketId !== 'LV' || pub.typeId !== typeId)
          return fail('target_unavailable');
        const publisher = pub.publisherRef as { type: string; id: string };
        let owner = publisher.id;
        if (publisher.type === 'page')
          owner = (await tx.get(this.db.collection(ids.managedPages).doc(publisher.id))).get(
            'ownerUserId',
          ) as string;
        if (owner !== p.subjectUserId) return fail('subject_mismatch');
      }
      const budget = await this.budget(tx, actor.userId, 'staff');
      if (!budget.allowed) return fail('rate_limited');
      const now = this.clock.now();
      const s: Sanction = {
        sanctionId: p.sanctionId as string,
        revision: 1,
        policyRevision: safetyPolicyRevision,
        subjectUserId: p.subjectUserId as string,
        contentId: (p.contentId as string | undefined) ?? null,
        typeId,
        marketId: 'LV',
        family: p.family as Sanction['family'],
        desired: 'active',
        untilUtc:
          p.family === 'temporarySuspend'
            ? new Date(now.getTime() + Number(p.durationDays) * 86400000).toISOString()
            : null,
        reason: p.reason as string,
        reasonCode: p.reasonCode as keyof typeof sanctionReasonLabels,
        issuedBy: actor.userId,
        issuedAtUtc: now.toISOString(),
        appealDeadlineUtc: appealDeadline(now.toISOString()),
        status: 'pending',
        acks: {},
      };
      const result = ok({ sanctionId: s.sanctionId, status: 'pending', revision: 1 });
      tx.create(ref, s);
      tx.create(receiptRef, { hash: digest(p), result });
      tx.set(budget.ref, budget.value);
      tx.create(this.db.collection(c.notices).doc(s.sanctionId), this.notice(s));
      tx.create(this.db.collection(c.audit).doc(randomUUID()), {
        operation: 'issue',
        actorId: actor.userId,
        ...s,
      });
      return result;
    });
  }
  private notice(s: Sanction) {
    return {
      sanctionId: s.sanctionId,
      subjectUserId: s.subjectUserId,
      reason: sanctionReasonLabels[s.reasonCode],
      reasonCode: s.reasonCode,
      family: s.family,
      status: s.status,
      untilUtc: s.untilUtc,
      appealDeadlineUtc: s.appealDeadlineUtc,
      revision: s.revision,
      responseTargetDays: 7,
    };
  }
  /** Trusted reconciliation entry. Acknowledgements are source-revision fenced and retryable. */
  async reconcile(sanctionId: string) {
    if (
      !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled('trustSafety.runtime'))
    )
      return fail('feature_disabled');
    const ref = this.db.collection(c.sanctions).doc(sanctionId);
    const s = await this.db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data() as Sanction | undefined;
      if (!current) return null;
      if (
        current.desired !== 'active' ||
        current.untilUtc === null ||
        Date.parse(current.untilUtc) > this.clock.now().getTime()
      )
        return current;
      const expired: Sanction = {
        ...current,
        desired: 'expired',
        status: 'pending',
        revision: current.revision + 1,
        acks: {},
      };
      tx.set(ref, expired);
      tx.create(this.db.collection(c.audit).doc(randomUUID()), {
        ...expired,
        operation: 'expire',
        atUtc: this.clock.now().toISOString(),
      });
      return expired;
    });
    if (!s) return fail('target_not_found');
    const commands = {
      content: applyContentSafety,
      catalog: applyCatalogSafety,
      booking: applyBookingSafety,
    };
    for (const [owner, command] of Object.entries(commands)) {
      const result = await command(this.db, this, instr(s));
      if (result.kind !== 'succeeded') return result;
      const acknowledged = await this.db.runTransaction(async (tx) => {
        const current = (await tx.get(ref)).data() as Sanction;
        if (current.revision !== s.revision) return false;
        tx.update(ref, { acks: { ...current.acks, [owner]: s.revision } });
        return true;
      });
      if (!acknowledged) return fail('instruction_stale');
    }
    return this.db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data() as Sanction;
      if (current.revision !== s.revision) return fail('instruction_stale');
      if (!['content', 'catalog', 'booking'].every((o) => current.acks[o] === s.revision))
        return fail('enforcement_pending');
      const status = current.desired;
      tx.update(ref, { status });
      tx.set(this.db.collection(c.notices).doc(sanctionId), this.notice({ ...current, status }));
      return ok({ sanctionId, revision: s.revision, status });
    });
  }
  async change(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['sanctionId', 'expectedRevision', 'operation', 'reason', 'idempotencyKey']) ||
      !isEntityId(p.sanctionId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      typeof p.operation !== 'string' ||
      !['revoke', 'expire'].includes(p.operation) ||
      typeof p.reason !== 'string' ||
      p.reason.length < 1 ||
      p.reason.length > 1000
    )
      return fail('invalid_contract');
    const original = (await this.db.collection(c.sanctions).doc(p.sanctionId).get()).data() as
      Sanction | undefined;
    if (!original) return fail('target_not_found');
    if (!(await this.staff.allowed(actor, 'LV', original.typeId, 'sanction')))
      return fail('staff_denied');
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection(c.sanctions).doc(p.sanctionId as string);
      const current = (await tx.get(ref)).data() as Sanction;
      if (
        !(await scopedStaffInTransaction(
          this.db,
          tx,
          actor,
          current.typeId,
          'sanction',
          this.clock.now(),
        ))
      )
        return fail('staff_denied');
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'trustSafety.runtime',
          tx,
        ))
      )
        return fail('feature_disabled');
      const receiptRef = this.db
        .collection(c.receipts)
        .doc(digest(['change', actor.userId, p.idempotencyKey]));
      const receipt = (await tx.get(receiptRef)).data();
      if (receipt)
        return receipt.hash === digest(p)
          ? (receipt.result as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (current.revision !== p.expectedRevision || current.desired !== 'active')
        return fail('revision_conflict');
      // Mirror of issuance: only the trusted owner may lift a permanent ban.
      if (current.family === 'permanentBan' && !(await this.isOwner(tx, actor)))
        return fail('owner_required');
      if (
        p.operation === 'expire' &&
        (current.untilUtc === null || Date.parse(current.untilUtc) > this.clock.now().getTime())
      )
        return fail('not_expired');
      const next = {
        ...current,
        revision: current.revision + 1,
        desired: p.operation === 'expire' ? ('expired' as const) : ('revoked' as const),
        status: 'pending' as const,
        acks: {},
      };
      const result = ok({
        sanctionId: current.sanctionId,
        revision: next.revision,
        status: 'pending',
      });
      tx.set(ref, next);
      tx.create(receiptRef, { hash: digest(p), result });
      tx.create(this.db.collection(c.audit).doc(randomUUID()), {
        ...next,
        operation: p.operation,
        changeReason: p.reason,
        actorId: actor.userId,
      });
      return result;
    });
  }
  async appeal(h: BookingAccessHint, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['sanctionId', 'appealId', 'reason', 'idempotencyKey']) ||
      !isEntityId(p.sanctionId) ||
      !isEntityId(p.appealId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      typeof p.reason !== 'string' ||
      p.reason.trim().length < 1 ||
      p.reason.length > 2000
    )
      return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const user = await this.actor(tx, h);
      if (!user) return fail('access_denied');
      const source = (
        await tx.get(this.db.collection(c.sanctions).doc(p.sanctionId as string))
      ).data() as Sanction | undefined;
      if (!source || source.subjectUserId !== user) return fail('target_not_found');
      const ref = this.db.collection(c.appeals).doc(source.sanctionId);
      const prior = (await tx.get(ref)).data();
      if (prior)
        return prior.hash === digest(p)
          ? ok({ appealId: prior.appealId, status: prior.status })
          : fail('appeal_already_exists');
      if (this.clock.now().getTime() > Date.parse(source.appealDeadlineUtc))
        return fail('appeal_deadline_passed');
      const budget = await this.budget(tx, user, 'appeal');
      if (!budget.allowed) return fail('rate_limited');
      tx.create(ref, {
        ...p,
        hash: digest(p),
        subjectUserId: user,
        status: 'pending',
        revision: 1,
        submittedAtUtc: this.clock.now().toISOString(),
        responseTargetUtc: new Date(this.clock.now().getTime() + 7 * 86400000).toISOString(),
      });
      tx.set(budget.ref, budget.value);
      // Server-only record of the appellant's own statement; staff decisions never overwrite it.
      tx.create(this.db.collection(c.audit).doc(randomUUID()), {
        operation: 'appealSubmitted',
        sanctionId: source.sanctionId,
        appealId: p.appealId,
        actorId: user,
        reason: p.reason,
        atUtc: this.clock.now().toISOString(),
      });
      return ok({ appealId: p.appealId, status: 'pending' });
    });
  }
  async decideAppeal(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['sanctionId', 'expectedRevision', 'outcome', 'reason', 'idempotencyKey']) ||
      !isEntityId(p.sanctionId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      p.expectedRevision !== 1 ||
      typeof p.outcome !== 'string' ||
      !['upheld', 'revoked'].includes(p.outcome) ||
      typeof p.reason !== 'string' ||
      p.reason.length < 1 ||
      p.reason.length > 1000
    )
      return fail('invalid_contract');
    const source = (await this.db.collection(c.sanctions).doc(p.sanctionId).get()).data() as
      Sanction | undefined;
    if (!source) return fail('target_not_found');
    if (source.issuedBy === actor.userId || source.subjectUserId === actor.userId)
      return fail('independent_reviewer_required');
    if (!(await this.staff.allowed(actor, 'LV', source.typeId, 'appeal')))
      return fail('staff_denied');
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection(c.appeals).doc(p.sanctionId as string);
      const original = (await tx.get(ref)).data();
      const sanctionRef = this.db.collection(c.sanctions).doc(p.sanctionId as string);
      const s = (await tx.get(sanctionRef)).data() as Sanction;
      if (
        !(await scopedStaffInTransaction(this.db, tx, actor, s.typeId, 'appeal', this.clock.now()))
      )
        return fail('staff_denied');
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'trustSafety.runtime',
          tx,
        ))
      )
        return fail('feature_disabled');
      if (!original) return fail('target_not_found');
      if (original.status !== 'pending')
        return original.decisionHash === digest(p)
          ? ok({ outcome: original.outcome })
          : fail('revision_conflict');
      if (p.outcome === 'revoked' && s.desired !== 'active') return fail('revision_conflict');
      if (
        p.outcome === 'revoked' &&
        s.family === 'permanentBan' &&
        !(await this.isOwner(tx, actor))
      )
        return fail('owner_required');
      tx.update(ref, {
        revision: 2,
        status: 'decided',
        outcome: p.outcome,
        // Staff narrative is kept apart from the appellant's `reason`.
        decisionReason: p.reason,
        decidedBy: actor.userId,
        decisionHash: digest(p),
        decidedAtUtc: this.clock.now().toISOString(),
      });
      if (p.outcome === 'revoked')
        tx.set(sanctionRef, {
          ...s,
          revision: s.revision + 1,
          desired: 'revoked',
          status: 'pending',
          acks: {},
        });
      tx.create(this.db.collection(c.audit).doc(randomUUID()), {
        operation: 'appealDecision',
        actorId: actor.userId,
        ...p,
      });
      return ok({
        outcome: p.outcome,
        enforcementStatus: p.outcome === 'revoked' ? 'pending' : 'unchanged',
      });
    });
  }
}
