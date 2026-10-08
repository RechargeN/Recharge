import type { Firestore } from 'firebase-admin/firestore';

import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { standMarketId, standMaximumOwnedPages } from './stand_plan.js';
import { standLinkedUserId } from './stand_session_fixture.js';

/**
 * E2 two-client fixture: the stand `viewer` becomes a second verified Creator
 * with its own Page, so both independent clients can go through Create. It is
 * not part of the A2 seed (the digest is unchanged); the E2 gate runs it on a
 * freshly reset stand, decided by the staff Account like the seed's Creator.
 */
export const standSecondCreator = Object.freeze({
  user: 'viewer',
  verificationId: '5d1e0000-0000-4000-8000-00000000c002',
  evidenceRefIds: Object.freeze(['5d1e0000-0000-4000-8000-00000000d002']),
  page: Object.freeze({
    label: 'workshop',
    pageId: '5d1e0000-0000-4000-8000-00000000a003',
    membershipId: '5d1e0000-0000-4000-8000-00000000b003',
  }),
});

/** Idempotent: a repeated run finds the verified Creator and its Page and changes nothing. */
export async function ensureSecondCreator(
  firestore: Firestore,
  nowUtc: string,
): Promise<{ readonly userId: string; readonly pageId: string; readonly created: boolean }> {
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const userId = await standLinkedUserId(firestore, standSecondCreator.user);
  const staffId = await standLinkedUserId(firestore, 'staff');
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([staffId])),
    pagePolicy: new LocalPageCreationPolicy(true, standMaximumOwnedPages),
  });
  const pageId = standSecondCreator.page.pageId;
  const before = await repository.transact(async (tx) => ({
    verification: await tx.verificationForUser(userId),
    page: await tx.page(pageId),
  }));
  let created = false;
  if (before.verification?.status !== 'verified') {
    if (before.verification === null)
      await authority.creatorVerification.submit({
        userId,
        verificationId: standSecondCreator.verificationId,
        evidenceRefIds: standSecondCreator.evidenceRefIds,
        nowUtc,
      });
    await authority.creatorVerification.decide({
      reviewerId: staffId,
      userId,
      status: 'verified',
      nowUtc,
    });
    created = true;
  }
  if (before.page === null) {
    await authority.pages.create({
      userId,
      pageId,
      membershipId: standSecondCreator.page.membershipId,
      marketId: standMarketId,
      nowUtc,
    });
    await authority.pages.decidePage({ reviewerId: staffId, pageId, decision: 'verified', nowUtc });
    created = true;
  }
  return { userId, pageId, created };
}
