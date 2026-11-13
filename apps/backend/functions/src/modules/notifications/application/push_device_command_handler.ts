import { isPushToken } from '../domain/push.js';
import { isNotificationLocale } from '../domain/notification_templates.js';
import type { PushDispatcher } from './push_dispatcher.js';

/**
 * N3c (2026-11-13) `pushDeviceCommandV1`: registers or removes the FCM token of
 * the caller's own Session installation. The installation and the user come
 * from the verified Session, never from the payload.
 */
export async function handlePushDeviceCommand(input: {
  readonly push: PushDispatcher;
  readonly userId: string;
  readonly installationId: string;
  readonly data: unknown;
}): Promise<Readonly<Record<string, unknown>>> {
  const body =
    typeof input.data === 'object' && input.data !== null && !Array.isArray(input.data)
      ? (input.data as Record<string, unknown>)
      : null;
  const requestId =
    typeof body?.requestId === 'string' && /^[A-Za-z0-9_-]{1,128}$/u.test(body.requestId)
      ? body.requestId
      : null;
  const refuse = (code: string) => ({ schemaVersion: 1, requestId, kind: 'rejected', code });
  if (body === null || body.schemaVersion !== 1 || requestId === null)
    return refuse('request_invalid');
  for (const key of Object.keys(body))
    if (!['schemaVersion', 'requestId', 'commandType', 'payload', 'sessionContext'].includes(key))
      return refuse('request_invalid');
  const payload = body.payload;
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload))
    return refuse('request_invalid');
  const fields = payload as Record<string, unknown>;
  try {
    if (body.commandType === 'registerPushDevice') {
      if (
        Object.keys(fields).some((key) => !['platform', 'token', 'locale'].includes(key)) ||
        fields.platform !== 'android' ||
        !isPushToken(fields.token) ||
        (fields.locale !== undefined && !isNotificationLocale(fields.locale))
      )
        return refuse('request_invalid');
      await input.push.register({
        userId: input.userId,
        installationId: input.installationId,
        platform: 'android',
        token: fields.token,
        ...(fields.locale !== undefined ? { locale: fields.locale } : {}),
      });
      return { schemaVersion: 1, requestId, kind: 'succeeded', registered: true };
    }
    if (body.commandType === 'unregisterPushDevice') {
      if (Object.keys(fields).length > 0) return refuse('request_invalid');
      await input.push.unregister(input.userId, input.installationId);
      return { schemaVersion: 1, requestId, kind: 'succeeded', registered: false };
    }
    return refuse('request_invalid');
  } catch {
    return refuse('temporarily_unavailable');
  }
}
