import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildR0ProbeResult } from '../../src/r0_toolchain_probe.js';

void test('returns the fixed emulator-only response without unstable fields', () => {
  assert.deepEqual(buildR0ProbeResult(true), {
    schemaVersion: 1,
    status: 'emulator_only',
    runtimeMajor: 22,
  });
});

void test('fails closed outside the emulator', () => {
  assert.deepEqual(buildR0ProbeResult(false), {
    schemaVersion: 1,
    status: 'unavailable',
    code: 'emulator_required',
  });
});
