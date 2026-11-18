import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import { cloudEffectFlags, devContentEffectsOpen } from '../../src/dev_content_effects_entry.js';
import { catalogFlagIds, contentFlagIds } from '../../src/shared/feature_flags.js';

/**
 * Round 2.2 (owner approval 2026-11-19): the cloud Content-effects runtime
 * runs only the Event → Booking handoff, only behind its switches.
 */

const dev = 'recharge-dev-n2a01';

void test('the runtime opens only with every switch, in the reviewed project, without Emulator', () => {
  const open = {
    GCLOUD_PROJECT: dev,
    N4F_CONTENT_EFFECTS_ENABLED: 'true',
    RECHARGE_DEV_RUNTIME: 'content-media',
  };
  assert.equal(devContentEffectsOpen(open), true);
  assert.equal(devContentEffectsOpen({ ...open, N4F_CONTENT_EFFECTS_ENABLED: 'false' }), false);
  assert.equal(devContentEffectsOpen({ ...open, RECHARGE_DEV_RUNTIME: 'other' }), false);
  assert.equal(devContentEffectsOpen({ ...open, GCLOUD_PROJECT: 'recharge-prod' }), false);
  assert.equal(
    devContentEffectsOpen({ ...open, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }),
    false,
  );
});

function firestoreWith(docs: Record<string, Record<string, unknown>>): Firestore {
  return {
    collection: (collection: string) => ({
      doc: (id: string) => ({
        get: () => Promise.resolve({ data: () => docs[`${collection}/${id}`] }),
      }),
    }),
  } as unknown as Firestore;
}

void test('only the handoff can run, and only while its Operations switch is open', async () => {
  const saved = { ...process.env };
  for (const name of [
    'FUNCTIONS_EMULATOR',
    'FIRESTORE_EMULATOR_HOST',
    'FIREBASE_AUTH_EMULATOR_HOST',
    'FIREBASE_STORAGE_EMULATOR_HOST',
    'STORAGE_EMULATOR_HOST',
    'GOOGLE_CLOUD_PROJECT',
  ])
    delete process.env[name];
  process.env.GCLOUD_PROJECT = dev;
  try {
    const key = 'dev:LV:content.eventBookingHandoff.incidentDisable';
    const opened = firestoreWith({
      [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 1 },
      [`platformFeatureFlagRevisions/${key}:1`]: {
        schemaVersion: 1,
        environmentId: 'dev',
        marketId: 'LV',
        capabilityId: 'content.eventBookingHandoff.incidentDisable',
        revision: 1,
        enabled: false,
      },
    });
    assert.equal(
      await cloudEffectFlags(opened).isEnabled(contentFlagIds.eventBookingHandoff),
      true,
    );
    assert.equal(await cloudEffectFlags(opened).isEnabled(catalogFlagIds.delivery), false);
    assert.equal(
      await cloudEffectFlags(firestoreWith({})).isEnabled(contentFlagIds.eventBookingHandoff),
      false,
      'no switch in the cloud: contained',
    );
  } finally {
    process.env = saved;
  }
});
