import assert from 'node:assert/strict';
import test from 'node:test';

import { createLocalIdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { createAccount } from '../../src/modules/identity_publisher/domain/account.js';
import { IdentityFailure } from '../../src/modules/identity_publisher/domain/failures.js';
import { parseEntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

const ids = {
  user1: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
  user2: '018FQ2Z8Q9N4M7K2T6V3W1X5YB',
  identity1: '018FQ2Z8Q9N4M7K2T6V3W1X5YC',
  identity2: '018FQ2Z8Q9N4M7K2T6V3W1X5YD',
  session1: '018FQ2Z8Q9N4M7K2T6V3W1X5YE',
  session2: '018FQ2Z8Q9N4M7K2T6V3W1X5YF',
  verification1: '018FQ2Z8Q9N4M7K2T6V3W1X5YG',
  evidence1: '018FQ2Z8Q9N4M7K2T6V3W1X5YH',
  page1: '018FQ2Z8Q9N4M7K2T6V3W1X5YJ',
  page2: '018FQ2Z8Q9N4M7K2T6V3W1X5YK',
  membership1: '018FQ2Z8Q9N4M7K2T6V3W1X5YM',
  membership2: '018FQ2Z8Q9N4M7K2T6V3W1X5YN',
} as const;

function setup() {
  return createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 3,
  });
}

const googleProof = (subject: string) => ({
  provider: 'google' as const,
  providerTenant: 'consumer',
  proof: `local-test:google:${subject}`,
});
const appleProof = (subject: string) => ({
  provider: 'apple' as const,
  providerTenant: 'consumer',
  proof: `local-test:apple:${subject}`,
});

void test('provider tuple links once and collisions remain anti-enumerating', async () => {
  const { authority } = setup();
  const first = await authority.accounts.ensureAccount({
    proof: googleProof('subject-1'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  const replay = await authority.accounts.ensureAccount({
    proof: googleProof('subject-1'),
    proposedUserId: ids.user2,
    proposedIdentityId: ids.identity2,
    nowUtc: '2026-09-22T00:00:01.000Z',
    accountCreationEnabled: true,
  });
  assert.equal(replay.userId, first.userId);
  await authority.accounts.ensureAccount({
    proof: appleProof('subject-2'),
    proposedUserId: ids.user2,
    proposedIdentityId: ids.identity2,
    nowUtc: '2026-09-22T00:00:01.000Z',
    accountCreationEnabled: true,
  });
  await assert.rejects(
    authority.accounts.linkIdentity({
      actorUserId: ids.user2,
      proof: googleProof('subject-1'),
      identityId: ids.identity1,
      nowUtc: '2026-09-22T00:00:02.000Z',
    }),
    (error: unknown) =>
      error instanceof IdentityFailure && error.code === 'provider_subject_conflict',
  );
});

void test('concurrent duplicate provider assertions create one account only', async () => {
  const { authority } = setup();
  const results = await Promise.all([
    authority.accounts.ensureAccount({
      proof: googleProof('concurrent'),
      proposedUserId: ids.user1,
      proposedIdentityId: ids.identity1,
      nowUtc: '2026-09-22T00:00:00.000Z',
      accountCreationEnabled: true,
    }),
    authority.accounts.ensureAccount({
      proof: googleProof('concurrent'),
      proposedUserId: ids.user2,
      proposedIdentityId: ids.identity2,
      nowUtc: '2026-09-22T00:00:00.000Z',
      accountCreationEnabled: true,
    }),
  ]);
  assert.equal(new Set(results.map((account) => account.userId)).size, 1);
});

void test('fourth active Session is rejected and rotation preserves Session identity', async () => {
  const { authority } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('session-cap'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  const sessionIds = [
    '018FQ2Z8Q9N4M7K2T6V3W1X5YP',
    '018FQ2Z8Q9N4M7K2T6V3W1X5YQ',
    '018FQ2Z8Q9N4M7K2T6V3W1X5YR',
  ] as const;
  const issuedSessions = [];
  for (const [index, sessionId] of sessionIds.entries()) {
    issuedSessions.push(
      await authority.sessions.issue({
        userId: ids.user1,
        sessionId,
        issuedAtUtc: `2026-09-22T00:00:0${index + 1}.000Z`,
        firebaseUid: ids.user1,
        installationId: `install-${index + 1}`,
        snapshotExpiresAtUtc: '2026-09-22T00:20:00.000Z',
      }),
    );
  }
  await assert.rejects(
    authority.sessions.issue({
      userId: ids.user1,
      sessionId: '018FQ2Z8Q9N4M7K2T6V3W1X5YS',
      issuedAtUtc: '2026-09-22T00:00:05.000Z',
      firebaseUid: ids.user1,
      installationId: 'install-4',
      snapshotExpiresAtUtc: '2026-09-22T00:20:00.000Z',
    }),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'session_limit_reached',
  );

  const before = await authority.sessions.getCurrent(ids.user1, sessionIds[0]);
  const rotated = await authority.sessions.rotate({
    sessionId: sessionIds[0],
    sessionHandle: issuedSessions[0]!.sessionHandle,
    firebaseUid: ids.user1,
    installationId: 'install-1',
    nowUtc: '2026-09-22T00:00:06.000Z',
    snapshotExpiresAtUtc: '2026-09-22T00:20:06.000Z',
  });
  assert.equal(rotated.session.sessionId, before.sessionId);
  assert.equal(rotated.session.revision, before.revision + 1);
  assert.equal(rotated.accessSnapshot.sessionRevision, rotated.session.revision);
  assert.match(rotated.sessionHandle, /^[A-Za-z0-9_-]{43}$/u);
});

void test('same installation replaces its Session and twelve refreshes retain one live authority', async () => {
  const { authority } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('refresh-chain'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  const first = await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: 'firebase-refresh-chain',
    installationId: 'install-refresh',
    snapshotExpiresAtUtc: '2026-09-22T01:00:01.000Z',
  });
  const replacement = await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:02.000Z',
    firebaseUid: 'firebase-refresh-chain',
    installationId: 'install-refresh',
    snapshotExpiresAtUtc: '2026-09-22T01:00:02.000Z',
  });
  await assert.rejects(
    authority.sessions.getCurrent(ids.user1, first.session.sessionId, '2026-09-22T00:00:03.000Z'),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'session_revoked',
  );
  let current = replacement;
  for (let index = 0; index < 12; index += 1) {
    const hour = String(Math.floor(index / 4)).padStart(2, '0');
    const minute = String((index % 4) * 15 + 1).padStart(2, '0');
    const nowUtc = `2026-09-22T${hour}:${minute}:00.000Z`;
    current = await authority.sessions.rotate({
      sessionId: ids.session2,
      sessionHandle: current.sessionHandle,
      firebaseUid: 'firebase-refresh-chain',
      installationId: 'install-refresh',
      nowUtc,
      snapshotExpiresAtUtc: new Date(Date.parse(nowUtc) + 60 * 60 * 1000).toISOString(),
    });
  }
  assert.equal(current.session.revision, 13);
  assert.equal(current.accessSnapshot.expiresAtUtc, '2026-09-22T03:46:00.000Z');
});

void test('recent-auth recovery revokes three prior Sessions and issues a usable replacement', async () => {
  const { authority } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('recover-chain'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  const issued = [];
  for (const [index, sessionId] of [ids.session1, ids.session2, ids.verification1].entries()) {
    issued.push(
      await authority.sessions.issue({
        userId: ids.user1,
        sessionId,
        issuedAtUtc: `2026-09-22T00:00:0${index + 1}.000Z`,
        firebaseUid: 'firebase-recover-chain',
        installationId: `recover-install-${index + 1}`,
        snapshotExpiresAtUtc: '2026-09-22T01:00:00.000Z',
      }),
    );
  }
  await assert.rejects(
    authority.sessions.issue({
      userId: ids.user1,
      sessionId: ids.evidence1,
      issuedAtUtc: '2026-09-22T00:00:05.000Z',
      firebaseUid: 'firebase-recover-chain',
      installationId: 'recover-install-4',
      snapshotExpiresAtUtc: '2026-09-22T01:00:05.000Z',
    }),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'session_limit_reached',
  );
  const recovered = await authority.sessions.recover({
    userId: ids.user1,
    sessionId: ids.evidence1,
    firebaseUid: 'firebase-recover-chain',
    installationId: 'recover-install-4',
    nowUtc: '2026-09-22T00:00:06.000Z',
    snapshotExpiresAtUtc: '2026-09-22T01:00:06.000Z',
  });
  for (const previous of issued) {
    await assert.rejects(
      authority.sessions.getCurrent(
        ids.user1,
        previous.session.sessionId,
        '2026-09-22T00:00:07.000Z',
      ),
      (error: unknown) => error instanceof IdentityFailure && error.code === 'session_revoked',
    );
  }
  assert.equal(
    (
      await authority.sessions.getCurrent(
        ids.user1,
        recovered.session.sessionId,
        '2026-09-22T00:00:07.000Z',
      )
    ).sessionId,
    recovered.session.sessionId,
  );
});

void test('verified Creator obtains exact personal and page Publisher authority only', async () => {
  const { authority } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('creator'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  const unverifiedSnapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:02.000Z',
    expiresAtUtc: '2026-09-22T00:05:02.000Z',
  });
  const unverified = await authority.publishers.evaluate({
    snapshot: unverifiedSnapshot,
    requestedPublisher: authority.publishers.personalRef(ids.user1),
    requiredCapability: 'content.publish',
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  assert.equal(unverified.reason, 'creator_verification_required');
  await authority.creatorVerification.submit({
    userId: ids.user1,
    verificationId: ids.verification1,
    evidenceRefIds: [ids.evidence1],
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: ids.user1,
    status: 'verified',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:04.500Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:04.500Z',
  });
  const personalSnapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session2,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:05.000Z',
    expiresAtUtc: '2026-09-22T00:05:05.000Z',
  });
  assert.equal(
    (
      await authority.publishers.evaluate({
        snapshot: personalSnapshot,
        requestedPublisher: authority.publishers.personalRef(ids.user1),
        requiredCapability: 'content.publish',
        nowUtc: '2026-09-22T00:00:06.000Z',
      })
    ).eligible,
    true,
  );
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:07.000Z',
  });
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page2,
    membershipId: ids.membership2,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:08.000Z',
  });
  await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'verified',
    nowUtc: '2026-09-22T00:00:09.000Z',
  });
  const pageSnapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session2,
    pageId: ids.page1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:10.000Z',
    expiresAtUtc: '2026-09-22T00:05:10.000Z',
  });
  assert.equal(
    (
      await authority.publishers.evaluate({
        snapshot: pageSnapshot,
        requestedPublisher: authority.publishers.pageRef(ids.page1),
        requiredCapability: 'content.publish',
        nowUtc: '2026-09-22T00:00:11.000Z',
      })
    ).eligible,
    true,
  );
  assert.equal(
    (
      await authority.publishers.evaluate({
        snapshot: pageSnapshot,
        requestedPublisher: authority.publishers.pageRef(ids.page2),
        requiredCapability: 'content.publish',
        nowUtc: '2026-09-22T00:00:11.000Z',
      })
    ).reason,
    'publisher_not_accessible',
  );
});

void test('membership and account revocation invalidate cached authority', async () => {
  const { authority } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('revoked'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  await authority.creatorVerification.submit({
    userId: ids.user1,
    verificationId: ids.verification1,
    evidenceRefIds: [ids.evidence1],
    nowUtc: '2026-09-22T00:00:02.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: ids.user1,
    status: 'verified',
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:03.500Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:03.500Z',
  });
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  const snapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session2,
    pageId: ids.page1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:05.000Z',
    expiresAtUtc: '2026-09-22T00:05:05.000Z',
  });
  await assert.rejects(
    authority.pages.revokeMembership({
      actorUserId: ids.user1,
      pageId: ids.page1,
      targetUserId: ids.user1,
      nowUtc: '2026-09-22T00:00:06.000Z',
    }),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'invalid_transition',
  );
  await assert.doesNotReject(authority.access.assertFresh(snapshot, '2026-09-22T00:00:07.000Z'));
  await authority.accountSecurity.setStatus({
    userId: ids.user1,
    status: 'blocked',
    nowUtc: '2026-09-22T00:00:08.000Z',
  });
  await assert.rejects(authority.sessions.getCurrent(ids.user1, ids.session1));
});

void test('logout-all and restriction revoke every active local session', async () => {
  const first = setup();
  await first.authority.accounts.ensureAccount({
    proof: googleProof('logout-all'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await first.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  await first.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:02.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:02.000Z',
  });
  await first.authority.sessions.logoutAll({
    actorUserId: ids.user1,
    currentSessionId: ids.session1,
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await assert.rejects(first.authority.sessions.getCurrent(ids.user1, ids.session1));
  await assert.rejects(first.authority.sessions.getCurrent(ids.user1, ids.session2));

  const second = setup();
  await second.authority.accounts.ensureAccount({
    proof: googleProof('restricted'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await second.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  await second.authority.accountSecurity.setStatus({
    userId: ids.user1,
    status: 'restricted',
    nowUtc: '2026-09-22T00:00:02.000Z',
  });
  await assert.rejects(second.authority.sessions.getCurrent(ids.user1, ids.session1));
});

void test('Admin role is never sufficient Publisher authority', async () => {
  const { authority, repository } = setup();
  await repository.transact((transaction) => {
    transaction.putAccount(createAccount(ids.user1, '2026-09-22T00:00:00.000Z', ['Admin']));
  });
  await authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  const snapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:02.000Z',
    expiresAtUtc: '2026-09-22T00:05:02.000Z',
  });
  const decision = await authority.publishers.evaluate({
    snapshot,
    requestedPublisher: authority.publishers.personalRef(ids.user1),
    requiredCapability: 'content.publish',
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  assert.equal(decision.eligible, false);
  assert.equal(decision.reason, 'creator_verification_required');
});

void test('page grants are role-bounded and suspended pages become restricted', async () => {
  const { authority, repository } = setup();
  await authority.accounts.ensureAccount({
    proof: googleProof('grant-owner'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await authority.creatorVerification.submit({
    userId: ids.user1,
    verificationId: ids.verification1,
    evidenceRefIds: [ids.evidence1],
    nowUtc: '2026-09-22T00:00:01.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: ids.user1,
    status: 'verified',
    nowUtc: '2026-09-22T00:00:02.000Z',
  });
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'verified',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  await repository.transact((transaction) => {
    transaction.putMembership({
      schemaVersion: 1,
      membershipId: parseEntityId(ids.membership2),
      pageId: parseEntityId(ids.page1),
      userId: parseEntityId(ids.user2),
      role: 'analyst',
      status: 'active',
      capabilityIds: ['view_insights'],
      revision: 1,
      createdAtUtc: parseUtcInstant('2026-09-22T00:00:04.000Z'),
      updatedAtUtc: parseUtcInstant('2026-09-22T00:00:04.000Z'),
    });
  });
  await assert.rejects(
    authority.pages.setCapabilities({
      actorUserId: ids.user1,
      pageId: ids.page1,
      targetUserId: ids.user2,
      capabilityIds: ['manage_page'],
      nowUtc: '2026-09-22T00:00:05.000Z',
    }),
    (error: unknown) =>
      error instanceof IdentityFailure && error.code === 'not_found_or_not_accessible',
  );
  const granted = await authority.pages.setCapabilities({
    actorUserId: ids.user1,
    pageId: ids.page1,
    targetUserId: ids.user2,
    capabilityIds: ['view_insights'],
    nowUtc: '2026-09-22T00:00:06.000Z',
  });
  assert.deepEqual(granted.capabilityIds, ['view_insights']);
  await repository.transact((transaction) => {
    transaction.putMembership({
      ...granted,
      status: 'revoked',
      revision: granted.revision + 1,
      updatedAtUtc: parseUtcInstant('2026-09-22T00:00:06.500Z'),
    });
  });
  await assert.rejects(
    authority.pages.setCapabilities({
      actorUserId: ids.user1,
      pageId: ids.page1,
      targetUserId: ids.user2,
      capabilityIds: ['view_insights'],
      nowUtc: '2026-09-22T00:00:06.750Z',
    }),
    (error: unknown) =>
      error instanceof IdentityFailure && error.code === 'not_found_or_not_accessible',
  );
  const suspended = await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'suspended',
    nowUtc: '2026-09-22T00:00:07.000Z',
  });
  assert.equal(suspended.status, 'restricted');
  const revoked = await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'revoked',
    nowUtc: '2026-09-22T00:00:08.000Z',
  });
  assert.equal(revoked.status, 'restricted');
});

void test('restricted pages do not consume active page creation quota', async () => {
  const { authority } = createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 1,
  });
  await authority.accounts.ensureAccount({
    proof: googleProof('quota-owner'),
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await authority.creatorVerification.submit({
    userId: ids.user1,
    verificationId: ids.verification1,
    evidenceRefIds: [ids.evidence1],
    nowUtc: '2026-09-22T00:00:01.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: ids.user1,
    status: 'verified',
    nowUtc: '2026-09-22T00:00:02.000Z',
  });
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'rejected',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  const replacement = await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page2,
    membershipId: ids.membership2,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:05.000Z',
  });
  assert.equal(replacement.page.status, 'pendingReview');
});
