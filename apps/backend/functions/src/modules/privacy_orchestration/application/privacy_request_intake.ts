import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../../shared/booking_access_authority.js';
import type { PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyRequest, PrivacyRequestType } from '../domain/privacy_request.js';
import type { PrivacyTaskRepository } from '../domain/repositories.js';
import { privacyErasureDomainIds } from '../domain/privacy_writer_registry.js';
import type { PrivacyOrchestrationService } from './privacy_orchestration_service.js';

/** L4.8: mirrors `privacy/v1/privacy_intake_refusal.schema.json`; a contract test compares them. */
export const privacyIntakeRefusalCodes = [
  'access_denied',
  'idempotency_conflict',
  'invalid_contract',
  'request_not_found',
  'revision_conflict',
  'subject_mismatch',
] as const;
export type PrivacyIntakeRefusalCode = (typeof privacyIntakeRefusalCodes)[number];
export type PrivacyIntakeResult =
  | { readonly ok: true; readonly view: PrivacyRequestView }
  | { readonly ok: false; readonly code: PrivacyIntakeRefusalCode };

/**
 * What the requester sees: status, revision and per-domain progress codes.
 * No subject, other person, record, hold basis or reporter ever appears in it.
 */
export interface PrivacyRequestView {
  readonly requestId: string;
  readonly requestType: PrivacyRequestType;
  readonly status: PrivacyRequest['status'];
  readonly revision: number;
  readonly domains: readonly {
    readonly domainId: string;
    readonly status: PrivacyDomainTask['status'];
    readonly retainedCount: number;
    readonly blockedCodes: readonly string[];
  }[];
}

/**
 * L1 DSR intake (BCK-04 §20.2, BCK04-SEC-DEC-01 items 1, 5). The subject is
 * the server-verified Session user; a client-named subject is only an untrusted
 * filter and a different one is refused. A logical submission is identified by
 * its idempotency key and normalized payload, so a retry returns the same
 * request and a changed payload under the same key is a conflict. Recent
 * re-authentication and a manual support channel are not part of this slice.
 */
export class PrivacyRequestIntake {
  constructor(
    private readonly db: Firestore,
    private readonly service: PrivacyOrchestrationService,
    private readonly tasks: PrivacyTaskRepository,
  ) {}

  async submitForSession(
    hint: BookingAccessHint,
    input: {
      readonly requestId: string;
      readonly requestType: 'access' | 'erasure' | 'restriction';
      readonly idempotencyKey: string;
      readonly subjectId?: string;
      readonly nowUtc: string;
    },
  ): Promise<PrivacyIntakeResult> {
    let decision;
    try {
      decision = await new FirestoreBookingAccessAuthority(this.db).authorize(
        hint,
        new Date(input.nowUtc),
      );
    } catch {
      return { ok: false, code: 'access_denied' };
    }
    if (!decision.allowed) return { ok: false, code: 'access_denied' };
    const subjectId = decision.userId;
    if (input.subjectId !== undefined && input.subjectId !== subjectId)
      return { ok: false, code: 'subject_mismatch' };
    const requiredDomainIds = [...privacyErasureDomainIds];
    const semanticHash = `sha256:${createHash('sha256')
      .update(JSON.stringify({ requestType: input.requestType, requiredDomainIds }), 'utf8')
      .digest('hex')}`;
    let submitted;
    try {
      submitted = await this.service.submit({
        requestId: input.requestId,
        subjectId,
        requestType: input.requestType,
        idempotencyKey: input.idempotencyKey,
        semanticHash,
        requiredDomainIds,
        occurredAtUtc: input.nowUtc,
      });
    } catch (error) {
      if (error instanceof TypeError) return { ok: false, code: 'invalid_contract' };
      throw error;
    }
    if (!submitted.ok) return failure(submitted.code);
    let request = submitted.request;
    if (request.status === 'submitted') {
      const verified = await this.service.verify(request.requestId, request.revision, input.nowUtc);
      if (!verified.ok) return failure(verified.code);
      request = verified.request;
    }
    if (request.status === 'verified') {
      const dispatched = await this.service.dispatch(
        request.requestId,
        request.revision,
        requiredDomainIds.map((domainId) => ({ domainId, marketId: 'LV', targetRevision: 1 })),
        input.nowUtc,
      );
      if (!dispatched.ok) return failure(dispatched.code);
      request = dispatched.request;
    }
    return { ok: true, view: await this.view(request) };
  }

  async view(request: PrivacyRequest): Promise<PrivacyRequestView> {
    const tasks = await this.tasks.listByRequest(request.requestId);
    return {
      requestId: request.requestId,
      requestType: request.requestType,
      status: request.status,
      revision: request.revision,
      domains: tasks.map((task) => ({
        domainId: task.domainId,
        status: task.status,
        retainedCount: task.retainedCount,
        blockedCodes: [...(task.blockedCodes ?? [])],
      })),
    };
  }
}

function failure(code: string): PrivacyIntakeResult {
  return {
    ok: false,
    code:
      code === 'idempotency_conflict' ||
      code === 'request_not_found' ||
      code === 'revision_conflict'
        ? code
        : 'invalid_contract',
  };
}
