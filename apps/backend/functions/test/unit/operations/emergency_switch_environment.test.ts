import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import {
  emergencySwitchEnvironment,
  emergencySwitchState,
} from '../../../src/modules/operations/emergency_switch.js';

/**
 * Round 2.1 (owner approval 2026-11-18): Operations switches in dev and
 * staging. Production, unknown projects and mixed setups never get a switch
 * environment; in the cloud a missing pointer stays contained, so a deploy
 * opens nothing by itself.
 */

const dev = 'recharge-dev-n2a01';
const staging = 'recharge-staging-y9y2y';

void test('the switch environment follows the runtime, production never has one', () => {
  assert.equal(
    emergencySwitchEnvironment({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-recharge' }),
    'local',
  );
  assert.equal(
    emergencySwitchEnvironment({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: dev }),
    null,
  );
  assert.equal(emergencySwitchEnvironment({ GCLOUD_PROJECT: dev }), 'dev');
  assert.equal(
    emergencySwitchEnvironment({ GCLOUD_PROJECT: staging, GOOGLE_CLOUD_PROJECT: staging }),
    'stage',
  );
  assert.equal(emergencySwitchEnvironment({ GCLOUD_PROJECT: 'recharge-prod' }), null);
  assert.equal(emergencySwitchEnvironment({}), null);
  assert.equal(
    emergencySwitchEnvironment({ GCLOUD_PROJECT: dev, GOOGLE_CLOUD_PROJECT: staging }),
    null,
  );
  assert.equal(
    emergencySwitchEnvironment({ GCLOUD_PROJECT: dev, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }),
    null,
  );
});

function fakeFirestore(docs: Record<string, Record<string, unknown>>): Firestore {
  return {
    collection: (collection: string) => ({
      doc: (id: string) => ({
        get: () => Promise.resolve({ data: () => docs[`${collection}/${id}`] }),
      }),
    }),
  } as unknown as Firestore;
}

async function withEnvironment<T>(
  values: Record<string, string | undefined>,
  run: () => Promise<T>,
): Promise<T> {
  const saved: Record<string, string | undefined> = {};
  for (const [name, value] of Object.entries(values)) {
    saved[name] = process.env[name];
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
  try {
    return await run();
  } finally {
    for (const [name, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

const cloudDev = {
  FUNCTIONS_EMULATOR: undefined,
  FIRESTORE_EMULATOR_HOST: undefined,
  FIREBASE_AUTH_EMULATOR_HOST: undefined,
  FIREBASE_STORAGE_EMULATOR_HOST: undefined,
  STORAGE_EMULATOR_HOST: undefined,
  GOOGLE_CLOUD_PROJECT: undefined,
  GCLOUD_PROJECT: dev,
};

void test('in the cloud a missing pointer is contained; an explicit open revision opens', async () => {
  const key = 'dev:LV:ops.test-switch';
  await withEnvironment(cloudDev, async () => {
    assert.equal(await emergencySwitchState(fakeFirestore({}), 'ops.test-switch'), 'contained');
    const open = fakeFirestore({
      [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 2 },
      [`platformFeatureFlagRevisions/${key}:2`]: {
        schemaVersion: 1,
        environmentId: 'dev',
        marketId: 'LV',
        capabilityId: 'ops.test-switch',
        revision: 2,
        enabled: false,
      },
    });
    assert.equal(await emergencySwitchState(open, 'ops.test-switch'), 'open');
    // A revision written for another environment never opens this one.
    const foreign = fakeFirestore({
      [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 2 },
      [`platformFeatureFlagRevisions/${key}:2`]: {
        schemaVersion: 1,
        environmentId: 'stage',
        marketId: 'LV',
        capabilityId: 'ops.test-switch',
        revision: 2,
        enabled: false,
      },
    });
    assert.equal(await emergencySwitchState(foreign, 'ops.test-switch'), 'contained');
  });
});

void test('production stays contained whatever is stored', async () => {
  await withEnvironment({ ...cloudDev, GCLOUD_PROJECT: 'recharge-prod' }, async () => {
    assert.equal(await emergencySwitchState(fakeFirestore({}), 'ops.test-switch'), 'contained');
  });
});
