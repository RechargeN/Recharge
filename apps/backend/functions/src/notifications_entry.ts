import type { Firestore } from 'firebase-admin/firestore';

import {
  NotificationEffectConsumer,
  type ConsumeOutcome,
} from './modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from './modules/notifications/application/notification_reconciler.js';
import { handleNotificationsCommandRequest } from './modules/notifications/application/notifications_command_handler.js';
import { NotificationsPrivacyTaskHandler } from './modules/notifications/application/notifications_privacy_task_handler.js';
import { handleNotificationsQueryRequest } from './modules/notifications/application/notifications_query_handler.js';
import {
  attemptIdFor,
  type DeliveryAttempt,
} from './modules/notifications/domain/delivery_attempt.js';
import type { NotificationsStore } from './modules/notifications/domain/repositories.js';
import { emergencySwitchState } from './modules/operations/emergency_switch.js';
import type {
  OperationsFailureEntry,
  OperationsFamilyPort,
  OperationsTaskView,
} from './modules/operations/operations_ports.js';
import {
  bookingOutboxCollection,
  FirestoreBookingOutboxSource,
} from './modules/notifications/infrastructure/firestore_notification_sources.js';
import { FirestoreNotificationsStore } from './modules/notifications/infrastructure/firestore_notifications_repository.js';
import { info } from 'firebase-functions/logger';
import {
  PushDispatcher,
  type PushProviderPort,
} from './modules/notifications/application/push_dispatcher.js';
import { FakePushProvider } from './modules/notifications/infrastructure/fake_push_provider.js';
import {
  FirestorePushSessions,
  FirestorePushStore,
} from './modules/notifications/infrastructure/firestore_push_store.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { notificationsFlagIds, operationsEmergencySwitchIds } from './shared/feature_flags.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/** The verified Session subject behind a client Notifications call. */
export interface NotificationsCaller {
  readonly firestore: Firestore;
  readonly userId: string;
  readonly features: Readonly<{ inbox: boolean; preferences: boolean }>;
}

export interface NotificationsComposition {
  readonly store: NotificationsStore;
  /** N3c: the FCM push hint after the inbox item (fake provider in the Emulator). */
  readonly push: PushDispatcher;
  readonly consumer: NotificationEffectConsumer;
  readonly reconciler: NotificationReconciler;
  readonly privacy: NotificationsPrivacyTaskHandler;
}

/**
 * F1 Emulator composition. `store` may be replaced (tests inject a failing
 * decorator to prove that Notifications outages never block Booking, access
 * recovery or independent privacy tasks).
 */
export function createEmulatorNotifications(
  firestore: Firestore,
  options: Readonly<{
    clock?: ServerClock;
    store?: NotificationsStore;
    pushProvider?: PushProviderPort;
  }> = {},
): NotificationsComposition {
  const clock = options.clock ?? systemServerClock;
  const store = options.store ?? new FirestoreNotificationsStore(firestore);
  const push = createPushDispatcher(firestore, store, clock, options.pushProvider);
  const consumer = new NotificationEffectConsumer({
    store,
    clock,
    afterInboxCreated: (notificationId) => dispatchPushFor(store, push, notificationId),
    contained: async () =>
      (await emergencySwitchState(
        firestore,
        operationsEmergencySwitchIds.notificationsConsumeBooking,
      )) === 'contained',
  });
  return {
    store,
    push,
    consumer,
    reconciler: new NotificationReconciler(
      store,
      new FirestoreBookingOutboxSource(firestore),
      consumer,
      clock,
      {},
      push,
    ),
    privacy: new NotificationsPrivacyTaskHandler(store, clock, push),
  };
}

/**
 * N3c (2026-11-13): push over Firestore state and the Identity Sessions. The
 * Emulator never reaches FCM: without a provider it uses the fake one.
 */
export function createPushDispatcher(
  firestore: Firestore,
  store: NotificationsStore,
  clock: ServerClock = systemServerClock,
  provider: PushProviderPort = new FakePushProvider(),
): PushDispatcher {
  return new PushDispatcher({
    store: new FirestorePushStore(firestore),
    provider,
    sessions: new FirestorePushSessions(firestore),
    preferences: (userId) => store.transact((tx) => tx.preferences(userId)),
    clock,
    log: (event, fields) => info(event, fields),
  });
}

/** Reads the committed inbox item and sends its push hint. */
export async function dispatchPushFor(
  store: NotificationsStore,
  push: PushDispatcher,
  notificationId: string,
): Promise<void> {
  const item = await store.transact((tx) => tx.inboxItem(notificationId));
  if (item === undefined || item === 'foreign') return;
  await push.dispatch({
    notificationId: item.notificationId,
    recipientId: item.recipientId,
    category: item.category,
  });
}

/**
 * L2 port of TF-03 for the operations console (OPS-L2 §3.6): the receipt and
 * its attempt records seen as codes and counters, never the recipient, event or
 * payload. Replay and reconciliation stay the F1 reconciler's own.
 */
export function notificationOperationsPort(
  composition: NotificationsComposition,
): OperationsFamilyPort {
  return {
    async inspect(receiptId, nowUtc): Promise<OperationsTaskView | undefined> {
      return composition.store.transact(async (tx) => {
        const receipt = await tx.receipt(receiptId);
        if (receipt === undefined) return undefined;
        if (receipt.shape === 'minimal')
          return {
            taskId: receiptId,
            state: 'done',
            storedStatus: receipt.status,
            attempts: 0,
            attemptBudget: 0,
            failureClass: null,
            failureCode: receipt.reason,
            firstFailure: null,
            failureHistory: [],
            replayCount: 0,
            nextAttemptAtUtc: null,
          };
        const attempts: DeliveryAttempt[] = [];
        for (let number = 1; number <= Math.min(receipt.attemptCount, 40); number += 1) {
          const attempt = await tx.attempt(attemptIdFor(receiptId, number));
          if (attempt !== undefined) attempts.push(attempt);
        }
        const history: OperationsFailureEntry[] = attempts
          .filter((attempt) => attempt.status === 'failed' || attempt.status === 'abandoned')
          .map((attempt) => ({
            attempt: attempt.attemptNumber,
            failureClass:
              attempt.status === 'abandoned'
                ? 'unknown'
                : attempt.failureClass === 'permanent'
                  ? 'permanent'
                  : 'transient',
            code: attempt.failureCode ?? 'unknown',
            atUtc: attempt.finishedAtUtc ?? attempt.startedAtUtc,
          }));
        const leaseLive =
          receipt.leaseExpiresAtUtc !== null &&
          Date.parse(receipt.leaseExpiresAtUtc) > Date.parse(nowUtc);
        return {
          taskId: receiptId,
          state:
            receipt.status === 'created'
              ? 'done'
              : receipt.status === 'dead_lettered'
                ? 'dead_letter'
                : receipt.status === 'retry_scheduled'
                  ? 'retry_scheduled'
                  : leaseLive
                    ? 'in_flight'
                    : 'unknown',
          storedStatus: receipt.status,
          attempts: receipt.attemptCount,
          attemptBudget: receipt.attemptBudget,
          failureClass: history.at(-1)?.failureClass ?? null,
          failureCode: receipt.reason ?? history.at(-1)?.code ?? null,
          firstFailure: history[0] ?? null,
          failureHistory: history.slice(-20),
          replayCount: receipt.replayCount,
          nextAttemptAtUtc: receipt.nextAttemptAtUtc,
        };
      });
    },
    async replay(receiptId, _nowUtc, decision) {
      const result = await composition.reconciler.replay({
        receiptId,
        reason: decision.reason,
        operator: decision.actorId,
      });
      switch (result.kind) {
        case 'replayed':
          return 'requeued';
        case 'refused':
          return 'not_dead_letter';
        case 'reason_invalid':
          return 'decision_conflict';
        default:
          return result.kind;
      }
    },
    async reconcile() {
      const report = await composition.reconciler.reconcile();
      return {
        complete: report.complete,
        scanned: report.scanned,
        redispatched: Object.values(report.outcomes).reduce((sum, count) => sum + (count ?? 0), 0),
        findings: report.findings.map((finding) => ({ code: finding.code, ref: finding.ref })),
      };
    },
  };
}

export function notificationFlags(firestore: Firestore): FirestoreFeatureFlagGate {
  return new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
}

export async function notificationFeatures(
  firestore: Firestore,
): Promise<Readonly<{ inbox: boolean; preferences: boolean }>> {
  const flags = notificationFlags(firestore);
  return {
    inbox: await flags.isEnabled(notificationsFlagIds.inbox),
    preferences: await flags.isEnabled(notificationsFlagIds.preferences),
  };
}

const outboxIdPattern = /^[A-Za-z0-9_.:-]{1,200}$/u;

/**
 * Trusted backend context for the `bookingOutbox` trigger: no Session, but the
 * source path, document id, producer and schema version are checked, and the
 * consumer flag must be on. A disabled consumer leaves the obligation pending
 * for reconciliation; v1 `suppressedPreActivation` records are never consumed.
 */
export async function consumeBookingNotificationEffect(
  firestore: Firestore,
  input: Readonly<{ collection: string; outboxId: string; data: unknown }>,
  options: Readonly<{ clock?: ServerClock; store?: NotificationsStore }> = {},
): Promise<ConsumeOutcome | 'disabled' | 'source_refused'> {
  if (input.collection !== bookingOutboxCollection || !outboxIdPattern.test(input.outboxId))
    return 'source_refused';
  const data = input.data as Record<string, unknown> | null | undefined;
  if (data?.schemaVersion === 2 && (data.producer !== 'booking' || data.eventId !== input.outboxId))
    return 'source_refused';
  if (!(await notificationFlags(firestore).isEnabled(notificationsFlagIds.consumeBooking)))
    return 'disabled';
  return createEmulatorNotifications(firestore, options).consumer.consume(
    input.outboxId,
    input.data,
  );
}

function stripTransport(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}

export function handleNotificationsQuery(
  caller: NotificationsCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  return handleNotificationsQueryRequest(
    {
      store: new FirestoreNotificationsStore(caller.firestore),
      clock: systemServerClock,
      features: caller.features,
    },
    caller.userId,
    stripTransport(data),
  );
}

export function handleNotificationsCommand(
  caller: NotificationsCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  return handleNotificationsCommandRequest(
    {
      store: new FirestoreNotificationsStore(caller.firestore),
      clock: systemServerClock,
      features: caller.features,
    },
    caller.userId,
    stripTransport(data),
  );
}
