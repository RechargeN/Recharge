import { IdentityFailure } from '../domain/failures.js';
import { createManagedPage, decideManagedPage, type ManagedPage } from '../domain/managed_page.js';
import {
  createOwnerMembership,
  revokeMembership,
  setMembershipCapabilities,
  type PageMembership,
} from '../domain/page_membership.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import type { PageCreationPolicyPort } from './ports/page_creation_policy_port.js';
import type { VerificationDecisionPort } from './ports/verification_decision_port.js';

export class ManagedPageService {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly pagePolicy: PageCreationPolicyPort,
    private readonly decisionPort: VerificationDecisionPort,
  ) {}

  async create(input: {
    readonly userId: string;
    readonly pageId: string;
    readonly membershipId: string;
    readonly marketId: string;
    readonly nowUtc: string;
  }): Promise<{ readonly page: ManagedPage; readonly membership: PageMembership }> {
    return this.repository.transact(async (transaction) => {
      const policy = await this.pagePolicy.evaluate({
        userId: input.userId,
        ownedPageCount: transaction.pagesForOwner(input.userId).length,
        marketId: input.marketId,
      });
      if (policy !== 'allowed') throw new IdentityFailure('policy_unavailable');
      const account = transaction.account(input.userId);
      const verification = transaction.verificationForUser(input.userId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      if (verification?.status !== 'verified')
        throw new IdentityFailure('creator_verification_required');
      if (transaction.page(input.pageId) !== null) throw new IdentityFailure('revision_conflict');
      const page = createManagedPage({
        pageId: input.pageId,
        ownerUserId: input.userId,
        marketId: input.marketId,
        nowUtc: input.nowUtc,
      });
      const membership = createOwnerMembership({
        membershipId: input.membershipId,
        pageId: input.pageId,
        userId: input.userId,
        nowUtc: input.nowUtc,
      });
      transaction.putPage(page);
      transaction.putMembership(membership);
      return { page, membership };
    });
  }

  async decidePage(input: {
    readonly reviewerId: string;
    readonly pageId: string;
    readonly decision: 'verified' | 'rejected' | 'suspended' | 'revoked';
    readonly nowUtc: string;
  }): Promise<ManagedPage> {
    if (!(await this.decisionPort.mayDecide(input.reviewerId)))
      throw new IdentityFailure('not_found_or_not_accessible');
    return this.repository.transact((transaction) => {
      const page = transaction.page(input.pageId);
      if (page === null) throw new IdentityFailure('not_found_or_not_accessible');
      const next = decideManagedPage(page, input.decision, input.nowUtc);
      transaction.putPage(next);
      return next;
    });
  }

  setCapabilities(input: {
    readonly actorUserId: string;
    readonly pageId: string;
    readonly targetUserId: string;
    readonly capabilityIds: readonly string[];
    readonly nowUtc: string;
  }): Promise<PageMembership> {
    return this.repository.transact((transaction) => {
      const actor = transaction.membership(input.pageId, input.actorUserId);
      const target = transaction.membership(input.pageId, input.targetUserId);
      if (
        actor?.status !== 'active' ||
        !actor.capabilityIds.includes('manage_page') ||
        target === null
      )
        throw new IdentityFailure('not_found_or_not_accessible');
      const next = setMembershipCapabilities(target, input.capabilityIds, input.nowUtc);
      transaction.putMembership(next);
      return next;
    });
  }

  revokeMembership(input: {
    readonly actorUserId: string;
    readonly pageId: string;
    readonly targetUserId: string;
    readonly nowUtc: string;
  }): Promise<void> {
    return this.repository.transact((transaction) => {
      const actor = transaction.membership(input.pageId, input.actorUserId);
      const target = transaction.membership(input.pageId, input.targetUserId);
      if (
        actor?.status !== 'active' ||
        !actor.capabilityIds.includes('manage_page') ||
        target === null
      )
        throw new IdentityFailure('not_found_or_not_accessible');
      transaction.putMembership(revokeMembership(target, input.nowUtc));
    });
  }
}
