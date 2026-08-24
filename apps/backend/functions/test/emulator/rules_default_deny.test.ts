import assert from 'node:assert/strict';
import { test } from 'node:test';

const projectId = 'demo-recharge';

type SyntheticIdentity = Readonly<{ token: string; uid: string }>;

function requireHost(name: string): string {
  const value = process.env[name];
  assert.ok(value, `${name} must be set by emulators:exec`);
  assert.match(value, /^(127\.0\.0\.1|localhost):\d+$/u);
  return value;
}

async function createSyntheticEmulatorIdentity(): Promise<SyntheticIdentity> {
  const authHost = requireHost('FIREBASE_AUTH_EMULATOR_HOST');
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(response.status, 200);
  const body = (await response.json()) as {
    idToken?: unknown;
    localId?: unknown;
  };
  if (typeof body.idToken !== 'string' || typeof body.localId !== 'string') {
    throw new TypeError('Auth emulator response must contain string idToken and localId values');
  }
  return Object.freeze({ token: body.idToken, uid: body.localId });
}

function authorizationHeaders(token?: string): Record<string, string> {
  return token === undefined ? {} : { authorization: `Bearer ${token}` };
}

async function firestoreWrite(documentPath: string, token?: string): Promise<Response> {
  const host = requireHost('FIRESTORE_EMULATOR_HOST');
  return fetch(
    `http://${host}/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
    {
      method: 'PATCH',
      headers: {
        ...authorizationHeaders(token),
        'content-type': 'application/json',
      },
      body: JSON.stringify({ fields: { value: { stringValue: 'synthetic' } } }),
    },
  );
}

async function firestoreRead(documentPath: string, token?: string): Promise<Response> {
  const host = requireHost('FIRESTORE_EMULATOR_HOST');
  return fetch(
    `http://${host}/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
    { headers: authorizationHeaders(token) },
  );
}

async function storageWrite(objectName: string, token?: string): Promise<Response> {
  const host = requireHost('FIREBASE_STORAGE_EMULATOR_HOST');
  const bucket = `${projectId}.appspot.com`;
  return fetch(
    `http://${host}/v0/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(objectName)}`,
    {
      method: 'POST',
      headers: {
        ...authorizationHeaders(token),
        'content-type': 'text/plain',
      },
      body: 'synthetic',
    },
  );
}

async function storageRead(objectName: string, token?: string): Promise<Response> {
  const host = requireHost('FIREBASE_STORAGE_EMULATOR_HOST');
  const bucket = `${projectId}.appspot.com`;
  return fetch(`http://${host}/v0/b/${bucket}/o/${encodeURIComponent(objectName)}?alt=media`, {
    headers: authorizationHeaders(token),
  });
}

function assertDenied(response: Response): void {
  assert.ok(
    response.status === 401 || response.status === 403,
    `expected rules denial, received HTTP ${response.status}`,
  );
}

void test('Firestore and Storage deny unauthenticated client writes', async () => {
  assertDenied(await firestoreWrite('users/anonymous/private/probe'));
  assertDenied(await storageWrite('users/anonymous/probe.txt'));
});

void test('authenticated own-scope reads and writes remain denied', async () => {
  const identity = await createSyntheticEmulatorIdentity();
  const firestorePath = `users/${identity.uid}/private/probe`;
  const storagePath = `users/${identity.uid}/probe.txt`;
  assertDenied(await firestoreRead(firestorePath, identity.token));
  assertDenied(await firestoreWrite(firestorePath, identity.token));
  assertDenied(await storageRead(storagePath, identity.token));
  assertDenied(await storageWrite(storagePath, identity.token));
});

void test('cross-user and cross-page writes remain denied by default', async () => {
  const identity = await createSyntheticEmulatorIdentity();
  assertDenied(await firestoreWrite('users/another-user/private/probe', identity.token));
  assertDenied(await firestoreWrite('pages/another-page/private/probe', identity.token));
  assertDenied(await storageWrite('users/another-user/probe.txt', identity.token));
  assertDenied(await storageWrite('pages/another-page/probe.txt', identity.token));
});

void test('unknown Firestore and Storage paths remain denied', async () => {
  const identity = await createSyntheticEmulatorIdentity();
  assertDenied(await firestoreRead('unknown-root/probe', identity.token));
  assertDenied(await firestoreWrite('unknown-root/probe', identity.token));
  assertDenied(await storageRead('unknown-root/probe.txt', identity.token));
  assertDenied(await storageWrite('unknown-root/probe.txt', identity.token));
});
