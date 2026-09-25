import type {
  IdentityAuthorityRepository,
  IdentityAuthorityTransaction,
} from '../domain/repositories.js';
import type { Account } from '../domain/account.js';
import type { AuthIdentity } from '../domain/auth_identity.js';
import type { CreatorVerification } from '../domain/creator_verification.js';
import type { ManagedPage } from '../domain/managed_page.js';
import type { PageMembership } from '../domain/page_membership.js';
import type { IdentitySession } from '../domain/session.js';
import type { AccessSnapshot } from '../domain/access_snapshot.js';

interface Store {
  readonly accounts: Map<string, Account>;
  readonly identities: Map<string, AuthIdentity>;
  readonly sessions: Map<string, IdentitySession>;
  readonly accessSnapshots: Map<string, AccessSnapshot>;
  readonly verifications: Map<string, CreatorVerification>;
  readonly pages: Map<string, ManagedPage>;
  readonly memberships: Map<string, PageMembership>;
}

export class InMemoryIdentityAuthorityRepository implements IdentityAuthorityRepository {
  #store: Store = emptyStore();
  #tail: Promise<void> = Promise.resolve();

  async transact<T>(
    operation: (transaction: IdentityAuthorityTransaction) => T | Promise<T>,
  ): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.#tail;
    this.#tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    const working = cloneStore(this.#store);
    try {
      const result = await operation(transactionFor(working));
      this.#store = working;
      return result;
    } finally {
      release?.();
    }
  }
}

function emptyStore(): Store {
  return {
    accounts: new Map(),
    identities: new Map(),
    sessions: new Map(),
    accessSnapshots: new Map(),
    verifications: new Map(),
    pages: new Map(),
    memberships: new Map(),
  };
}

function cloneStore(source: Store): Store {
  return {
    accounts: new Map(source.accounts),
    identities: new Map(source.identities),
    sessions: new Map(source.sessions),
    accessSnapshots: new Map(source.accessSnapshots),
    verifications: new Map(source.verifications),
    pages: new Map(source.pages),
    memberships: new Map(source.memberships),
  };
}

function membershipKey(pageId: string, userId: string): string {
  return `${pageId}:${userId}`;
}

function transactionFor(store: Store): IdentityAuthorityTransaction {
  return {
    account: (userId) => Promise.resolve(store.accounts.get(userId) ?? null),
    putAccount: (account) => store.accounts.set(account.userId, account),
    identityBySubjectHash: (subjectHash) =>
      Promise.resolve(store.identities.get(subjectHash) ?? null),
    putIdentity: (identity) => store.identities.set(identity.subjectHash, identity),
    session: (sessionId) => Promise.resolve(store.sessions.get(sessionId) ?? null),
    sessionByHandleHash: (handleHash) =>
      Promise.resolve(
        [...store.sessions.values()].find((session) => session.handleHash === handleHash) ?? null,
      ),
    sessionsForUser: (userId) =>
      Promise.resolve([...store.sessions.values()].filter((session) => session.userId === userId)),
    putSession: (session) => store.sessions.set(session.sessionId, session),
    accessSnapshot: (sessionId) => Promise.resolve(store.accessSnapshots.get(sessionId) ?? null),
    putAccessSnapshot: (snapshot) =>
      store.accessSnapshots.set(accessSnapshotKey(snapshot), snapshot),
    verificationForUser: (userId) => Promise.resolve(store.verifications.get(userId) ?? null),
    putVerification: (verification) => store.verifications.set(verification.userId, verification),
    page: (pageId) => Promise.resolve(store.pages.get(pageId) ?? null),
    pagesForOwner: (userId) =>
      Promise.resolve([...store.pages.values()].filter((page) => page.ownerUserId === userId)),
    putPage: (page) => store.pages.set(page.pageId, page),
    membership: (pageId, userId) =>
      Promise.resolve(store.memberships.get(membershipKey(pageId, userId)) ?? null),
    membershipsForPage: (pageId) =>
      Promise.resolve(
        [...store.memberships.values()].filter((membership) => membership.pageId === pageId),
      ),
    membershipsForUser: (userId) =>
      Promise.resolve(
        [...store.memberships.values()].filter((membership) => membership.userId === userId),
      ),
    putMembership: (membership) =>
      store.memberships.set(membershipKey(membership.pageId, membership.userId), membership),
  };
}

function accessSnapshotKey(snapshot: AccessSnapshot): string {
  return snapshot.pageId === undefined
    ? snapshot.sessionId
    : `${snapshot.sessionId}__page__${snapshot.pageId}`;
}
