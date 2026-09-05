import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  asRecord,
  bookingSchemaFiles,
  createBookingSchemaRegistry,
  readBookingJson,
} from '../support/booking_schema_registry.js';

const validGroups = {
  bookings: 'booking.schema.json',
  holds: 'booking_hold.schema.json',
  policies: 'booking_policy.schema.json',
  commands: 'booking_command.schema.json',
  errors: 'booking_error.schema.json',
  results: 'booking_result.schema.json',
} as const;

void test('all canonical Booking v1 schema ids are unique and registered', async () => {
  const registry = await createBookingSchemaRegistry();
  assert.equal(registry.ids.length, bookingSchemaFiles.length);
  assert.equal(new Set(registry.ids).size, bookingSchemaFiles.length);
  for (const fileName of bookingSchemaFiles)
    assert.equal(typeof registry.validator(fileName), 'function');
});

void test('existing valid fixtures pass actual Draft 2020-12 validation', async () => {
  const registry = await createBookingSchemaRegistry();
  const container = asRecord(await readBookingJson('fixtures/valid.json'));
  for (const [group, schema] of Object.entries(validGroups)) {
    const values = container[group];
    assert.ok(Array.isArray(values), group);
    const validate = registry.validator(schema);
    for (const value of values)
      assert.equal(validate(value), true, JSON.stringify(validate.errors));
  }
});

void test('existing invalid and forward fixtures retain fail-closed verdicts', async () => {
  const registry = await createBookingSchemaRegistry();
  const invalid = asRecord(await readBookingJson('fixtures/invalid.json'));
  assert.ok(Array.isArray(invalid.cases));
  const byTarget: Record<string, string> = {
    booking: 'booking.schema.json',
    hold: 'booking_hold.schema.json',
    policy: 'booking_policy.schema.json',
    command: 'booking_command.schema.json',
    error: 'booking_error.schema.json',
  };
  for (const raw of invalid.cases) {
    const fixture = asRecord(raw);
    const schema = byTarget[String(fixture.target)];
    assert.notEqual(schema, undefined);
    const validate = registry.validator(schema!);
    const schemaRejected = !validate(fixture.value);
    const value = asRecord(fixture.value);
    const frozenDartInvariantRejected =
      (fixture.target === 'booking' &&
        Object.hasOwn(value, 'inventoryPoolId') !== Object.hasOwn(value, 'channel')) ||
      (fixture.target === 'hold' &&
        value.state !== 'active' &&
        !Object.hasOwn(value, 'resolvedAt'));
    assert.equal(schemaRejected || frozenDartInvariantRejected, true, String(fixture.reason));
  }

  const forward = asRecord(await readBookingJson('fixtures/forward.json'));
  assert.ok(Array.isArray(forward.cases));
  const validateResult = registry.validator('booking_result.schema.json');
  for (const raw of forward.cases) {
    const fixture = asRecord(raw);
    assert.equal(validateResult(fixture.value), false, String(fixture.reason));
  }
});
