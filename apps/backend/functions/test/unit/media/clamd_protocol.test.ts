import assert from 'node:assert/strict';
import test from 'node:test';

import {
  databaseState,
  instreamFrames,
  parseScanReply,
  parseVersion,
  scanVerdict,
  type DatabaseState,
} from '../../../src/modules/media/infrastructure/clamd_protocol.js';
import { databaseMaxAgeMs } from '../../../src/modules/media/infrastructure/media_tool_limits.js';

void test('INSTREAM frames: command, length-prefixed chunks, zero terminator', () => {
  const frames = instreamFrames(Buffer.from('abcdefg'), 3);
  assert.equal(frames[0]?.toString('ascii'), 'zINSTREAM\0');
  assert.deepEqual(
    frames.slice(1).map((frame) => frame.toString('hex')),
    ['00000003', '616263', '00000003', '646566', '00000001', '67', '00000000'],
  );
  assert.equal(instreamFrames(Buffer.alloc(0), 4).length, 2);
  assert.throws(() => instreamFrames(Buffer.from('x'), 0), RangeError);
});

void test('scan replies: OK, FOUND, size limit and anything else', () => {
  assert.deepEqual(parseScanReply('stream: OK\0'), { kind: 'ok' });
  assert.deepEqual(parseScanReply('stream: Recharge.Test.Marker.UNOFFICIAL FOUND\0'), {
    kind: 'found',
    signature: 'Recharge.Test.Marker.UNOFFICIAL',
  });
  assert.deepEqual(parseScanReply('INSTREAM size limit exceeded. ERROR\0'), {
    kind: 'error',
    reason: 'size_limit',
  });
  assert.deepEqual(parseScanReply("stream: Can't allocate memory ERROR"), {
    kind: 'error',
    reason: 'clamd_error',
  });
  assert.deepEqual(parseScanReply(''), { kind: 'error', reason: 'unparsed_reply' });
  assert.deepEqual(parseScanReply('stream: OK and more'), {
    kind: 'error',
    reason: 'unparsed_reply',
  });
});

void test('VERSION: engine only (no official daily), full, or unreadable', () => {
  assert.deepEqual(parseVersion('ClamAV 1.5.4\0'), { engine: '1.5.4' });
  const full = parseVersion('ClamAV 1.5.4/27800/Wed Oct  8 09:21:02 2026');
  assert.equal(full?.engine, '1.5.4');
  assert.equal(full?.daily, 27800);
  assert.deepEqual(full?.builtAt, new Date(2026, 9, 8, 9, 21, 2));
  assert.equal(parseVersion('ClamAV 1.5.4/27800/Xyz Foo  8 09:21:02 2026'), null);
  assert.equal(parseVersion('something else'), null);
});

void test('database state: exactly seven days is fresh, one second more is stale', () => {
  const builtAt = new Date(2026, 9, 1, 12, 0, 0);
  const version = { engine: '1.5.4', daily: 27800, builtAt };
  const at = (ms: number) => databaseState(version, new Date(builtAt.getTime() + ms));
  assert.equal(at(0).state, 'fresh');
  assert.equal(at(databaseMaxAgeMs).state, 'fresh');
  assert.equal(at(databaseMaxAgeMs + 1000).state, 'stale');
});

void test('database state: no official daily, an unreadable reply or a future build is absent', () => {
  const now = new Date(2026, 9, 9);
  assert.deepEqual(databaseState({ engine: '1.5.4' }, now), {
    state: 'absent',
    reason: 'no_official_daily',
  });
  assert.deepEqual(databaseState(null, now), { state: 'absent', reason: 'unparsed' });
  assert.deepEqual(
    databaseState({ engine: '1.5.4', daily: 1, builtAt: new Date(2026, 9, 10) }, now),
    { state: 'absent', reason: 'future' },
  );
});

const absent: DatabaseState = { state: 'absent', reason: 'no_official_daily' };
const fresh: DatabaseState = { state: 'fresh', daily: 27800, builtAt: '2026-10-08T00:00:00.000Z' };
const stale: DatabaseState = { state: 'stale', daily: 27700, builtAt: '2026-09-01T00:00:00.000Z' };
const verdict = (
  reply: Parameters<typeof scanVerdict>[0]['reply'],
  database: DatabaseState,
  standSignaturesOnly: boolean,
) => scanVerdict({ reply, database, engine: '1.5.4', standSignaturesOnly });

void test('a missing official database is never a pass in normal mode', () => {
  const normal = verdict({ kind: 'ok' }, absent, false);
  assert.equal(normal.result, 'inconclusive');
  assert.equal(normal.reason, 'database_absent');
  assert.equal(normal.toolRevision, 'clamav-1.5.4/no-database/official-db-absent');
});

void test('only the explicit L1 stand exemption turns OK on an absent database into clean', () => {
  const stand = verdict({ kind: 'ok' }, absent, true);
  assert.equal(stand.result, 'clean');
  assert.equal(stand.toolRevision, 'clamav-1.5.4/stand-marker-1/official-db-absent');
  assert.equal(stand.reason, 'official_db_absent_stand_exemption');
});

void test('fresh is clean, stale is inconclusive, FOUND blocks whatever the database', () => {
  assert.equal(verdict({ kind: 'ok' }, fresh, false).result, 'clean');
  assert.equal(verdict({ kind: 'ok' }, fresh, false).toolRevision, 'clamav-1.5.4/daily-27800');
  const old = verdict({ kind: 'ok' }, stale, true);
  assert.equal(old.result, 'inconclusive');
  assert.equal(old.toolRevision, 'clamav-1.5.4/daily-27700/stale');
  for (const database of [absent, fresh, stale])
    for (const exemption of [false, true])
      assert.equal(
        verdict(
          { kind: 'found', signature: 'Recharge.Test.Marker.UNOFFICIAL' },
          database,
          exemption,
        ).result,
        'rejected',
      );
});

void test('limit heuristics and errors are inconclusive, never clean', () => {
  const limits = verdict(
    { kind: 'found', signature: 'Heuristics.Limits.Exceeded.MaxRecursion' },
    fresh,
    false,
  );
  assert.equal(limits.result, 'inconclusive');
  assert.equal(limits.reason, 'scan_limit');
  assert.equal(
    verdict({ kind: 'error', reason: 'size_limit' }, fresh, true).result,
    'inconclusive',
  );
  assert.equal(
    verdict({ kind: 'found', signature: 'Heuristics.Broken.Media.JPEG.Truncated' }, absent, true)
      .result,
    'rejected',
  );
});
