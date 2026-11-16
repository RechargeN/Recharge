import assert from 'node:assert/strict';
import test from 'node:test';

import {
  DeploySwitchBookingFlags,
  devBookingCallables,
  isDevBookingCallable,
} from '../../src/dev_booking_composition.js';
import {
  devBookingLoadOpen,
  devBookingOpen,
  loadRequestAllowed,
  loadRunLimits,
} from '../../src/dev_booking_entry.js';
import { abuseEmergencySwitchIds, bookingFlagIds } from '../../src/shared/feature_flags.js';

// N4c step 1 (2026-11-16): the cloud Booking runtime is closed unless every
// switch is set; the load ingress exists in staging only and accepts nothing
// but synthetic actors on synthetic occurrences.

const uid = 'abcdefghijklmnopqrstuvwxyz012345';
const dev = {
  GCLOUD_PROJECT: 'recharge-dev-n2a01',
  N4C_BOOKING_ENABLED: 'true',
  N4C_ALLOWED_FIREBASE_UIDS: uid,
};

void test('closed unless reviewed project, switch on, exact allowlist and no Emulator', () => {
  assert.deepEqual(devBookingOpen(dev), [uid]);
  for (const broken of [
    { ...dev, GCLOUD_PROJECT: 'recharge-prod' },
    { ...dev, N4C_BOOKING_ENABLED: 'false' },
    { ...dev, N4C_ALLOWED_FIREBASE_UIDS: '' },
    { ...dev, N4C_ALLOWED_FIREBASE_UIDS: 'bad uid' },
    { ...dev, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
    { ...dev, FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' },
  ])
    assert.equal(devBookingOpen(broken), null, JSON.stringify(broken));
  assert.deepEqual(
    [...devBookingCallables],
    [
      'createInternalBookingV1',
      'cancelInternalBookingV1',
      'reconfirmInternalBookingV1',
      'getMyBookingV1',
      'listMyBookingsV1',
      'getEventAvailabilityV1',
    ],
  );
  assert.equal(isDevBookingCallable('bookingLoadV1'), false);
});

void test('the load ingress never opens in dev and needs both switches', () => {
  // The entry binds to dev when imported locally, so staging is never "this project" here.
  assert.equal(devBookingLoadOpen({ ...dev, N4C_LOAD_ENABLED: 'true' }), false);
  assert.equal(
    devBookingLoadOpen({
      GCLOUD_PROJECT: 'recharge-staging-y9y2y',
      N4C_BOOKING_ENABLED: 'true',
      N4C_LOAD_ENABLED: 'true',
    }),
    false,
  );
});

void test('load limits rise only in staging and only inside the reviewed bounds', () => {
  const staging = { GCLOUD_PROJECT: 'recharge-staging-y9y2y' };
  assert.deepEqual(loadRunLimits(staging), { maxInstances: 1, concurrency: 1 });
  assert.deepEqual(
    loadRunLimits({ ...staging, N4C_LOAD_MAX_INSTANCES: '3', N4C_LOAD_CONCURRENCY: '20' }),
    { maxInstances: 3, concurrency: 20 },
  );
  for (const [instances, concurrency] of [
    ['4', '20'],
    ['0', '0'],
    ['3x', '-1'],
    ['', '400'],
  ])
    assert.deepEqual(
      loadRunLimits({
        ...staging,
        N4C_LOAD_MAX_INSTANCES: instances,
        N4C_LOAD_CONCURRENCY: concurrency,
      }).maxInstances === 1 ||
        loadRunLimits({
          ...staging,
          N4C_LOAD_MAX_INSTANCES: instances,
          N4C_LOAD_CONCURRENCY: concurrency,
        }).concurrency === 1,
      true,
    );
  assert.deepEqual(
    loadRunLimits({ ...dev, N4C_LOAD_MAX_INSTANCES: '3', N4C_LOAD_CONCURRENCY: '20' }),
    { maxInstances: 1, concurrency: 1 },
  );
});

void test('a load request is a synthetic actor on a synthetic occurrence', () => {
  const create = (occurrenceId: string) => ({ payload: { occurrenceId } });
  assert.equal(
    loadRequestAllowed('createInternalBookingV1', 'n4cload0001', create('occ_n4cload_a')),
    true,
  );
  assert.equal(
    loadRequestAllowed('getEventAvailabilityV1', 'n4cload0001', create('occ_n4cload_a')),
    true,
  );
  assert.equal(loadRequestAllowed('cancelInternalBookingV1', 'n4cload0001', {}), true);
  for (const actor of [uid, 'n4cload1', 'n4cload00012', '', null, 7])
    assert.equal(
      loadRequestAllowed('createInternalBookingV1', actor, create('occ_n4cload_a')),
      false,
      String(actor),
    );
  for (const data of [create('occ_real'), {}, null, { payload: null }, { payload: {} }])
    assert.equal(
      loadRequestAllowed('createInternalBookingV1', 'n4cload0001', data),
      false,
      JSON.stringify(data),
    );
});

void test('deploy-switch flags: interactive Booking on, workers off, one incident switch', async () => {
  const open = new DeploySwitchBookingFlags(false);
  for (const id of [
    bookingFlagIds.create,
    bookingFlagIds.cancel,
    bookingFlagIds.reconfirm,
    bookingFlagIds.read,
  ])
    assert.equal(await open.isEnabled(id), true, id);
  for (const id of [
    bookingFlagIds.eventProjectionDelivery,
    bookingFlagIds.reconfirmationDeadlineWorker,
    'unknown.capability',
    ...Object.values(abuseEmergencySwitchIds),
  ])
    assert.equal(await open.isEnabled(id), false, id);
  const contained = new DeploySwitchBookingFlags(true);
  assert.equal(await contained.isEnabled(bookingFlagIds.create), false);
  assert.equal(await contained.isEnabled(abuseEmergencySwitchIds.bookingCreate), true);
});
