import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createAccount,
  advanceRevocationFence,
  setCreatorRole,
} from '../../../src/modules/identity_publisher/domain/account.js';
import {
  decideCreatorVerification,
  submitCreatorVerification,
} from '../../../src/modules/identity_publisher/domain/creator_verification.js';
import { IdentityFailure } from '../../../src/modules/identity_publisher/domain/failures.js';
import {
  assertCurrentSession,
  changeSessionStatus,
  createSession,
} from '../../../src/modules/identity_publisher/domain/session.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const sessionId = '018FQ2Z8Q9N4M7K2T6V3W1X5YB';
const verificationId = '018FQ2Z8Q9N4M7K2T6V3W1X5YC';
const evidenceId = '018FQ2Z8Q9N4M7K2T6V3W1X5YD';

void test('session and account revocation fences are monotonic', () => {
  const account = createAccount(userId, '2026-09-22T00:00:00.000Z');
  const session = createSession({
    sessionId,
    userId,
    issuedAtUtc: '2026-09-22T00:00:01.000Z',
    authzRevision: account.securityRevision,
    firebaseUid: userId,
    installationId: 'install-1',
    sessionHandle: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  });
  assert.doesNotThrow(() => assertCurrentSession(session, account));
  assert.throws(
    () =>
      assertCurrentSession(session, advanceRevocationFence(account, '2026-09-22T00:00:02.000Z')),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'session_revoked',
  );
  const revoked = changeSessionStatus(session, 'revoked', '2026-09-22T00:00:03.000Z');
  assert.throws(() => changeSessionStatus(revoked, 'expired', '2026-09-22T00:00:04.000Z'));
});

void test('Creator verification cannot be granted by skipping pending review', () => {
  const pending = submitCreatorVerification({
    verificationId,
    userId,
    evidenceRefIds: [evidenceId],
    submittedAtUtc: '2026-09-22T00:00:00.000Z',
  });
  const verified = decideCreatorVerification(pending, 'verified', '2026-09-22T00:01:00.000Z');
  const suspended = decideCreatorVerification(verified, 'suspended', '2026-09-22T00:02:00.000Z');
  assert.equal(suspended.status, 'suspended');
  assert.throws(() => decideCreatorVerification(pending, 'suspended', '2026-09-22T00:03:00.000Z'));
});

void test('revision fences allow same-instant issuance and stale changed authority', () => {
  const account = createAccount(userId, '2026-09-22T00:00:00.000Z');
  const session = createSession({
    sessionId,
    userId,
    issuedAtUtc: '2026-09-22T00:00:00.000Z',
    authzRevision: account.securityRevision,
    firebaseUid: userId,
    installationId: 'install-same-instant',
    sessionHandle: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  });
  assert.doesNotThrow(() => assertCurrentSession(session, account));
  assert.throws(
    () => assertCurrentSession(session, setCreatorRole(account, true, '2026-09-22T00:00:01.000Z')),
    (error: unknown) => error instanceof IdentityFailure && error.code === 'snapshot_stale',
  );
});
