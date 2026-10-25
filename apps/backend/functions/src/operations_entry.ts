import type { Firestore } from 'firebase-admin/firestore';

import {
  inspectEventBookingDelivery,
  reconcileEventBookingDeliveries,
  replayDeadLetterEventBookingProjection,
} from './booking/event_projection_delivery.js';
import {
  inspectReconfirmationDeadlineJob,
  replayDeadLetterReconfirmationDeadline,
} from './booking/reconfirmation_deadline_worker.js';
import { OperationsConsole } from './modules/operations/operations_console.js';
import {
  createEmulatorNotifications,
  notificationOperationsPort,
  type NotificationsComposition,
} from './notifications_entry.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/**
 * L2 Emulator composition of the operations console (OPS-L2 §3.6): one port
 * per family that the console serves, each over the owner's own functions.
 * There is no callable, schedule or UI; tests and the stand drive it directly.
 */
export function createEmulatorOperationsConsole(
  firestore: Firestore,
  options: Readonly<{
    clock?: ServerClock;
    notifications?: NotificationsComposition;
    /** Test-only fault injection before every audit write. */
    beforeAudit?: () => void;
  }> = {},
): OperationsConsole {
  const clock = options.clock ?? systemServerClock;
  const notifications = options.notifications ?? createEmulatorNotifications(firestore, { clock });
  return new OperationsConsole(
    firestore,
    clock,
    {
      'TF-01': {
        inspect: (taskId, nowUtc) => inspectEventBookingDelivery(firestore, taskId, nowUtc),
        replay: (taskId, nowUtc, decision) =>
          replayDeadLetterEventBookingProjection(firestore, taskId, nowUtc, decision),
        reconcile: (nowUtc) => reconcileEventBookingDeliveries(firestore, nowUtc),
      },
      'TF-02': {
        inspect: (taskId, nowUtc) => inspectReconfirmationDeadlineJob(firestore, taskId, nowUtc),
        replay: (taskId, nowUtc, decision) =>
          replayDeadLetterReconfirmationDeadline(firestore, taskId, nowUtc, decision),
      },
      'TF-03': notificationOperationsPort(notifications),
    },
    options.beforeAudit,
  );
}
