import { createAccount } from '../../../src/modules/identity_publisher/domain/account.js';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleDevIdentityRequest } from '../../../src/modules/identity_publisher/infrastructure/dev_identity_session_handler.js';
import type { DevIdentitySessionBinding } from '../../../src/modules/identity_publisher/infrastructure/dev_identity_session_binding.js';
import { IdentityFailure } from '../../../src/modules/identity_publisher/domain/failures.js';
const now = '2026-11-05T10:00:00.000Z';
const command = {
  schemaVersion: 1,
  commandType: 'establishIdentitySession',
  requestId: 'attempt',
  installationId: 'install-dev',
};
const request = {
  method: 'POST',
  callableName: 'establishIdentitySessionV1',
  headers: {
    'content-type': 'application/json',
    authorization: 'Bearer test-token',
    'x-firebase-appcheck': 'test-check',
    'x-recharge-identity-provider': 'google',
  },
  body: Buffer.from(JSON.stringify({ data: command })),
};
function fixture() {
  let calls = 0;
  let admitted = true;
  let failure: Error | undefined;
  const issued = {
    account: createAccount('018FQ2Z8Q9N4M7K2T6V3W1X5YA', now),
    session: {
      userId: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
      sessionId: 'server-session',
      installationId: 'install-dev',
    },
    sessionHandle: 'A'.repeat(43),
    accessSnapshot: { expiresAtUtc: '2026-11-05T11:00:00.000Z' },
  } as Awaited<ReturnType<DevIdentitySessionBinding['establish']>>;
  const invoke = () => {
    calls++;
    return failure === undefined ? Promise.resolve(issued) : Promise.reject(failure);
  };
  const deps = {
    projectId: 'recharge-dev-n2a01',
    enabled: true,
    sessions: {
      establish: invoke,
      refresh: invoke,
      recover: invoke,
      read: invoke,
      revoke: () => {
        calls++;
        return Promise.resolve();
      },
    },
    admitRequest: () => Promise.resolve(admitted),
    now: () => new Date(now),
  };
  return {
    deps,
    calls: () => calls,
    deny: () => {
      admitted = false;
    },
    fail: (error: Error) => {
      failure = error;
    },
  };
}
void test('handler preserves existing Session result shape and emits no authority claims', async () => {
  const f = fixture();
  const response = await handleDevIdentityRequest(request, f.deps);
  assert.equal(response.status, 200);
  assert.equal(f.calls(), 1);
  assert.deepEqual(response.body, {
    result: {
      schemaVersion: 1,
      commandType: command.commandType,
      requestId: 'attempt',
      serverTime: now,
      kind: 'succeeded',
      data: {
        authContext: {
          schemaVersion: 1,
          profile: {
            userId: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
            accountStatus: 'active',
            systemRoles: ['User'],
          },
          accessSnapshot: { expiresAtUtc: '2026-11-05T11:00:00.000Z' },
        },
        sessionContext: {
          userId: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
          sessionId: 'server-session',
          sessionHandle: 'A'.repeat(43),
          installationId: 'install-dev',
          expiresAtUtc: '2026-11-05T11:00:00.000Z',
        },
      },
    },
  });
});
void test('wrong project, method, endpoint, size, credentials and client authority deny before Session', async () => {
  const f = fixture();
  for (const invalid of [
    { ...request, method: 'GET' },
    { ...request, callableName: 'mediaCommandV1' },
    { ...request, body: Buffer.alloc(8193) },
    { ...request, body: Buffer.from([0xff]) },
    { ...request, headers: { ...request.headers, authorization: '' } },
    { ...request, headers: { ...request.headers, 'x-firebase-appcheck': '' } },
    { ...request, body: Buffer.from(JSON.stringify({ data: { ...command, roles: ['Admin'] } })) },
    {
      ...request,
      body: Buffer.from(
        JSON.stringify({ data: { ...command, commandType: 'recoverIdentitySessions' } }),
      ),
    },
  ])
    assert.notEqual((await handleDevIdentityRequest(invalid, f.deps)).status, 200);
  assert.equal(
    (await handleDevIdentityRequest(request, { ...f.deps, projectId: 'other' })).status,
    503,
  );
  assert.equal(
    (await handleDevIdentityRequest(request, { ...f.deps, enabled: false })).status,
    503,
  );
  assert.equal(f.calls(), 0);
  f.deny();
  assert.equal((await handleDevIdentityRequest(request, f.deps)).status, 429);
  assert.equal(f.calls(), 0);
});
void test('domain refusals preserve typed codes; arbitrary SDK errors never leak', async () => {
  const f = fixture();
  f.fail(new IdentityFailure('rate_limited', 60));
  assert.equal(
    JSON.stringify((await handleDevIdentityRequest(request, f.deps)).body).includes(
      '"retryAfter":60',
    ),
    true,
  );
  f.fail(new Error('private-sdk-token-value'));
  const result = JSON.stringify((await handleDevIdentityRequest(request, f.deps)).body);
  assert.equal(result.includes('private-sdk-token-value'), false);
  assert.equal(result.includes('temporarily_unavailable'), true);
});

void test('remote revoke uses existing authority and returns typed acknowledgement only', async () => {
  const f = fixture();
  const command = {
    schemaVersion: 1,
    commandType: 'revokeIdentitySession',
    requestId: 'revoke',
    allSessions: false,
    sessionContext: {
      sessionId: 'session',
      sessionHandle: 'A'.repeat(43),
      installationId: 'install-dev',
    },
  };
  const response = await handleDevIdentityRequest(
    {
      ...request,
      callableName: 'revokeIdentitySessionV1',
      body: Buffer.from(JSON.stringify({ data: command })),
    },
    f.deps,
  );
  assert.equal(response.status, 200);
  assert.equal(f.calls(), 1);
  assert.deepEqual(response.body, {
    result: {
      schemaVersion: 1,
      commandType: 'revokeIdentitySession',
      requestId: 'revoke',
      serverTime: now,
      kind: 'succeeded',
      data: { revoked: true },
    },
  });
});

void test('missing App Check is admitted only in explicit observe mode; credentials stay mandatory', async () => {
  const f = fixture();
  const { 'x-firebase-appcheck': _omitted, ...withoutCheck } = request.headers;
  void _omitted;
  const missing = { ...request, headers: withoutCheck };
  assert.equal((await handleDevIdentityRequest(missing, f.deps)).status, 401);
  assert.equal(
    (await handleDevIdentityRequest(missing, { ...f.deps, appCheckMode: 'enforce' })).status,
    401,
  );
  assert.equal(f.calls(), 0);
  const observe = { ...f.deps, appCheckMode: 'observe' as const };
  assert.equal((await handleDevIdentityRequest(missing, observe)).status, 200);
  assert.equal(f.calls(), 1);
  for (const invalid of [
    { ...missing, headers: { ...withoutCheck, authorization: '' } },
    { ...missing, headers: { ...withoutCheck, 'x-recharge-identity-provider': 'github' } },
    { ...request, headers: { ...request.headers, 'x-firebase-appcheck': 'x'.repeat(8193) } },
  ])
    assert.equal((await handleDevIdentityRequest(invalid, observe)).status, 401);
  assert.equal(f.calls(), 1);
});
