import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { AccountLinkingService } from './account_linking_service.js';
import { SessionAuthorityService } from './session_authority_service.js';
import { FirestoreIdentityAuthorityRepository } from '../infrastructure/firestore_identity_authority_repository.js';
import { SyntheticProviderIdentityVerifier } from '../infrastructure/synthetic_provider_identity_verifier.js';

const snapshotLifetimeMs = 15 * 60 * 1000;

/** Emulator-only bridge. Firebase Auth is transport identity; Account.userId remains authoritative. */
export async function establishEmulatorIdentitySession(input: {
  readonly firestore: Firestore;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly now: Date;
}) {
  const repository = new FirestoreIdentityAuthorityRepository(input.firestore);
  const accounts = new AccountLinkingService(repository, new SyntheticProviderIdentityVerifier());
  const sessions = new SessionAuthorityService(repository);
  const nowUtc = input.now.toISOString();
  const account = await accounts.ensureAccount({
    proof: {
      provider: 'google',
      providerTenant: 'demo-recharge-emulator',
      proof: `local-test:google:${input.firebaseUid}`,
    },
    proposedUserId: randomUUID(),
    proposedIdentityId: randomUUID(),
    nowUtc,
    accountCreationEnabled: true,
  });
  const issued = await sessions.issue({
    userId: account.userId,
    sessionId: randomUUID(),
    firebaseUid: input.firebaseUid,
    installationId: input.installationId,
    issuedAtUtc: nowUtc,
    snapshotExpiresAtUtc: new Date(input.now.getTime() + snapshotLifetimeMs).toISOString(),
  });
  return Object.freeze({
    userId: account.userId,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
    installationId: issued.session.installationId,
    expiresAtUtc: issued.accessSnapshot.expiresAtUtc,
  });
}
