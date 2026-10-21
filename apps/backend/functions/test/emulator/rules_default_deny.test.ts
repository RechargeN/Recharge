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

void test('I2 Scenario, memberships, invites, receipts and J2 Route revisions/trust deny direct client reads/writes', async () => {
  const identity = await createSyntheticEmulatorIdentity();
  try {
    for (const collection of [
      'scenarios',
      'scenarioMembers',
      'scenarioInvites',
      'scenarioCommandReceipts',
      'scenarioRevisions',
      'routeRevisions',
      'moderationPublisherTrust',
      'scenarioShares',
    ]) {
      for (const token of [undefined, identity.token]) {
        assertDenied(await firestoreRead(`${collection}/${identity.uid}`, token));
        assertDenied(await firestoreWrite(`${collection}/${identity.uid}`, token));
      }
    }
  } finally {
    const host = requireHost('FIREBASE_AUTH_EMULATOR_HOST');
    const deleted = await fetch(
      `http://${host}/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ idToken: identity.token }),
      },
    );
    assert.equal(deleted.status, 200);
  }
});

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

void test('I1 Quick Plan collections explicitly deny anonymous and authenticated client access', async () => {
  const { quickPlanCollections } =
    await import('../../src/modules/quick_plan/quick_plan_contract.js');
  const identity = await createSyntheticEmulatorIdentity();
  for (const name of Object.values(quickPlanCollections)) {
    for (const probe of [`${name}/i1-rules-probe`, `${name}/${identity.uid}:i1-rules-probe`]) {
      for (const token of [undefined, identity.token]) {
        assertDenied(await firestoreRead(probe, token));
        assertDenied(await firestoreWrite(probe, token));
      }
    }
  }
});

void test('J1 Route collections explicitly deny anonymous and authenticated client access', async () => {
  const { routeCollections } = await import('../../src/modules/route/route_contract.js');
  const identity = await createSyntheticEmulatorIdentity();
  for (const name of Object.values(routeCollections)) {
    for (const probe of [`${name}/j1-rules-probe`, `${name}/${identity.uid}:j1-rules-probe`]) {
      for (const token of [undefined, identity.token]) {
        assertDenied(await firestoreRead(probe, token));
        assertDenied(await firestoreWrite(probe, token));
      }
    }
  }
});

void test('unknown Firestore and Storage paths remain denied', async () => {
  const identity = await createSyntheticEmulatorIdentity();
  assertDenied(await firestoreRead('unknown-root/probe', identity.token));
  assertDenied(await firestoreWrite('unknown-root/probe', identity.token));
  assertDenied(await storageRead('unknown-root/probe.txt', identity.token));
  assertDenied(await storageWrite('unknown-root/probe.txt', identity.token));
});

void test('K3 Admin/Support collections explicitly deny anonymous and authenticated client access', async () => {
  const { adminCollections } =
    await import('../../src/modules/admin_support/admin_support_service.js');
  const identity = await createSyntheticEmulatorIdentity();
  try {
    for (const name of Object.values(adminCollections)) {
      const probe = `${name}/k3-rules-probe`;
      for (const token of [undefined, identity.token]) {
        assertDenied(await firestoreRead(probe, token));
        assertDenied(await firestoreWrite(probe, token));
      }
    }
  } finally {
    const response = await fetch(
      `http://${requireHost('FIREBASE_AUTH_EMULATOR_HOST')}/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ idToken: identity.token }),
      },
    );
    assert.equal(response.status, 200, 'K3 Rules identity fixture cleanup');
  }
});
