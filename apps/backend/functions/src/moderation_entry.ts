import { FirestoreReviewService } from './modules/reviews/firestore_review_service.js';
import type { Firestore } from 'firebase-admin/firestore';
import type { ServerClock } from './shared/server_clock.js';
import type { BookingAccessHint } from './shared/booking_access_authority.js';
import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { eventAuthoringComposition } from './content_entry.js';
import { FirestoreIdentityAuthorityRepository } from './modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { ModerationService } from './modules/moderation/application/moderation_service.js';
import { ContentModerationAdapter } from './modules/moderation/infrastructure/content_moderation_adapter.js';
import { EmulatorStaffAuthority } from './modules/moderation/infrastructure/emulator_staff_authority.js';
import { FirestoreModerationRepository } from './modules/moderation/infrastructure/firestore_moderation_repository.js';
import { K1Workflows, exact, fail, object } from './modules/moderation/application/k1_workflows.js';
import { ReportService } from './modules/moderation/application/report_service.js';

export function createK1(firestore: Firestore, clock: ServerClock) {
  const owner = eventAuthoringComposition(firestore, { clock, enabledTypes: new Set() });
  const repository = new FirestoreModerationRepository(firestore);
  const staff = new EmulatorStaffAuthority(
    firestore,
    new FirestoreIdentityAuthorityRepository(firestore),
  );
  const content = new ContentModerationAdapter(firestore, owner.contentRepository, owner.content);
  const moderation = new ModerationService({
    repository,
    staff,
    content,
    clock,
    requireScope: true,
  });
  const workflows = new K1Workflows(firestore, content, staff, moderation, clock);
  return {
    owner,
    staff,
    content,
    moderation,
    workflows,
    reports: new ReportService(firestore, content, workflows, clock, (id, revision) =>
      new FirestoreReviewService(firestore, clock).reportTarget(id, revision),
    ),
  };
}

export async function handleK1(
  db: Firestore,
  hint: BookingAccessHint,
  surface: string,
  raw: unknown,
  clock: ServerClock,
) {
  const r = object(raw);
  if (!r || r.schemaVersion !== 1 || typeof r.requestId !== 'string')
    return fail('invalid_contract');
  const k1 = createK1(db, clock);
  if (surface === 'reportCommandV1') return k1.reports.submit(hint, r);
  if (surface === 'reportQueryV1') {
    if (!exact(r, ['schemaVersion', 'requestId', 'reportId'])) return fail('invalid_contract');
    return k1.reports.receipt(hint, r.reportId);
  }
  const access = await new FirestoreBookingAccessAuthority(db).authorize(hint, clock.now());
  if (!access.allowed) return fail('unauthenticated');
  if (!(await new FirestoreFeatureFlagGate(db, 'local', 'LV').isEnabled('moderation.staff')))
    return fail('feature_disabled');
  const actor = { userId: access.userId, sessionId: hint.sessionId };
  if (surface === 'moderationCommandV1') {
    if (!exact(r, ['schemaVersion', 'requestId', 'operation', 'payload']))
      return fail('invalid_contract');
    const payload = object(r.payload);
    if (!payload) return fail('invalid_contract');
    switch (r.operation) {
      case 'decide':
        if (
          !exact(payload, [
            'schemaVersion',
            'action',
            'idempotencyKey',
            'reason',
            'target',
            'restoresDecisionId',
          ]) ||
          !['approve', 'reject', 'restrict', 'withdraw', 'restore'].includes(
            String(payload.action),
          ) ||
          !object(payload.target) ||
          !exact(object(payload.target)!, ['contentId', 'submissionId', 'expectedRevision'])
        )
          return fail('invalid_contract');
        return k1.moderation.decide(actor, payload);
      case 'requestRemoderation':
        return k1.workflows.request(actor, payload);
      case 'reviewRemoderation':
        return k1.workflows.review(actor, payload);
      case 'moderateReview':
        return new FirestoreReviewService(db, clock).moderate(actor, k1.workflows, payload);
      case 'triageReport':
        return k1.reports.triage(actor, payload);
      default:
        return fail('invalid_contract');
    }
  }
  if (surface === 'moderationQueryV1') {
    if (
      !exact(r, [
        'schemaVersion',
        'requestId',
        'queryType',
        'marketId',
        'typeId',
        'after',
        'decisionId',
      ]) ||
      typeof r.marketId !== 'string' ||
      !/^[A-Z]{2}$/.test(r.marketId) ||
      typeof r.typeId !== 'string' ||
      !/^[a-z_]{1,40}$/.test(r.typeId) ||
      (r.after !== undefined && (typeof r.after !== 'string' || r.after.length > 128))
    )
      return fail('invalid_contract');
    if (
      !(await k1.workflows.allowed(
        actor,
        r.marketId,
        r.typeId,
        r.queryType === 'reports' ? 'triage' : 'queue',
      ))
    )
      return fail('staff_denied');
    const after = typeof r.after === 'string' ? r.after : undefined;
    switch (r.queryType) {
      case 'queue':
        return k1.moderation.queue(actor, 50, {
          marketId: r.marketId,
          typeId: r.typeId,
          ...(after ? { after } : {}),
        });
      case 'remoderation':
        return k1.workflows.queue(actor, r.marketId, r.typeId, after);
      case 'reports':
        return k1.reports.queue(actor, r.marketId, r.typeId, after);
      case 'receipt':
        return typeof r.decisionId === 'string'
          ? k1.moderation.receipt(actor, r.decisionId)
          : fail('invalid_contract');
      default:
        return fail('invalid_contract');
    }
  }
  return fail('invalid_contract');
}
