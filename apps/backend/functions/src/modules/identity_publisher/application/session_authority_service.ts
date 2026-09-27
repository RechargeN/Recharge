import { randomBytes } from 'node:crypto';
import { advanceRevocationFence } from '../domain/account.js';
import { createAccessSnapshot, type AccessSnapshot } from '../domain/access_snapshot.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import {
  assertCurrentSession,
  changeSessionStatus,
  createSession,
  isLiveSession,
  type IdentitySession,
  hashSessionHandle,
  rotateSessionHandle,
} from '../domain/session.js';
import { maximumActiveSessions } from '../../../security/abuse_policy.js';

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
      const sessions = await transaction.sessionsForUser(input.userId);
      const activeSessions = sessions.filter((session) =>
        isLiveSession(session, input.issuedAtUtc),
      );
      const replaced = activeSessions.filter(
        (session) => session.installationId === input.installationId,
      );
      const otherActiveSessions = activeSessions.filter(
        (session) => session.installationId !== input.installationId,
      );
      if (otherActiveSessions.length >= maximumActiveSessions) {
        throw new IdentityFailure('session_limit_reached');
      }
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
      for (const previous of replaced) {
        transaction.putSession(
          changeSessionStatus(previous, 'revoked', input.issuedAtUtc, 'replaced'),
        );
      }
      for (const expired of sessions.filter(
        (candidate) =>
          (candidate.status === 'active' || candidate.status === 'stepUpRequired') &&
          !isLiveSession(candidate, input.issuedAtUtc) &&
          !replaced.some((previous) => previous.sessionId === candidate.sessionId),
      )) {
        transaction.putSession(changeSessionStatus(expired, 'expired', input.issuedAtUtc));
      }
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

  rotate(input: {
    readonly sessionId: string;
    readonly installationId: string;
    readonly firebaseUid: string;
    readonly sessionHandle: string;
    readonly nowUtc: string;
    readonly snapshotExpiresAtUtc: string;
  }): Promise<{
    readonly session: IdentitySession;
    readonly accessSnapshot: AccessSnapshot;
    readonly sessionHandle: string;
  }> {
    return this.repository.transact(async (transaction) => {
      const current = await transaction.session(input.sessionId);
      const account = current === null ? null : await transaction.account(current.userId);
      const snapshot = await transaction.accessSnapshot(input.sessionId);
      if (account === null || current === null || snapshot === null) {
        throw new IdentityFailure('unauthenticated');
      }
      assertCurrentSession(current, account, input.nowUtc);
      if (
        current.installationId !== input.installationId ||
        current.firebaseUid !== input.firebaseUid ||
        current.handleHash !== hashSessionHandle(input.sessionHandle)
      ) {
        throw new IdentityFailure('not_found_or_not_accessible');
      }
      let sessionHandle = '';
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const candidate = this.issueOpaqueHandle();
        if ((await transaction.sessionByHandleHash(hashSessionHandle(candidate))) === null) {
          sessionHandle = candidate;
          break;
        }
      }
      if (sessionHandle.length === 0) throw new IdentityFailure('temporarily_unavailable');
      const session = rotateSessionHandle(current, sessionHandle, input.nowUtc);
      const accessSnapshot = Object.freeze({
        ...snapshot,
        accountRevision: account.revision,
        sessionRevision: session.revision,
        authzRevision: session.authzRevision,
        evaluatedAtUtc: input.nowUtc,
        expiresAtUtc: input.snapshotExpiresAtUtc,
      }) as AccessSnapshot;
      transaction.putSession(session);
      transaction.putAccessSnapshot(accessSnapshot);
      return Object.freeze({ session, accessSnapshot, sessionHandle });
    });
  }

  resolveSessionOwner(input: {
    readonly sessionId: string;
    readonly sessionHandle: string;
    readonly firebaseUid: string;
    readonly installationId: string;
    readonly nowUtc: string;
  }): Promise<string> {
    return this.repository.transact(async (transaction) => {
      const session = await transaction.session(input.sessionId);
      if (session === null) throw new IdentityFailure('unauthenticated');
      const account = await transaction.account(session.userId);
      if (account === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account, input.nowUtc);
      if (
        session.handleHash !== hashSessionHandle(input.sessionHandle) ||
        session.firebaseUid !== input.firebaseUid ||
        session.installationId !== input.installationId
      ) {
        throw new IdentityFailure('unauthenticated');
      }
      return session.userId;
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
      assertCurrentSession(current, account, input.nowUtc);
      const sessions = await transaction.sessionsForUser(input.actorUserId);
      transaction.putAccount(advanceRevocationFence(account, input.nowUtc));
      for (const session of sessions) {
        if (session.status === 'active' || session.status === 'stepUpRequired')
          transaction.putSession(
            changeSessionStatus(session, 'revoked', input.nowUtc, 'logoutAll'),
          );
      }
    });
  }

  getCurrent(userId: string, sessionId: string, nowUtc?: string): Promise<IdentitySession> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(userId);
      const session = await transaction.session(sessionId);
      if (account === null || session === null) throw new IdentityFailure('unauthenticated');
      assertCurrentSession(session, account, nowUtc ?? session.lastActiveAtUtc);
      return session;
    });
  }

  recover(input: {
    readonly userId: string;
    readonly sessionId: string;
    readonly firebaseUid: string;
    readonly installationId: string;
    readonly nowUtc: string;
    readonly snapshotExpiresAtUtc: string;
  }): Promise<{
    readonly session: IdentitySession;
    readonly accessSnapshot: AccessSnapshot;
    readonly sessionHandle: string;
  }> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      const sessions = await transaction.sessionsForUser(input.userId);
      if (account === null || account.status !== 'active') {
        throw new IdentityFailure('account_blocked');
      }
      if ((await transaction.session(input.sessionId)) !== null) {
        throw new IdentityFailure('revision_conflict');
      }
      const nextAccount = advanceRevocationFence(account, input.nowUtc);
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
        issuedAtUtc: input.nowUtc,
        authzRevision: nextAccount.securityRevision,
        firebaseUid: input.firebaseUid,
        installationId: input.installationId,
        sessionHandle,
      });
      const accessSnapshot = createAccessSnapshot({
        account: nextAccount,
        session,
        personalCapabilityIds: ['booking.self_service'],
        capabilityPolicyRevision: 1,
        evaluatedAtUtc: input.nowUtc,
        expiresAtUtc: input.snapshotExpiresAtUtc,
      });
      transaction.putAccount(nextAccount);
      for (const previous of sessions) {
        if (previous.status === 'active' || previous.status === 'stepUpRequired') {
          transaction.putSession(
            changeSessionStatus(previous, 'revoked', input.nowUtc, 'recovery'),
          );
        }
      }
      transaction.putSession(session);
      transaction.putAccessSnapshot(accessSnapshot);
      return Object.freeze({ session, accessSnapshot, sessionHandle });
    });
  }
}
