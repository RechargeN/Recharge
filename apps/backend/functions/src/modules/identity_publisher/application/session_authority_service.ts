import { advanceRevocationFence } from '../domain/account.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import {
  assertCurrentSession,
  changeSessionStatus,
  createSession,
  type IdentitySession,
} from '../domain/session.js';

export class SessionAuthorityService {
  constructor(private readonly repository: IdentityAuthorityRepository) {}

  issue(input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly issuedAtUtc: string;
  }): Promise<IdentitySession> {
    return this.repository.transact((transaction) => {
      const account = transaction.account(input.userId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      if (Date.parse(input.issuedAtUtc) <= Date.parse(account.revokeAllBeforeUtc))
        throw new IdentityFailure('session_revoked');
      if (transaction.session(input.sessionId) !== null)
        throw new IdentityFailure('revision_conflict');
      const session = createSession({
        sessionId: input.sessionId,
        userId: input.userId,
        issuedAtUtc: input.issuedAtUtc,
        authzRevision: account.securityRevision,
      });
      transaction.putSession(session);
      return session;
    });
  }

  revoke(input: {
    readonly actorUserId: string;
    readonly sessionId: string;
    readonly nowUtc: string;
  }): Promise<void> {
    return this.repository.transact((transaction) => {
      const session = transaction.session(input.sessionId);
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
    return this.repository.transact((transaction) => {
      const account = transaction.account(input.actorUserId);
      const current = transaction.session(input.currentSessionId);
      if (account === null || current === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(current, account);
      transaction.putAccount(advanceRevocationFence(account, input.nowUtc));
      for (const session of transaction.sessionsForUser(input.actorUserId)) {
        if (session.status === 'active' || session.status === 'stepUpRequired')
          transaction.putSession(changeSessionStatus(session, 'revoked', input.nowUtc));
      }
    });
  }

  getCurrent(userId: string, sessionId: string): Promise<IdentitySession> {
    return this.repository.transact((transaction) => {
      const account = transaction.account(userId);
      const session = transaction.session(sessionId);
      if (account === null || session === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account);
      return session;
    });
  }
}
