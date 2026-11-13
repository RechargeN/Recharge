import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  asRecord,
  createBookingSchemaRegistry,
  readBookingJson,
} from '../support/booking_schema_registry.js';
import { StrictJsonReader } from '../support/booking_raw_json.js';
import { computeBookingSemanticHash } from '../support/booking_semantic_hash.js';

void test('shared vectors freeze independent TypeScript JCS bytes and SHA-256', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const container = asRecord(await readBookingJson('fixtures/semantic_hash_vectors.json'));
  assert.ok(Array.isArray(container.vectors));
  const results = new Map<string, ReturnType<typeof computeBookingSemanticHash>>();

  for (const raw of container.vectors) {
    const vector = asRecord(raw);
    const rawCommand = String(vector.rawCommandJson);
    assert.equal(validateCommand(new StrictJsonReader(rawCommand).read()), true, String(vector.id));
    const result = computeBookingSemanticHash(
      rawCommand,
      asRecord(vector.resolvedActorScope),
      validateCommand,
    );
    assert.deepEqual(result.projection, vector.expectedProjection, String(vector.id));
    assert.equal(result.canonicalHex, vector.expectedCanonicalHex, String(vector.id));
    assert.equal(result.digest, vector.expectedDigest, String(vector.id));
    results.set(String(vector.id), result);
  }

  assert.equal(
    results.get('key-order-a')!.digest,
    results.get('key-order-b-request-change')!.digest,
  );
  assert.equal(
    results.get('nested-unicode-nfc-literal')!.digest,
    results.get('nested-unicode-nfc-escaped')!.digest,
  );
  assert.notEqual(
    results.get('nested-unicode-nfc-literal')!.digest,
    results.get('unicode-nfd-distinct')!.digest,
  );
  assert.notEqual(
    results.get('booking-revision-7')!.digest,
    results.get('booking-revision-8')!.digest,
  );
  assert.notEqual(
    results.get('event-revision-11')!.digest,
    results.get('event-revision-12')!.digest,
  );
  assert.equal(results.get('idempotency-a')!.digest, results.get('idempotency-b')!.digest);
  assert.notEqual(
    results.get('idempotency-a')!.logicalIdentity,
    results.get('idempotency-b')!.logicalIdentity,
  );
});

void test('raw invalid vectors are rejected before hashing', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const container = asRecord(await readBookingJson('fixtures/semantic_hash_invalid.json'));
  assert.ok(Array.isArray(container.cases));
  for (const raw of container.cases) {
    const fixture = asRecord(raw);
    assert.throws(
      () =>
        computeBookingSemanticHash(
          String(fixture.rawCommandJson),
          asRecord(fixture.resolvedActorScope),
          validateCommand,
        ),
      /.+/u,
      `${String(fixture.id)}: ${String(fixture.reason)}`,
    );
  }
});
