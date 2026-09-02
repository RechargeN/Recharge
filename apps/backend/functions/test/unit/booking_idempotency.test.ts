import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  computeBookingSemanticHash,
  inspectBookingCommand,
} from '../../src/contracts/booking_v1.js';
import {
  lengthPrefixedHash,
  logicalMutationId,
  requestAttemptId,
} from '../../src/booking/idempotency.js';
import { createCommand } from '../support/booking_fixtures.js';
import { asRecord, readBookingJson } from '../support/booking_schema_registry.js';

void test('split logical and attempt identities are deterministic and domain-separated', () => {
  const logical = logicalMutationId('user', 'createBooking', 'same');
  const attempt = requestAttemptId('user', 'same');
  assert.match(logical, /^m1_[0-9a-f]{64}$/u);
  assert.match(attempt, /^r1_[0-9a-f]{64}$/u);
  assert.notEqual(logical.slice(3), attempt.slice(3));
  assert.equal(logical, logicalMutationId('user', 'createBooking', 'same'));
  assert.notEqual(logical, logicalMutationId('user', 'cancelBooking', 'same'));
});

void test('length prefixes prevent concatenation ambiguity', () => {
  assert.notEqual(lengthPrefixedHash('ab', 'c'), lengthPrefixedHash('a', 'bc'));
});

void test('semantic hash ignores transport identity but includes domain meaning', () => {
  const first = createCommand();
  const replay = { ...first, requestId: 'req_other', idempotencyKey: 'idem_other' };
  assert.equal(
    computeBookingSemanticHash(first, 'user'),
    computeBookingSemanticHash(replay, 'user'),
  );
  assert.notEqual(
    computeBookingSemanticHash(first, 'user'),
    computeBookingSemanticHash(
      {
        ...first,
        payload: { ...first.payload, participantUnits: 2, namedGuests: [{ displayName: 'Guest' }] },
      },
      'user',
    ),
  );
});

void test('product adapter preserves every applicable frozen semantic-hash vector', async () => {
  const container = asRecord(await readBookingJson('fixtures/semantic_hash_vectors.json'));
  assert.ok(Array.isArray(container.vectors));
  let checked = 0;
  for (const rawVector of container.vectors) {
    const vector = asRecord(rawVector);
    const rawCommand = String(vector.rawCommandJson);
    const decoded = JSON.parse(rawCommand) as unknown;
    const commandType = asRecord(decoded).commandType;
    if (commandType !== 'createBooking' && commandType !== 'cancelBooking') continue;
    const inspected = inspectBookingCommand(Buffer.from(`{"data":${rawCommand}}`, 'utf8'), decoded);
    assert.equal(inspected.ok, true, String(vector.id));
    if (!inspected.ok) continue;
    assert.equal(
      computeBookingSemanticHash(inspected.value, String(asRecord(vector.resolvedActorScope).id)),
      vector.expectedDigest,
      String(vector.id),
    );
    checked += 1;
  }
  assert.ok(checked >= 10);
});
