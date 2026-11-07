import assert from 'node:assert/strict';
import test from 'node:test';

import type { ContentTypeId } from '../../../src/contracts/content_v1.js';
import { createLocalIdentityPublisherAuthority } from '../../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import {
  freePersonalContentTypes,
  identityVerificationRequired,
} from '../../../src/modules/content/domain/personal_publishing_policy.js';
import { IdentityPublisherEligibility } from '../../../src/modules/content/infrastructure/identity_publisher_eligibility.js';
import { IdentityMediaActorAuthority } from '../../../src/modules/media/infrastructure/identity_media_authority.js';
import type { EntityId } from '../../../src/shared/ids.js';
import type { MarketId } from '../../../src/modules/reference_data/domain/identifiers.js';

// ADR 0023 (User = Creator, OQ-2): free personal content without identity
// verification; risky types and Page publishing keep the verification fact.

const ids = {
  user1: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
  user2: '018FQ2Z8Q9N4M7K2T6V3W1X5YB',
  identity1: '018FQ2Z8Q9N4M7K2T6V3W1X5YC',
  session1: '018FQ2Z8Q9N4M7K2T6V3W1X5YE',
  session2: '018FQ2Z8Q9N4M7K2T6V3W1X5YF',
  verification1: '018FQ2Z8Q9N4M7K2T6V3W1X5YG',
  evidence1: '018FQ2Z8Q9N4M7K2T6V3W1X5YH',
} as const;
const now = '2026-09-22T00:00:02.000Z';

async function plainUser() {
  const local = createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 3,
  });
  await local.authority.accounts.ensureAccount({
    proof: { provider: 'google', providerTenant: 'consumer', proof: 'local-test:google:subject-1' },
    proposedUserId: ids.user1,
    proposedIdentityId: ids.identity1,
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  await local.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session1,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-1',
    snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
  });
  return local;
}

const request = (
  typeId: ContentTypeId,
  publisherId: string = ids.user1,
  sessionId: string = ids.session1,
) => ({
  actor: { userId: ids.user1 as EntityId, sessionId: sessionId as EntityId },
  publisherRef: { type: 'user' as const, id: publisherId as EntityId },
  typeId,
  action: 'create' as const,
  marketId: 'LV' as MarketId,
  requiredCapability: 'content.create',
  nowUtc: now,
});

void test('policy: only the free personal types skip verification; Page and unknown types never do', () => {
  assert.deepEqual([...freePersonalContentTypes].sort(), [
    'activity',
    'collection',
    'place',
    'route',
    'scenario',
  ]);
  const user = { type: 'user' as const, id: ids.user1 as EntityId };
  for (const typeId of [
    'event',
    'rental',
    'session',
    'class_workshop',
    'find_people',
  ] as ContentTypeId[])
    assert.equal(identityVerificationRequired(typeId, user), true, typeId);
  assert.equal(identityVerificationRequired('place', user), false);
  assert.equal(identityVerificationRequired('place', { type: 'page', id: 'p' as EntityId }), true);
  assert.equal(identityVerificationRequired('unknown_type' as ContentTypeId, user), true);
});

void test('a plain User (no Creator role, no verification) may author free personal content', async () => {
  const { repository } = await plainUser();
  const eligibility = new IdentityPublisherEligibility(repository);
  for (const typeId of freePersonalContentTypes) {
    const result = await eligibility.evaluate(request(typeId));
    assert.equal(result.eligible, true, typeId);
    assert.equal(result.reason, 'eligible');
  }
});

void test('risky types still need the verification fact for the personal publisher', async () => {
  const { repository } = await plainUser();
  const eligibility = new IdentityPublisherEligibility(repository);
  for (const typeId of [
    'event',
    'rental',
    'session',
    'class_workshop',
    'find_people',
  ] as ContentTypeId[]) {
    const result = await eligibility.evaluate(request(typeId));
    assert.equal(result.eligible, false, typeId);
    assert.equal(result.reason, 'creator_verification_required', typeId);
  }
});

void test('a verified User may author risky types (no Creator role consulted)', async () => {
  const local = await plainUser();
  await local.authority.creatorVerification.submit({
    userId: ids.user1,
    verificationId: ids.verification1,
    evidenceRefIds: [ids.evidence1],
    nowUtc: '2026-09-22T00:00:03.000Z',
  });
  await local.authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: ids.user1,
    status: 'verified',
    nowUtc: '2026-09-22T00:00:04.000Z',
  });
  await local.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:04.500Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:04.500Z',
  });
  const eligibility = new IdentityPublisherEligibility(local.repository);
  const event = await eligibility.evaluate({
    ...request('event', ids.user1, ids.session2),
    nowUtc: '2026-09-22T00:00:05.000Z',
  });
  assert.equal(event.eligible, true);
});

void test('the free path never weakens identity: other user, no session, inactive account', async () => {
  const { repository } = await plainUser();
  const eligibility = new IdentityPublisherEligibility(repository);
  assert.equal(
    (await eligibility.evaluate(request('place', ids.user2))).reason,
    'publisher_not_accessible',
  );
  assert.equal(
    (await eligibility.evaluate(request('place', ids.user1, ids.session2))).reason,
    'account_inactive',
  );
  await repository.transact(async (transaction) => {
    const account = await transaction.account(ids.user1);
    assert.ok(account !== null);
    transaction.putAccount({ ...account, status: 'suspended' } as never);
  });
  const suspended = await eligibility.evaluate(request('place'));
  assert.equal(suspended.eligible, false);
});

void test('Media upload authority follows the same rule: a plain User may upload for themself', async () => {
  const { repository } = await plainUser();
  const media = new IdentityMediaActorAuthority(repository, new Set(['LV']));
  const own = await media.evaluate({
    actor: { userId: ids.user1 as never, sessionId: ids.session1 as never },
    action: 'upload',
    marketId: 'LV',
    family: 'image',
    publisherRef: { type: 'user', id: ids.user1 },
    nowUtc: now,
  } as never);
  assert.equal(own.allowed, true);
  const other = await media.evaluate({
    actor: { userId: ids.user1 as never, sessionId: ids.session1 as never },
    action: 'upload',
    marketId: 'LV',
    family: 'image',
    publisherRef: { type: 'user', id: ids.user2 },
    nowUtc: now,
  } as never);
  assert.equal(other.allowed, false);
});
