import { safetyBudget } from '../../trust_safety/safety_abuse.js';
import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import type { BookingAccessHint } from '../../../shared/booking_access_authority.js';
import { FirestoreBookingAccessAuthority } from '../../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../../../platform/config/firestore_feature_flag_gate.js';
import { isEntityId, isIdempotencyKey } from '../../../shared/ids.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import type { ContentModerationPort, StaffActor } from './ports.js';
import {
  digest,
  exact,
  fail,
  k1Collections as cols,
  object,
  ok,
  type K1Workflows,
} from './k1_workflows.js';
import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';

const reasons = ['spam', 'misleading', 'safety', 'harassment', 'illegalContent', 'other'];
/** T&S owns reports and routes. Report intake never writes Content or changes visibility. */
export class ReportService {
  constructor(
    private readonly db: Firestore,
    private readonly content: ContentModerationPort,
    private readonly workflows: K1Workflows,
    private readonly clock: ServerClock,
    private readonly reviewTarget?: (
      id: string,
      revision: number,
    ) => Promise<{ marketId: string; typeId: string } | null>,
  ) {
    assertContentEmulatorContext(db);
  }

  async submit(hint: BookingAccessHint, raw: unknown) {
    const p = object(raw),
      t = object(p?.target);
    if (
      !p ||
      !t ||
      !exact(p, [
        'schemaVersion',
        'reportId',
        'requestId',
        'idempotencyKey',
        'target',
        'reasonCode',
        'narrative',
      ]) ||
      !(
        exact(t, ['contentId', 'publishedRevisionId']) || exact(t, ['reviewId', 'reviewRevision'])
      ) ||
      p.schemaVersion !== 1 ||
      !isEntityId(p.reportId) ||
      !isEntityId(p.requestId) ||
      !isIdempotencyKey(p.idempotencyKey) ||
      !(
        (isEntityId(t.contentId) && isEntityId(t.publishedRevisionId)) ||
        (isEntityId(t.reviewId) &&
          Number.isSafeInteger(t.reviewRevision) &&
          Number(t.reviewRevision) > 0)
      ) ||
      typeof p.reasonCode !== 'string' ||
      !reasons.includes(p.reasonCode) ||
      (p.narrative !== undefined &&
        (typeof p.narrative !== 'string' ||
          p.narrative.length > 2000 ||
          /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(p.narrative)))
    )
      return fail('invalid_contract');
    const initialActor = await new FirestoreBookingAccessAuthority(this.db).authorize(
      hint,
      this.clock.now(),
    );
    if (!initialActor.allowed) return fail('unauthenticated');
    if (
      !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled('trustSafety.reports'))
    )
      return fail('feature_disabled');
    const initialReceipt = await this.db
      .collection(cols.reportReceipts)
      .doc(digest(['report', initialActor.userId, p.idempotencyKey]))
      .get();
    if (initialReceipt.exists) {
      const semantic = digest({
        reportId: p.reportId,
        target: t,
        reasonCode: p.reasonCode,
        narrative: p.narrative ?? null,
      });
      return initialReceipt.get('hash') === semantic
        ? (initialReceipt.get('result') as ReturnType<typeof ok>)
        : fail('idempotency_conflict');
    }
    const source = isEntityId(t.reviewId)
      ? await this.reviewTarget?.(t.reviewId, Number(t.reviewRevision))
      : await this.content.publication(t.contentId as string);
    if (!source?.marketId || !source.typeId) return fail('target_not_found');
    if (
      !t.reviewId &&
      'currentPublishedRevisionId' in source &&
      source.currentPublishedRevisionId !== t.publishedRevisionId
    )
      return fail('target_stale');
    return this.db.runTransaction(async (tx) => {
      const actor = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      if (!actor.allowed) return fail('unauthenticated');
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'trustSafety.reports',
          tx,
        ))
      )
        return fail('feature_disabled');
      const receiptRef = this.db
        .collection(cols.reportReceipts)
        .doc(digest(['report', actor.userId, p.idempotencyKey]));
      const reportRef = this.db.collection(cols.reports).doc(p.reportId as string);
      const [receipt, existing] = await tx.getAll(receiptRef, reportRef);
      const semantic = digest({
        reportId: p.reportId,
        target: t,
        reasonCode: p.reasonCode,
        narrative: p.narrative ?? null,
      });
      if (receipt!.exists)
        return receipt!.get('hash') === semantic
          ? (receipt!.get('result') as ReturnType<typeof ok>)
          : fail('idempotency_conflict');
      if (existing!.exists) return fail('duplicate_id');
      const useBudget = await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
        'trustSafety.runtime',
        tx,
      );
      const budget = useBudget
        ? await safetyBudget(this.db, tx, actor.userId, 'report', this.clock.now())
        : null;
      if (budget && !budget.allowed) return fail('rate_limited');
      const report = {
        schemaVersion: 1,
        reportId: p.reportId,
        reporterUserId: actor.userId,
        target: t,
        marketId: source.marketId,
        typeId: source.typeId,
        reasonCode: p.reasonCode,
        narrative: p.narrative ?? null,
        revision: 1,
        status: 'submitted',
        reasonCatalogRevision: 'local-k1-reasons-v1',
        createdAtUtc: this.clock.now().toISOString(),
      };
      const result = ok({ reportId: p.reportId, status: 'received' });
      if (budget) tx.set(budget.ref, budget.value);
      tx.create(reportRef, report);
      tx.create(this.db.collection(cols.routes).doc(p.reportId as string), {
        reportId: p.reportId,
        ownerService: 'trustSafety',
        destination: 'triage',
        status: 'pending',
        revision: 1,
        marketId: source.marketId,
        typeId: source.typeId,
      });
      tx.create(receiptRef, { hash: semantic, result, reporterUserId: actor.userId });
      return result;
    });
  }

  async receipt(hint: BookingAccessHint, reportId: unknown) {
    if (!isEntityId(reportId)) return fail('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const actor = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      if (!actor.allowed) return fail('unauthenticated');
      if (
        !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
          'trustSafety.reports',
          tx,
        ))
      )
        return fail('feature_disabled');
      const report = await tx.get(this.db.collection(cols.reports).doc(reportId));
      return report.get('reporterUserId') === actor.userId
        ? ok({ reportId, status: 'received' })
        : fail('target_not_found');
    });
  }

  async queue(actor: StaffActor, marketId: string, typeId: string, after?: string) {
    if (!(await this.workflows.allowed(actor, marketId, typeId, 'triage')))
      return fail('staff_denied');
    let query = this.db
      .collection(cols.reports)
      .where('marketId', '==', marketId)
      .where('typeId', '==', typeId)
      .orderBy(FieldPath.documentId());
    if (after !== undefined) query = query.startAfter(after);
    const page = await query.limit(50).get();
    return ok({
      items: page.docs.map((d) => d.data()),
      nextCursor: page.size === 50 ? page.docs.at(-1)!.id : null,
    });
  }

  async triage(actor: StaffActor, raw: unknown) {
    const p = object(raw);
    if (
      !p ||
      !exact(p, ['reportId', 'expectedRevision', 'classification']) ||
      !isEntityId(p.reportId) ||
      !Number.isSafeInteger(p.expectedRevision) ||
      Number(p.expectedRevision) < 1 ||
      typeof p.classification !== 'string' ||
      !['accepted', 'duplicate', 'outOfScope'].includes(p.classification)
    )
      return fail('invalid_contract');
    const ref = this.db.collection(cols.reports).doc(p.reportId);
    const original = (await ref.get()).data();
    if (!original) return fail('target_not_found');
    if (
      !(await this.workflows.allowed(
        actor,
        String(original.marketId),
        String(original.typeId),
        'triage',
      ))
    )
      return fail('staff_denied');
    return this.db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      const routeRef = this.db.collection(cols.routes).doc(p.reportId as string);
      const route = await tx.get(routeRef);
      if (
        current.get('status') === 'triaged' &&
        current.get('classification') === p.classification &&
        current.get('revision') === Number(p.expectedRevision) + 1
      )
        return ok({ reportId: p.reportId, revision: current.get('revision'), status: 'triaged' });
      if (current.get('revision') !== p.expectedRevision || current.get('status') !== 'submitted')
        return fail('revision_conflict');
      tx.update(ref, {
        status: 'triaged',
        classification: p.classification,
        revision: Number(p.expectedRevision) + 1,
        triagedBy: actor.userId,
        triagedAtUtc: this.clock.now().toISOString(),
      });
      tx.set(routeRef, {
        ...route.data(),
        ownerService: 'trustSafety',
        destination: 'investigation',
        status: 'routed',
        revision: Number(route.get('revision')) + 1,
        classification: p.classification,
      });
      return ok({
        reportId: p.reportId,
        revision: Number(p.expectedRevision) + 1,
        status: 'triaged',
      });
    });
  }
}
