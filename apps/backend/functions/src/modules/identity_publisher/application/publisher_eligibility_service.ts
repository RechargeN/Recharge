import type { PublisherEligibilityV1 } from '../../../contracts/identity_v1.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import type { AccessSnapshot } from '../domain/access_snapshot.js';
import { createPublisherRef, type PublisherRef } from '../domain/publisher_ref.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import { AccessSnapshotService } from './access_snapshot_service.js';

export class PublisherEligibilityService {
  readonly #snapshots: AccessSnapshotService;

  constructor(private readonly repository: IdentityAuthorityRepository) {
    this.#snapshots = new AccessSnapshotService(repository);
  }

  async evaluate(input: {
    readonly snapshot: AccessSnapshot;
    readonly requestedPublisher: PublisherRef;
    readonly requiredCapability: string;
    readonly nowUtc: string;
  }): Promise<PublisherEligibilityV1> {
    try {
      await this.#snapshots.assertFresh(input.snapshot, input.nowUtc);
    } catch {
      return result(
        input.requestedPublisher,
        false,
        'snapshot_stale',
        input.snapshot.authzRevision,
        input.nowUtc,
      );
    }
    return this.repository.transact((transaction) => {
      const account = transaction.account(input.snapshot.userId);
      if (account?.status !== 'active')
        return result(
          input.requestedPublisher,
          false,
          'account_inactive',
          input.snapshot.authzRevision,
          input.nowUtc,
        );
      const verification = transaction.verificationForUser(input.snapshot.userId);
      if (verification?.status !== 'verified' || !account.systemRoles.includes('Creator'))
        return result(
          input.requestedPublisher,
          false,
          'creator_verification_required',
          account.securityRevision,
          input.nowUtc,
        );
      if (input.requestedPublisher.type === 'user') {
        if (input.requestedPublisher.id !== input.snapshot.userId)
          return result(
            input.requestedPublisher,
            false,
            'publisher_not_accessible',
            account.securityRevision,
            input.nowUtc,
          );
        if (!input.snapshot.capabilityIds.includes(input.requiredCapability))
          return result(
            input.requestedPublisher,
            false,
            'capability_denied',
            account.securityRevision,
            input.nowUtc,
          );
        return result(
          input.requestedPublisher,
          true,
          'eligible',
          account.securityRevision,
          input.nowUtc,
        );
      }
      if (input.snapshot.pageId !== input.requestedPublisher.id)
        return result(
          input.requestedPublisher,
          false,
          'publisher_not_accessible',
          account.securityRevision,
          input.nowUtc,
        );
      const membership = transaction.membership(input.requestedPublisher.id, input.snapshot.userId);
      const page = transaction.page(input.requestedPublisher.id);
      if (membership?.status !== 'active')
        return result(
          input.requestedPublisher,
          false,
          'membership_inactive',
          account.securityRevision,
          input.nowUtc,
        );
      if (page?.status !== 'active' || page.verificationStatus !== 'verified')
        return result(
          input.requestedPublisher,
          false,
          'publisher_not_accessible',
          account.securityRevision,
          input.nowUtc,
        );
      if (!membership.capabilityIds.includes(input.requiredCapability))
        return result(
          input.requestedPublisher,
          false,
          'capability_denied',
          account.securityRevision,
          input.nowUtc,
        );
      return result(
        input.requestedPublisher,
        true,
        'eligible',
        account.securityRevision,
        input.nowUtc,
      );
    });
  }

  personalRef(userId: string): PublisherRef {
    return createPublisherRef('user', userId);
  }

  pageRef(pageId: string): PublisherRef {
    return createPublisherRef('page', pageId);
  }
}

function result(
  publisherRef: PublisherRef,
  eligible: boolean,
  reason: PublisherEligibilityV1['reason'],
  authorityRevision: number,
  nowUtc: string,
): PublisherEligibilityV1 {
  return Object.freeze({
    schemaVersion: 1,
    publisherRef,
    eligible,
    reason,
    authorityRevision,
    evaluatedAtUtc: parseUtcInstant(nowUtc),
  });
}
