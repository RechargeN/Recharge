import {
  LibraryPrivacyTaskHandler,
  libraryPrivacyAppliers,
} from '../../library/library_privacy_task_handler.js';
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
import { privacyPolicyRevision } from '../domain/privacy_writer_registry.js';
import type { PrivacyLegalHold } from '../domain/privacy_legal_hold.js';
import { privacyHoldCollections } from '../infrastructure/firestore_privacy_legal_hold_service.js';
import type {
  PrivacyApplier,
  PrivacyFaultPoint,
} from '../infrastructure/firestore_privacy_subject_sweep.js';
import {
  RegistryPrivacyTaskHandler,
  type PrivacyDomainHandler,
  type PrivacyDomainOutcome,
  type PrivacyDomainRun,
} from '../infrastructure/registry_privacy_task_handler.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { systemServerClock } from '../../../shared/server_clock.js';
import { FirestoreQuickPlanService } from '../../quick_plan/firestore_quick_plan_service.js';
import { FirestoreScenarioService } from '../../quick_plan/firestore_scenario_service.js';
import { FirestoreRouteService } from '../../route/firestore_route_service.js';
import { safetyPrivacyAppliers } from '../../trust_safety/safety_privacy.js';
import { mediaPrivacyApplier } from '../../media/infrastructure/media_privacy_applier.js';
import type { MediaDeletionService } from '../../media/application/media_deletion_service.js';
import type { AttachmentReferencePort } from '../../media/application/ports/attachment_reference_port.js';

type PrivacyTask = Awaited<ReturnType<PrivacyTaskRepository['listByRequest']>>[number];
export type RunOutcome =
  | 'succeeded'
  | 'blocked'
  | 'progress'
  | 'retry_scheduled'
  | 'failed'
  | 'not_found'
  | 'lease_held'
  | 'lease_lost'
  | 'handler_missing';

export interface PrivacyRunnerOptions {
  /** Owner of this runner's leases; one per process in production. */
  readonly leaseOwner?: string;
  readonly leaseSeconds?: number;
  readonly clock?: ServerClock;
  readonly notificationsStore?: NotificationsStore;
  /** Media's own deletion service; without it free Media stays (PB-14). */
  readonly media?: {
    readonly deletion: MediaDeletionService;
    readonly references: AttachmentReferencePort;
    readonly retentionPolicyAvailable: boolean;
  };
  /** Bounded work per run. */
  readonly maxPages?: number;
  readonly pageSize?: number;
  /** Test hook: throws at a named point to simulate a crash. */
  readonly fault?: (point: PrivacyFaultPoint) => void;
}

/**
 * The one DSR runner. It leases a task, restricts the account for erasure and
 * restriction (so no new user command can recreate data), asks the owning
 * domain's handler for the effect and records exactly what happened. Domains
 * are found by `domainId`; a domain without a handler stays visibly incomplete.
 */
export class PrivacyDomainTaskRunner {
  readonly #leaseOwner: string;
  readonly #handlers: ReadonlyMap<string, PrivacyDomainHandler>;

  constructor(
    private readonly firestore: Firestore,
    private readonly tasks: PrivacyTaskRepository,
    private readonly orchestration: PrivacyOrchestrationService,
    private readonly options: PrivacyRunnerOptions = {},
  ) {
    this.#leaseOwner = options.leaseOwner ?? `runner:${randomUUID()}`;
    this.#handlers = this.#composeHandlers();
  }

  /** Domain IDs this runner can serve; the registry coverage test reads it. */
  get handlerDomainIds(): readonly string[] {
    return [...this.#handlers.keys()].sort();
  }

  async runBookingTask(input: {
    readonly requestId: string;
    readonly taskId: string;
    readonly nowUtc: string;
  }): Promise<RunOutcome | 'not_booking'> {
    return this.#runFor(input, 'booking');
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
    if (options.store !== undefined) {
      const runner = new PrivacyDomainTaskRunner(this.firestore, this.tasks, this.orchestration, {
        ...this.options,
        leaseOwner: this.#leaseOwner,
        notificationsStore: options.store,
      });
      return runner.#runFor(input, 'notifications');
    }
    return this.#runFor(input, 'notifications');
  }

  async runLibraryTask(input: {
    readonly requestId: string;
    readonly taskId: string;
    readonly nowUtc: string;
  }): Promise<RunOutcome | 'not_library'> {
    return this.#runFor(input, 'library');
  }

  async #runFor<D extends string>(
    input: { readonly requestId: string; readonly taskId: string; readonly nowUtc: string },
    domainId: D,
  ): Promise<RunOutcome | `not_${D}`> {
    const task = await this.#task(input);
    if (task !== undefined && task.domainId !== domainId) return `not_${domainId}`;
    return this.runTask(input);
  }

  /** Runs one task of any domain once, within the bounded work of one lease. */
  async runTask(input: {
    readonly requestId: string;
    readonly taskId: string;
    readonly nowUtc: string;
  }): Promise<RunOutcome> {
    let task = await this.#task(input);
    if (task === undefined) return 'not_found';
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
      if (dispatched !== 'saved') return dispatched === 'not_found' ? 'not_found' : 'lease_lost';
      task = await this.#task(input);
      if (task === undefined) return 'not_found';
    }
    const requestSnapshot = await this.firestore
      .collection('privacyRequests')
      .doc(input.requestId)
      .get();
    if (!requestSnapshot.exists) return 'not_found';
    const requestType: unknown = requestSnapshot.get('requestType');
    const leased = await this.orchestration.leaseTask({
      requestId: task.requestId,
      taskId: task.taskId,
      expectedTaskRevision: task.revision,
      leaseOwner: this.#leaseOwner,
      leaseSeconds: this.options.leaseSeconds ?? 300,
      policyRevision: privacyPolicyRevision,
      nowUtc: input.nowUtc,
    });
    if (leased.kind === 'lease_held') return 'lease_held';
    if (leased.kind !== 'leased') return leased.kind === 'not_found' ? 'not_found' : 'lease_lost';
    task = leased.task;
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
    // Restriction and erasure close user authority before any domain effect.
    if (requestType === 'erasure' || requestType === 'restriction')
      await this.#restrictAccount(task.subjectId, input.nowUtc);
    const handler = this.#handlers.get(task.domainId);
    if (handler === undefined) {
      // An unverified writer never completes: the task stays visibly open.
      await this.orchestration.releaseTaskLease({
        requestId: task.requestId,
        taskId: task.taskId,
        expectedTaskRevision: task.revision,
        nowUtc: input.nowUtc,
      });
      return 'handler_missing';
    }
    const outcome = await handler.handle({
      taskType: requestType,
      subjectId: task.subjectId,
      taskId: task.taskId,
      leaseOwner: this.#leaseOwner,
      nowUtc: input.nowUtc,
      ...(this.options.fault === undefined ? {} : { fault: this.options.fault }),
      ...(this.options.maxPages === undefined ? {} : { maxPages: this.options.maxPages }),
      ...(this.options.pageSize === undefined ? {} : { pageSize: this.options.pageSize }),
    });
    return this.#record(task, outcome, input.nowUtc);
  }

  async #task(input: { readonly requestId: string; readonly taskId: string }) {
    return (await this.tasks.listByRequest(input.requestId)).find(
      (candidate) => candidate.taskId === input.taskId,
    );
  }

  async #restrictAccount(subjectId: string, nowUtc: string): Promise<void> {
    const account = await this.firestore
      .collection(identityAuthorityCollections.accounts)
      .doc(subjectId)
      .get();
    if (account.exists && account.get('status') !== 'restricted') {
      await new AccountSecurityService(
        new FirestoreIdentityAuthorityRepository(this.firestore),
      ).setStatus({ userId: subjectId, status: 'restricted', nowUtc });
    }
  }

  async #record(
    task: PrivacyTask,
    result: PrivacyDomainOutcome,
    nowUtc: string,
  ): Promise<RunOutcome> {
    const base = {
      requestId: task.requestId,
      taskId: task.taskId,
      expectedTaskRevision: task.revision,
      occurredAtUtc: nowUtc,
    };
    // A write refused for its revision means another runner took the task over.
    const conflict = (saved: string) => (saved === 'revision_conflict' ? 'lease_lost' : 'failed');
    switch (result.kind) {
      case 'lease_lost':
        return 'lease_lost';
      case 'progress': {
        const saved = await this.orchestration.releaseTaskLease({
          requestId: task.requestId,
          taskId: task.taskId,
          expectedTaskRevision: task.revision,
          nowUtc,
        });
        return saved === 'saved' ? 'progress' : conflict(saved);
      }
      case 'succeeded': {
        const saved = await this.orchestration.recordTaskOutcome({
          ...base,
          nextStatus: 'succeeded',
          evidenceId: randomUUID(),
          completionOutcome: result.evidence.outcome,
          retainedCount: result.evidence.retainedCount,
        });
        return saved === 'saved' ? 'succeeded' : conflict(saved);
      }
      case 'blocked': {
        const saved = await this.orchestration.recordTaskOutcome({
          ...base,
          nextStatus: 'blocked',
          blockedCodes: result.blockedCodes,
        });
        return saved === 'saved' ? 'blocked' : conflict(saved);
      }
      case 'retryableFailure': {
        const saved = await this.orchestration.recordTaskOutcome({
          ...base,
          nextStatus: 'dispatched',
        });
        if (saved === 'saved') return 'retry_scheduled';
        if (saved === 'revision_conflict') return 'lease_lost';
        break;
      }
      case 'failed':
        break;
    }
    await this.orchestration.recordTaskOutcome({ ...base, nextStatus: 'failed' });
    return 'failed';
  }

  #composeHandlers(): ReadonlyMap<string, PrivacyDomainHandler> {
    const db = this.firestore;
    const clock = this.options.clock ?? systemServerClock;
    const registry = (domainId: string, appliers: Readonly<Record<string, PrivacyApplier>> = {}) =>
      new RegistryPrivacyTaskHandler(db, domainId, appliers);
    const lazy = (make: () => PrivacyDomainHandler): PrivacyDomainHandler => {
      let handler: PrivacyDomainHandler | undefined;
      return { handle: (run) => (handler ??= make()).handle(run) };
    };
    // Notifications deletes through its own store: any active hold over the
    // domain (or the whole subject) keeps every remaining Notifications record.
    const held = (subjectId: string, domainId: string) => async () => {
      const holds = await db
        .collection(privacyHoldCollections.holds)
        .where('subjectId', '==', subjectId)
        .where('status', '==', 'active')
        .get();
      return holds.docs.some((hold) => {
        const { domainId: scope } = (hold.data() as PrivacyLegalHold).scope;
        return scope === '*' || scope === domainId;
      });
    };
    return new Map<string, PrivacyDomainHandler>([
      [
        'booking',
        {
          handle: async (run: PrivacyDomainRun) =>
            fromDomainResult(
              await new BookingPrivacyTaskHandler(
                new FirestoreBookingPrivacyRecordStore(db, run.subjectId, run.taskId),
              ).handle({
                taskType: run.taskType,
                subjectId: run.subjectId,
                pseudonymousActorId: pseudonymousBookingActorId(run.subjectId),
                nowUtc: run.nowUtc,
              }),
            ),
        },
      ],
      [
        'notifications',
        {
          handle: async (run: PrivacyDomainRun) =>
            fromDomainResult(
              await new NotificationsPrivacyTaskHandler(
                this.options.notificationsStore ?? new FirestoreNotificationsStore(db),
                { now: () => new Date(run.nowUtc) },
              ).handle({
                taskType: run.taskType,
                subjectId: run.subjectId,
                held: held(run.subjectId, 'notifications'),
              }),
            ),
        },
      ],
      [
        'library',
        {
          handle: async (run: PrivacyDomainRun) =>
            fromDomainResult(
              await new LibraryPrivacyTaskHandler(db).handle({
                taskType: run.taskType,
                subjectId: run.subjectId,
                erase: () => registry('library', libraryPrivacyAppliers).handle(run),
              }),
            ),
        },
      ],
      ['identity', registry('identity')],
      ['security', registry('security')],
      ['content', registry('content')],
      [
        'media',
        registry(
          'media',
          this.options.media === undefined ? {} : mediaPrivacyApplier(this.options.media),
        ),
      ],
      ['moderation', registry('moderation')],
      ['trust_safety', registry('trust_safety', safetyPrivacyAppliers(clock))],
      ['reviews', registry('reviews')],
      ['admin_support', registry('admin_support')],
      [
        'quick_plan',
        lazy(() => {
          const service = new FirestoreQuickPlanService(db, clock);
          return registry('quick_plan', {
            quickPlans: { inTransaction: (tx, ref, data) => service.privacyErasure(tx, ref, data) },
          });
        }),
      ],
      [
        'scenario',
        lazy(() => {
          const service = new FirestoreScenarioService(db, clock);
          return registry('scenario', {
            scenarios: { inTransaction: (tx, ref, data) => service.privacyErasure(tx, ref, data) },
          });
        }),
      ],
      [
        'route',
        lazy(() => {
          const service = new FirestoreRouteService(db, clock);
          return registry('route', {
            routes: { inTransaction: (tx, ref, data) => service.privacyErasure(tx, ref, data) },
          });
        }),
      ],
    ]);
  }
}

/** Existing Booking/Notifications/Library results in the runner's terms. */
function fromDomainResult(
  result:
    | PrivacyDomainOutcome
    | Readonly<{
        kind: 'succeeded';
        evidence: Readonly<{ outcome: 'completed' | 'retained_legal_hold'; retainedCount: number }>;
      }>
    | Readonly<{ kind: 'retryableFailure' | 'failed' }>,
): PrivacyDomainOutcome {
  if (result.kind === 'succeeded')
    return {
      kind: 'succeeded',
      evidence: { outcome: result.evidence.outcome, retainedCount: result.evidence.retainedCount },
    };
  return result;
}

export function pseudonymousBookingActorId(subjectId: string): string {
  return `anon_${createHash('sha256')
    .update(`booking_privacy_subject_v1\0${subjectId}`, 'utf8')
    .digest('hex')}`;
}
