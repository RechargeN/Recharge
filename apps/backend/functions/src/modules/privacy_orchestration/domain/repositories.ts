import type { DeepReadonly } from '../../../shared/immutable.js';
import type { PrivacyDomainTask } from './privacy_domain_task.js';
import type { PrivacyRequest } from './privacy_request.js';

export interface PrivacyRequestRepository {
  create(request: PrivacyRequest): Promise<'created' | 'replayed' | 'idempotency_conflict'>;
  get(requestId: string): Promise<DeepReadonly<PrivacyRequest> | null>;
  findByIdempotency(
    subjectId: string,
    requestType: string,
    idempotencyKey: string,
  ): Promise<DeepReadonly<PrivacyRequest> | null>;
  save(
    request: PrivacyRequest,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'>;
}

export interface PrivacyTaskRepository {
  createMany(tasks: readonly PrivacyDomainTask[]): Promise<void>;
  listByRequest(requestId: string): Promise<readonly DeepReadonly<PrivacyDomainTask>[]>;
  save(
    task: PrivacyDomainTask,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'>;
}

export interface PrivacyDispatchRepository {
  dispatchAtomically(
    request: PrivacyRequest,
    expectedRevision: number,
    tasks: readonly PrivacyDomainTask[],
  ): Promise<'saved' | 'revision_conflict' | 'not_found'>;
}
