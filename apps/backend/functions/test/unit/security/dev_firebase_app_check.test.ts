import assert from 'node:assert/strict';
import test from 'node:test';
import type { VerifyAppCheckTokenResponse } from 'firebase-admin/app-check';

import { DevFirebaseAppCheckPort } from '../../../src/platform/adapters/dev_firebase_app_check.js';
import { appCheckGrantsAuthority } from '../../../src/security/app_check_port.js';

const appId = '1:420479958348:android:abcdef123456';
function verified(): VerifyAppCheckTokenResponse {
  return {
    appId,
    token: {
      app_id: appId,
      sub: appId,
      iss: 'https://firebaseappcheck.googleapis.com/420479958348',
      aud: ['projects/420479958348'],
      iat: 900,
      exp: 1100,
    },
  };
}

void test('dev attestation requires an explicit project and nonempty native app allowlist', () => {
  for (const [project, ids] of [
    ['other-project', [appId]],
    ['recharge-dev-n2a01', []],
    ['recharge-dev-n2a01', ['1:111:android:abcdef']],
    ['recharge-dev-n2a01', ['1:420479958348:web:abcdef']],
  ] as const) {
    assert.throws(
      () => new DevFirebaseAppCheckPort(project, ids, () => Promise.resolve(verified())),
    );
  }
});

void test('missing tokens do not call SDK; verified attestation grants no authority', async () => {
  let calls = 0;
  const ids = [appId];
  const port = new DevFirebaseAppCheckPort(
    'recharge-dev-n2a01',
    ids,
    () => {
      calls += 1;
      return Promise.resolve(verified());
    },
    () => 1000,
  );
  ids.length = 0;
  assert.deepEqual(await port.verify(undefined), { state: 'missing' });
  assert.deepEqual(await port.verify('  '), { state: 'missing' });
  assert.equal(calls, 0);
  const evidence = await port.verify('opaque-test-token');
  assert.deepEqual(evidence, { state: 'valid', tokenAgeSeconds: 100 });
  assert.equal(appCheckGrantsAuthority(evidence), false);
  assert.equal(calls, 1);
});

void test('foreign, inconsistent, already-consumed and malformed verified claims fail closed', async () => {
  const mutations: ((value: VerifyAppCheckTokenResponse) => void)[] = [
    (v) => {
      v.appId = '1:420479958348:android:999999';
    },
    (v) => {
      v.token.sub = 'another-app';
    },
    (v) => {
      v.token.app_id = 'another-app';
    },
    (v) => {
      v.token.iss = 'https://firebaseappcheck.googleapis.com/111';
    },
    (v) => {
      v.token.aud = ['projects/111'];
    },
    (v) => {
      v.alreadyConsumed = true;
    },
    (v) => {
      v.token.iat = 1001;
    },
    (v) => {
      v.token.exp = 899;
    },
    (v) => {
      v.token.exp = Number.NaN;
    },
  ];
  for (const mutate of mutations) {
    const value = verified();
    mutate(value);
    const port = new DevFirebaseAppCheckPort(
      'recharge-dev-n2a01',
      [appId],
      () => Promise.resolve(value),
      () => 1000,
    );
    assert.deepEqual(await port.verify('opaque-test-token'), { state: 'invalid' });
  }
});

void test('expiry, clock failure and SDK rejection never fall back to allow', async () => {
  const expired = verified();
  expired.token.exp = 1000;
  const port = new DevFirebaseAppCheckPort(
    'recharge-dev-n2a01',
    [appId],
    () => Promise.resolve(expired),
    () => 1000,
  );
  assert.deepEqual(await port.verify('opaque-test-token'), { state: 'expired' });
  const failure = new DevFirebaseAppCheckPort('recharge-dev-n2a01', [appId], () =>
    Promise.reject(new Error('unavailable')),
  );
  assert.deepEqual(await failure.verify('opaque-test-token'), { state: 'invalid' });
  const clock = new DevFirebaseAppCheckPort(
    'recharge-dev-n2a01',
    [appId],
    () => Promise.resolve(verified()),
    () => Number.NaN,
  );
  assert.deepEqual(await clock.verify('opaque-test-token'), { state: 'invalid' });
});
