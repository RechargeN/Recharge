import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyRequest } from '../domain/privacy_request.js';
import type {
  PrivacyDispatchRepository,
  PrivacyRequestRepository,
  PrivacyTaskRepository,
} from '../domain/repositories.js';

export class InMemoryPrivacyOrchestrationRepository
  implements PrivacyRequestRepository, PrivacyTaskRepository, PrivacyDispatchRepository
{
  readonly #requests = new Map<string, DeepReadonly<PrivacyRequest>>();
  readonly #idempotency = new Map<string, string>();
  readonly #tasks = new Map<string, DeepReadonly<PrivacyDomainTask>>();

  create(request: PrivacyRequest): Promise<'created' | 'replayed' | 'idempotency_conflict'> {
    const key = scope(request.subjectId, request.requestType, request.idempotencyKey);
    const existingId = this.#idempotency.get(key);
    if (existingId !== undefined) {
      const existing = this.#requests.get(existingId);
      return Promise.resolve(
        existing?.semanticHash === request.semanticHash ? 'replayed' : 'idempotency_conflict',
      );
    }
    this.#requests.set(request.requestId, freezeRequest(request));
    this.#idempotency.set(key, request.requestId);
    return Promise.resolve('created');
  }

  get(requestId: string): Promise<DeepReadonly<PrivacyRequest> | null> {
    return Promise.resolve(this.#requests.get(requestId) ?? null);
  }

  findByIdempotency(
    subjectId: string,
    requestType: string,
    idempotencyKey: string,
  ): Promise<DeepReadonly<PrivacyRequest> | null> {
    const id = this.#idempotency.get(scope(subjectId, requestType, idempotencyKey));
    return Promise.resolve(id === undefined ? null : (this.#requests.get(id) ?? null));
  }

  save(
    value: PrivacyRequest | PrivacyDomainTask,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    if ('requestType' in value) {
      const existing = this.#requests.get(value.requestId);
      if (existing === undefined) return Promise.resolve('not_found');
      if (existing.revision !== expectedRevision || value.revision !== expectedRevision + 1) {
        return Promise.resolve('revision_conflict');
      }
      this.#requests.set(value.requestId, freezeRequest(value));
      return Promise.resolve('saved');
    }
    const existing = this.#tasks.get(value.taskId);
    if (existing === undefined) return Promise.resolve('not_found');
    if (existing.revision !== expectedRevision || value.revision !== expectedRevision + 1) {
      return Promise.resolve('revision_conflict');
    }
    this.#tasks.set(value.taskId, deepFreeze({ ...value }));
    return Promise.resolve('saved');
  }

  createMany(tasks: readonly PrivacyDomainTask[]): Promise<void> {
    for (const task of tasks) {
      const existing = this.#tasks.get(task.taskId);
      if (existing !== undefined && JSON.stringify(existing) !== JSON.stringify(task)) {
        throw new TypeError('immutable_privacy_task_conflict');
      }
      this.#tasks.set(task.taskId, existing ?? deepFreeze({ ...task }));
    }
    return Promise.resolve();
  }

  listByRequest(requestId: string): Promise<readonly DeepReadonly<PrivacyDomainTask>[]> {
    return Promise.resolve(
      Object.freeze(
        [...this.#tasks.values()]
          .filter((task) => task.requestId === requestId)
          .sort((left, right) => left.domainId.localeCompare(right.domainId)),
      ),
    );
  }

  dispatchAtomically(
    request: PrivacyRequest,
    expectedRevision: number,
    tasks: readonly PrivacyDomainTask[],
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    const existing = this.#requests.get(request.requestId);
    if (existing === undefined) return Promise.resolve('not_found');
    if (existing.revision !== expectedRevision || request.revision !== expectedRevision + 1) {
      return Promise.resolve('revision_conflict');
    }
    for (const task of tasks) {
      const duplicate = this.#tasks.get(task.taskId);
      if (duplicate !== undefined && JSON.stringify(duplicate) !== JSON.stringify(task)) {
        return Promise.resolve('revision_conflict');
      }
    }
    // The in-memory adapter has one synchronous commit point: no await or
    // externally visible partial state occurs between these mutations.
    for (const task of tasks) this.#tasks.set(task.taskId, deepFreeze({ ...task }));
    this.#requests.set(request.requestId, freezeRequest(request));
    return Promise.resolve('saved');
  }
}

function freezeRequest(request: PrivacyRequest): DeepReadonly<PrivacyRequest> {
  return deepFreeze({
    ...request,
    requiredDomainIds: [...request.requiredDomainIds],
    terminalEvidenceIds: [...request.terminalEvidenceIds],
  });
}

function scope(subjectId: string, requestType: string, idempotencyKey: string): string {
  return `${subjectId}:${requestType}:${idempotencyKey}`;
}
