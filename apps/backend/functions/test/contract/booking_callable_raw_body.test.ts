import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  inspectBookingCallableRawBody,
  type BookingCallableRawBodyFailureReason,
} from '../support/booking_callable_raw_body.js';
import {
  asRecord,
  createBookingSchemaRegistry,
  readBookingJson,
} from '../support/booking_schema_registry.js';
import { StrictJsonReader } from '../support/booking_raw_json.js';
import { computeBookingSemanticHash } from '../support/booking_semantic_hash.js';

function encodeEnvelope(rawCommand: string): Buffer {
  return Buffer.from(`{"data":${rawCommand}}`, 'utf8');
}

function expectFailure(
  rawBody: Buffer,
  decodedData: unknown,
  validateCommand: (value: unknown) => boolean,
  reason: BookingCallableRawBodyFailureReason,
): void {
  assert.deepEqual(inspectBookingCallableRawBody(rawBody, decodedData, validateCommand), {
    ok: false,
    reason,
  });
}

void test('all valid Booking commands survive strict callable-envelope inspection', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const fixtures = asRecord(await readBookingJson('fixtures/valid.json'));
  assert.ok(Array.isArray(fixtures.commands));

  for (const value of fixtures.commands) {
    const rawCommand = JSON.stringify(value);
    const decodedData = JSON.parse(rawCommand) as unknown;
    const result = inspectBookingCallableRawBody(
      Buffer.from(` \r\n { "data" : ${rawCommand} } \t`, 'utf8'),
      decodedData,
      validateCommand,
    );
    assert.equal(result.ok, true, String(asRecord(value).commandType));
    if (result.ok) {
      assert.deepEqual(JSON.parse(JSON.stringify(result.command)) as unknown, value);
    }
  }
});

void test('raw command vectors preserve semantic-hash evidence through the adapter', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const fixtures = asRecord(await readBookingJson('fixtures/semantic_hash_vectors.json'));
  assert.ok(Array.isArray(fixtures.vectors));

  for (const value of fixtures.vectors) {
    const vector = asRecord(value);
    const rawCommand = String(vector.rawCommandJson);
    const decodedData = new StrictJsonReader(rawCommand).read();
    const result = inspectBookingCallableRawBody(
      encodeEnvelope(rawCommand),
      decodedData,
      validateCommand,
    );
    assert.equal(result.ok, true, String(vector.id));
    if (!result.ok) continue;
    const hash = computeBookingSemanticHash(
      JSON.stringify(result.command),
      asRecord(vector.resolvedActorScope),
      validateCommand,
    );
    assert.equal(hash.canonicalHex, vector.expectedCanonicalHex, String(vector.id));
    assert.equal(hash.digest, vector.expectedDigest, String(vector.id));
  }
});

void test('object order differences do not create a callable decode mismatch', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const fixtures = asRecord(await readBookingJson('fixtures/valid.json'));
  const command = asRecord((fixtures.commands as unknown[])[0]);
  const reversed = Object.fromEntries(Object.entries(command).reverse());
  const result = inspectBookingCallableRawBody(
    encodeEnvelope(JSON.stringify(command)),
    reversed,
    validateCommand,
  );
  assert.equal(result.ok, true);
});

void test('malformed wire representations fail before contract hashing', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const cases: readonly [Buffer, unknown, BookingCallableRawBodyFailureReason][] = [
    [Buffer.from('{}'), {}, 'invalid_envelope'],
    [Buffer.from('{"data":{},"data":{}}'), {}, 'duplicate_key'],
    [Buffer.from('{"data":{},"extra":true}'), {}, 'invalid_envelope'],
    [Buffer.from([0xc3, 0x28]), {}, 'invalid_utf8'],
    [Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('{"data":{}}')]), {}, 'utf8_bom'],
    [Buffer.from('{"data":{}} trailing'), {}, 'invalid_json'],
    [Buffer.from('{"data":{"field":"\\ud800"}}'), { field: '\ud800' }, 'unpaired_surrogate'],
    [Buffer.from('{"data":{"value":1.5}}'), { value: 1.5 }, 'unsafe_number'],
    [Buffer.from('{"data":{"value":1.0000000000000001}}'), { value: 1 }, 'unsafe_number'],
    [Buffer.from('{"data":{"value":1e-400}}'), { value: 0 }, 'unsafe_number'],
    [
      Buffer.from('{"data":{"value":9007199254740992}}'),
      { value: 9_007_199_254_740_992 },
      'unsafe_number',
    ],
    [Buffer.from('{"data":null}'), null, 'invalid_envelope'],
    [Buffer.from('{"data":[]}'), [], 'invalid_envelope'],
    [
      Buffer.from(
        '{"data":{"value":{"@type":"type.googleapis.com/google.protobuf.Int64Value","value":"1"}}}',
      ),
      { value: 1 },
      'unsupported_protocol_value',
    ],
  ];

  for (const [rawBody, decodedData, reason] of cases) {
    expectFailure(rawBody, decodedData, validateCommand, reason);
  }

  const nested = `${'{"value":'.repeat(66)}0${'}'.repeat(66)}`;
  expectFailure(Buffer.from(`{"data":${nested}}`), {}, validateCommand, 'invalid_json');
  expectFailure(Buffer.alloc(64 * 1024 + 1, 0x20), {}, validateCommand, 'body_too_large');
});

void test('decoded-data changes and invalid commands fail closed', async () => {
  const registry = await createBookingSchemaRegistry();
  const validateCommand = registry.validator('booking_command.schema.json');
  const fixtures = asRecord(await readBookingJson('fixtures/valid.json'));
  const command = asRecord((fixtures.commands as unknown[])[0]);
  const rawBody = encodeEnvelope(JSON.stringify(command));

  expectFailure(
    rawBody,
    { ...command, requestId: 'changed-after-decode' },
    validateCommand,
    'callable_decode_mismatch',
  );
  const withoutRevision = { ...command };
  delete withoutRevision.occurredAgainstEventRevision;
  expectFailure(rawBody, withoutRevision, validateCommand, 'callable_decode_mismatch');
  expectFailure(encodeEnvelope('{}'), {}, validateCommand, 'invalid_contract');
  const unknownCommand = { ...command, commandType: 'futureBookingCommand' };
  expectFailure(
    encodeEnvelope(JSON.stringify(unknownCommand)),
    unknownCommand,
    validateCommand,
    'invalid_contract',
  );
});
