import type { Firestore } from 'firebase-admin/firestore';

import {
  NotificationEffectConsumer,
  type ConsumeOutcome,
} from './modules/notifications/application/consume_notification_effect.js';
import { NotificationReconciler } from './modules/notifications/application/notification_reconciler.js';
import { handleNotificationsCommandRequest } from './modules/notifications/application/notifications_command_handler.js';
import { NotificationsPrivacyTaskHandler } from './modules/notifications/application/notifications_privacy_task_handler.js';
import { handleNotificationsQueryRequest } from './modules/notifications/application/notifications_query_handler.js';
import type { NotificationsStore } from './modules/notifications/domain/repositories.js';
import {
  bookingOutboxCollection,
  FirestoreBookingOutboxSource,
} from './modules/notifications/infrastructure/firestore_notification_sources.js';
import { FirestoreNotificationsStore } from './modules/notifications/infrastructure/firestore_notifications_repository.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { notificationsFlagIds } from './shared/feature_flags.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/** The verified Session subject behind a client Notifications call. */
export interface NotificationsCaller {
  readonly firestore: Firestore;
  readonly userId: string;
  readonly features: Readonly<{ inbox: boolean; preferences: boolean }>;
}

export interface NotificationsComposition {
  readonly store: NotificationsStore;
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
  options: Readonly<{ clock?: ServerClock; store?: NotificationsStore }> = {},
): NotificationsComposition {
  const clock = options.clock ?? systemServerClock;
  const store = options.store ?? new FirestoreNotificationsStore(firestore);
  const consumer = new NotificationEffectConsumer({ store, clock });
  return {
    store,
    consumer,
    reconciler: new NotificationReconciler(
      store,
      new FirestoreBookingOutboxSource(firestore),
      consumer,
      clock,
    ),
    privacy: new NotificationsPrivacyTaskHandler(store, clock),
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
