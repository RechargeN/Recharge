import {
  createAccessSnapshot,
  isAccessSnapshotFresh,
  type AccessSnapshot,
} from '../domain/access_snapshot.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import { assertCurrentSession } from '../domain/session.js';

export class AccessSnapshotService {
  constructor(private readonly repository: IdentityAuthorityRepository) {}

  create(input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly pageId?: string;
    readonly capabilityPolicyRevision: number;
    readonly evaluatedAtUtc: string;
    readonly expiresAtUtc: string;
  }): Promise<AccessSnapshot> {
    if (Date.parse(input.expiresAtUtc) <= Date.parse(input.evaluatedAtUtc))
      throw new TypeError('snapshot_expiry_invalid');
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      const session = await transaction.session(input.sessionId);
      if (account === null || session === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account);
      const verification = await transaction.verificationForUser(input.userId);
      const personalCapabilityIds =
        verification?.status === 'verified' && account.systemRoles.includes('Creator')
          ? ['booking.self_service', 'content.create', 'content.submit', 'content.publish']
          : ['booking.self_service'];
      const membership =
        input.pageId === undefined
          ? undefined
          : await transaction.membership(input.pageId, input.userId);
      if (input.pageId !== undefined && membership?.status !== 'active')
        throw new IdentityFailure('membership_inactive');
      const snapshot = createAccessSnapshot({
        account,
        session,
        ...(membership === undefined || membership === null ? {} : { membership }),
        personalCapabilityIds,
        capabilityPolicyRevision: input.capabilityPolicyRevision,
        evaluatedAtUtc: input.evaluatedAtUtc,
        expiresAtUtc: input.expiresAtUtc,
      });
      transaction.putAccessSnapshot(snapshot);
      return snapshot;
    });
  }

  assertFresh(snapshot: AccessSnapshot, nowUtc: string): Promise<void> {
    if (!isAccessSnapshotFresh(snapshot, nowUtc))
      return Promise.reject(new IdentityFailure('snapshot_stale'));
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(snapshot.userId);
      const session = await transaction.session(snapshot.sessionId);
      if (account === null || session === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account);
      if (
        account.revision !== snapshot.accountRevision ||
        session.revision !== snapshot.sessionRevision ||
        session.authzRevision !== snapshot.authzRevision
      )
        throw new IdentityFailure('snapshot_stale');
      if (snapshot.pageId !== undefined) {
        const membership = await transaction.membership(snapshot.pageId, snapshot.userId);
        if (membership?.status !== 'active' || membership.revision !== snapshot.membershipRevision)
          throw new IdentityFailure('snapshot_stale');
      }
    });
  }
}
