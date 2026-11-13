import { addDaysUtc, notificationDeliveryConfig } from './delivery_attempt.js';
import type { NotificationCategory } from './notification_policy.js';
import type { NotificationTemplateVariables } from './notification_templates.js';

/**
 * F1 logical inbox record. Server-authoritative recipient state:
 * `unread → read → archived`. Read never means the source action completed;
 * archive changes presentation only. Navigation is a typed intent, never a URL;
 * the client revalidates the target on open.
 */
export type InboxItemStatus = 'unread' | 'read' | 'archived';

export interface NotificationNavigationIntent {
  readonly routeKind: 'eventDetails';
  readonly objectRef: Readonly<{ type: 'event'; id: string }>;
  readonly routeContractVersion: 1;
}

export interface InboxItemRecord {
  readonly schemaVersion: 1;
  readonly notificationId: string;
  readonly recipientId: string;
  readonly receiptId: string;
  readonly category: NotificationCategory;
  readonly templateKey: string;
  readonly templateRevision: number;
  readonly variables: NotificationTemplateVariables;
  readonly navigation: NotificationNavigationIntent;
  readonly sourceRef: Readonly<{ type: 'booking'; id: string; revision: number }>;
  readonly status: InboxItemStatus;
  readonly revision: number;
  readonly readAtUtc: string | null;
  readonly archivedAtUtc: string | null;
  readonly occurredAtUtc: string;
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly expiresAt: Date;
}

export function createInboxItem(input: {
  readonly notificationId: string;
  readonly recipientId: string;
  readonly receiptId: string;
  readonly category: NotificationCategory;
  readonly templateKey: string;
  readonly templateRevision: number;
  readonly variables: NotificationTemplateVariables;
  readonly eventContentId: string;
  readonly bookingId: string;
  readonly bookingRevision: number;
  readonly occurredAtUtc: string;
  readonly createdAtUtc: string;
}): InboxItemRecord {
  return {
    schemaVersion: 1,
    notificationId: input.notificationId,
    recipientId: input.recipientId,
    receiptId: input.receiptId,
    category: input.category,
    templateKey: input.templateKey,
    templateRevision: input.templateRevision,
    variables: input.variables,
    navigation: {
      routeKind: 'eventDetails',
      objectRef: { type: 'event', id: input.eventContentId },
      routeContractVersion: 1,
    },
    sourceRef: { type: 'booking', id: input.bookingId, revision: input.bookingRevision },
    status: 'unread',
    revision: 1,
    readAtUtc: null,
    archivedAtUtc: null,
    occurredAtUtc: input.occurredAtUtc,
    createdAtUtc: input.createdAtUtc,
    updatedAtUtc: input.createdAtUtc,
    expiresAt: new Date(
      addDaysUtc(input.createdAtUtc, notificationDeliveryConfig.itemRetentionDays),
    ),
  };
}

/** Idempotent: an already read or archived record is returned unchanged. */
export function markInboxItemRead(item: InboxItemRecord, nowUtc: string): InboxItemRecord {
  if (item.status !== 'unread') return item;
  return {
    ...item,
    status: 'read',
    readAtUtc: nowUtc,
    revision: item.revision + 1,
    updatedAtUtc: nowUtc,
  };
}

export type ArchiveResult =
  | Readonly<{ kind: 'archived'; item: InboxItemRecord }>
  | Readonly<{ kind: 'stale_revision'; currentRevision: number }>;

/** Archiving keeps read state: an unread record is archived as read. */
export function archiveInboxItem(
  item: InboxItemRecord,
  expectedRevision: number,
  nowUtc: string,
): ArchiveResult {
  if (item.status === 'archived') return { kind: 'archived', item };
  if (item.revision !== expectedRevision)
    return { kind: 'stale_revision', currentRevision: item.revision };
  return {
    kind: 'archived',
    item: {
      ...item,
      status: 'archived',
      readAtUtc: item.readAtUtc ?? nowUtc,
      archivedAtUtc: nowUtc,
      revision: item.revision + 1,
      updatedAtUtc: nowUtc,
    },
  };
}
