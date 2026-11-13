import type { Firestore, Transaction } from 'firebase-admin/firestore';
import type { PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyRequest } from '../domain/privacy_request.js';
import type {
  PrivacyDispatchRepository,
  PrivacyRequestRepository,
  PrivacyTaskRepository,
} from '../domain/repositories.js';

export const privacyOrchestrationCollections = Object.freeze({
  requests: 'privacyRequests',
  tasks: 'privacyDomainTasks',
});

export class FirestorePrivacyOrchestrationRepository
  implements PrivacyRequestRepository, PrivacyTaskRepository, PrivacyDispatchRepository
{
  constructor(private readonly firestore: Firestore) {}

  create(request: PrivacyRequest): Promise<'created' | 'replayed' | 'idempotency_conflict'> {
    return this.firestore.runTransaction(async (transaction) => {
      const existing = await this.findByIdempotencyWithReader(
        transaction,
        request.subjectId,
        request.requestType,
        request.idempotencyKey,
      );
      if (existing !== null) {
        return existing.semanticHash === request.semanticHash
          ? ('replayed' as const)
          : ('idempotency_conflict' as const);
      }
      const ref = this.requestRef(request.requestId);
      if ((await transaction.get(ref)).exists) return 'idempotency_conflict' as const;
      transaction.create(ref, request);
      return 'created' as const;
    });
  }

  async get(requestId: string): Promise<PrivacyRequest | null> {
    const snapshot = await this.requestRef(requestId).get();
    return snapshot.exists ? (snapshot.data() as PrivacyRequest) : null;
  }

  findByIdempotency(
    subjectId: string,
    requestType: string,
    idempotencyKey: string,
  ): Promise<PrivacyRequest | null> {
    return this.findByIdempotencyWithReader(undefined, subjectId, requestType, idempotencyKey);
  }

  save(
    value: PrivacyRequest | PrivacyDomainTask,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    return this.firestore.runTransaction(async (transaction) => {
      const ref = 'taskId' in value ? this.taskRef(value.taskId) : this.requestRef(value.requestId);
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return 'not_found' as const;
      if (snapshot.get('revision') !== expectedRevision) return 'revision_conflict' as const;
      transaction.set(ref, value);
      return 'saved' as const;
    });
  }

  async createMany(tasks: readonly PrivacyDomainTask[]): Promise<void> {
    if (tasks.length === 0) return;
    await this.firestore.runTransaction(async (transaction) => {
      const refs = tasks.map((task) => this.taskRef(task.taskId));
      const snapshots = await transaction.getAll(...refs);
      if (snapshots.some((snapshot) => snapshot.exists)) {
        throw new TypeError('privacy_task_already_exists');
      }
      tasks.forEach((task, index) => transaction.create(refs[index]!, task));
    });
  }

  async listByRequest(requestId: string): Promise<readonly PrivacyDomainTask[]> {
    const snapshot = await this.firestore
      .collection(privacyOrchestrationCollections.tasks)
      .where('requestId', '==', requestId)
      .get();
    return Object.freeze(
      snapshot.docs
        .map((document) => document.data() as PrivacyDomainTask)
        .sort((left, right) => left.domainId.localeCompare(right.domainId)),
    );
  }

  dispatchAtomically(
    request: PrivacyRequest,
    expectedRevision: number,
    tasks: readonly PrivacyDomainTask[],
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    return this.firestore.runTransaction(async (transaction) => {
      const requestRef = this.requestRef(request.requestId);
      const taskRefs = tasks.map((task) => this.taskRef(task.taskId));
      const [requestSnapshot, ...taskSnapshots] = await transaction.getAll(requestRef, ...taskRefs);
      if (requestSnapshot === undefined || !requestSnapshot.exists) return 'not_found' as const;
      if (requestSnapshot.get('revision') !== expectedRevision) {
        return 'revision_conflict' as const;
      }
      if (taskSnapshots.some((snapshot) => snapshot?.exists === true)) {
        return 'revision_conflict' as const;
      }
      transaction.set(requestRef, request);
      tasks.forEach((task, index) => transaction.create(taskRefs[index]!, task));
      return 'saved' as const;
    });
  }

  private async findByIdempotencyWithReader(
    transaction: Transaction | undefined,
    subjectId: string,
    requestType: string,
    idempotencyKey: string,
  ): Promise<PrivacyRequest | null> {
    const query = this.firestore
      .collection(privacyOrchestrationCollections.requests)
      .where('subjectId', '==', subjectId)
      .where('requestType', '==', requestType)
      .where('idempotencyKey', '==', idempotencyKey)
      .limit(2);
    const snapshot = transaction === undefined ? await query.get() : await transaction.get(query);
    if (snapshot.size > 1) throw new Error('privacy_idempotency_record_collision');
    return (snapshot.docs[0]?.data() as PrivacyRequest | undefined) ?? null;
  }

  private requestRef(requestId: string) {
    return this.firestore.collection(privacyOrchestrationCollections.requests).doc(requestId);
  }

  private taskRef(taskId: string) {
    return this.firestore.collection(privacyOrchestrationCollections.tasks).doc(taskId);
  }
}
