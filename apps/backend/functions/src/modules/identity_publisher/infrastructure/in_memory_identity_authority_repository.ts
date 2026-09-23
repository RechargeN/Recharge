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

interface Store {
  readonly accounts: Map<string, Account>;
  readonly identities: Map<string, AuthIdentity>;
  readonly sessions: Map<string, IdentitySession>;
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
    account: (userId) => store.accounts.get(userId) ?? null,
    putAccount: (account) => store.accounts.set(account.userId, account),
    identityBySubjectHash: (subjectHash) => store.identities.get(subjectHash) ?? null,
    putIdentity: (identity) => store.identities.set(identity.subjectHash, identity),
    session: (sessionId) => store.sessions.get(sessionId) ?? null,
    sessionsForUser: (userId) =>
      [...store.sessions.values()].filter((session) => session.userId === userId),
    putSession: (session) => store.sessions.set(session.sessionId, session),
    verificationForUser: (userId) => store.verifications.get(userId) ?? null,
    putVerification: (verification) => store.verifications.set(verification.userId, verification),
    page: (pageId) => store.pages.get(pageId) ?? null,
    pagesForOwner: (userId) =>
      [...store.pages.values()].filter((page) => page.ownerUserId === userId),
    putPage: (page) => store.pages.set(page.pageId, page),
    membership: (pageId, userId) => store.memberships.get(membershipKey(pageId, userId)) ?? null,
    membershipsForUser: (userId) =>
      [...store.memberships.values()].filter((membership) => membership.userId === userId),
    putMembership: (membership) =>
      store.memberships.set(membershipKey(membership.pageId, membership.userId), membership),
  };
}
