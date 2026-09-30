import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const projectId = 'demo-recharge';
const firestore = emulatorFirestore();
const collections = Object.values(contentCollections);

function requireHost(name: string): string {
  const value = process.env[name];
  assert.ok(value, `${name} must be set by emulators:exec`);
  assert.match(value, /^(127\.0\.0\.1|localhost):\d+$/u);
  return value;
}

async function syntheticIdentity(): Promise<{ token: string; uid: string }> {
  const response = await fetch(
    `http://${requireHost('FIREBASE_AUTH_EMULATOR_HOST')}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(response.status, 200);
  const body = (await response.json()) as { idToken?: unknown; localId?: unknown };
  if (typeof body.idToken !== 'string' || typeof body.localId !== 'string')
    throw new TypeError('Auth emulator response must contain string idToken and localId values');
  return { token: body.idToken, uid: body.localId };
}

const base = () =>
  `http://${requireHost('FIRESTORE_EMULATOR_HOST')}/v1/projects/${projectId}/databases/(default)/documents`;
const headers = (token?: string): Record<string, string> =>
  token === undefined ? {} : { authorization: `Bearer ${token}` };

function assertDenied(response: Response, label: string): void {
  assert.ok(
    response.status === 401 || response.status === 403,
    `${label}: expected rules denial, received HTTP ${String(response.status)}`,
  );
}

async function probe(path: string, token?: string): Promise<Response[]> {
  const body = JSON.stringify({ fields: { value: { stringValue: 'client-write' } } });
  return [
    await fetch(`${base()}/${path}`, { headers: headers(token) }),
    await fetch(`${base()}/${path}`, {
      method: 'PATCH',
      headers: { ...headers(token), 'content-type': 'application/json' },
      body,
    }),
    await fetch(`${base()}/${path}`, { method: 'DELETE', headers: headers(token) }),
  ];
}

const cleanup = async () => {
  for (const collection of collections) {
    const snapshot = await firestore.collection(collection).limit(50).get();
    const batch = firestore.batch();
    for (const document of snapshot.docs) batch.delete(document.ref);
    await batch.commit();
  }
};
before(cleanup);
after(cleanup);

void test('the manifest names exactly the eight Content collections', () => {
  assert.deepEqual([...collections].sort(), [
    'contentAudit',
    'contentDrafts',
    'contentEffects',
    'contentExternalBindings',
    'contentIdempotency',
    'contentPublicationPointers',
    'contentPublishedRevisions',
    'contentSubmissions',
  ]);
});

void test('unauthenticated clients can neither read nor write any Content collection', async () => {
  for (const collection of collections) {
    const responses = await probe(`${collection}/probe`);
    responses.forEach((response, index) =>
      assertDenied(response, `${collection} #${String(index)}`),
    );
    assertDenied(await fetch(`${base()}/${collection}`), `${collection} list`);
  }
});

void test('authenticated clients, including a same-id user document, remain denied everywhere', async () => {
  const identity = await syntheticIdentity();
  for (const collection of collections) {
    for (const path of [`${collection}/probe`, `${collection}/${identity.uid}`]) {
      const responses = await probe(path, identity.token);
      responses.forEach((response, index) => assertDenied(response, `${path} #${String(index)}`));
    }
    assertDenied(
      await fetch(`${base()}/${collection}`, { headers: headers(identity.token) }),
      `${collection} list`,
    );
  }
});

void test('a document written by the server stays unreadable and unchangeable for clients', async () => {
  const identity = await syntheticIdentity();
  for (const collection of collections) {
    await firestore.collection(collection).doc('server-owned').set({ serverOnly: true });
    for (const token of [undefined, identity.token]) {
      const responses = await probe(`${collection}/server-owned`, token);
      responses.forEach((response, index) =>
        assertDenied(response, `${collection}/server-owned #${String(index)}`),
      );
    }
    const stored = await firestore.collection(collection).doc('server-owned').get();
    assert.equal(stored.data()?.serverOnly, true);
  }
});
