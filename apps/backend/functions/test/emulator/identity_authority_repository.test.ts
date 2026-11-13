import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { IdentityFailure } from '../../src/modules/identity_publisher/domain/failures.js';
import {
  FirestoreIdentityAuthorityRepository,
  identityAuthorityCollections,
} from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCapabilityGrantPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_capability_grant_policy.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const repository = new FirestoreIdentityAuthorityRepository(firestore);
const authority = new IdentityPublisherAuthority({
  repository,
  providerVerifier: new SyntheticProviderIdentityVerifier(),
  verificationDecisions: new LocalVerificationDecisionAdapter(new Set(['reviewer'])),
  pagePolicy: new LocalPageCreationPolicy(true, 3),
  pageCapabilityGrantPolicy: new LocalPageCapabilityGrantPolicy(),
});

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5ZA';
const identityId = '018FQ2Z8Q9N4M7K2T6V3W1X5ZB';
const sessionId = '018FQ2Z8Q9N4M7K2T6V3W1X5ZC';

before(cleanup);
after(cleanup);

void test('Firestore Identity atomically stores opaque Session and baseline access snapshot', async () => {
  await authority.accounts.ensureAccount({
    proof: {
      provider: 'google',
      providerTenant: 'consumer',
      proof: 'local-test:google:firestore-user',
    },
    proposedUserId: userId,
    proposedIdentityId: identityId,
    nowUtc: '2026-09-24T10:00:00.000Z',
    accountCreationEnabled: true,
  });
  const issued = await authority.sessions.issue({
    userId,
    sessionId,
    firebaseUid: 'firebase-user-1',
    installationId: 'install-1',
    issuedAtUtc: '2026-09-24T10:01:00.000Z',
    snapshotExpiresAtUtc: '2026-09-24T10:06:00.000Z',
  });
  assert.match(issued.sessionHandle, /^[A-Za-z0-9_-]{43}$/u);
  assert.deepEqual(issued.accessSnapshot.capabilityIds, ['booking.self_service']);

  const [session, snapshot] = await firestore.getAll(
    firestore.collection(identityAuthorityCollections.sessions).doc(sessionId),
    firestore.collection(identityAuthorityCollections.accessSnapshots).doc(sessionId),
  );
  assert.ok(session);
  assert.ok(snapshot);
  assert.equal(session.get('sessionHandle'), undefined);
  assert.match(String(session.get('handleHash')), /^[a-f0-9]{64}$/u);
  assert.equal(session.get('firebaseUid'), 'firebase-user-1');
  assert.equal(snapshot.get('sessionId'), sessionId);
  assert.deepEqual(snapshot.get('capabilityIds'), ['booking.self_service']);
});

void test('duplicate provider and concurrent Session issuance remain transactional', async () => {
  const replay = await authority.accounts.ensureAccount({
    proof: {
      provider: 'google',
      providerTenant: 'consumer',
      proof: 'local-test:google:firestore-user',
    },
    proposedUserId: '018FQ2Z8Q9N4M7K2T6V3W1X5ZD',
    proposedIdentityId: '018FQ2Z8Q9N4M7K2T6V3W1X5ZE',
    nowUtc: '2026-09-24T10:02:00.000Z',
    accountCreationEnabled: true,
  });
  assert.equal(replay.userId, userId);

  const duplicateSessionId = '018FQ2Z8Q9N4M7K2T6V3W1X5ZF';
  const attempts = await Promise.allSettled(
    ['install-a', 'install-b'].map((installationId) =>
      authority.sessions.issue({
        userId,
        sessionId: duplicateSessionId,
        firebaseUid: 'firebase-user-1',
        installationId,
        issuedAtUtc: '2026-09-24T10:03:00.000Z',
        snapshotExpiresAtUtc: '2026-09-24T10:08:00.000Z',
      }),
    ),
  );
  assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1);
  const rejected = attempts.find((result) => result.status === 'rejected');
  assert.ok(rejected?.status === 'rejected');
  assert.ok(rejected.reason instanceof IdentityFailure);
  assert.equal(rejected.reason.code, 'revision_conflict');
});

void test('Firestore adapter rejects a read after the first transaction write', async () => {
  await assert.rejects(
    repository.transact(async (transaction) => {
      const account = await transaction.account(userId);
      assert.ok(account);
      transaction.putAccount(account);
      await transaction.session(sessionId);
    }),
    /identity_firestore_read_after_write/u,
  );
});

async function cleanup(): Promise<void> {
  for (const collectionName of Object.values(identityAuthorityCollections)) {
    const snapshot = await firestore.collection(collectionName).get();
    if (snapshot.empty) continue;
    const batch = firestore.batch();
    for (const document of snapshot.docs) batch.delete(document.ref);
    await batch.commit();
  }
}
