import { createHash, randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { AccountLinkingService } from './account_linking_service.js';
import { SessionAuthorityService } from './session_authority_service.js';
import { FirestoreIdentityAuthorityRepository } from '../infrastructure/firestore_identity_authority_repository.js';
import { SyntheticProviderIdentityVerifier } from '../infrastructure/synthetic_provider_identity_verifier.js';
import { FirestoreAbuseRateLimiter } from '../../../platform/security/firestore_abuse_rate_limiter.js';
import { IdentityFailure } from '../domain/failures.js';

const snapshotLifetimeMs = 60 * 60 * 1000;

/** Emulator-only bridge. Firebase Auth is transport identity; Account.userId remains authoritative. */
export async function establishEmulatorIdentitySession(input: {
  readonly firestore: Firestore;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly attemptRequestId: string;
  readonly networkRiskHash?: string;
  readonly now: Date;
}) {
  const repository = new FirestoreIdentityAuthorityRepository(input.firestore);
  const accounts = new AccountLinkingService(repository, new SyntheticProviderIdentityVerifier());
  const sessions = new SessionAuthorityService(repository);
  const nowUtc = input.now.toISOString();
  const transportIdentityHash = hashTransportIdentity(input.firebaseUid);
  const bootstrapDecision = await new FirestoreAbuseRateLimiter(input.firestore).consume({
    operation: 'identity.session.bootstrap',
    attemptRequestId: input.attemptRequestId,
    transportIdentityHash,
    installationId: input.installationId,
    ...(input.networkRiskHash === undefined ? {} : { networkRiskHash: input.networkRiskHash }),
    environmentId: 'local',
    marketId: 'LV',
    now: input.now,
    correlationId: input.attemptRequestId,
  });
  if (!bootstrapDecision.allowed) {
    throw new IdentityFailure('rate_limited', bootstrapDecision.retryAfterSeconds);
  }
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
  const rateDecision = await new FirestoreAbuseRateLimiter(input.firestore).consume({
    operation: 'identity.session.issue',
    attemptRequestId: input.attemptRequestId,
    accountId: account.userId,
    installationId: input.installationId,
    ...(input.networkRiskHash === undefined ? {} : { networkRiskHash: input.networkRiskHash }),
    environmentId: 'local',
    marketId: 'LV',
    now: input.now,
    correlationId: input.attemptRequestId,
  });
  if (!rateDecision.allowed) {
    throw new IdentityFailure('rate_limited', rateDecision.retryAfterSeconds);
  }
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

/** Internal-only rotation path; deliberately has no callable export. */
export async function rotateEmulatorIdentitySession(input: {
  readonly firestore: Firestore;
  readonly sessionId: string;
  readonly sessionHandle: string;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly attemptRequestId: string;
  readonly now: Date;
}) {
  const sessions = new SessionAuthorityService(
    new FirestoreIdentityAuthorityRepository(input.firestore),
  );
  const userId = await sessions.resolveSessionOwner({
    sessionId: input.sessionId,
    sessionHandle: input.sessionHandle,
    firebaseUid: input.firebaseUid,
    installationId: input.installationId,
    nowUtc: input.now.toISOString(),
  });
  const decision = await new FirestoreAbuseRateLimiter(input.firestore).consume({
    operation: 'identity.session.rotate',
    attemptRequestId: input.attemptRequestId,
    accountId: userId,
    installationId: input.installationId,
    sessionId: input.sessionId,
    environmentId: 'local',
    marketId: 'LV',
    now: input.now,
    correlationId: input.attemptRequestId,
  });
  if (!decision.allowed) throw new IdentityFailure('rate_limited', decision.retryAfterSeconds);
  return sessions.rotate({
    sessionId: input.sessionId,
    sessionHandle: input.sessionHandle,
    firebaseUid: input.firebaseUid,
    installationId: input.installationId,
    nowUtc: input.now.toISOString(),
    snapshotExpiresAtUtc: new Date(input.now.getTime() + snapshotLifetimeMs).toISOString(),
  });
}

/** Recent-auth recovery revokes every prior handle and issues one new installation-bound Session. */
export async function recoverEmulatorIdentitySessions(input: {
  readonly firestore: Firestore;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly attemptRequestId: string;
  readonly networkRiskHash?: string;
  readonly now: Date;
}) {
  const repository = new FirestoreIdentityAuthorityRepository(input.firestore);
  const accounts = new AccountLinkingService(repository, new SyntheticProviderIdentityVerifier());
  const transportIdentityHash = hashTransportIdentity(input.firebaseUid);
  const limiter = new FirestoreAbuseRateLimiter(input.firestore);
  const bootstrapDecision = await limiter.consume({
    operation: 'identity.session.bootstrap',
    attemptRequestId: input.attemptRequestId,
    transportIdentityHash,
    installationId: input.installationId,
    ...(input.networkRiskHash === undefined ? {} : { networkRiskHash: input.networkRiskHash }),
    environmentId: 'local',
    marketId: 'LV',
    now: input.now,
    correlationId: input.attemptRequestId,
  });
  if (!bootstrapDecision.allowed) {
    throw new IdentityFailure('rate_limited', bootstrapDecision.retryAfterSeconds);
  }
  const account = await accounts.ensureAccount({
    proof: {
      provider: 'google',
      providerTenant: 'demo-recharge-emulator',
      proof: `local-test:google:${input.firebaseUid}`,
    },
    proposedUserId: randomUUID(),
    proposedIdentityId: randomUUID(),
    nowUtc: input.now.toISOString(),
    accountCreationEnabled: false,
  });
  const accountDecision = await limiter.consume({
    operation: 'identity.session.issue',
    attemptRequestId: input.attemptRequestId,
    accountId: account.userId,
    installationId: input.installationId,
    ...(input.networkRiskHash === undefined ? {} : { networkRiskHash: input.networkRiskHash }),
    environmentId: 'local',
    marketId: 'LV',
    now: input.now,
    correlationId: input.attemptRequestId,
  });
  if (!accountDecision.allowed) {
    throw new IdentityFailure('rate_limited', accountDecision.retryAfterSeconds);
  }
  const recovered = await new SessionAuthorityService(repository).recover({
    userId: account.userId,
    sessionId: randomUUID(),
    firebaseUid: input.firebaseUid,
    installationId: input.installationId,
    nowUtc: input.now.toISOString(),
    snapshotExpiresAtUtc: new Date(input.now.getTime() + snapshotLifetimeMs).toISOString(),
  });
  return Object.freeze({
    userId: account.userId,
    sessionId: recovered.session.sessionId,
    sessionHandle: recovered.sessionHandle,
    installationId: recovered.session.installationId,
    expiresAtUtc: recovered.accessSnapshot.expiresAtUtc,
  });
}

function hashTransportIdentity(firebaseUid: string): string {
  return createHash('sha256')
    .update(`identity_bootstrap_transport_v1|${firebaseUid}`, 'utf8')
    .digest('hex');
}
