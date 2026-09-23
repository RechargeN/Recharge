import type { Account } from './account.js';
import type { AuthIdentity } from './auth_identity.js';
import type { CreatorVerification } from './creator_verification.js';
import type { ManagedPage } from './managed_page.js';
import type { PageMembership } from './page_membership.js';
import type { IdentitySession } from './session.js';

export interface IdentityAuthorityTransaction {
  account(userId: string): Account | null;
  putAccount(account: Account): void;
  identityBySubjectHash(subjectHash: string): AuthIdentity | null;
  putIdentity(identity: AuthIdentity): void;
  session(sessionId: string): IdentitySession | null;
  sessionsForUser(userId: string): readonly IdentitySession[];
  putSession(session: IdentitySession): void;
  verificationForUser(userId: string): CreatorVerification | null;
  putVerification(verification: CreatorVerification): void;
  page(pageId: string): ManagedPage | null;
  pagesForOwner(userId: string): readonly ManagedPage[];
  putPage(page: ManagedPage): void;
  membership(pageId: string, userId: string): PageMembership | null;
  membershipsForUser(userId: string): readonly PageMembership[];
  putMembership(membership: PageMembership): void;
}

export interface IdentityAuthorityRepository {
  transact<T>(operation: (transaction: IdentityAuthorityTransaction) => T | Promise<T>): Promise<T>;
}
