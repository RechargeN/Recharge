import type { Account } from './account.js';
import type { AuthIdentity } from './auth_identity.js';
import type { CreatorVerification } from './creator_verification.js';
import type { ManagedPage } from './managed_page.js';
import type { PageMembership } from './page_membership.js';
import type { IdentitySession } from './session.js';
import type { AccessSnapshot } from './access_snapshot.js';

export interface IdentityAuthorityTransaction {
  account(userId: string): Promise<Account | null>;
  putAccount(account: Account): void;
  identityBySubjectHash(subjectHash: string): Promise<AuthIdentity | null>;
  putIdentity(identity: AuthIdentity): void;
  session(sessionId: string): Promise<IdentitySession | null>;
  sessionByHandleHash(handleHash: string): Promise<IdentitySession | null>;
  sessionsForUser(userId: string): Promise<readonly IdentitySession[]>;
  putSession(session: IdentitySession): void;
  accessSnapshot(sessionId: string): Promise<AccessSnapshot | null>;
  putAccessSnapshot(snapshot: AccessSnapshot): void;
  verificationForUser(userId: string): Promise<CreatorVerification | null>;
  putVerification(verification: CreatorVerification): void;
  page(pageId: string): Promise<ManagedPage | null>;
  pagesForOwner(userId: string): Promise<readonly ManagedPage[]>;
  putPage(page: ManagedPage): void;
  membership(pageId: string, userId: string): Promise<PageMembership | null>;
  membershipsForPage(pageId: string): Promise<readonly PageMembership[]>;
  membershipsForUser(userId: string): Promise<readonly PageMembership[]>;
  putMembership(membership: PageMembership): void;
}

export interface IdentityAuthorityRepository {
  transact<T>(operation: (transaction: IdentityAuthorityTransaction) => T | Promise<T>): Promise<T>;
}
