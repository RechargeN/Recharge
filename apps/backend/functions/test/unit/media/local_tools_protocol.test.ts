import assert from 'node:assert/strict';
import test from 'node:test';

import {
  parseDatabase,
  parseProcessResponse,
  parseScanResponse,
  ToolsProtocolError,
} from '../../../src/modules/media/infrastructure/local_tools_protocol.js';

const limits = { maxVariantBytes: 409_600, profiles: ['display', 'thumb'] };
const variant = (profile: string) => ({
  profile,
  format: 'image/webp',
  width: 32,
  height: 32,
  byteLength: 3,
  sha256: 'a'.repeat(64),
  bytesBase64: 'AAAA',
});

void test('scan answers are checked field by field', () => {
  const ok = parseScanResponse({
    schemaVersion: 1,
    result: 'clean',
    toolRevision: 'clamav-1.5.4/stand-marker-1/official-db-absent',
    database: { state: 'absent', reason: 'no_official_daily', exemption: 'stand-signatures-only' },
  });
  assert.equal(ok.result, 'clean');
  for (const bad of [
    null,
    {
      schemaVersion: 2,
      result: 'clean',
      toolRevision: 'x',
      database: { state: 'absent', reason: 'r' },
    },
    {
      schemaVersion: 1,
      result: 'maybe',
      toolRevision: 'x',
      database: { state: 'absent', reason: 'r' },
    },
    {
      schemaVersion: 1,
      result: 'clean',
      toolRevision: '',
      database: { state: 'absent', reason: 'r' },
    },
    { schemaVersion: 1, result: 'clean', toolRevision: 'x', database: { state: 'sunny' } },
  ])
    assert.throws(() => parseScanResponse(bad), ToolsProtocolError);
});

void test('only the stand exemption value is accepted', () => {
  assert.throws(
    () => parseDatabase({ state: 'absent', reason: 'r', exemption: 'anything' }),
    ToolsProtocolError,
  );
  assert.deepEqual(parseDatabase({ state: 'absent', reason: 'r' }), {
    state: 'absent',
    reason: 'r',
  });
  assert.equal(
    parseDatabase({ state: 'fresh', daily: 1, builtAt: '2026-10-08T00:00:00Z' }).state,
    'fresh',
  );
});

void test('process answers: exactly the requested profiles, WebP, bounded, hashed', () => {
  const ok = parseProcessResponse(
    {
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: 'sharp-0.35.5/libvips-8.18.7/win32-x64-native',
      transformProfileRevision: 'd1-local-1',
      variants: [variant('display'), variant('thumb')],
    },
    limits,
  );
  assert.equal(ok.variants?.length, 2);
  const base = {
    schemaVersion: 1,
    result: 'succeeded',
    toolRevision: 't',
    transformProfileRevision: 'd1',
  };
  for (const variants of [
    [variant('display')],
    [variant('display'), variant('display')],
    [variant('display'), variant('poster')],
    [variant('display'), { ...variant('thumb'), format: 'image/png' }],
    [variant('display'), { ...variant('thumb'), byteLength: 409_601 }],
    [variant('display'), { ...variant('thumb'), sha256: 'nothex' }],
  ])
    assert.throws(() => parseProcessResponse({ ...base, variants }, limits), ToolsProtocolError);
  assert.deepEqual(
    parseProcessResponse(
      { schemaVersion: 1, result: 'rejected', toolRevision: 't', reason: 'decode_failed' },
      limits,
    ),
    { schemaVersion: 1, result: 'rejected', toolRevision: 't', reason: 'decode_failed' },
  );
});
