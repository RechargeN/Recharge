import assert from 'node:assert/strict';
import test from 'node:test';

import { createLocalIdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { createAccount } from '../../src/modules/identity_publisher/domain/account.js';
import { IdentityFailure } from '../../src/modules/identity_publisher/domain/failures.js';

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
  const personalSnapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session1,
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
    sessionId: ids.session1,
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
  await authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  const snapshot = await authority.access.create({
    userId: ids.user1,
    sessionId: ids.session1,
    pageId: ids.page1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:05.000Z',
    expiresAtUtc: '2026-09-22T00:05:05.000Z',
  });
  await authority.pages.revokeMembership({
    actorUserId: ids.user1,
    pageId: ids.page1,
    targetUserId: ids.user1,
    nowUtc: '2026-09-22T00:00:06.000Z',
  });
  await assert.rejects(authority.access.assertFresh(snapshot, '2026-09-22T00:00:07.000Z'));
  await assert.rejects(
    authority.access.create({
      userId: ids.user1,
      sessionId: ids.session1,
      pageId: ids.page1,
      capabilityPolicyRevision: 1,
      evaluatedAtUtc: '2026-09-22T00:00:07.000Z',
      expiresAtUtc: '2026-09-22T00:05:07.000Z',
    }),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'membership_inactive',
  );
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
  });
  await first.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:02.000Z',
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
