import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { request } from 'node:http';

const endpoint = new URL('http://127.0.0.1:5101/demo-recharge/europe-west1/bookingRawBodyProbeV1');

type ExpectedOutcome =
  | Readonly<{ kind: 'accepted'; semanticGroup: string }>
  | Readonly<{ kind: 'rejected'; reason: string }>
  | Readonly<{ kind: 'closed'; adapterReason?: string }>;

interface ProbeVector {
  readonly id: string;
  readonly body: Buffer;
  readonly expected: ExpectedOutcome;
}

interface HttpResult {
  readonly status: number;
  readonly body: unknown;
}

const compactCommand =
  '{"schemaVersion":1,"commandType":"createBooking","requestId":"attempt:raw-b","idempotencyKey":"idempotency-raw-b","occurredAgainstEventRevision":4,"payload":{"occurrenceId":"01JOCCURRENCE000000000001","inventoryPoolId":"01JPOOL000000000000000001","channel":"onsite","participantUnits":2,"namedGuests":[{"displayName":"Guest"}]}}';
const reorderedCommand =
  '{"payload":{"namedGuests":[{"displayName":"Guest"}],"participantUnits":2,"channel":"onsite","inventoryPoolId":"01JPOOL000000000000000001","occurrenceId":"01JOCCURRENCE000000000001"},"occurredAgainstEventRevision":4,"idempotencyKey":"idempotency-raw-b","requestId":"attempt:raw-b","commandType":"createBooking","schemaVersion":1}';
const literalUnicodeCommand =
  '{"schemaVersion":1,"commandType":"createBooking","requestId":"attempt-😀","idempotencyKey":"idempotency-unicode","payload":{"occurrenceId":"01JOCCURRENCE000000000001","participantUnits":1}}';
const escapedUnicodeCommand =
  '{"schemaVersion":1,"commandType":"createBooking","requestId":"attempt-\\ud83d\\ude00","idempotencyKey":"idempotency-unicode","payload":{"occurrenceId":"01JOCCURRENCE000000000001","participantUnits":1}}';

const vectors: readonly ProbeVector[] = [
  {
    id: 'valid-compact',
    body: envelope(compactCommand),
    expected: { kind: 'accepted', semanticGroup: 'base' },
  },
  {
    id: 'valid-whitespace-reordered',
    body: Buffer.from(` \r\n { "data" : ${reorderedCommand} } \t`, 'utf8'),
    expected: { kind: 'accepted', semanticGroup: 'base' },
  },
  {
    id: 'unicode-literal',
    body: envelope(literalUnicodeCommand),
    expected: { kind: 'accepted', semanticGroup: 'unicode' },
  },
  {
    id: 'unicode-escaped',
    body: envelope(escapedUnicodeCommand),
    expected: { kind: 'accepted', semanticGroup: 'unicode' },
  },
  {
    id: 'duplicate-nested-key',
    body: envelope(
      compactCommand.replace('"participantUnits":2', '"participantUnits":1,"participantUnits":2'),
    ),
    expected: { kind: 'rejected', reason: 'duplicate_key' },
  },
  {
    id: 'duplicate-top-level-data',
    body: Buffer.from(`{"data":${compactCommand},"data":${compactCommand}}`, 'utf8'),
    expected: { kind: 'rejected', reason: 'duplicate_key' },
  },
  {
    id: 'unpaired-surrogate',
    body: envelope(compactCommand.replace('attempt:raw-b', 'attempt-\\ud800')),
    expected: { kind: 'rejected', reason: 'unpaired_surrogate' },
  },
  {
    id: 'fractional-number',
    body: envelope(compactCommand.replace('"participantUnits":2', '"participantUnits":1.5')),
    expected: { kind: 'rejected', reason: 'unsafe_number' },
  },
  {
    id: 'rounded-number',
    body: envelope(
      compactCommand.replace('"participantUnits":2', '"participantUnits":1.0000000000000001'),
    ),
    expected: { kind: 'rejected', reason: 'unsafe_number' },
  },
  {
    id: 'underflow-number',
    body: envelope(compactCommand.replace('"participantUnits":2', '"participantUnits":1e-400')),
    expected: { kind: 'rejected', reason: 'unsafe_number' },
  },
  {
    id: 'callable-type-wrapper',
    body: envelope(
      compactCommand.replace(
        '"participantUnits":2',
        '"participantUnits":{"@type":"type.googleapis.com/google.protobuf.Int64Value","value":"2"}',
      ),
    ),
    expected: { kind: 'rejected', reason: 'unsupported_protocol_value' },
  },
  {
    id: 'callable-decode-negative-zero',
    body: envelope(compactCommand.replace('"participantUnits":2', '"participantUnits":-0')),
    expected: { kind: 'rejected', reason: 'callable_decode_mismatch' },
  },
  {
    id: 'framework-invalid-utf8',
    body: Buffer.from([0xc3, 0x28]),
    expected: { kind: 'closed', adapterReason: 'invalid_utf8' },
  },
  {
    id: 'framework-bom',
    body: Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), envelope(compactCommand)]),
    expected: { kind: 'closed', adapterReason: 'utf8_bom' },
  },
  {
    id: 'framework-missing-data',
    body: Buffer.from('{}', 'utf8'),
    expected: { kind: 'closed', adapterReason: 'invalid_envelope' },
  },
  {
    id: 'framework-extra-top-level-member',
    body: Buffer.from(`{"data":${compactCommand},"extra":true}`, 'utf8'),
    expected: { kind: 'closed', adapterReason: 'invalid_envelope' },
  },
  {
    id: 'framework-non-json',
    body: Buffer.from('not-json', 'utf8'),
    expected: { kind: 'closed', adapterReason: 'invalid_json' },
  },
  {
    id: 'framework-trailing-bytes',
    body: Buffer.from(`{"data":${compactCommand}} trailing`, 'utf8'),
    expected: { kind: 'closed', adapterReason: 'invalid_json' },
  },
  {
    id: 'framework-or-adapter-oversized',
    body: Buffer.from(`{"data":{"padding":"${'a'.repeat(64 * 1024)}"}}`, 'utf8'),
    expected: { kind: 'closed', adapterReason: 'body_too_large' },
  },
];

const semanticHashes = new Map<string, string>();
for (const vector of vectors) {
  const result = await postRaw(vector.body);
  const boundary = verifyResult(vector, result, semanticHashes);
  process.stdout.write(`${vector.id}: ${boundary}\n`);
}
assert.equal(semanticHashes.size, 2);
process.stdout.write(`RAW-B callable transport corpus passed (${vectors.length} vectors).\n`);

function envelope(command: string): Buffer {
  return Buffer.from(`{"data":${command}}`, 'utf8');
}

async function postRaw(body: Buffer): Promise<HttpResult> {
  return await new Promise((resolve, reject) => {
    const outbound = request(
      endpoint,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'content-length': String(body.byteLength),
        },
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => chunks.push(chunk));
        response.on('end', () => {
          const rawResponse = Buffer.concat(chunks).toString('utf8');
          let decoded: unknown = null;
          try {
            decoded = JSON.parse(rawResponse) as unknown;
          } catch {
            decoded = rawResponse;
          }
          resolve({ status: response.statusCode ?? 0, body: decoded });
        });
      },
    );
    outbound.once('error', reject);
    outbound.setTimeout(20_000, () => {
      outbound.destroy(new Error('RAW-B loopback request exceeded 20 seconds'));
    });
    outbound.end(body);
  });
}

function verifyResult(
  vector: ProbeVector,
  response: HttpResult,
  hashes: Map<string, string>,
): 'handler-accepted' | 'handler-rejected' | 'framework-rejected' {
  if (response.status !== 200) {
    assert.equal(vector.expected.kind, 'closed', `${vector.id}: unexpected framework rejection`);
    assert.ok([400, 413].includes(response.status), `${vector.id}: HTTP ${response.status}`);
    if (isRecord(response.body)) assert.equal(Object.hasOwn(response.body, 'result'), false);
    return 'framework-rejected';
  }

  const envelopeBody = asRecord(response.body, `${vector.id}: response envelope`);
  assert.deepEqual(Object.keys(envelopeBody), ['result']);
  const probe = asRecord(envelopeBody.result, `${vector.id}: result`);
  const digest = createHash('sha256').update(vector.body).digest('hex');
  assert.equal(probe.rawByteLength, vector.body.byteLength, `${vector.id}: byte length`);
  assert.equal(probe.rawSha256, digest, `${vector.id}: byte digest`);

  if (vector.expected.kind === 'accepted') {
    assert.deepEqual(Object.keys(probe).sort(), [
      'kind',
      'rawByteLength',
      'rawSha256',
      'semanticHash',
    ]);
    assert.equal(probe.kind, 'accepted', vector.id);
    assert.match(String(probe.semanticHash), /^[0-9a-f]{64}$/u);
    const previous = hashes.get(vector.expected.semanticGroup);
    if (previous === undefined)
      hashes.set(vector.expected.semanticGroup, String(probe.semanticHash));
    else assert.equal(probe.semanticHash, previous, `${vector.id}: semantic hash`);
    return 'handler-accepted';
  }

  assert.deepEqual(Object.keys(probe).sort(), ['kind', 'rawByteLength', 'rawSha256', 'reason']);
  assert.equal(probe.kind, 'rejected', vector.id);
  const expectedReason =
    vector.expected.kind === 'rejected' ? vector.expected.reason : vector.expected.adapterReason;
  if (expectedReason !== undefined) assert.equal(probe.reason, expectedReason, vector.id);
  return 'handler-rejected';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function asRecord(value: unknown, label: string): Record<string, unknown> {
  assert.ok(isRecord(value), label);
  return value;
}
