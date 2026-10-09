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
import { NotificationsPrivacyTaskHandler } from '../../notifications/application/notifications_privacy_task_handler.js';
import type { NotificationsStore } from '../../notifications/domain/repositories.js';
import { FirestoreNotificationsStore } from '../../notifications/infrastructure/firestore_notifications_repository.js';

type PrivacyRequestType = 'access' | 'erasure' | 'restriction';
type PrivacyTask = Awaited<ReturnType<PrivacyTaskRepository['listByRequest']>>[number];
type DomainResult =
  | Readonly<{
      kind: 'succeeded';
      evidence: Readonly<{ outcome: 'completed' | 'retained_legal_hold'; retainedCount: number }>;
    }>
  | Readonly<{ kind: 'retryableFailure' }>
  | Readonly<{ kind: 'failed' }>;
type RunOutcome = 'succeeded' | 'retry_scheduled' | 'failed' | 'not_found';

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
  }): Promise<RunOutcome | 'not_booking'> {
    const prepared = await this.#prepare(input, 'booking');
    if (prepared.kind !== 'ready') return prepared.outcome;
    const { task, requestType } = prepared;
    const handler = new BookingPrivacyTaskHandler(
      new FirestoreBookingPrivacyRecordStore(this.firestore, task.subjectId, task.taskId),
    );
    const result = await handler.handle({
      taskType: requestType,
      subjectId: task.subjectId,
      pseudonymousActorId: pseudonymousBookingActorId(task.subjectId),
      nowUtc: input.nowUtc,
    });
    return this.#record(task, result, input.nowUtc);
  }

  /**
   * F1: the Notifications privacy domain. Erasure restricts the account first
   * (as for Booking), so a running consumer cannot create a new inbox record
   * afterwards. A Notifications outage fails only this task, which is retried
   * independently; the request is complete only once this task succeeded.
   */
  async runNotificationsTask(
    input: {
      readonly requestId: string;
      readonly taskId: string;
      readonly nowUtc: string;
    },
    options: Readonly<{ store?: NotificationsStore }> = {},
  ): Promise<RunOutcome | 'not_notifications'> {
    const prepared = await this.#prepare(input, 'notifications');
    if (prepared.kind !== 'ready') return prepared.outcome;
    const { task, requestType } = prepared;
    const handler = new NotificationsPrivacyTaskHandler(
      options.store ?? new FirestoreNotificationsStore(this.firestore),
      { now: () => new Date(input.nowUtc) },
    );
    const result = await handler.handle({ taskType: requestType, subjectId: task.subjectId });
    return this.#record(task, result, input.nowUtc);
  }

  async #prepare<D extends 'booking' | 'notifications'>(
    input: { readonly requestId: string; readonly taskId: string; readonly nowUtc: string },
    domainId: D,
  ): Promise<
    | Readonly<{ kind: 'ready'; task: PrivacyTask; requestType: PrivacyRequestType }>
    | Readonly<{ kind: 'done'; outcome: RunOutcome | `not_${D}` }>
  > {
    const done = (outcome: RunOutcome | `not_${D}`) => ({ kind: 'done' as const, outcome });
    let task = (await this.tasks.listByRequest(input.requestId)).find(
      (candidate) => candidate.taskId === input.taskId,
    );
    if (task === undefined) return done('not_found');
    if (task.domainId !== domainId) return done(`not_${domainId}`);
    if (task.status === 'succeeded') return done('succeeded');
    if (task.status === 'failed' || task.status === 'cancelled') return done('failed');
    if (task.status === 'pending') {
      const dispatched = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'dispatched',
        occurredAtUtc: input.nowUtc,
      });
      if (dispatched !== 'saved') return done(dispatched === 'not_found' ? 'not_found' : 'failed');
      task = (await this.tasks.listByRequest(input.requestId)).find(
        (candidate) => candidate.taskId === input.taskId,
      );
      if (task === undefined) return done('not_found');
    }

    const requestSnapshot = await this.firestore
      .collection('privacyRequests')
      .doc(input.requestId)
      .get();
    if (!requestSnapshot.exists) return done('not_found');
    const requestType: unknown = requestSnapshot.get('requestType');
    if (requestType !== 'access' && requestType !== 'erasure' && requestType !== 'restriction') {
      await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'failed',
        occurredAtUtc: input.nowUtc,
      });
      return done('failed');
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
    return { kind: 'ready', task, requestType };
  }

  async #record(task: PrivacyTask, result: DomainResult, nowUtc: string): Promise<RunOutcome> {
    if (result.kind === 'succeeded') {
      const saved = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'succeeded',
        evidenceId: randomUUID(),
        completionOutcome: result.evidence.outcome,
        retainedCount: result.evidence.retainedCount,
        occurredAtUtc: nowUtc,
      });
      return saved === 'saved' ? 'succeeded' : 'failed';
    }
    if (result.kind === 'retryableFailure') {
      const saved = await this.orchestration.recordTaskOutcome({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nextStatus: 'dispatched',
        occurredAtUtc: nowUtc,
      });
      if (saved === 'saved') return 'retry_scheduled';
    }
    await this.orchestration.recordTaskOutcome({
      requestId: task.requestId,
      taskId: task.taskId,
      expectedTaskRevision: task.revision,
      nextStatus: 'failed',
      occurredAtUtc: nowUtc,
    });
    return 'failed';
  }
}

export function pseudonymousBookingActorId(subjectId: string): string {
  return `anon_${createHash('sha256')
    .update(`booking_privacy_subject_v1\0${subjectId}`, 'utf8')
    .digest('hex')}`;
}
