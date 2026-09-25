import type { Firestore, Transaction } from 'firebase-admin/firestore';

import type { AccessSnapshot } from '../domain/access_snapshot.js';
import type { Account } from '../domain/account.js';
import type { AuthIdentity } from '../domain/auth_identity.js';
import type { CreatorVerification } from '../domain/creator_verification.js';
import type { ManagedPage } from '../domain/managed_page.js';
import type { PageMembership } from '../domain/page_membership.js';
import type {
  IdentityAuthorityRepository,
  IdentityAuthorityTransaction,
} from '../domain/repositories.js';
import type { IdentitySession } from '../domain/session.js';

export const identityAuthorityCollections = Object.freeze({
  accounts: 'identityAccounts',
  providerLinks: 'identityProviderLinks',
  sessions: 'identitySessions',
  accessSnapshots: 'identityAccessSnapshots',
  creatorVerifications: 'identityCreatorVerifications',
  managedPages: 'identityManagedPages',
  pageMemberships: 'identityPageMemberships',
});

export class FirestoreIdentityAuthorityRepository implements IdentityAuthorityRepository {
  constructor(private readonly firestore: Firestore) {}

  transact<T>(
    operation: (transaction: IdentityAuthorityTransaction) => T | Promise<T>,
  ): Promise<T> {
    return this.firestore.runTransaction(
      async (transaction) =>
        await operation(new FirestoreIdentityAuthorityTransaction(this.firestore, transaction)),
    );
  }
}

class FirestoreIdentityAuthorityTransaction implements IdentityAuthorityTransaction {
  #writeStarted = false;

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  account(userId: string): Promise<Account | null> {
    return this.readDocument(identityAuthorityCollections.accounts, userId);
  }

  putAccount(account: Account): void {
    this.write(identityAuthorityCollections.accounts, account.userId, account);
  }

  identityBySubjectHash(subjectHash: string): Promise<AuthIdentity | null> {
    return this.readDocument(identityAuthorityCollections.providerLinks, subjectHash);
  }

  putIdentity(identity: AuthIdentity): void {
    this.write(identityAuthorityCollections.providerLinks, identity.subjectHash, identity);
  }

  session(sessionId: string): Promise<IdentitySession | null> {
    return this.readDocument(identityAuthorityCollections.sessions, sessionId);
  }

  async sessionByHandleHash(handleHash: string): Promise<IdentitySession | null> {
    this.assertMayRead();
    const snapshot = await this.transaction.get(
      this.firestore
        .collection(identityAuthorityCollections.sessions)
        .where('handleHash', '==', handleHash)
        .limit(2),
    );
    if (snapshot.size > 1) throw new Error('identity_session_handle_collision');
    return (snapshot.docs[0]?.data() as IdentitySession | undefined) ?? null;
  }

  sessionsForUser(userId: string): Promise<readonly IdentitySession[]> {
    return this.readQuery<IdentitySession>(identityAuthorityCollections.sessions, 'userId', userId);
  }

  putSession(session: IdentitySession): void {
    this.write(identityAuthorityCollections.sessions, session.sessionId, session);
  }

  accessSnapshot(sessionId: string): Promise<AccessSnapshot | null> {
    return this.readDocument(identityAuthorityCollections.accessSnapshots, sessionId);
  }

  putAccessSnapshot(snapshot: AccessSnapshot): void {
    this.write(
      identityAuthorityCollections.accessSnapshots,
      snapshot.pageId === undefined
        ? snapshot.sessionId
        : `${snapshot.sessionId}__page__${snapshot.pageId}`,
      snapshot,
    );
  }

  verificationForUser(userId: string): Promise<CreatorVerification | null> {
    return this.readDocument(identityAuthorityCollections.creatorVerifications, userId);
  }

  putVerification(verification: CreatorVerification): void {
    this.write(
      identityAuthorityCollections.creatorVerifications,
      verification.userId,
      verification,
    );
  }

  page(pageId: string): Promise<ManagedPage | null> {
    return this.readDocument(identityAuthorityCollections.managedPages, pageId);
  }

  pagesForOwner(userId: string): Promise<readonly ManagedPage[]> {
    return this.readQuery<ManagedPage>(
      identityAuthorityCollections.managedPages,
      'ownerUserId',
      userId,
    );
  }

  putPage(page: ManagedPage): void {
    this.write(identityAuthorityCollections.managedPages, page.pageId, page);
  }

  membership(pageId: string, userId: string): Promise<PageMembership | null> {
    return this.readDocument(
      identityAuthorityCollections.pageMemberships,
      membershipDocumentId(pageId, userId),
    );
  }

  membershipsForPage(pageId: string): Promise<readonly PageMembership[]> {
    return this.readQuery<PageMembership>(
      identityAuthorityCollections.pageMemberships,
      'pageId',
      pageId,
    );
  }

  membershipsForUser(userId: string): Promise<readonly PageMembership[]> {
    return this.readQuery<PageMembership>(
      identityAuthorityCollections.pageMemberships,
      'userId',
      userId,
    );
  }

  putMembership(membership: PageMembership): void {
    this.write(
      identityAuthorityCollections.pageMemberships,
      membershipDocumentId(membership.pageId, membership.userId),
      membership,
    );
  }

  async readDocument<T>(collection: string, documentId: string): Promise<T | null> {
    this.assertMayRead();
    const snapshot = await this.transaction.get(
      this.firestore.collection(collection).doc(documentId),
    );
    return snapshot.exists ? (snapshot.data() as T) : null;
  }

  async readQuery<T>(collection: string, field: string, value: string): Promise<readonly T[]> {
    this.assertMayRead();
    const snapshot = await this.transaction.get(
      this.firestore.collection(collection).where(field, '==', value),
    );
    return snapshot.docs.map((document) => document.data() as T);
  }

  write(collection: string, documentId: string, value: object): void {
    this.#writeStarted = true;
    this.transaction.set(this.firestore.collection(collection).doc(documentId), value);
  }

  assertMayRead(): void {
    if (this.#writeStarted) throw new Error('identity_firestore_read_after_write');
  }
}

function membershipDocumentId(pageId: string, userId: string): string {
  return `${pageId}__${userId}`;
}
