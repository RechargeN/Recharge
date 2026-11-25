import { validateIdentityContract } from '../../../src/contracts/validate_identity_contract.js';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DevIdentitySessionBinding } from '../../../src/modules/identity_publisher/infrastructure/dev_identity_session_binding.js';
import { DevFirebaseProviderIdentityVerifier } from '../../../src/modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { InMemoryIdentityAuthorityRepository } from '../../../src/modules/identity_publisher/infrastructure/in_memory_identity_authority_repository.js';
import { changeAccountStatus } from '../../../src/modules/identity_publisher/domain/account.js';
import { abusePolicyId, abusePolicyRevision } from '../../../src/security/abuse_policy.js';

const project = 'recharge-dev-n2a01';
const instant = new Date('2026-11-05T10:00:00.000Z');
const seconds = instant.getTime() / 1000;
const proof = { provider: 'google' as const, providerTenant: project, proof: 'test-token' };
const input = {
  proof,
  appCheckToken: 'test-appcheck',
  installationId: 'install-dev',
  attemptRequestId: 'attempt-dev',
};
function fixture(mode?: 'observe' | 'enforce') {
  const observed: string[] = [];
  const repository = new InMemoryIdentityAuthorityRepository();
  let uid = 'firebase-user';
  let subject = 'google-subject';
  let authTime = seconds - 20;
  let appCheckValid = true;
  let rateAllowed = true;
  const verifier = new DevFirebaseProviderIdentityVerifier(project, () =>
    Promise.resolve({
      aud: project,
      iss: `https://securetoken.google.com/${project}`,
      uid,
      sub: uid,
      iat: seconds - 10,
      exp: seconds + 100,
      auth_time: authTime,
      firebase: { sign_in_provider: 'google.com', identities: { 'google.com': [subject] } },
      role: 'admin',
      capabilities: ['admin.tools.view'],
    }),
  );
  const binding = new DevIdentitySessionBinding(
    project,
    repository,
    verifier,
    {
      verify: () =>
        Promise.resolve(
          appCheckValid
            ? { state: 'valid' as const, tokenAgeSeconds: 1 }
            : { state: 'invalid' as const },
        ),
    },
    {
      consume: (request) => {
        assert.equal(request.environmentId, project);
        return Promise.resolve(
          rateAllowed
            ? {
                allowed: true as const,
                remaining: 10,
                policyId: abusePolicyId,
                policyRevision: abusePolicyRevision,
                networkRiskExceeded: false,
              }
            : {
                allowed: false as const,
                retryAfterSeconds: 60,
                policyId: abusePolicyId,
                policyRevision: abusePolicyRevision,
                networkRiskExceeded: false,
              },
        );
      },
    },
    () => instant,
    mode,
    mode === undefined ? undefined : (state) => void observed.push(state),
  );
  return {
    repository,
    binding,
    observed,
    otherUser: () => {
      uid = 'other-uid';
      subject = 'other-subject';
    },
    staleAuth: () => {
      authTime = seconds - 301;
    },
    denyAppCheck: () => {
      appCheckValid = false;
    },
    denyRate: () => {
      rateAllowed = false;
    },
  };
}

void test('dev Session uses owning authority, rotates handles and revokes without elevated provider grants', async () => {
  const { binding, repository } = fixture();
  const issued = await binding.establish(input);
  const response = {
    schemaVersion: 1,
    commandType: 'establishIdentitySession',
    requestId: 'attempt',
    serverTime: instant.toISOString(),
    kind: 'succeeded',
    data: {
      sessionContext: {
        userId: issued.session.userId,
        sessionId: issued.session.sessionId,
        sessionHandle: issued.sessionHandle,
        installationId: issued.session.installationId,
        expiresAtUtc: issued.accessSnapshot.expiresAtUtc,
      },
      authContext: {
        schemaVersion: 1,
        profile: {
          userId: issued.account.userId,
          accountStatus: issued.account.status,
          systemRoles: issued.account.systemRoles,
        },
        accessSnapshot: issued.accessSnapshot,
      },
    },
  };
  assert.equal((await validateIdentityContract('identitySessionResult', response)).ok, true);
  assert.equal(
    (
      await validateIdentityContract('identitySessionResult', {
        ...response,
        data: { ...response.data, authContext: { ...response.data.authContext, schemaVersion: 2 } },
      })
    ).ok,
    false,
  );
  assert.equal(issued.account.revision, issued.accessSnapshot.accountRevision);

  const account = await repository.transact((tx) => tx.account(issued.session.userId));
  assert.deepEqual(account?.systemRoles, ['User']);
  assert.equal(JSON.stringify(issued.accessSnapshot).includes('admin.tools.view'), false);
  const credentials = {
    ...input,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  };
  const beforeRead = await binding.read(credentials);
  const afterRead = await binding.read(credentials);
  assert.equal(beforeRead.sessionHandle, credentials.sessionHandle);
  assert.equal(afterRead.session.revision, issued.session.revision);
  const refreshed = await binding.refresh(credentials);
  assert.notEqual(refreshed.sessionHandle, credentials.sessionHandle);
  const current = { ...credentials, sessionHandle: refreshed.sessionHandle };
  // Owner 2026-11-19, confirmed 2026-11-22 (replaces the N2c single-use rule): the
  // replaced handle repairs a lost answer until the new one is used, then it is refused.
  await binding.read(current);
  await assert.rejects(binding.refresh(credentials));
  await binding.revoke(current);
  await assert.rejects(binding.refresh(current));
});

void test('cross-user, App Check, rate limit and blocked accounts deny', async () => {
  const f = fixture();
  const issued = await f.binding.establish(input);
  const credentials = {
    ...input,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  };
  f.otherUser();
  await assert.rejects(f.binding.refresh(credentials));
  await assert.rejects(f.binding.revoke(credentials));
  const noAppCheck = fixture();
  noAppCheck.denyAppCheck();
  await assert.rejects(noAppCheck.binding.establish(input));
  const noRate = fixture();
  noRate.denyRate();
  await assert.rejects(noRate.binding.establish(input));
  const blocked = fixture();
  const session = await blocked.binding.establish(input);
  await blocked.repository.transact(async (tx) => {
    const account = await tx.account(session.session.userId);
    assert.ok(account);
    tx.putAccount(changeAccountStatus(account, 'blocked', instant.toISOString()));
  });
  await assert.rejects(blocked.binding.establish(input));
});

void test('recovery requires recent auth and fences previous Sessions; logoutAll revokes recovered Session', async () => {
  const f = fixture();
  const issued = await f.binding.establish(input);
  const recovered = await f.binding.recover(input);
  assert.equal(recovered.account.revision, recovered.accessSnapshot.accountRevision);
  assert.equal(recovered.account.securityRevision, recovered.session.authzRevision);
  await assert.rejects(
    f.binding.refresh({
      ...input,
      sessionId: issued.session.sessionId,
      sessionHandle: issued.sessionHandle,
    }),
  );
  const current = {
    ...input,
    sessionId: recovered.session.sessionId,
    sessionHandle: recovered.sessionHandle,
  };
  await f.binding.revoke(current, true);
  await assert.rejects(f.binding.refresh(current));
  const stale = fixture();
  await stale.binding.establish(input);
  stale.staleAuth();
  await assert.rejects(stale.binding.recover(input));
});

void test('observe mode records App Check state without granting it authority; default stays enforce', async () => {
  const observing = fixture('observe');
  observing.denyAppCheck();
  const issued = await observing.binding.establish(input);
  assert.deepEqual(observing.observed, ['invalid']);
  assert.deepEqual(issued.account.systemRoles, ['User']);
  // Firebase identity, Session ownership and rate limits are still mandatory in observe mode.
  observing.otherUser();
  await assert.rejects(
    observing.binding.refresh({
      ...input,
      sessionId: issued.session.sessionId,
      sessionHandle: issued.sessionHandle,
    }),
  );
  const throttled = fixture('observe');
  throttled.denyRate();
  await assert.rejects(throttled.binding.establish(input));
  const explicitEnforce = fixture('enforce');
  explicitEnforce.denyAppCheck();
  await assert.rejects(explicitEnforce.binding.establish(input));
  assert.deepEqual(explicitEnforce.observed, ['invalid']);
  const defaultMode = fixture();
  defaultMode.denyAppCheck();
  await assert.rejects(defaultMode.binding.establish(input));
});

// A34 staging 2026-11-21 00:26 UTC: the rotation answer was lost, then the
// refresh with the previous handle was refused before it reached rotate().
void test('a refresh whose answer was lost can be repeated with the previous handle until the new one is used', async () => {
  const { binding } = fixture();
  const issued = await binding.establish(input);
  const held = {
    ...input,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  };
  await binding.refresh(held); // the answer never reaches the device

  const repaired = await binding.refresh(held);
  assert.notEqual(repaired.sessionHandle, held.sessionHandle);

  await assert.rejects(binding.refresh({ ...held, installationId: 'other-install' }));
  await assert.rejects(binding.revoke(held), 'a previous handle only repairs a rotation');

  await binding.read({ ...held, sessionHandle: repaired.sessionHandle });
  await assert.rejects(binding.refresh(held), 'using the new handle retires the previous one');
});

// Mobile decision 2026-11-21 #5 wipes copies of server data only on these two
// answers. A restriction moves the revocation fence, so it answers as a
// revocation too (accepted by the owner 2026-11-22).
for (const end of ['logoutAll', 'recovery', 'restricted', 'blocked', 'deleted'] as const) {
  void test(`end of access answers read and refresh with its own code: ${end}`, async () => {
    const f = fixture();
    const held = await f.binding.establish(input);
    const other = await f.binding.establish({ ...input, installationId: 'install-other' });
    if (end === 'logoutAll') {
      await f.binding.revoke(
        {
          ...input,
          installationId: 'install-other',
          sessionId: other.session.sessionId,
          sessionHandle: other.sessionHandle,
        },
        true,
      );
    } else if (end === 'recovery') {
      await f.binding.recover({ ...input, installationId: 'install-other' });
    } else {
      await f.repository.transact(async (tx) => {
        const account = await tx.account(held.session.userId);
        assert.ok(account);
        tx.putAccount(changeAccountStatus(account, end, instant.toISOString()));
      });
    }
    const presented = {
      ...input,
      sessionId: held.session.sessionId,
      sessionHandle: held.sessionHandle,
    };
    for (const call of [() => f.binding.read(presented), () => f.binding.refresh(presented)])
      await assert.rejects(call, (error: { code?: string }) => {
        assert.ok(
          error.code === 'session_revoked' || error.code === 'account_blocked',
          `code: ${String(error.code)}`,
        );
        return true;
      });
  });
}

// A34 2026-11-24 (staging, RC 15df1cb): the phone's Session context carried
// only `booking.self_service`, so Create refused Session, Class/Workshop and
// Route before any request. ADR 0023: every active User authors personal
// content; the Session snapshot carries the same personal set as the access
// snapshot service (money still needs verification, checked per command).
void test('Session snapshots carry the ADR 0023 personal capabilities on establish, refresh and recovery', async () => {
  const personal = ['booking.self_service', 'content.create', 'content.publish', 'content.submit'];
  const f = fixture();
  const issued = await f.binding.establish(input);
  assert.deepEqual([...issued.accessSnapshot.capabilityIds].sort(), personal);
  const refreshed = await f.binding.refresh({
    ...input,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  });
  assert.deepEqual([...refreshed.accessSnapshot.capabilityIds].sort(), personal);
  const recovered = await f.binding.recover(input);
  assert.deepEqual([...recovered.accessSnapshot.capabilityIds].sort(), personal);
});

// A34 2026-11-24 (staging, RC-2): a Session issued before the personal set
// was deployed kept `['booking.self_service']` across refreshes, because a
// refresh copied the previous snapshot. A personal snapshot is re-evaluated
// on refresh; a Page snapshot keeps its membership capabilities.
void test('a refresh re-evaluates a personal snapshot issued under the old capability set', async () => {
  const f = fixture();
  const issued = await f.binding.establish(input);
  await f.repository.transact(async (tx) => {
    const current = await tx.accessSnapshot(issued.session.sessionId);
    assert.ok(current !== null);
    tx.putAccessSnapshot({ ...current, capabilityIds: ['booking.self_service'] });
  });
  const refreshed = await f.binding.refresh({
    ...input,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  });
  assert.deepEqual([...refreshed.accessSnapshot.capabilityIds].sort(), [
    'booking.self_service',
    'content.create',
    'content.publish',
    'content.submit',
  ]);
  const stored = await f.repository.transact((tx) => tx.accessSnapshot(issued.session.sessionId));
  assert.deepEqual(
    [...(stored?.capabilityIds ?? [])].sort(),
    [...refreshed.accessSnapshot.capabilityIds].sort(),
  );
});
