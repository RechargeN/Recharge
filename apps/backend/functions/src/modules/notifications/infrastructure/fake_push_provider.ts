import type { PushProviderPort } from '../application/push_dispatcher.js';
import type { PushSendResult } from '../domain/push.js';

/** N3c: Emulator and test provider; scripted answers, records what was sent. */
export class FakePushProvider implements PushProviderPort {
  readonly sent: { readonly token: string; readonly notificationId: string }[] = [];
  readonly script: PushSendResult[] = [];

  send(message: Parameters<PushProviderPort['send']>[0]): Promise<PushSendResult> {
    this.sent.push({ token: message.token, notificationId: message.notificationId });
    return Promise.resolve(
      this.script.shift() ?? { kind: 'accepted', providerMessageId: `fake-${this.sent.length}` },
    );
  }
}
