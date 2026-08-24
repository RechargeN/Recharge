import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { test } from 'node:test';

const bookingContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'booking',
  'v1',
);

const schemaFiles = [
  'common.schema.json',
  'booking.schema.json',
  'booking_hold.schema.json',
  'booking_policy.schema.json',
  'booking_command.schema.json',
  'booking_result.schema.json',
  'booking_error.schema.json',
] as const;

async function readJson(filePath: string): Promise<unknown> {
  return JSON.parse(await readFile(filePath, 'utf8')) as unknown;
}

function asRecord(value: unknown): Record<string, unknown> {
  assert.equal(typeof value, 'object');
  assert.notEqual(value, null);
  assert.equal(Array.isArray(value), false);
  return value as Record<string, unknown>;
}

void test('all canonical Booking v1 schemas remain parseable and version-owned', async () => {
  for (const fileName of schemaFiles) {
    const schema = asRecord(await readJson(path.join(bookingContractRoot, fileName)));
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
    assert.match(String(schema.$id), /^https:\/\/recharge\.app\/schemas\/booking\/v1\//u);
  }
});

void test('valid, invalid and forward fixture containers remain readable without mutation', async () => {
  const valid = asRecord(await readJson(path.join(bookingContractRoot, 'fixtures', 'valid.json')));
  const invalid = asRecord(
    await readJson(path.join(bookingContractRoot, 'fixtures', 'invalid.json')),
  );
  const forward = asRecord(
    await readJson(path.join(bookingContractRoot, 'fixtures', 'forward.json')),
  );

  assert.ok(Array.isArray(valid.bookings));
  assert.ok(Array.isArray(valid.holds));
  assert.ok(Array.isArray(valid.commands));
  assert.ok(Array.isArray(invalid.cases));
  assert.ok(Array.isArray(forward.cases));

  const commandSchema = asRecord(
    await readJson(path.join(bookingContractRoot, 'booking_command.schema.json')),
  );
  assert.deepEqual(commandSchema.required, [
    'schemaVersion',
    'commandType',
    'requestId',
    'idempotencyKey',
    'payload',
  ]);
});
