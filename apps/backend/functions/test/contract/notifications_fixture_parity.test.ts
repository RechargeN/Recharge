import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { test } from 'node:test';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

import { NotificationEffectConsumer } from '../../src/modules/notifications/application/consume_notification_effect.js';
import { handleNotificationsCommandRequest } from '../../src/modules/notifications/application/notifications_command_handler.js';
import { handleNotificationsQueryRequest } from '../../src/modules/notifications/application/notifications_query_handler.js';
import {
  notificationIdFor,
  notificationReceiptId,
  parseNotificationEffect,
} from '../../src/modules/notifications/domain/notification_effect.js';
import { InMemoryNotificationsStore } from '../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { FakeClock } from '../support/fake_clock.js';
import { bookingEffect } from '../support/notifications_world.js';

/**
 * F1 contract parity: the local JSON Schemas in packages/api_contracts and the
 * backend handlers accept and refuse exactly the same fixtures, and every
 * result the handlers produce validates against the result schema. A local
 * stand contract only: BCK13-OD-01 (codegen, compatibility workflow) stays open.
 */
const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;
const root = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'notifications',
  'v1',
);
const files = {
  query: 'notifications_query.schema.json',
  command: 'notifications_command.schema.json',
  result: 'notifications_result.schema.json',
  effect: 'notification_effect.schema.json',
} as const;

async function json(name: string): Promise<unknown> {
  return JSON.parse(await readFile(path.join(root, name), 'utf8')) as unknown;
}

async function validators(): Promise<Record<keyof typeof files, ValidateFunction>> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const entries = await Promise.all(
    Object.entries(files).map(
      async ([key, file]) => [key, ajv.compile((await json(file)) as object)] as const,
    ),
  );
  return Object.fromEntries(entries) as Record<keyof typeof files, ValidateFunction>;
}

async function world() {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const clock = new FakeClock(new Date('2026-08-29T12:00:00.000Z'));
  const effect = bookingEffect();
  assert.equal(
    await new NotificationEffectConsumer({ store, clock }).consume(effect.id, effect.data),
    'created',
  );
  clock.set(new Date('2026-08-29T13:00:00.000Z'));
  const dependencies = { store, clock, features: { inbox: true, preferences: true } };
  return {
    notificationId: notificationIdFor(notificationReceiptId(effect.id)),
    query: (body: unknown) => handleNotificationsQueryRequest(dependencies, 'recipient-1', body),
    command: (body: unknown) =>
      handleNotificationsCommandRequest(dependencies, 'recipient-1', body),
  };
}

void test('the four schemas compile in strict mode with unique ids', async () => {
  const ids = await Promise.all(
    Object.values(files).map(async (file) => (await json(file)) as { $id: string }),
  );
  assert.equal(new Set(ids.map((schema) => schema.$id)).size, 4);
  await validators();
});

void test('valid queries pass the schema and the handler; invalid ones fail both with the same code', async () => {
  const validate = await validators();
  const { query } = await world();
  for (const request of (await json('fixtures/query_valid.json')) as unknown[]) {
    assert.equal(validate.query(request), true, JSON.stringify(validate.query.errors));
    const result = await query(request);
    assert.equal(result.kind, 'succeeded', JSON.stringify(result));
    assert.equal(validate.result(result), true, JSON.stringify(validate.result.errors));
  }
  for (const { code, request } of (await json('fixtures/query_invalid.json')) as {
    code: string;
    request: unknown;
  }[]) {
    assert.equal(validate.query(request), false, code);
    const result = await query(request);
    assert.equal(result.code, code);
    assert.equal(validate.result(result), true, JSON.stringify(validate.result.errors));
  }
});

void test('valid commands pass the schema and execute; invalid ones fail both', async () => {
  const validate = await validators();
  const { command, notificationId } = await world();
  for (const request of (await json('fixtures/command_valid.json')) as Record<string, unknown>[]) {
    assert.equal(validate.command(request), true, JSON.stringify(validate.command.errors));
    const payload = request.payload as Record<string, unknown>;
    const bound =
      payload.notificationId === undefined
        ? request
        : { ...request, payload: { ...payload, notificationId } };
    const result = await command(bound);
    assert.equal(result.kind, 'succeeded', JSON.stringify(result));
    assert.equal(validate.result(result), true, JSON.stringify(validate.result.errors));
  }
  // A fresh world: the valid updatePreferences above already moved the revision.
  const fresh = await world();
  for (const { code, detail, request } of (await json('fixtures/command_invalid.json')) as {
    code: string;
    detail?: string;
    request: unknown;
  }[]) {
    assert.equal(validate.command(request), false, code);
    const result = await fresh.command(request);
    assert.equal(result.code, code);
    if (detail !== undefined) assert.equal(result.detail, detail);
    assert.equal(validate.result(result), true, JSON.stringify(validate.result.errors));
  }
});

void test('result examples validate', async () => {
  const validate = await validators();
  for (const result of (await json('fixtures/result_valid.json')) as unknown[])
    assert.equal(validate.result(result), true, JSON.stringify(validate.result.errors));
});

void test('Booking v2 effects and the consumer agree; the producer output matches the schema', async () => {
  const validate = await validators();
  for (const record of (await json('fixtures/effect_valid.json')) as Record<string, unknown>[]) {
    assert.equal(validate.effect(record), true, JSON.stringify(validate.effect.errors));
    assert.equal(parseNotificationEffect(String(record.eventId), record).kind, 'effect');
  }
  for (const { code, record } of (await json('fixtures/effect_invalid.json')) as {
    code: string;
    record: Record<string, unknown>;
  }[]) {
    assert.equal(validate.effect(record), false, code);
    assert.deepEqual(parseNotificationEffect(String(record.eventId), record), {
      kind: 'invalid',
      code,
    });
  }
  const produced = bookingEffect({
    effect: {
      kind: 'reconfirmationRequired',
      reconfirmationDeadlineUtc: '2026-08-30T12:00:00.000Z',
    },
  }).data;
  const wire = { ...produced, expiresAt: (produced.expiresAt as Date).toISOString() };
  assert.equal(validate.effect(wire), true, JSON.stringify(validate.effect.errors));
});
