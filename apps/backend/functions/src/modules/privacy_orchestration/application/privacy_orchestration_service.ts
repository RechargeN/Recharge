import type { PrivacyFailure } from '../domain/failures.js';
import {
  transitionPrivacyDomainTask,
  type PrivacyDomainTaskStatus,
} from '../domain/privacy_domain_task.js';
import {
  createPrivacyRequest,
  transitionPrivacyRequest,
  type PrivacyRequest,
  type PrivacyRequestType,
} from '../domain/privacy_request.js';
import type {
  PrivacyDispatchRepository,
  PrivacyRequestRepository,
  PrivacyTaskRepository,
} from '../domain/repositories.js';
import { buildPrivacyDomainTasks, type PrivacyTaskSeed } from './dispatch_privacy_tasks.js';
import { reconcilePrivacyRequest } from './reconcile_privacy_request.js';

export type PrivacyOperationResult =
  { readonly ok: true; readonly request: PrivacyRequest } | PrivacyFailure;

export class PrivacyOrchestrationService {
  constructor(
    private readonly requests: PrivacyRequestRepository,
    private readonly tasks: PrivacyTaskRepository,
    private readonly dispatchRepository: PrivacyDispatchRepository,
  ) {}

  async submit(input: {
    readonly requestId: string;
    readonly subjectId: string;
    readonly requestType: PrivacyRequestType;
    readonly idempotencyKey: string;
    readonly semanticHash: string;
    readonly requiredDomainIds: readonly string[];
    readonly occurredAtUtc: string;
  }): Promise<PrivacyOperationResult> {
    const request = createPrivacyRequest(input);
    const result = await this.requests.create(request);
    if (result === 'idempotency_conflict') return { ok: false, code: 'idempotency_conflict' };
    if (result === 'replayed') {
      const replay = await this.requests.findByIdempotency(
        request.subjectId,
        request.requestType,
        request.idempotencyKey,
      );
      return replay === null
        ? { ok: false, code: 'request_not_found' }
        : { ok: true, request: replay };
    }
    return { ok: true, request };
  }

  async verify(
    requestId: string,
    expectedRevision: number,
    occurredAtUtc: string,
  ): Promise<PrivacyOperationResult> {
    return this.transition(requestId, expectedRevision, 'verified', occurredAtUtc);
  }

  async dispatch(
    requestId: string,
    expectedRevision: number,
    seeds: readonly PrivacyTaskSeed[],
    occurredAtUtc: string,
  ): Promise<PrivacyOperationResult> {
    const request = await this.requests.get(requestId);
    if (request === null) return { ok: false, code: 'request_not_found' };
    if (request.revision !== expectedRevision) return { ok: false, code: 'revision_conflict' };
    if (request.status !== 'verified') return { ok: false, code: 'verification_required' };
    let tasks: ReturnType<typeof buildPrivacyDomainTasks>;
    try {
      tasks = buildPrivacyDomainTasks(request, seeds, occurredAtUtc);
    } catch (error) {
      if (error instanceof TypeError) {
        return { ok: false, code: 'scope_widening_forbidden' };
      }
      throw error;
    }
    let next: PrivacyRequest;
    try {
      next = transitionPrivacyRequest({
        request,
        nextStatus: 'dispatched',
        occurredAtUtc,
      });
    } catch {
      return { ok: false, code: 'invalid_transition' };
    }
    const saved = await this.dispatchRepository.dispatchAtomically(next, expectedRevision, tasks);
    return saved === 'saved'
      ? { ok: true, request: next }
      : { ok: false, code: saved === 'not_found' ? 'request_not_found' : 'revision_conflict' };
  }

  async recordTaskOutcome(input: {
    readonly requestId: string;
    readonly taskId: string;
    readonly expectedTaskRevision: number;
    readonly nextStatus: PrivacyDomainTaskStatus;
    readonly evidenceId?: string;
    readonly occurredAtUtc: string;
  }): Promise<
    'saved' | 'revision_conflict' | 'not_found' | 'invalid_transition' | 'task_retry_exhausted'
  > {
    const task = (await this.tasks.listByRequest(input.requestId)).find(
      (candidate) => candidate.taskId === input.taskId,
    );
    if (task === undefined) return 'not_found';
    if (task.revision !== input.expectedTaskRevision) return 'revision_conflict';
    try {
      return this.tasks.save(
        transitionPrivacyDomainTask({
          task,
          nextStatus: input.nextStatus,
          occurredAtUtc: input.occurredAtUtc,
          ...(input.evidenceId === undefined ? {} : { evidenceId: input.evidenceId }),
        }),
        input.expectedTaskRevision,
      );
    } catch (error) {
      if (error instanceof TypeError) {
        return error.message === 'privacy_task_retry_exhausted'
          ? 'task_retry_exhausted'
          : 'invalid_transition';
      }
      throw error;
    }
  }

  async reconcile(
    requestId: string,
    expectedRevision: number,
    occurredAtUtc: string,
  ): Promise<PrivacyOperationResult> {
    const request = await this.requests.get(requestId);
    if (request === null) return { ok: false, code: 'request_not_found' };
    if (request.revision !== expectedRevision) return { ok: false, code: 'revision_conflict' };
    const next = reconcilePrivacyRequest(
      request,
      await this.tasks.listByRequest(requestId),
      occurredAtUtc,
    );
    if (next === request) return { ok: true, request };
    const saved = await this.requests.save(next, expectedRevision);
    return saved === 'saved'
      ? { ok: true, request: next }
      : { ok: false, code: saved === 'not_found' ? 'request_not_found' : 'revision_conflict' };
  }

  private async transition(
    requestId: string,
    expectedRevision: number,
    nextStatus: 'verified' | 'dispatched',
    occurredAtUtc: string,
  ): Promise<PrivacyOperationResult> {
    const request = await this.requests.get(requestId);
    if (request === null) return { ok: false, code: 'request_not_found' };
    if (request.revision !== expectedRevision) return { ok: false, code: 'revision_conflict' };
    let next: PrivacyRequest;
    try {
      next = transitionPrivacyRequest({ request, nextStatus, occurredAtUtc });
    } catch {
      return { ok: false, code: 'invalid_transition' };
    }
    const saved = await this.requests.save(next, expectedRevision);
    return saved === 'saved'
      ? { ok: true, request: next }
      : { ok: false, code: saved === 'not_found' ? 'request_not_found' : 'revision_conflict' };
  }
}
