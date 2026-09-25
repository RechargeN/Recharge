import { randomBytes } from 'node:crypto';
import { advanceRevocationFence } from '../domain/account.js';
import { createAccessSnapshot, type AccessSnapshot } from '../domain/access_snapshot.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import {
  assertCurrentSession,
  changeSessionStatus,
  createSession,
  type IdentitySession,
  hashSessionHandle,
} from '../domain/session.js';

export class SessionAuthorityService {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly issueOpaqueHandle: () => string = () => randomBytes(32).toString('base64url'),
  ) {}

  issue(input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly issuedAtUtc: string;
    readonly firebaseUid: string;
    readonly installationId: string;
    readonly snapshotExpiresAtUtc: string;
    readonly capabilityPolicyRevision?: number;
  }): Promise<{
    readonly session: IdentitySession;
    readonly accessSnapshot: AccessSnapshot;
    readonly sessionHandle: string;
  }> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      if ((await transaction.session(input.sessionId)) !== null)
        throw new IdentityFailure('revision_conflict');
      let sessionHandle = '';
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const candidate = this.issueOpaqueHandle();
        if ((await transaction.sessionByHandleHash(hashSessionHandle(candidate))) === null) {
          sessionHandle = candidate;
          break;
        }
      }
      if (sessionHandle.length === 0) throw new IdentityFailure('temporarily_unavailable');
      const session = createSession({
        sessionId: input.sessionId,
        userId: input.userId,
        issuedAtUtc: input.issuedAtUtc,
        authzRevision: account.securityRevision,
        firebaseUid: input.firebaseUid,
        installationId: input.installationId,
        sessionHandle,
      });
      const accessSnapshot = createAccessSnapshot({
        account,
        session,
        personalCapabilityIds: ['booking.self_service'],
        capabilityPolicyRevision: input.capabilityPolicyRevision ?? 1,
        evaluatedAtUtc: input.issuedAtUtc,
        expiresAtUtc: input.snapshotExpiresAtUtc,
      });
      transaction.putSession(session);
      transaction.putAccessSnapshot(accessSnapshot);
      return Object.freeze({ session, accessSnapshot, sessionHandle });
    });
  }

  revoke(input: {
    readonly actorUserId: string;
    readonly sessionId: string;
    readonly nowUtc: string;
  }): Promise<void> {
    return this.repository.transact(async (transaction) => {
      const session = await transaction.session(input.sessionId);
      if (session === null || session.userId !== input.actorUserId)
        throw new IdentityFailure('not_found_or_not_accessible');
      if (session.status === 'revoked') return;
      transaction.putSession(changeSessionStatus(session, 'revoked', input.nowUtc));
    });
  }

  logoutAll(input: {
    readonly actorUserId: string;
    readonly currentSessionId: string;
    readonly nowUtc: string;
  }): Promise<void> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.actorUserId);
      const current = await transaction.session(input.currentSessionId);
      if (account === null || current === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(current, account);
      const sessions = await transaction.sessionsForUser(input.actorUserId);
      transaction.putAccount(advanceRevocationFence(account, input.nowUtc));
      for (const session of sessions) {
        if (session.status === 'active' || session.status === 'stepUpRequired')
          transaction.putSession(changeSessionStatus(session, 'revoked', input.nowUtc));
      }
    });
  }

  getCurrent(userId: string, sessionId: string): Promise<IdentitySession> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(userId);
      const session = await transaction.session(sessionId);
      if (account === null || session === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account);
      return session;
    });
  }
}
