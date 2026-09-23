import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  isIanaTimezone,
  isUtcInstant,
  parseIanaTimezone,
  parseUtcInstant,
} from '../../../src/shared/utc_instant.js';

void test('normalizes valid UTC instants and rejects offsets or invalid dates', () => {
  assert.equal(parseUtcInstant('2026-09-21T10:00:00Z'), '2026-09-21T10:00:00.000Z');
  assert.equal(isUtcInstant('2026-09-21T10:00:00.123Z'), true);
  assert.equal(isUtcInstant('2026-09-21T13:00:00+03:00'), false);
  assert.equal(isUtcInstant('2026-02-30T10:00:00Z'), false);
});

void test('accepts IANA zones and never treats device offsets as zones', () => {
  assert.equal(parseIanaTimezone('Europe/Riga'), 'Europe/Riga');
  assert.equal(isIanaTimezone('Europe/Tallinn'), true);
  assert.equal(isIanaTimezone('Europe/Vilnius'), true);
  assert.equal(isIanaTimezone('+03:00'), false);
  assert.equal(isIanaTimezone('device'), false);
});
