import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import {
  cloudEventDeliveryGate,
  processEventBookingOutboxDocument,
} from '../../src/booking/event_projection_runtime.js';
import {
  cloudReconfirmationGate,
  runReconfirmationDeadlineWorker,
} from '../../src/booking/reconfirmation_deadline_worker.js';
import { operationsEmergencySwitchIds } from '../../src/shared/feature_flags.js';

/**
 * A34 staging 2026-11-19: the cloud outbox trigger read the Emulator-only
 * product flag (always off in the cloud), answered 200 and delivered nothing.
 * In the cloud the Operations switch decides; a missing switch is contained.
 */

const switchId = operationsEmergencySwitchIds.eventProjectionDelivery;
const key = `stage:LV:${switchId}`;

function firestoreWith(docs: Record<string, Record<string, unknown>>): Firestore {
  return {
    collection: (collection: string) => ({
      doc: (id: string) => ({
        get: () => Promise.resolve({ data: () => docs[`${collection}/${id}`] }),
      }),
    }),
  } as unknown as Firestore;
}

function switchDocs(enabled: boolean): Record<string, Record<string, unknown>> {
  return {
    [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 1 },
    [`platformFeatureFlagRevisions/${key}:1`]: {
      schemaVersion: 1,
      environmentId: 'stage',
      marketId: 'LV',
      capabilityId: switchId,
      revision: 1,
      enabled,
    },
  };
}

async function inStagingCloud<T>(run: () => Promise<T>): Promise<T> {
  const names = [
    'FUNCTIONS_EMULATOR',
    'FIRESTORE_EMULATOR_HOST',
    'FIREBASE_AUTH_EMULATOR_HOST',
    'GOOGLE_CLOUD_PROJECT',
    'GCLOUD_PROJECT',
  ];
  const saved = names.map((name) => [name, process.env[name]] as const);
  for (const name of names) delete process.env[name];
  process.env.GCLOUD_PROJECT = 'recharge-staging-y9y2y';
  try {
    return await run();
  } finally {
    for (const [name, value] of saved) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

void test('the cloud delivery gate follows the Operations switch; none is contained', async () => {
  await inStagingCloud(async () => {
    assert.equal(await cloudEventDeliveryGate(firestoreWith(switchDocs(false)))(), true);
    assert.equal(await cloudEventDeliveryGate(firestoreWith(switchDocs(true)))(), false);
    assert.equal(await cloudEventDeliveryGate(firestoreWith({}))(), false);
  });
});

void test('a closed gate delivers nothing and touches no outbox record', async () => {
  const untouched = {
    collection: () => {
      throw new Error('must not read');
    },
  } as unknown as Firestore;
  assert.equal(
    await processEventBookingOutboxDocument(untouched, 'ebh_x', '2026-11-19T20:00:00.000Z', () =>
      Promise.resolve(false),
    ),
    'disabled',
  );
});

void test('the cloud reconfirmation gate follows its own Operations switch', async () => {
  const workerSwitch = operationsEmergencySwitchIds.reconfirmationDeadlineWorker;
  const workerKey = `stage:LV:${workerSwitch}`;
  const docs = (enabled: boolean) =>
    firestoreWith({
      [`platformActiveFeatureFlagPointers/${workerKey}`]: { key: workerKey, activeRevision: 1 },
      [`platformFeatureFlagRevisions/${workerKey}:1`]: {
        schemaVersion: 1,
        environmentId: 'stage',
        marketId: 'LV',
        capabilityId: workerSwitch,
        revision: 1,
        enabled,
      },
    });
  await inStagingCloud(async () => {
    assert.equal(await cloudReconfirmationGate(docs(false))(), true);
    assert.equal(await cloudReconfirmationGate(docs(true))(), false);
    assert.equal(await cloudReconfirmationGate(firestoreWith({}))(), false);
    // The delivery switch does not open the reconfirmation worker.
    assert.equal(await cloudReconfirmationGate(firestoreWith(switchDocs(false)))(), false);
  });
});

void test('a closed reconfirmation gate runs nothing', async () => {
  const untouched = {
    collection: () => {
      throw new Error('must not read');
    },
  } as unknown as Firestore;
  assert.deepEqual(
    await runReconfirmationDeadlineWorker(untouched, '2026-11-19T20:00:00.000Z', 20, () =>
      Promise.resolve(false),
    ),
    { discovered: 0, examined: 0, attempted: 0 },
  );
});
