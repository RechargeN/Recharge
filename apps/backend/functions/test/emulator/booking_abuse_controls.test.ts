import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import {
  FirestoreAbuseRateLimiter,
  abuseCollections,
} from '../../src/platform/security/firestore_abuse_rate_limiter.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();

before(() => cleanupBookingEmulator(firestore));
after(() => cleanupBookingEmulator(firestore));

void test('create rate is transaction-safe, request-deduped and returns retryAfter', async () => {
  const limiter = new FirestoreAbuseRateLimiter(firestore);
  const now = new Date('2026-09-26T10:00:00.000Z');
  for (let index = 0; index < 5; index += 1) {
    const result = await limiter.consume(request('booking.create', `req-create-${index}`, now));
    assert.equal(result.allowed, true);
  }
  const denied = await limiter.consume(request('booking.create', 'req-create-5', now));
  assert.equal(denied.allowed, false);
  if (!denied.allowed) assert.equal(denied.retryAfterSeconds, 10);

  const replay = await limiter.consume(request('booking.create', 'req-create-5', now));
  assert.deepEqual(replay, denied);
  assert.equal((await firestore.collection(abuseCollections.attempts).get()).size, 6);
});

void test('cancel has an independent budget and a network signal never blocks it', async () => {
  const limiter = new FirestoreAbuseRateLimiter(firestore);
  const now = new Date('2026-09-26T10:02:00.000Z');
  const result = await limiter.consume(request('booking.cancel', 'req-cancel-1', now));
  assert.equal(result.allowed, true);
  assert.equal(result.networkRiskExceeded, false);
});

void test('corrupt counter fails closed as unavailable policy evidence', async () => {
  const limiter = new FirestoreAbuseRateLimiter(firestore);
  const now = new Date('2026-09-26T10:04:00.000Z');
  await limiter.consume(request('booking.query', 'req-query-prime', now));
  const counters = await firestore.collection(abuseCollections.counters).get();
  const queryCounter = counters.docs.find(
    (document) => document.get('operation') === 'booking.query',
  );
  assert.ok(queryCounter);
  await queryCounter.ref.update({ policyRevision: 999 });
  await assert.rejects(
    limiter.consume(request('booking.query', 'req-query-corrupt', now)),
    /abuse_policy_unavailable/u,
  );
});

function request(
  operation: 'booking.create' | 'booking.cancel' | 'booking.query',
  attemptRequestId: string,
  now: Date,
) {
  return {
    operation,
    attemptRequestId,
    accountId: 'user-rate-limit',
    installationId: 'install-rate-limit',
    sessionId: 'session-rate-limit',
    networkRiskHash: 'network-risk-hash',
    environmentId: 'local' as const,
    marketId: 'LV' as const,
    now,
    correlationId: attemptRequestId,
  };
}
