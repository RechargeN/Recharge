import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { AccountLinkingService } from '../../src/modules/identity_publisher/application/account_linking_service.js';
import { SessionAuthorityService } from '../../src/modules/identity_publisher/application/session_authority_service.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { identitySessionIdleLifetimeMs } from '../../src/modules/identity_publisher/domain/session.js';
import { standUsers, type StandUserLabel } from './stand_plan.js';

const dayMs = 24 * 60 * 60 * 1000;

function standUser(label: string) {
  const user = standUsers.find((candidate) => candidate.label === (label as StandUserLabel));
  if (user === undefined) throw new Error(`unknown stand user: ${label}`);
  return user;
}

async function owner(firestore: Firestore, label: string) {
  const user = standUser(label);
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const now = new Date().toISOString();
  // Existing Account only: account creation stays disabled for fixtures.
  const account = await new AccountLinkingService(
    repository,
    new SyntheticProviderIdentityVerifier(),
  ).ensureAccount({
    proof: {
      provider: 'google',
      providerTenant: 'demo-recharge-emulator',
      proof: `local-test:google:${user.firebaseUid}`,
    },
    proposedUserId: randomUUID(),
    proposedIdentityId: randomUUID(),
    nowUtc: now,
    accountCreationEnabled: false,
  });
  return { user, repository, userId: account.userId, now };
}

/** Revokes every live Session of a stand user through the Session owner service. */
export async function revokeActiveSessions(firestore: Firestore, label: string): Promise<number> {
  const { repository, userId, now } = await owner(firestore, label);
  const sessions = new SessionAuthorityService(repository);
  const active = (
    await repository.transact((transaction) => transaction.sessionsForUser(userId))
  ).filter((session) => session.status === 'active' || session.status === 'stepUpRequired');
  for (const session of active) {
    await sessions.revoke({ actorUserId: userId, sessionId: session.sessionId, nowUtc: now });
  }
  return active.length;
}

/**
 * Issues a Session whose idle lifetime has already ended, through the owner
 * `issue` path with explicit past instants. It replaces a live Session of the
 * same installation and prints no secret other than the handle the client needs.
 */
export async function issueExpiredSession(
  firestore: Firestore,
  label: string,
  installationId: string,
) {
  const { user, repository, userId, now } = await owner(firestore, label);
  const issuedAt = new Date(Date.parse(now) - identitySessionIdleLifetimeMs - dayMs);
  const issued = await new SessionAuthorityService(repository).issue({
    userId,
    sessionId: randomUUID(),
    firebaseUid: user.firebaseUid,
    installationId,
    issuedAtUtc: issuedAt.toISOString(),
    snapshotExpiresAtUtc: new Date(issuedAt.getTime() + 60 * 60 * 1000).toISOString(),
  });
  return Object.freeze({
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
    installationId,
  });
}

/** Read-only: Booking counts of a stand user by state, to prove no duplicate was created. */
export async function bookingCounts(firestore: Firestore, label: string) {
  const { userId } = await owner(firestore, label);
  const snapshot = await firestore.collection('bookings').where('userId', '==', userId).get();
  const byState: Record<string, number> = {};
  for (const document of snapshot.docs) {
    const state = String(document.get('state'));
    byState[state] = (byState[state] ?? 0) + 1;
  }
  const active = (byState.pending ?? 0) + (byState.confirmed ?? 0) + (byState.waitlisted ?? 0);
  return Object.freeze({ total: snapshot.size, active, byState });
}

/** The domain User id the backend linked to a stand user's transport identity. */
export async function standLinkedUserId(firestore: Firestore, label: string): Promise<string> {
  return (await owner(firestore, label)).userId;
}
