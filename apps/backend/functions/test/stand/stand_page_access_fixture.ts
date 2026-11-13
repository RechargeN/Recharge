import type { Firestore } from 'firebase-admin/firestore';

import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { standMaximumOwnedPages } from './stand_plan.js';
import { standLinkedUserId } from './stand_session_fixture.js';

/** The capabilities Content asks for on save, submit and publish. */
const contentCapabilities = Object.freeze(['content.create', 'content.submit', 'content.publish']);

const usage =
  'page-access withdraw-publish <label> <pageId> | restore-publish <label> <pageId> <capability,...> | suspend <pageId> | reverify <pageId> | status <label> <pageId>';

async function authorityFor(firestore: Firestore) {
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const staffId = await standLinkedUserId(firestore, 'staff');
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([staffId])),
    pagePolicy: new LocalPageCreationPolicy(true, standMaximumOwnedPages),
  });
  return { repository, authority, staffId };
}

async function readAccess(
  repository: FirestoreIdentityAuthorityRepository,
  pageId: string,
  userId: string,
) {
  const { membership, page } = await repository.transact(async (tx) => ({
    membership: await tx.membership(pageId, userId),
    page: await tx.page(pageId),
  }));
  if (membership === null || page === null) throw new Error(`no membership of page ${pageId}`);
  return Object.freeze({
    pageId,
    pageStatus: page.status,
    verificationStatus: page.verificationStatus,
    membershipStatus: membership.status,
    capabilityIds: [...membership.capabilityIds].sort(),
  });
}

/**
 * M1 stage 2: reversible Page access for client tests, only through the
 * existing Identity owner services (`setCapabilities` by the Page owner on its
 * own membership, `decidePage` by the stand staff reviewer). No direct write
 * and no new authority path. `withdraw-publish` prints the capabilities it
 * found; `restore-publish` puts back exactly that saved set, so the stand
 * returns to its seeded state.
 */
export async function runPageAccess(firestore: Firestore, args: readonly string[]) {
  const [action, ...rest] = args;
  const { repository, authority, staffId } = await authorityFor(firestore);
  const nowUtc = new Date().toISOString();
  if ((action === 'withdraw-publish' || action === 'status') && rest.length === 2) {
    const [label, pageId] = rest as [string, string];
    const userId = await standLinkedUserId(firestore, label);
    const before = await readAccess(repository, pageId, userId);
    if (action === 'status') return before;
    if (!contentCapabilities.every((id) => before.capabilityIds.includes(id)))
      throw new Error(`page ${pageId}: Content capabilities already withdrawn`);
    await authority.pages.setCapabilities({
      actorUserId: userId,
      pageId,
      targetUserId: userId,
      capabilityIds: before.capabilityIds.filter((id) => !contentCapabilities.includes(id)),
      nowUtc,
    });
    const after = await readAccess(repository, pageId, userId);
    return Object.freeze({ pageId, before: before.capabilityIds, after: after.capabilityIds });
  }
  if (action === 'restore-publish' && rest.length === 3) {
    const [label, pageId, saved] = rest as [string, string, string];
    const capabilityIds = saved.split(',').filter((id) => id.length > 0);
    if (!contentCapabilities.every((id) => capabilityIds.includes(id)))
      throw new Error('restore-publish needs the saved set with the Content capabilities');
    const userId = await standLinkedUserId(firestore, label);
    await authority.pages.setCapabilities({
      actorUserId: userId,
      pageId,
      targetUserId: userId,
      capabilityIds,
      nowUtc,
    });
    const after = await readAccess(repository, pageId, userId);
    return Object.freeze({ pageId, after: after.capabilityIds });
  }
  if ((action === 'suspend' || action === 'reverify') && rest.length === 1) {
    const [pageId] = rest as [string];
    const page = await authority.pages.decidePage({
      reviewerId: staffId,
      pageId,
      decision: action === 'suspend' ? 'suspended' : 'verified',
      nowUtc,
    });
    return Object.freeze({
      pageId,
      status: page.status,
      verificationStatus: page.verificationStatus,
    });
  }
  throw new Error(usage);
}
