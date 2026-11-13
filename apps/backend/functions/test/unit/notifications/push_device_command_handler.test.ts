import assert from 'node:assert/strict';
import test from 'node:test';

import { handlePushDeviceCommand } from '../../../src/modules/notifications/application/push_device_command_handler.js';
import { PushDispatcher } from '../../../src/modules/notifications/application/push_dispatcher.js';
import { FakePushProvider } from '../../../src/modules/notifications/infrastructure/fake_push_provider.js';
import { InMemoryPushStore } from '../../../src/modules/notifications/infrastructure/in_memory_push_store.js';

// N3c (A34 2026-11-13): the optional app language of the registration decides
// the generic lock-screen text; anything else in the payload is refused.

const token = `fcm-token-${'d'.repeat(40)}`;

function setup() {
  const store = new InMemoryPushStore();
  const push = new PushDispatcher({
    store,
    provider: new FakePushProvider(),
    sessions: { activeSession: () => Promise.resolve(true) },
    preferences: () => Promise.resolve(undefined),
    clock: { now: () => new Date('2026-11-13T10:00:00.000Z') },
  });
  const call = (payload: Record<string, unknown>) =>
    handlePushDeviceCommand({
      push,
      userId: 'user-1',
      installationId: 'inst-1',
      data: { schemaVersion: 1, requestId: 'req-1', commandType: 'registerPushDevice', payload },
    });
  return { store, call };
}

void test('registerPushDevice stores a known app language', async () => {
  const { store, call } = setup();
  const answer = await call({ platform: 'android', token, locale: 'ru' });
  assert.equal(answer.kind, 'succeeded');
  assert.equal((await store.registration('inst-1'))?.locale, 'ru');
});

void test('without a language the registration has none (English text)', async () => {
  const { store, call } = setup();
  assert.equal((await call({ platform: 'android', token })).kind, 'succeeded');
  assert.equal((await store.registration('inst-1'))?.locale, undefined);
});

void test('an unknown language or extra field is refused', async () => {
  const { store, call } = setup();
  for (const payload of [
    { platform: 'android', token, locale: 'de' },
    { platform: 'android', token, locale: 'lv' },
    { platform: 'android', token, extra: true },
  ]) {
    const answer = await call(payload);
    assert.equal(answer.code, 'request_invalid', JSON.stringify(payload));
  }
  assert.equal(await store.registration('inst-1'), undefined);
});
