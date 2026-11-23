import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import {
  bookingNotificationEffectsEnabled,
  useCloudBookingNotificationEffects,
} from '../../src/booking/notification_effects.js';
import { bookingNotificationsOpen } from '../../src/dev_booking_entry.js';
import { consumeCloudBookingEffect } from '../../src/dev_notifications_composition.js';
import { bookingConsumeOpen } from '../../src/dev_notifications_entry.js';
import { operationsEmergencySwitchIds } from '../../src/shared/feature_flags.js';

/**
 * Round 1 stage 1.3 (owner 2026-11-20): Booking notifications in the cloud.
 * The producer follows its deploy switch, the consumer its own deploy switch
 * and the pinned Operations incident switch; anything missing stays closed.
 */

const dev = 'recharge-dev-n2a01';
const uid = 'a'.repeat(28);
const consumeSwitch = operationsEmergencySwitchIds.notificationsConsumeBooking;
const key = `dev:LV:${consumeSwitch}`;

function firestoreWith(docs: Record<string, Record<string, unknown>>): Firestore {
  return {
    collection: (collection: string) => ({
      doc: (id: string) => ({
        get: () => Promise.resolve({ data: () => docs[`${collection}/${id}`] }),
      }),
    }),
  } as unknown as Firestore;
}

function switchWith(enabled: boolean): Firestore {
  return firestoreWith({
    [`platformActiveFeatureFlagPointers/${key}`]: { key, activeRevision: 1 },
    [`platformFeatureFlagRevisions/${key}:1`]: {
      schemaVersion: 1,
      environmentId: 'dev',
      marketId: 'LV',
      capabilityId: consumeSwitch,
      revision: 1,
      enabled,
    },
  });
}

const untouched = {
  collection: () => {
    throw new Error('must not read');
  },
} as unknown as Firestore;

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
  process.env.GCLOUD_PROJECT = dev;
  try {
    return await run();
  } finally {
    for (const [name, value] of saved) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

function effect(id: string, overrides: Record<string, unknown> = {}) {
  return { schemaVersion: 2, producer: 'booking', eventId: id, ...overrides };
}

function consumer(calls: string[]) {
  return () => ({
    consumer: {
      consume: (eventId: string) => {
        calls.push(eventId);
        return Promise.resolve('created' as never);
      },
    } as never,
  });
}

void test('producer: the cloud deploy switch decides, never the Emulator flag', async () => {
  try {
    useCloudBookingNotificationEffects(true);
    assert.equal(await bookingNotificationEffectsEnabled(untouched), true);
    useCloudBookingNotificationEffects(false);
    assert.equal(await bookingNotificationEffectsEnabled(untouched), false);
  } finally {
    useCloudBookingNotificationEffects(undefined);
  }
});

void test('producer switch opens only with the runtime and its own switch', () => {
  const open = {
    GCLOUD_PROJECT: dev,
    N4C_BOOKING_ENABLED: 'true',
    N4C_BOOKING_NOTIFICATIONS_ENABLED: 'true',
  };
  assert.equal(bookingNotificationsOpen(open), true);
  assert.equal(
    bookingNotificationsOpen({ ...open, N4C_BOOKING_NOTIFICATIONS_ENABLED: 'false' }),
    false,
  );
  assert.equal(bookingNotificationsOpen({ ...open, N4C_BOOKING_ENABLED: 'false' }), false);
  assert.equal(
    bookingNotificationsOpen({ ...open, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }),
    false,
  );
  assert.equal(bookingNotificationsOpen({ ...open, GCLOUD_PROJECT: 'other-project' }), false);
});

void test('consumer switch opens only with the runtime, the allowlist and its own switch', () => {
  const open = {
    GCLOUD_PROJECT: dev,
    N3C_DEV_ENABLED: 'true',
    N3C_ALLOWED_FIREBASE_UIDS: uid,
    N3C_BOOKING_CONSUME_ENABLED: 'true',
  };
  assert.equal(bookingConsumeOpen(open), true);
  assert.equal(bookingConsumeOpen({ ...open, N3C_BOOKING_CONSUME_ENABLED: 'false' }), false);
  assert.equal(bookingConsumeOpen({ ...open, N3C_DEV_ENABLED: 'false' }), false);
  assert.equal(bookingConsumeOpen({ ...open, N3C_ALLOWED_FIREBASE_UIDS: '' }), false);
});

void test('consumer: only an opened incident switch lets a v2 Booking effect through', async () => {
  await inDevCloud(async () => {
    const calls: string[] = [];
    const id = 'booking_effect_001';
    const run = (
      firestore: Firestore,
      data: unknown,
      outboxId = id,
      collection = 'bookingOutbox',
    ) =>
      consumeCloudBookingEffect({
        firestore,
        collection,
        outboxId,
        data,
        compose: consumer(calls),
      });

    assert.equal(await run(switchWith(false), effect(id)), 'created');
    assert.deepEqual(calls, [id]);

    // No pointer in the cloud: contained until the operator opens it.
    assert.equal(await run(firestoreWith({}), effect(id)), 'disabled');
    // An operator revision that disables it.
    assert.equal(await run(switchWith(true), effect(id)), 'disabled');
    // A v1 record before activation is never consumed and reads nothing.
    assert.equal(
      await run(untouched, { schemaVersion: 1, kind: 'suppressedPreActivation' }),
      'not_activated',
    );
    // Foreign producer, id mismatch, collection or malformed id: refused without a read.
    assert.equal(await run(untouched, effect(id, { producer: 'content' })), 'source_refused');
    assert.equal(await run(untouched, effect('other')), 'source_refused');
    assert.equal(await run(untouched, effect(id), id, 'eventBookingOutbox'), 'source_refused');
    assert.equal(await run(untouched, effect('bad/id'), 'bad/id'), 'source_refused');
    assert.deepEqual(calls, [id]);
  });
});
