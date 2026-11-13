import { randomUUID } from 'node:crypto';

import type { App } from 'firebase-admin/app';
import type { Firestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';

import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import { NotificationEffectConsumer } from './modules/notifications/application/consume_notification_effect.js';
import { handleNotificationsCommandRequest } from './modules/notifications/application/notifications_command_handler.js';
import { handleNotificationsQueryRequest } from './modules/notifications/application/notifications_query_handler.js';
import { handlePushDeviceCommand } from './modules/notifications/application/push_device_command_handler.js';
import {
  dispatchPushFor,
  PushDispatcher,
  type PushProviderPort,
} from './modules/notifications/application/push_dispatcher.js';
import type { NotificationsStore } from './modules/notifications/domain/repositories.js';
import { FcmPushProvider } from './modules/notifications/infrastructure/fcm_push_provider.js';
import { FirestoreNotificationsStore } from './modules/notifications/infrastructure/firestore_notifications_repository.js';
import {
  FirestorePushSessions,
  FirestorePushStore,
} from './modules/notifications/infrastructure/firestore_push_store.js';
import { resolveBookingActor } from './shared/auth_context.js';
import { bookingAccessCapability } from './shared/booking_access_authority.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/**
 * N3c (owner-approved 2026-11-13): the dev-cloud Notifications runtime for
 * recharge-dev-n2a01. The inbox stays the source of truth; push is the FCM hint
 * after it. No Booking runs in dev, so the owner's self-test feeds one synthetic
 * Booking effect through the ordinary consumer (inbox first, then push).
 */
export const devNotificationsCallables = Object.freeze([
  'notificationsQueryV1',
  'notificationsCommandV1',
  'pushDeviceCommandV1',
  'sendSelfTestNotificationV1',
] as const);
export type DevNotificationsCallable = (typeof devNotificationsCallables)[number];

export interface DevNotifications {
  readonly store: NotificationsStore;
  readonly push: PushDispatcher;
  readonly consumer: NotificationEffectConsumer;
}

export function createDevNotifications(input: {
  readonly app: App;
  readonly firestore: Firestore;
  readonly clock?: ServerClock;
  readonly provider?: PushProviderPort;
}): DevNotifications {
  const clock = input.clock ?? systemServerClock;
  const store = new FirestoreNotificationsStore(input.firestore);
  const push = new PushDispatcher({
    store: new FirestorePushStore(input.firestore),
    provider: input.provider ?? new FcmPushProvider(input.app),
    sessions: new FirestorePushSessions(input.firestore),
    preferences: (userId) => store.transact((tx) => tx.preferences(userId)),
    clock,
    log: (event, fields) => info(event, fields),
  });
  const consumer = new NotificationEffectConsumer({
    store,
    clock,
    afterInboxCreated: (notificationId) => dispatchPushFor(store, push, notificationId),
  });
  return { store, push, consumer };
}

/** One synthetic, already-consumable Booking v2 effect for the recipient. */
export function selfTestEffect(recipientId: string, nowUtc: string, id: string = randomUUID()) {
  const eventId = `devselftest_${id}`;
  return {
    eventId,
    data: {
      schemaVersion: 2,
      effectDisposition: 'pending',
      dispatchable: true,
      replayable: true,
      eventId,
      eventType: 'booking.confirmed',
      eventVersion: 1,
      producer: 'booking',
      aggregateType: 'booking',
      aggregateId: `devselftest-booking-${id}`,
      aggregateRevision: 1,
      occurredAt: nowUtc,
      correlationId: `devselftest-${id}`,
      marketId: 'LV',
      dataClass: 'personal',
      actorId: recipientId,
      payload: {
        schemaVersion: 1,
        eventContentId: 'dev-self-test',
        occurrenceId: 'dev-self-test',
        deliverUntilUtc: new Date(Date.parse(nowUtc) + 3_600_000).toISOString(),
      },
    },
  };
}

function stripTransport(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}

/**
 * The verified Firebase uid is already on the owner allowlist; the Recharge
 * Session in the payload decides the user and the installation.
 */
export async function handleDevNotifications(input: {
  readonly callable: DevNotificationsCallable;
  readonly firebaseUid: string;
  readonly data: unknown;
  readonly firestore: Firestore;
  readonly compose: () => DevNotifications;
  readonly now?: () => Date;
}): Promise<Readonly<Record<string, unknown>>> {
  const rejected = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });
  const sessionContext =
    typeof input.data === 'object' && input.data !== null && !Array.isArray(input.data)
      ? (input.data as Record<string, unknown>).sessionContext
      : undefined;
  const actor = resolveBookingActor({ uid: input.firebaseUid, token: {} }, sessionContext);
  if (!actor.ok) return rejected('unauthenticated');
  const now = (input.now ?? (() => new Date()))();
  const decision = await new FirestoreBookingAccessAuthority(input.firestore).authorize(
    actor.actor,
    now,
    bookingAccessCapability,
  );
  if (!decision.allowed) return rejected('unauthenticated');
  const userId = decision.userId;
  const notifications = input.compose();
  const dependencies = {
    store: notifications.store,
    clock: { now: () => new Date() },
    features: { inbox: true, preferences: true },
  };
  switch (input.callable) {
    case 'notificationsQueryV1':
      return handleNotificationsQueryRequest(dependencies, userId, stripTransport(input.data));
    case 'notificationsCommandV1':
      return handleNotificationsCommandRequest(dependencies, userId, stripTransport(input.data));
    case 'pushDeviceCommandV1':
      return handlePushDeviceCommand({
        push: notifications.push,
        userId,
        installationId: actor.actor.installationId,
        data: input.data,
      });
    case 'sendSelfTestNotificationV1': {
      const effect = selfTestEffect(userId, now.toISOString());
      const outcome = await notifications.consumer.consume(effect.eventId, effect.data);
      return { schemaVersion: 1, kind: 'succeeded', outcome };
    }
  }
}
