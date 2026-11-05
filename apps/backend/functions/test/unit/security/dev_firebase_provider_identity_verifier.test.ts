import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { App } from 'firebase-admin/app';
import type { DecodedIdToken } from 'firebase-admin/auth';
import {
  DevFirebaseProviderIdentityVerifier,
  createDevFirebaseProviderIdentityVerifier,
} from '../../../src/modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';

const project = 'recharge-dev-n2a01';
const now = '2026-11-05T10:00:00.000Z';
const seconds = Date.parse(now) / 1000;
const proof = { provider: 'google' as const, providerTenant: project, proof: 'opaque-test-token' };
function claims(): DecodedIdToken {
  return {
    aud: project,
    iss: `https://securetoken.google.com/${project}`,
    sub: 'firebase-uid',
    uid: 'firebase-uid',
    iat: seconds - 10,
    exp: seconds + 100,
    auth_time: seconds - 20,
    firebase: {
      sign_in_provider: 'google.com',
      identities: { 'google.com': ['provider-subject'] },
    },
  };
}

void test('dev verifier uses revoke-aware verification and provider subject, ignores elevated claims', async () => {
  const token = { ...claims(), role: 'admin', capabilities: ['admin.tools.view'] };
  const verifier = new DevFirebaseProviderIdentityVerifier(project, (raw, revoked) => {
    assert.equal(raw, proof.proof);
    assert.equal(revoked, true);
    return Promise.resolve(token);
  });
  assert.deepEqual(await verifier.verify(proof, now), {
    provider: 'google',
    providerTenant: project,
    providerSubject: 'provider-subject',
    verifiedAtUtc: now,
  });
});

void test('wrong project binding, proof tenant and synthetic proof fail closed', async () => {
  assert.throws(
    () => new DevFirebaseProviderIdentityVerifier('other', () => Promise.resolve(claims())),
  );
  const verifier = new DevFirebaseProviderIdentityVerifier(project, () =>
    Promise.reject(new Error('invalid')),
  );
  assert.equal(await verifier.verify({ ...proof, providerTenant: 'demo-recharge' }, now), null);
  assert.equal(await verifier.verify({ ...proof, proof: 'local-test:google:admin' }, now), null);
});

void test('invalid claims, provider mismatch, expiry and tenant fail closed', async () => {
  for (const override of [
    { aud: 'other' },
    { iss: 'other' },
    { sub: 'other' },
    { exp: seconds },
    { iat: seconds + 1 },
    { auth_time: seconds + 1 },
    { firebase: { ...claims().firebase, tenant: 'other' } },
    { firebase: { ...claims().firebase, sign_in_provider: 'password' } },
    { firebase: { ...claims().firebase, identities: {} } },
  ]) {
    const verifier = new DevFirebaseProviderIdentityVerifier(project, () =>
      Promise.resolve({
        ...claims(),
        ...override,
      }),
    );
    assert.equal(await verifier.verify(proof, now), null);
  }
});

void test('Apple uses separate verified provider subject and SDK errors deny', async () => {
  const verifier = new DevFirebaseProviderIdentityVerifier(project, () =>
    Promise.resolve({
      ...claims(),
      firebase: { sign_in_provider: 'apple.com', identities: { 'apple.com': ['apple-subject'] } },
    }),
  );
  assert.equal(
    (await verifier.verify({ ...proof, provider: 'apple' }, now))?.providerSubject,
    'apple-subject',
  );
  const denied = new DevFirebaseProviderIdentityVerifier(project, () =>
    Promise.reject(new Error('revoked')),
  );
  assert.equal(await denied.verify(proof, now), null);
});

void test('factory rejects a process switched into Auth or Firestore Emulator after construction', async () => {
  const previousAuth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const previousFirestore = process.env.FIRESTORE_EMULATOR_HOST;
  try {
    delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
    delete process.env.FIRESTORE_EMULATOR_HOST;
    const app = { options: { projectId: project } } as App;
    const verifier = createDevFirebaseProviderIdentityVerifier(app);
    process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
    assert.equal(await verifier.verify(proof, now), null);
    delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    assert.equal(await verifier.verify(proof, now), null);
  } finally {
    if (previousAuth === undefined) delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
    else process.env.FIREBASE_AUTH_EMULATOR_HOST = previousAuth;
    if (previousFirestore === undefined) delete process.env.FIRESTORE_EMULATOR_HOST;
    else process.env.FIRESTORE_EMULATOR_HOST = previousFirestore;
  }
});
