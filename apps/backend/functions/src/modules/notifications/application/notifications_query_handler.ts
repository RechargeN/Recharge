import { createHash } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import type { InboxItemRecord } from '../domain/inbox_item.js';
import {
  defaultNotificationPolicies,
  inAppDecision,
  notificationCategories,
  type NotificationPolicyRegistry,
} from '../domain/notification_policy.js';
import {
  defaultNotificationTemplates,
  isNotificationLocale,
  renderNotificationTemplate,
  type NotificationLocale,
  type NotificationTemplateRegistry,
} from '../domain/notification_templates.js';
import type { InboxPosition, InboxView, NotificationsStore } from '../domain/repositories.js';

/**
 * F1 `notificationsQueryV1` body:
 * { schemaVersion: 1, requestId, queryType: 'listInbox' | 'unreadSummary' |
 *   'getPreferences', payload }. The caller is the verified Session subject;
 * a client-supplied user id is never accepted.
 */
export type NotificationsWireResult = Readonly<Record<string, unknown>>;

export interface NotificationsHandlerDependencies {
  readonly store: NotificationsStore;
  readonly clock: ServerClock;
  readonly features: Readonly<{ inbox: boolean; preferences: boolean }>;
  readonly policies?: NotificationPolicyRegistry;
  readonly templates?: NotificationTemplateRegistry;
}

export const requestIdPattern = /^[A-Za-z0-9_.:-]{1,128}$/u;
const queryTypes = ['listInbox', 'unreadSummary', 'getPreferences'] as const;
type QueryType = (typeof queryTypes)[number];
const maxPageSize = 50;
const defaultPageSize = 20;

export function wireRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function refusal(
  typeKey: 'queryType' | 'commandType',
  type: string | null,
  requestId: string | null,
  kind: 'rejected' | 'unsupported',
  code: string,
  extra: Readonly<Record<string, unknown>> = {},
): NotificationsWireResult {
  return {
    schemaVersion: 1,
    ...(type === null ? {} : { [typeKey]: type }),
    ...(requestId === null ? {} : { requestId }),
    kind,
    code,
    ...extra,
  };
}

function recipientTag(userId: string): string {
  return createHash('sha256')
    .update(`notifications-cursor|${userId}`, 'utf8')
    .digest('hex')
    .slice(0, 16);
}

function encodeCursor(userId: string, view: InboxView, position: InboxPosition): string {
  return Buffer.from(
    JSON.stringify({
      v: 1,
      r: recipientTag(userId),
      w: view,
      c: position.createdAtUtc,
      n: position.notificationId,
    }),
    'utf8',
  ).toString('base64url');
}

function decodeCursor(userId: string, view: InboxView, cursor: string): InboxPosition | null {
  try {
    if (cursor.length > 512) return null;
    const parsed = wireRecord(JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')));
    if (
      parsed === null ||
      parsed.v !== 1 ||
      parsed.r !== recipientTag(userId) ||
      parsed.w !== view ||
      typeof parsed.c !== 'string' ||
      !Number.isFinite(Date.parse(parsed.c)) ||
      typeof parsed.n !== 'string' ||
      !/^ntf_[0-9a-f]{32}$/u.test(parsed.n)
    )
      return null;
    return { createdAtUtc: parsed.c, notificationId: parsed.n };
  } catch {
    return null;
  }
}

export function inboxItemWire(
  item: InboxItemRecord,
  locale: NotificationLocale,
  templates: NotificationTemplateRegistry,
): Readonly<Record<string, unknown>> {
  const template = templates.get(item.templateKey, item.templateRevision);
  const content =
    template === undefined ? null : renderNotificationTemplate(template, locale, item.variables);
  return {
    notificationId: item.notificationId,
    category: item.category,
    status: item.status,
    revision: item.revision,
    createdAtUtc: item.createdAtUtc,
    occurredAtUtc: item.occurredAtUtc,
    readAtUtc: item.readAtUtc,
    archivedAtUtc: item.archivedAtUtc,
    template: { key: item.templateKey, revision: item.templateRevision },
    content,
    contentStatus:
      template === undefined
        ? 'template_unavailable'
        : content === null
          ? 'unsupported_locale'
          : 'rendered',
    navigation: item.navigation,
  };
}

export async function handleNotificationsQueryRequest(
  dependencies: NotificationsHandlerDependencies,
  userId: string,
  raw: unknown,
): Promise<NotificationsWireResult> {
  const request = wireRecord(raw);
  const rawType = typeof request?.queryType === 'string' ? request.queryType : null;
  if (request === null) return refusal('queryType', null, null, 'rejected', 'request_invalid');
  for (const key of Object.keys(request))
    if (!['schemaVersion', 'requestId', 'queryType', 'payload'].includes(key))
      return refusal('queryType', rawType, null, 'unsupported', `unknown_field:${key}`);
  const requestId =
    typeof request.requestId === 'string' && requestIdPattern.test(request.requestId)
      ? request.requestId
      : null;
  if (requestId === null)
    return refusal('queryType', rawType, null, 'rejected', 'request_id_invalid');
  if (request.schemaVersion !== 1)
    return refusal('queryType', rawType, requestId, 'unsupported', 'unsupported_version');
  if (!queryTypes.includes(rawType as QueryType))
    return refusal('queryType', rawType, requestId, 'unsupported', 'query_type_unsupported');
  const queryType = rawType as QueryType;
  const payload = wireRecord(request.payload);
  if (payload === null)
    return refusal('queryType', queryType, requestId, 'rejected', 'payload_invalid');
  const feature = queryType === 'getPreferences' ? 'preferences' : 'inbox';
  if (!dependencies.features[feature])
    return refusal('queryType', queryType, requestId, 'rejected', 'feature_disabled');
  const ok = (body: Readonly<Record<string, unknown>>): NotificationsWireResult => ({
    schemaVersion: 1,
    queryType,
    requestId,
    kind: 'succeeded',
    ...body,
  });
  const templates = dependencies.templates ?? defaultNotificationTemplates;
  const policies = dependencies.policies ?? defaultNotificationPolicies;
  try {
    if (queryType === 'unreadSummary') {
      if (Object.keys(payload).length > 0)
        return refusal(
          'queryType',
          queryType,
          requestId,
          'unsupported',
          `unknown_field:${Object.keys(payload)[0]!}`,
        );
      const unreadCount = await dependencies.store.unreadCount(userId);
      return ok({ unreadCount, asOfUtc: dependencies.clock.now().toISOString() });
    }
    if (queryType === 'getPreferences') {
      if (Object.keys(payload).length > 0)
        return refusal(
          'queryType',
          queryType,
          requestId,
          'unsupported',
          `unknown_field:${Object.keys(payload)[0]!}`,
        );
      const policy = policies.active();
      const preferences = await dependencies.store.transact((tx) => tx.preferences(userId));
      return ok({
        revision: preferences?.revision ?? 0,
        policyRevision: policy.revision,
        channels: [...policy.channels],
        categories: notificationCategories.map((category) => ({
          category,
          inApp: inAppDecision(policy, preferences, category),
        })),
      });
    }
    for (const key of Object.keys(payload))
      if (!['locale', 'view', 'pageSize', 'cursor'].includes(key))
        return refusal('queryType', queryType, requestId, 'unsupported', `unknown_field:${key}`);
    if (!isNotificationLocale(payload.locale))
      return refusal('queryType', queryType, requestId, 'rejected', 'unsupported_locale');
    const view = payload.view ?? 'active';
    if (view !== 'active' && view !== 'archived')
      return refusal('queryType', queryType, requestId, 'rejected', 'view_invalid');
    const pageSize = payload.pageSize ?? defaultPageSize;
    if (
      !Number.isSafeInteger(pageSize) ||
      (pageSize as number) < 1 ||
      (pageSize as number) > maxPageSize
    )
      return refusal('queryType', queryType, requestId, 'rejected', 'page_size_invalid');
    let after: InboxPosition | undefined;
    if (payload.cursor !== undefined) {
      const decoded =
        typeof payload.cursor === 'string' ? decodeCursor(userId, view, payload.cursor) : null;
      if (decoded === null)
        return refusal('queryType', queryType, requestId, 'rejected', 'cursor_invalid');
      after = decoded;
    }
    const page = await dependencies.store.listInbox(userId, view, after, (pageSize as number) + 1);
    const items = page.slice(0, pageSize as number);
    const last = items.at(-1);
    return ok({
      locale: payload.locale,
      view,
      items: items.map((item) =>
        inboxItemWire(item, payload.locale as NotificationLocale, templates),
      ),
      nextCursor:
        page.length > (pageSize as number) && last !== undefined
          ? encodeCursor(userId, view, {
              createdAtUtc: last.createdAtUtc,
              notificationId: last.notificationId,
            })
          : null,
    });
  } catch {
    // Store outage or an unreadable preference document: fail closed, typed.
    return refusal('queryType', queryType, requestId, 'rejected', 'temporarily_unavailable');
  }
}
