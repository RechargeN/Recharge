import assert from 'node:assert/strict';
import test from 'node:test';

import type { ContentTypeId } from '../../../src/contracts/content_v1.js';
import { createLocalIdentityPublisherAuthority } from '../../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import {
  contentCommerce,
  type ContentCommerce,
} from '../../../src/modules/content/domain/personal_publishing_policy.js';
import { IdentityPublisherEligibility } from '../../../src/modules/content/infrastructure/identity_publisher_eligibility.js';
import { IdentityMediaActorAuthority } from '../../../src/modules/media/infrastructure/identity_media_authority.js';
import { ClosedPayoutReadiness } from '../../../src/modules/identity_publisher/infrastructure/closed_payout_readiness.js';
import type { EntityId } from '../../../src/shared/ids.js';
import type { MarketId } from '../../../src/modules/reference_data/domain/identifiers.js';

// ADR 0023 (User = Creator; owner decision 2026-11-08, marketplace rule, DSA
// Art. 30): free content publishes freely; paid or bookable content needs the
// author's seller declaration; a trader selling inside the app, or any author
// under a fraud step-up, also needs identity verification. No Creator role.

const allTypes: ContentTypeId[] = [
  'place',
  'activity',
  'collection',
  'route',
  'scenario',
  'event',
  'rental',
  'session',
  'class_workshop',
  'find_people',
];

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
type Local = Awaited<ReturnType<typeof plainUser>>;

const request = (
  typeId: ContentTypeId,
  publisherId: string = ids.user1,
  sessionId: string = ids.session1,
  commerce?: ContentCommerce,
) => ({
  ...(commerce === undefined ? {} : { commerce }),
  actor: { userId: ids.user1 as EntityId, sessionId: sessionId as EntityId },
  publisherRef: { type: 'user' as const, id: publisherId as EntityId },
  typeId,
  action: 'create' as const,
  marketId: 'LV' as MarketId,
  requiredCapability: 'content.create',
  nowUtc: now,
});

const privateSeller = {
  status: 'private',
  contact: { email: 'seller@example.com' },
  dac7ActivityTypes: [],
};
const traderSeller = {
  status: 'trader',
  contact: { phone: '+37120000000' },
  trader: {
    legalName: 'Example SIA',
    registrationNumber: '40003000000',
    address: { line1: 'Brivibas iela 1', city: 'Riga', postalCode: 'LV-1010', countryCode: 'LV' },
  },
  dac7ActivityTypes: ['personalServices'],
};

async function declare(local: Local, body: unknown, expectedRevision = 0) {
  await local.authority.sellers.declare({
    userId: ids.user1,
    body,
    expectedRevision,
    nowUtc: '2026-09-22T00:00:01.500Z',
  });
}

/** Verified, with a fresh Session (session2) after the security revision moved. */
async function verify(local: Local) {
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
}

void test('commerce per type: what is sold or booked, and where', () => {
  const commerce = (typeId: string, body: Record<string, unknown>) =>
    contentCommerce(typeId as ContentTypeId, body);
  for (const typeId of ['place', 'activity', 'route', 'scenario', 'collection'])
    assert.equal(commerce(typeId, { pricing: { entryType: 'paid' } }), 'none', typeId);
  assert.equal(commerce('rental', {}), 'external');
  assert.equal(commerce('session', {}), 'external');
  assert.equal(commerce('event', { pricing: { mode: 'free' } }), 'none');
  // Free internal registration takes no money and concludes no sale (owner, 2026-11-08).
  assert.equal(
    commerce('event', { pricing: { mode: 'free' }, registration: { mode: 'internal' } }),
    'none',
  );
  assert.equal(
    commerce('event', { pricing: { mode: 'fixed', paymentCollectionMode: 'external' } }),
    'external',
  );
  assert.equal(
    commerce('event', { pricing: { mode: 'fixed', paymentCollectionMode: 'internal' } }),
    'inApp',
  );
  assert.equal(commerce('event', {}), 'external');
  assert.equal(commerce('class_workshop', { class_workshop: { price: { mode: 'free' } } }), 'none');
  assert.equal(
    commerce('class_workshop', { class_workshop: { price: { mode: 'fixed' } } }),
    'external',
  );
  assert.equal(commerce('find_people', { findPeople: { cost: { costType: 'free' } } }), 'none');
  assert.equal(
    commerce('find_people', { findPeople: { cost: { costType: 'estimated' } } }),
    'external',
  );
  assert.equal(commerce('unknown_type', {}), 'inApp');
});

void test('a plain User authors every type; drafts and free content need nothing', async () => {
  const { repository } = await plainUser();
  const eligibility = new IdentityPublisherEligibility(repository);
  for (const typeId of allTypes) {
    assert.equal((await eligibility.evaluate(request(typeId))).reason, 'eligible', typeId);
    const free = await eligibility.evaluate(request(typeId, ids.user1, ids.session1, 'none'));
    assert.equal(free.reason, 'eligible', typeId);
  }
});

void test('paid or bookable content needs the seller declaration (DSA Art. 30)', async () => {
  const local = await plainUser();
  const eligibility = new IdentityPublisherEligibility(local.repository);
  for (const commerce of ['external', 'inApp'] as const)
    assert.equal(
      (await eligibility.evaluate(request('event', ids.user1, ids.session1, commerce))).reason,
      'seller_declaration_required',
      commerce,
    );
  await declare(local, privateSeller);
  // A private seller: the declaration is enough, also inside the app.
  for (const commerce of ['external', 'inApp'] as const)
    assert.equal(
      (await eligibility.evaluate(request('event', ids.user1, ids.session1, commerce))).reason,
      'eligible',
      commerce,
    );
});

void test('a trader selling in the app is verified before sales start; outside, the declaration is enough', async () => {
  const local = await plainUser();
  await declare(local, traderSeller);
  const eligibility = new IdentityPublisherEligibility(local.repository);
  assert.equal(
    (await eligibility.evaluate(request('event', ids.user1, ids.session1, 'external'))).reason,
    'eligible',
  );
  assert.equal(
    (await eligibility.evaluate(request('event', ids.user1, ids.session1, 'inApp'))).reason,
    'identity_verification_required',
  );
  await verify(local);
  const verified = await eligibility.evaluate({
    ...request('event', ids.user1, ids.session2, 'inApp'),
    nowUtc: '2026-09-22T00:00:05.000Z',
  });
  assert.equal(verified.reason, 'eligible');
});

void test('suspected fraud: a step-up makes any paid or bookable publication need verification', async () => {
  const local = await plainUser();
  await declare(local, privateSeller);
  await local.authority.sellers.setStepUpRequired({
    reviewerId: 'reviewer',
    userId: ids.user1,
    required: true,
    nowUtc: '2026-09-22T00:00:02.500Z',
  });
  // The security revision moved: the old Session is stale, a new one is issued.
  await local.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:02.600Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:02.600Z',
  });
  const eligibility = new IdentityPublisherEligibility(local.repository);
  assert.equal(
    (await eligibility.evaluate(request('event', ids.user1, ids.session2, 'external'))).reason,
    'identity_verification_required',
  );
  assert.equal(
    (await eligibility.evaluate(request('place', ids.user1, ids.session2, 'none'))).reason,
    'eligible',
  );
  await assert.rejects(
    local.authority.sellers.setStepUpRequired({
      reviewerId: 'not-a-reviewer',
      userId: ids.user1,
      required: false,
      nowUtc: '2026-09-22T00:00:03.000Z',
    }),
  );
});

void test('declarations are validated and revisioned; a private seller carries no trader data', async () => {
  const local = await plainUser();
  await assert.rejects(declare(local, { ...privateSeller, trader: traderSeller.trader }));
  await assert.rejects(declare(local, { ...traderSeller, trader: undefined }));
  await assert.rejects(declare(local, { ...privateSeller, contact: {} }));
  await assert.rejects(declare(local, { ...privateSeller, contact: { phone: '20000000' } }));
  await declare(local, traderSeller);
  // A stale revision is refused, never written over.
  await assert.rejects(declare(local, privateSeller));
  const stored = await local.authority.sellers.read(ids.user1);
  assert.equal(stored?.revision, 1);
  assert.equal(stored?.declaration.status, 'trader');
  await declare(local, privateSeller, 1);
  assert.equal((await local.authority.sellers.read(ids.user1))?.declaration.trader, undefined);
});

void test('no payout before the payment provider KYC/KYB (none is connected)', async () => {
  assert.deepEqual(await new ClosedPayoutReadiness().readinessFor(), {
    ready: false,
    reason: 'payment_provider_not_connected',
  });
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
