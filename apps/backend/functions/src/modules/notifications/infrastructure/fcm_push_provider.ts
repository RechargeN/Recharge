import type { App } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

import type { PushProviderPort } from '../application/push_dispatcher.js';
import { classifyProviderError, type PushSendResult } from '../domain/push.js';

/**
 * N3c (2026-11-13, OD-07): FCM HTTP v1 through the Admin SDK. The message is
 * a generic hint plus opaque ids; the app shows details only after sign-in.
 * Normal priority, TTL from the policy. Every outcome is a typed result.
 */
export class FcmPushProvider implements PushProviderPort {
  readonly #messaging: Pick<Messaging, 'send'>;

  constructor(app: App, messaging?: Pick<Messaging, 'send'>) {
    this.#messaging = messaging ?? getMessaging(app);
  }

  async send(message: Parameters<PushProviderPort['send']>[0]): Promise<PushSendResult> {
    try {
      const providerMessageId = await this.#messaging.send({
        token: message.token,
        notification: { title: message.title, body: message.body },
        data: { notificationId: message.notificationId, category: message.category },
        android: {
          priority: 'normal',
          ttl: message.ttlSeconds * 1000,
          notification: { channelId: 'recharge_default' },
        },
      });
      return { kind: 'accepted', providerMessageId };
    } catch (error) {
      const raw = (error as { code?: unknown }).code;
      const code = typeof raw === 'string' && /^[a-z/-]{1,80}$/u.test(raw) ? raw : 'unknown';
      const kind = classifyProviderError(code);
      return kind === 'accepted' ? { kind: 'rejected', code } : { kind, code };
    }
  }
}
