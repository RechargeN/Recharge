import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { PrivacyRequestRepository } from '../domain/repositories.js';
import type { PrivacyRequest } from '../domain/privacy_request.js';

export class InMemoryPrivacyRequestRepository implements PrivacyRequestRepository {
  readonly #requests = new Map<string, DeepReadonly<PrivacyRequest>>();
  readonly #idempotency = new Map<string, string>();

  create(request: PrivacyRequest): Promise<'created' | 'replayed' | 'idempotency_conflict'> {
    const key = idempotencyScope(request.subjectId, request.requestType, request.idempotencyKey);
    const existingId = this.#idempotency.get(key);
    if (existingId !== undefined) {
      const existing = this.#requests.get(existingId);
      return Promise.resolve(
        existing?.semanticHash === request.semanticHash ? 'replayed' : 'idempotency_conflict',
      );
    }
    const frozen = deepFreeze({
      ...request,
      requiredDomainIds: [...request.requiredDomainIds],
      terminalEvidenceIds: [...request.terminalEvidenceIds],
    });
    this.#requests.set(request.requestId, frozen);
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
    const id = this.#idempotency.get(idempotencyScope(subjectId, requestType, idempotencyKey));
    return Promise.resolve(id === undefined ? null : (this.#requests.get(id) ?? null));
  }

  save(
    request: PrivacyRequest,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    const existing = this.#requests.get(request.requestId);
    if (existing === undefined) return Promise.resolve('not_found');
    if (existing.revision !== expectedRevision || request.revision !== expectedRevision + 1)
      return Promise.resolve('revision_conflict');
    this.#requests.set(
      request.requestId,
      deepFreeze({
        ...request,
        requiredDomainIds: [...request.requiredDomainIds],
        terminalEvidenceIds: [...request.terminalEvidenceIds],
      }),
    );
    return Promise.resolve('saved');
  }
}

function idempotencyScope(subjectId: string, requestType: string, idempotencyKey: string): string {
  return `${subjectId}:${requestType}:${idempotencyKey}`;
}
