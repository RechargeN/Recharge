import assert from 'node:assert/strict';
import test from 'node:test';

import { requireValidInstant, systemServerClock } from '../../../src/shared/server_clock.js';

void test('server clock yields a valid instant without changing RAW-C contract', () => {
  assert.ok(Number.isFinite(requireValidInstant(systemServerClock.now()).getTime()));
  assert.throws(() => requireValidInstant(new Date(Number.NaN)), /invalid_server_time/);
});
