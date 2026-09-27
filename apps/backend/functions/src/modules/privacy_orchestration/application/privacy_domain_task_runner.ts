import { createHash, randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { BookingPrivacyTaskHandler } from '../../../booking/booking_privacy_task_handler.js';
import { FirestoreBookingPrivacyRecordStore } from '../../../booking/firestore_booking_privacy_record_store.js';
import type { PrivacyTaskRepository } from '../domain/repositories.js';
import type { PrivacyOrchestrationService } from './privacy_orchestration_service.js';
import { AccountSecurityService } from '../../identity_publisher/application/account_security_service.js';
import {
  FirestoreIdentityAuthorityRepository,
  identityAuthorityCollections,
} from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';

export class PrivacyDomainTaskRunner {
  constructor(
    private readonly firestore: Firestore,
    private readonly tasks: PrivacyTaskRepository,
    private readonly orchestration: PrivacyOrchestrationService,
  ) {}

  async runBookingTask(input: {
    readonly requestId: string;
    readonly taskId: string;
    readonly nowUtc: string;
  }): Promise<'succeeded' | 'retry_scheduled' | 'failed' | 'not_found' | 'not_booking'> {
    let task = (await this.tasks.listByRequest(input.requestId)).find(
      (candidate) => candidate.taskId === input.taskId,
    );
    if (task === undefined) return 'not_found';
    if (task.domainId !== 'booking') return 'not_booking';
    if (task.status === 'succeeded') return 'succeeded';
    if (task.status === 'failed' || task.status === 'cancelled') return 'failed';
    if (task.status === 'pending') {
      const dispatched = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'dispatched',
        occurredAtUtc: input.nowUtc,
      });
      if (dispatched !== 'saved') return dispatched === 'not_found' ? 'not_found' : 'failed';
      task = (await this.tasks.listByRequest(input.requestId)).find(
        (candidate) => candidate.taskId === input.taskId,
      );
      if (task === undefined) return 'not_found';
    }

    const requestSnapshot = await this.firestore
      .collection('privacyRequests')
      .doc(input.requestId)
      .get();
    if (!requestSnapshot.exists) return 'not_found';
    const requestType: unknown = requestSnapshot.get('requestType');
    if (requestType !== 'access' && requestType !== 'erasure' && requestType !== 'restriction') {
      await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'failed',
        occurredAtUtc: input.nowUtc,
      });
      return 'failed';
    }
    if (requestType === 'erasure') {
      const account = await this.firestore
        .collection(identityAuthorityCollections.accounts)
        .doc(task.subjectId)
        .get();
      if (account.exists && account.get('status') !== 'restricted') {
        await new AccountSecurityService(
          new FirestoreIdentityAuthorityRepository(this.firestore),
        ).setStatus({ userId: task.subjectId, status: 'restricted', nowUtc: input.nowUtc });
      }
    }
    const handler = new BookingPrivacyTaskHandler(
      new FirestoreBookingPrivacyRecordStore(this.firestore, task.subjectId, task.taskId),
    );
    const result = await handler.handle({
      taskType: requestType,
      subjectId: task.subjectId,
      pseudonymousActorId: pseudonymousBookingActorId(task.subjectId),
      nowUtc: input.nowUtc,
    });
    if (result.kind === 'succeeded') {
      const saved = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'succeeded',
        evidenceId: randomUUID(),
        completionOutcome: result.evidence.outcome,
        retainedCount: result.evidence.retainedCount,
        occurredAtUtc: input.nowUtc,
      });
      return saved === 'saved' ? 'succeeded' : 'failed';
    }
    if (result.kind === 'retryableFailure') {
      const saved = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'dispatched',
        occurredAtUtc: input.nowUtc,
      });
      if (saved === 'saved') return 'retry_scheduled';
    }
    await this.orchestration.recordTaskOutcome({
      requestId: task.requestId,
      taskId: task.taskId,
      expectedTaskRevision: task.revision,
      nextStatus: 'failed',
      occurredAtUtc: input.nowUtc,
    });
    return 'failed';
  }
}

export function pseudonymousBookingActorId(subjectId: string): string {
  return `anon_${createHash('sha256')
    .update(`booking_privacy_subject_v1\0${subjectId}`, 'utf8')
    .digest('hex')}`;
}
