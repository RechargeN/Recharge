import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  asRecord,
  createBookingSchemaRegistry,
  readBookingJson,
  validateBoundedOpaquePayload,
} from '../support/booking_schema_registry.js';

const validGroups = {
  queries: 'booking_query.schema.json',
  reads: 'booking_read.schema.json',
  pages: 'booking_page.schema.json',
  availability: 'booking_availability.schema.json',
} as const;

void test('shared query and response fixtures pass actual schema validation', async () => {
  const registry = await createBookingSchemaRegistry();
  const container = asRecord(await readBookingJson('fixtures/query_valid.json'));
  for (const [group, schema] of Object.entries(validGroups)) {
    const values = container[group];
    assert.ok(Array.isArray(values), group);
    const validate = registry.validator(schema);
    for (const value of values)
      assert.equal(validate(value), true, JSON.stringify(validate.errors));
  }
});

for (const fixtureFile of ['query_invalid.json', 'query_forward.json'] as const) {
  void test(`${fixtureFile} remains fail-closed`, async () => {
    const registry = await createBookingSchemaRegistry();
    const container = asRecord(await readBookingJson(`fixtures/${fixtureFile}`));
    assert.ok(Array.isArray(container.cases));
    for (const raw of container.cases) {
      const fixture = asRecord(raw);
      const validate = registry.validator(String(fixture.schema));
      assert.equal(validate(fixture.value), false, String(fixture.reason));
    }
  });
}

void test('opaque unsupported payloads enforce byte and depth bounds', () => {
  assert.deepEqual(validateBoundedOpaquePayload({ future: 'safe' }), []);
  const oversized = Object.fromEntries(
    Array.from({ length: 9 }, (_, index) => [`field${String(index)}`, 'x'.repeat(512)]),
  );
  assert.ok(validateBoundedOpaquePayload(oversized).some((failure) => failure.includes('4096')));
  let tooDeep: unknown = 'leaf';
  for (let index = 0; index < 9; index += 1) tooDeep = { nested: tooDeep };
  assert.ok(validateBoundedOpaquePayload(tooDeep).some((failure) => failure.includes('depth 8')));
});

void test('cursor maximum is enforced at 2048 printable ASCII characters', async () => {
  const registry = await createBookingSchemaRegistry();
  const validate = registry.validator('booking_query.schema.json');
  assert.equal(
    validate({
      schemaVersion: 1,
      queryType: 'listMyBookings',
      requestId: 'cursor-max',
      payload: { cursor: 'x'.repeat(2049) },
    }),
    false,
  );
});
