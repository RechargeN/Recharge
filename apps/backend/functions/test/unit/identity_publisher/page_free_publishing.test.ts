import assert from 'node:assert/strict';
import test from 'node:test';

import { createLocalIdentityPublisherAuthority } from '../../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { IdentityPublisherEligibility } from '../../../src/modules/content/infrastructure/identity_publisher_eligibility.js';
import type { ContentCommerce } from '../../../src/modules/content/domain/personal_publishing_policy.js';
import type { EntityId } from '../../../src/shared/ids.js';
import type { MarketId } from '../../../src/modules/reference_data/domain/identifiers.js';

// Owner 2026-11-23, variant A (ADR 0023 amendment): free content from a
// Professional Page needs neither a verified Page nor a verified User, as on
// Facebook or LinkedIn pages. Identity is the Google (later Apple) sign-in.
// Paid or bookable content from a Page needs the verified Page and the seller
// declaration; a trader selling inside the app also needs provider KYC.
// Membership, an active Page and the capability are always checked.

const ids = {
  user1: '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
  user2: '018FQ2Z8Q9N4M7K2T6V3W1X5YB',
  identity1: '018FQ2Z8Q9N4M7K2T6V3W1X5YC',
  identity2: '018FQ2Z8Q9N4M7K2T6V3W1X5YD',
  session1: '018FQ2Z8Q9N4M7K2T6V3W1X5YE',
  session2: '018FQ2Z8Q9N4M7K2T6V3W1X5YF',
  session3: '018FQ2Z8Q9N4M7K2T6V3W1X5YJ',
  page1: '018FQ2Z8Q9N4M7K2T6V3W1X5YK',
  membership1: '018FQ2Z8Q9N4M7K2T6V3W1X5YM',
} as const;
const now = '2026-09-22T00:00:20.000Z';

async function userWithPage() {
  const local = createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 3,
  });
  for (const [userId, identityId, sessionId, subject] of [
    [ids.user1, ids.identity1, ids.session1, 'subject-1'],
    [ids.user2, ids.identity2, ids.session3, 'subject-2'],
  ] as const) {
    await local.authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'consumer',
        proof: `local-test:google:${subject}`,
      },
      proposedUserId: userId,
      proposedIdentityId: identityId,
      nowUtc: '2026-09-22T00:00:00.000Z',
      accountCreationEnabled: true,
    });
    await local.authority.sessions.issue({
      userId,
      sessionId,
      issuedAtUtc: '2026-09-22T00:00:01.000Z',
      firebaseUid: userId,
      installationId: `install-${subject}`,
      snapshotExpiresAtUtc: '2026-09-22T00:05:01.000Z',
    });
  }
  // An unverified User creates the Page (variant A).
  await local.authority.pages.create({
    userId: ids.user1,
    pageId: ids.page1,
    membershipId: ids.membership1,
    marketId: 'LV',
    nowUtc: '2026-09-22T00:00:02.000Z',
  });
  return local;
}
type Local = Awaited<ReturnType<typeof userWithPage>>;

const fromPage = (
  commerce: ContentCommerce,
  userId: string = ids.user1,
  sessionId: string = ids.session1,
) => ({
  commerce,
  actor: { userId: userId as EntityId, sessionId: sessionId as EntityId },
  publisherRef: { type: 'page' as const, id: ids.page1 as EntityId },
  typeId: 'event' as const,
  action: 'create' as const,
  marketId: 'LV' as MarketId,
  requiredCapability: 'content.create',
  nowUtc: now,
});

async function verifyPage(local: Local) {
  await local.authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: ids.page1,
    decision: 'verified',
    nowUtc: '2026-09-22T00:00:05.000Z',
  });
  // The security revision may move: a fresh Session.
  await local.authority.sessions.issue({
    userId: ids.user1,
    sessionId: ids.session2,
    issuedAtUtc: '2026-09-22T00:00:06.000Z',
    firebaseUid: ids.user1,
    installationId: 'install-2',
    snapshotExpiresAtUtc: '2026-09-22T00:05:06.000Z',
  });
}

async function declare(local: Local, status: 'private' | 'trader', revisionHint: number) {
  void revisionHint;
  await local.authority.sellers.declare({
    userId: ids.user1,
    body:
      status === 'private'
        ? { status: 'private', contact: { email: 'seller@example.com' }, dac7ActivityTypes: [] }
        : {
            status: 'trader',
            contact: { phone: '+37120000000' },
            trader: {
              legalName: 'Example SIA',
              registrationNumber: '40003000000',
              address: {
                line1: 'Brivibas iela 1',
                city: 'Riga',
                postalCode: 'LV-1010',
                countryCode: 'LV',
              },
            },
            dac7ActivityTypes: ['personalServices'],
          },
    expectedRevision: 0,
    nowUtc: '2026-09-22T00:00:06.500Z',
  });
}

void test('an unverified User publishes free content from an unverified Page', async () => {
  const local = await userWithPage();
  const eligibility = new IdentityPublisherEligibility(local.repository);
  assert.equal((await eligibility.evaluate(fromPage('none'))).reason, 'eligible');
});

// Owner 2026-11-23 scheme: a paid Page publication needs the verified Page and
// the seller declaration; a trader selling inside the app also needs the
// payment provider's KYC (none connected yet).
void test('paid or bookable content from a Page needs the verified Page and the declaration', async () => {
  const local = await userWithPage();
  const eligibility = new IdentityPublisherEligibility(local.repository);
  for (const commerce of ['external', 'inApp'] as const)
    assert.equal(
      (await eligibility.evaluate(fromPage(commerce))).reason,
      'publisher_not_accessible',
      `unverified Page, ${commerce}`,
    );
  await verifyPage(local);
  assert.equal(
    (await eligibility.evaluate(fromPage('external', ids.user1, ids.session2))).reason,
    'seller_declaration_required',
  );
  await declare(local, 'private', 2);
  for (const commerce of ['external', 'inApp'] as const)
    assert.equal(
      (await eligibility.evaluate(fromPage(commerce, ids.user1, ids.session2))).reason,
      'eligible',
      `private seller, ${commerce}`,
    );
});

void test('a trader Page selling inside the app needs provider KYC (none connected)', async () => {
  const local = await userWithPage();
  await verifyPage(local);
  await declare(local, 'trader', 2);
  const eligibility = new IdentityPublisherEligibility(local.repository);
  assert.equal(
    (await eligibility.evaluate(fromPage('external', ids.user1, ids.session2))).reason,
    'eligible',
  );
  assert.equal(
    (await eligibility.evaluate(fromPage('inApp', ids.user1, ids.session2))).reason,
    'identity_verification_required',
  );
});

void test('a User outside the Page cannot publish from it, even free', async () => {
  const local = await userWithPage();
  const eligibility = new IdentityPublisherEligibility(local.repository);
  assert.equal(
    (await eligibility.evaluate(fromPage('none', ids.user2, ids.session3))).reason,
    'membership_inactive',
  );
});

void test('the Page snapshot offers an unverified Page as a free publisher', async () => {
  const local = await userWithPage();
  const snapshot = await local.authority.access.create({
    userId: ids.user1,
    sessionId: ids.session1,
    pageId: ids.page1,
    capabilityPolicyRevision: 1,
    evaluatedAtUtc: '2026-09-22T00:00:07.000Z',
    expiresAtUtc: '2026-09-22T00:05:07.000Z',
  });
  const decision = await local.authority.publishers.evaluate({
    snapshot,
    requestedPublisher: local.authority.publishers.pageRef(ids.page1),
    requiredCapability: 'content.publish',
    nowUtc: '2026-09-22T00:00:08.000Z',
  });
  assert.equal(decision.reason, 'eligible');
});
