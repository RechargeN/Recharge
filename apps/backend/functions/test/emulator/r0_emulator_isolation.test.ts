import assert from 'node:assert/strict';
import { test } from 'node:test';

const expectedHosts = [
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
  'PUBSUB_EMULATOR_HOST',
] as const;

void test('all required services are emulator-bound to loopback', () => {
  assert.equal(process.env.FUNCTIONS_EMULATOR, 'true');
  assert.equal(process.env.GCLOUD_PROJECT, 'demo-recharge');

  for (const variableName of expectedHosts) {
    const value = process.env[variableName];
    assert.ok(value, `${variableName} must be set`);
    assert.match(value, /^(127\.0\.0\.1|localhost):\d+$/u);
  }
});

void test('canonical emulator job exposes no cloud credential variable', () => {
  const forbidden = [
    'GOOGLE_APPLICATION_CREDENTIALS',
    'FIREBASE_TOKEN',
    'GOOGLE_OAUTH_ACCESS_TOKEN',
    'ACTIONS_ID_TOKEN_REQUEST_URL',
    'ACTIONS_ID_TOKEN_REQUEST_TOKEN',
  ] as const;

  for (const variableName of forbidden) {
    assert.equal(Object.hasOwn(process.env, variableName), false, variableName);
  }
});

void test('R0 Functions probe is discoverable and remains emulator-only', async () => {
  const response = await fetch('http://127.0.0.1:5001/demo-recharge/us-central1/r0ToolchainProbe');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    schemaVersion: 1,
    status: 'emulator_only',
    runtimeMajor: 22,
  });
});
