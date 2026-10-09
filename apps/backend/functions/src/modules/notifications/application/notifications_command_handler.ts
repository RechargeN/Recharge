import { createHash } from 'node:crypto';

import { addDaysUtc, notificationDeliveryConfig } from '../domain/delivery_attempt.js';
import { archiveInboxItem, markInboxItemRead, type InboxItemRecord } from '../domain/inbox_item.js';
import { isUtcInstant } from '../domain/notification_effect.js';
import {
  applyPreferenceUpdate,
  defaultNotificationPolicies,
  inAppDecision,
  notificationCategories,
} from '../domain/notification_policy.js';
import type { CommandReceiptRecord, NotificationsTransaction } from '../domain/repositories.js';
import {
  refusal,
  requestIdPattern,
  wireRecord,
  type NotificationsHandlerDependencies,
  type NotificationsWireResult,
} from './notifications_query_handler.js';

/**
 * F1 `notificationsCommandV1` body:
 * { schemaVersion: 1, requestId, idempotencyKey, commandType, payload }.
 * The same idempotency key returns the stored result; the same key with a
 * different command is `idempotency_conflict` and mutates nothing.
 */
const commandTypes = ['markRead', 'markAllRead', 'archive', 'updatePreferences'] as const;
type CommandType = (typeof commandTypes)[number];
const idempotencyKeyPattern = /^[A-Za-z0-9_.:-]{8,128}$/u;
const notificationIdPattern = /^ntf_[0-9a-f]{32}$/u;
const maxMarkAll = 100;

const payloadKeys: Readonly<Record<CommandType, readonly string[]>> = {
  markRead: ['notificationId'],
  markAllRead: ['cutoffUtc', 'maxItems'],
  archive: ['notificationId', 'expectedRevision'],
  updatePreferences: ['expectedRevision', 'categories'],
};

function sha256(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (typeof value === 'object' && value !== null)
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonical((value as Record<string, unknown>)[key])}`)
      .join(',')}}`;
  return JSON.stringify(value);
}

type Outcome =
  | Readonly<{ kind: 'succeeded'; body: Readonly<Record<string, unknown>> }>
  | Readonly<{ kind: 'rejected'; code: string; extra?: Readonly<Record<string, unknown>> }>;

function itemBody(item: InboxItemRecord): Readonly<Record<string, unknown>> {
  return {
    notificationId: item.notificationId,
    status: item.status,
    revision: item.revision,
    readAtUtc: item.readAtUtc,
    archivedAtUtc: item.archivedAtUtc,
  };
}

export async function handleNotificationsCommandRequest(
  dependencies: NotificationsHandlerDependencies,
  userId: string,
  raw: unknown,
): Promise<NotificationsWireResult> {
  const request = wireRecord(raw);
  const rawType = typeof request?.commandType === 'string' ? request.commandType : null;
  if (request === null) return refusal('commandType', null, null, 'rejected', 'request_invalid');
  for (const key of Object.keys(request))
    if (!['schemaVersion', 'requestId', 'idempotencyKey', 'commandType', 'payload'].includes(key))
      return refusal('commandType', rawType, null, 'unsupported', `unknown_field:${key}`);
  const requestId =
    typeof request.requestId === 'string' && requestIdPattern.test(request.requestId)
      ? request.requestId
      : null;
  if (requestId === null)
    return refusal('commandType', rawType, null, 'rejected', 'request_id_invalid');
  if (request.schemaVersion !== 1)
    return refusal('commandType', rawType, requestId, 'unsupported', 'unsupported_version');
  if (!commandTypes.includes(rawType as CommandType))
    return refusal('commandType', rawType, requestId, 'unsupported', 'command_type_unsupported');
  const commandType = rawType as CommandType;
  if (
    typeof request.idempotencyKey !== 'string' ||
    !idempotencyKeyPattern.test(request.idempotencyKey)
  )
    return refusal('commandType', commandType, requestId, 'rejected', 'idempotency_key_invalid');
  const payload = wireRecord(request.payload);
  if (payload === null)
    return refusal('commandType', commandType, requestId, 'rejected', 'payload_invalid');
  for (const key of Object.keys(payload))
    if (!payloadKeys[commandType].includes(key))
      return refusal('commandType', commandType, requestId, 'unsupported', `unknown_field:${key}`);
  const feature = commandType === 'updatePreferences' ? 'preferences' : 'inbox';
  if (!dependencies.features[feature])
    return refusal('commandType', commandType, requestId, 'rejected', 'feature_disabled');

  const invalid = validate(commandType, payload);
  if (invalid !== null) return refusal('commandType', commandType, requestId, 'rejected', invalid);
  const now = dependencies.clock.now().toISOString();
  if (commandType === 'markAllRead' && Date.parse(payload.cutoffUtc as string) > Date.parse(now))
    return refusal('commandType', commandType, requestId, 'rejected', 'cutoff_in_future');

  const commandReceiptId = `ncr_${sha256(`${userId}|${commandType}|${request.idempotencyKey}`).slice(0, 40)}`;
  const semanticSha256 = sha256(canonical({ commandType, payload }));
  try {
    const markAllIds =
      commandType === 'markAllRead'
        ? await dependencies.store.unreadUpTo(
            userId,
            payload.cutoffUtc as string,
            (payload.maxItems as number) + 1,
          )
        : [];
    const outcome = await dependencies.store.transact(async (tx): Promise<Outcome> => {
      const prior = await tx.commandReceipt(commandReceiptId);
      if (prior !== undefined) {
        if (prior.userId !== userId || prior.semanticSha256 !== semanticSha256)
          return { kind: 'rejected', code: 'idempotency_conflict' };
        return { kind: 'succeeded', body: { ...prior.result, replayed: true } };
      }
      const result = await execute(tx, dependencies, userId, commandType, payload, markAllIds, now);
      if (result.kind === 'succeeded') {
        const receipt: CommandReceiptRecord = {
          schemaVersion: 1,
          commandReceiptId,
          userId,
          commandType,
          semanticSha256,
          result: result.body,
          createdAtUtc: now,
          expiresAt: new Date(
            addDaysUtc(now, notificationDeliveryConfig.commandReceiptRetentionDays),
          ),
        };
        tx.createCommandReceipt(receipt);
      }
      return result;
    });
    if (outcome.kind === 'rejected')
      return refusal(
        'commandType',
        commandType,
        requestId,
        'rejected',
        outcome.code,
        outcome.extra,
      );
    return { schemaVersion: 1, commandType, requestId, kind: 'succeeded', ...outcome.body };
  } catch {
    return refusal('commandType', commandType, requestId, 'rejected', 'temporarily_unavailable');
  }
}

function validate(commandType: CommandType, payload: Record<string, unknown>): string | null {
  switch (commandType) {
    case 'markRead':
      return typeof payload.notificationId === 'string' &&
        notificationIdPattern.test(payload.notificationId)
        ? null
        : 'notification_id_invalid';
    case 'archive':
      if (
        typeof payload.notificationId !== 'string' ||
        !notificationIdPattern.test(payload.notificationId)
      )
        return 'notification_id_invalid';
      return Number.isSafeInteger(payload.expectedRevision) &&
        (payload.expectedRevision as number) >= 1
        ? null
        : 'expected_revision_invalid';
    case 'markAllRead':
      if (!isUtcInstant(payload.cutoffUtc)) return 'cutoff_invalid';
      return Number.isSafeInteger(payload.maxItems) &&
        (payload.maxItems as number) >= 1 &&
        (payload.maxItems as number) <= maxMarkAll
        ? null
        : 'max_items_invalid';
    case 'updatePreferences':
      return Number.isSafeInteger(payload.expectedRevision) &&
        (payload.expectedRevision as number) >= 0
        ? null
        : 'expected_revision_invalid';
  }
}

async function execute(
  tx: NotificationsTransaction,
  dependencies: NotificationsHandlerDependencies,
  userId: string,
  commandType: CommandType,
  payload: Record<string, unknown>,
  markAllIds: readonly string[],
  now: string,
): Promise<Outcome> {
  if (commandType === 'markRead' || commandType === 'archive') {
    const item = await tx.inboxItem(payload.notificationId as string);
    // Another recipient's record is indistinguishable from a missing one.
    if (item === undefined || item === 'foreign' || item.recipientId !== userId)
      return { kind: 'rejected', code: 'notification_not_found' };
    if (commandType === 'markRead') {
      const next = markInboxItemRead(item, now);
      if (next !== item) tx.putInboxItem(next);
      return { kind: 'succeeded', body: itemBody(next) };
    }
    const archived = archiveInboxItem(item, payload.expectedRevision as number, now);
    if (archived.kind === 'stale_revision')
      return {
        kind: 'rejected',
        code: 'stale_revision',
        extra: { currentRevision: archived.currentRevision },
      };
    if (archived.item !== item) tx.putInboxItem(archived.item);
    return { kind: 'succeeded', body: itemBody(archived.item) };
  }
  if (commandType === 'markAllRead') {
    const maxItems = payload.maxItems as number;
    const ids = markAllIds.slice(0, maxItems);
    const items: (InboxItemRecord | 'foreign' | undefined)[] = [];
    for (const id of ids) items.push(await tx.inboxItem(id));
    let updated = 0;
    for (const item of items) {
      if (item === undefined || item === 'foreign' || item.recipientId !== userId) continue;
      const next = markInboxItemRead(item, now);
      if (next !== item) {
        tx.putInboxItem(next);
        updated += 1;
      }
    }
    return {
      kind: 'succeeded',
      body: { updated, remaining: markAllIds.length > maxItems, cutoffUtc: payload.cutoffUtc },
    };
  }
  const policy = (dependencies.policies ?? defaultNotificationPolicies).active();
  const current = await tx.preferences(userId);
  const update = applyPreferenceUpdate({
    policy,
    current,
    userId,
    expectedRevision: payload.expectedRevision as number,
    categories: payload.categories,
    nowUtc: now,
  });
  if (update.kind === 'stale_revision')
    return {
      kind: 'rejected',
      code: 'stale_revision',
      extra: { currentRevision: current?.revision ?? 0 },
    };
  if (update.kind === 'invalid_preference')
    return { kind: 'rejected', code: 'invalid_preference', extra: { detail: update.detail } };
  tx.putPreferences(update.preferences);
  return {
    kind: 'succeeded',
    body: {
      revision: update.preferences.revision,
      policyRevision: policy.revision,
      categories: notificationCategories.map((category) => ({
        category,
        inApp: inAppDecision(policy, update.preferences, category),
      })),
    },
  };
}
