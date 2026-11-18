import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import { DeploySwitchBookingFlags } from '../../src/dev_booking_composition.js';
import { abuseEmergencySwitchIds } from '../../src/shared/feature_flags.js';

/**
 * Round 2.1 (owner approval 2026-11-18): the Booking cost kill switch is also
 * an Operations switch of the environment. Either the deploy switch or the
 * Operations switch contains new Booking creation; nothing else is touched.
 */

const create = abuseEmergencySwitchIds.bookingCreate;
const key = `dev:LV:${create}`;

function firestoreWith(docs: Record<string, Record<string, unknown>>): Firestore {
  return {
    collection: (collection: string) => ({
      doc: (id: string) => ({
        get: () => Promise.resolve({ data: () => docs[`${collection}/${id}`] }),
      }),
    }),
  } as unknown as Firestore;
}

const opened = firestoreWith({
  [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 1 },
  [`platformFeatureFlagRevisions/${key}:1`]: {
    schemaVersion: 1,
    environmentId: 'dev',
    marketId: 'LV',
    capabilityId: create,
    revision: 1,
    enabled: false,
  },
});

async function inDevCloud<T>(run: () => Promise<T>): Promise<T> {
  const names = [
    'FUNCTIONS_EMULATOR',
    'FIRESTORE_EMULATOR_HOST',
    'FIREBASE_AUTH_EMULATOR_HOST',
    'FIREBASE_STORAGE_EMULATOR_HOST',
    'STORAGE_EMULATOR_HOST',
    'GOOGLE_CLOUD_PROJECT',
    'GCLOUD_PROJECT',
  ];
  const saved = names.map((name) => [name, process.env[name]] as const);
  for (const name of names) delete process.env[name];
  process.env.GCLOUD_PROJECT = 'recharge-dev-n2a01';
  try {
    return await run();
  } finally {
    for (const [name, value] of saved) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

void test('an opened Operations switch lets creation through; no switch contains it', async () => {
  await inDevCloud(async () => {
    assert.equal(await new DeploySwitchBookingFlags(false, opened).isEnabled(create), false);
    assert.equal(
      await new DeploySwitchBookingFlags(false, firestoreWith({})).isEnabled(create),
      true,
      'no pointer in the cloud: contained until the operator opens it',
    );
  });
});

void test('the deploy kill switch still contains on its own', async () => {
  await inDevCloud(async () => {
    assert.equal(await new DeploySwitchBookingFlags(true, opened).isEnabled(create), true);
  });
});

void test('other capabilities do not read the switch', async () => {
  await inDevCloud(async () => {
    const flags = new DeploySwitchBookingFlags(false, firestoreWith({}));
    assert.equal(await flags.isEnabled('booking.unknown.capability'), false);
  });
});
