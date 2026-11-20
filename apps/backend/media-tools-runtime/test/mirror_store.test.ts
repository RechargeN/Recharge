import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  MirrorStore,
  mirrorBucketFor,
  newestSet,
  parseCvdHeader,
  parseMirrorSet,
  setStamp,
  type Fetch,
} from '../src/mirror_store.js';
import { publish, readDatabaseDir } from '../src/publish_databases.js';
import { fetchNewestSet } from '../src/scanner_prepare.js';

/**
 * In-memory GCS JSON API: list, media download, create-only media upload, and
 * the metadata server (token and the running project's id).
 */
function fakeGcs(projectId = 'recharge-dev-n2a01') {
  const objects = new Map<string, Buffer>();
  const calls: string[] = [];
  const buckets = new Set<string>();
  const fetchImpl: Fetch = (url, init) => {
    const target = new URL(url);
    const method = init?.method ?? 'GET';
    calls.push(`${method} ${target.pathname}`);
    if (target.hostname === 'metadata.google.internal') {
      if (target.pathname === '/computeMetadata/v1/project/project-id')
        return Promise.resolve(new Response(projectId));
      return Promise.resolve(Response.json({ access_token: 'tok', expires_in: 3600 }));
    }
    const bucket = /\/b\/([^/]+)\/o/u.exec(target.pathname)?.[1];
    if (bucket !== undefined) buckets.add(bucket);
    if (new Headers(init?.headers).get('authorization') !== 'Bearer tok')
      return Promise.resolve(new Response('', { status: 401 }));
    const upload = /^\/upload\/storage\/v1\/b\/[^/]+\/o$/u.test(target.pathname);
    if (upload && method === 'POST') {
      const name = target.searchParams.get('name') ?? '';
      if (target.searchParams.get('ifGenerationMatch') !== '0')
        return Promise.resolve(new Response('', { status: 400 }));
      if (objects.has(name)) return Promise.resolve(new Response('', { status: 412 }));
      objects.set(name, Buffer.from(init?.body as Uint8Array));
      return Promise.resolve(Response.json({ name }));
    }
    const list = /^\/storage\/v1\/b\/[^/]+\/o$/u.test(target.pathname);
    if (list) {
      const prefix = target.searchParams.get('prefix') ?? '';
      const names = [...objects.keys()].filter((name) => name.startsWith(prefix)).sort();
      const start = Number(target.searchParams.get('pageToken') ?? '0');
      const page = names.slice(start, start + 2);
      return Promise.resolve(
        Response.json({
          items: page.map((name) => ({ name })),
          ...(start + 2 < names.length ? { nextPageToken: String(start + 2) } : {}),
        }),
      );
    }
    const single = /^\/storage\/v1\/b\/[^/]+\/o\/(.+)$/u.exec(target.pathname);
    if (single?.[1] !== undefined) {
      const bytes = objects.get(decodeURIComponent(single[1]));
      if (bytes === undefined) return Promise.resolve(new Response('', { status: 404 }));
      if (target.searchParams.get('alt') === 'media') return Promise.resolve(new Response(bytes));
      return Promise.resolve(
        Response.json({
          size: String(bytes.length),
          md5Hash: createHash('md5').update(bytes).digest('base64'),
        }),
      );
    }
    return Promise.resolve(new Response('', { status: 404 }));
  };
  return { objects, calls, buckets, store: new MirrorStore(fetchImpl) };
}

function cvd(version: number, stime: number, body: string): Buffer {
  const header = Buffer.alloc(512, ' ');
  header.write(
    `ClamAV-VDB:06 Nov 2026 09-00 +0000:${version}:100:90:md5:dsig:builder:${stime}`,
    'latin1',
  );
  return Buffer.concat([header, Buffer.from(body)]);
}

function databaseDir(dailyVersion: number): string {
  const dir = mkdtempSync(path.join(tmpdir(), 'n3b-db-'));
  writeFileSync(path.join(dir, 'main.cvd'), cvd(62, 1_700_000_000, 'main'));
  writeFileSync(
    path.join(dir, 'daily.cvd'),
    cvd(dailyVersion, 1_793_000_000 + dailyVersion, 'daily'),
  );
  writeFileSync(path.join(dir, 'bytecode.cvd'), cvd(339, 1_750_000_000, 'bytecode'));
  writeFileSync(path.join(dir, 'freshclam.dat'), 'state');
  return dir;
}

void test('CVD header: version and build time; anything else refused', () => {
  assert.deepEqual(parseCvdHeader(cvd(27800, 1_793_000_000, 'x')), {
    version: 27800,
    builtAtUtc: new Date(1_793_000_000 * 1000).toISOString(),
  });
  assert.throws(() => parseCvdHeader(Buffer.from('not a database')));
  assert.equal(setStamp(new Date('2026-11-07T04:00:05.123Z')), '20261107T040005Z');
  assert.equal(
    newestSet(['sets/20261101T000000Z.json', 'sets/20261107T000000Z.json', 'sets/x.json']),
    'sets/20261107T000000Z.json',
  );
  assert.equal(newestSet(['cvd/a.cvd']), null);
});

void test('set manifest: exactly main/daily/bytecode, content-addressed, bounded', () => {
  const file = (name: string) => ({
    name,
    object: `cvd/${'a'.repeat(64)}.cvd`,
    sha256: 'a'.repeat(64),
    size: 1000,
    version: 1,
    builtAtUtc: '2026-11-06T00:00:00.000Z',
  });
  const good = {
    schemaVersion: 1,
    createdAtUtc: '2026-11-07T00:00:00.000Z',
    files: [file('main.cvd'), file('daily.cvd'), file('bytecode.cvd')],
  };
  assert.equal(parseMirrorSet(good).files.length, 3);
  assert.throws(() => parseMirrorSet({ ...good, files: good.files.slice(0, 2) }));
  assert.throws(() =>
    parseMirrorSet({
      ...good,
      files: [file('main.cvd'), file('daily.cvd'), file('evil.ndb')],
    }),
  );
  assert.throws(() =>
    parseMirrorSet({
      ...good,
      files: [
        file('main.cvd'),
        file('daily.cvd'),
        { ...file('bytecode.cvd'), object: 'sets/x.json' },
      ],
    }),
  );
  assert.throws(() =>
    parseMirrorSet({
      ...good,
      files: [file('main.cvd'), file('daily.cvd'), { ...file('bytecode.cvd'), size: 500_000_000 }],
    }),
  );
});

void test('publish: create-only, unchanged files reused, a new set per run, nothing deleted', async () => {
  const gcs = fakeGcs();
  const first = databaseDir(27800);
  const second = databaseDir(27801);
  try {
    const one = await publish(gcs.store, first, new Date('2026-11-07T04:00:00Z'));
    assert.deepEqual(one.created.sort(), ['bytecode.cvd', 'daily.cvd', 'main.cvd']);
    const two = await publish(gcs.store, second, new Date('2026-11-10T04:00:00Z'));
    assert.deepEqual(two.created, ['daily.cvd']);
    assert.deepEqual(two.existing.sort(), ['bytecode.cvd', 'main.cvd']);
    assert.equal([...gcs.objects.keys()].filter((name) => name.startsWith('sets/')).length, 2);
    assert.equal([...gcs.objects.keys()].filter((name) => name.startsWith('cvd/')).length, 4);
    assert.ok(gcs.calls.every((call) => !call.startsWith('DELETE') && !call.startsWith('PUT')));
    // The same stamp twice is refused instead of overwriting the set.
    await assert.rejects(
      publish(gcs.store, second, new Date('2026-11-10T04:00:00Z')),
      /set already exists/u,
    );
  } finally {
    rmSync(first, { recursive: true, force: true });
    rmSync(second, { recursive: true, force: true });
  }
});

void test('publish: an existing object with other bytes, a .cld or a missing file stops the job', async () => {
  const gcs = fakeGcs();
  const dir = databaseDir(27800);
  try {
    const { file } = readDatabaseDir(dir)[1]!;
    gcs.objects.set(file.object, Buffer.from('tampered'));
    await assert.rejects(
      publish(gcs.store, dir, new Date('2026-11-07T04:00:00Z')),
      /existing object differs/u,
    );
    writeFileSync(path.join(dir, 'daily.cld'), 'x');
    assert.throws(() => readDatabaseDir(dir), /incremental databases refused/u);
    rmSync(path.join(dir, 'daily.cld'));
    rmSync(path.join(dir, 'bytecode.cvd'));
    assert.throws(() => readDatabaseDir(dir), /bytecode\.cvd missing/u);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

void test('scanner fetch: newest set only, every byte checked against the set', async () => {
  const gcs = fakeGcs();
  const older = databaseDir(27799);
  const newer = databaseDir(27801);
  const target = mkdtempSync(path.join(tmpdir(), 'n3b-fetch-'));
  const tampered = mkdtempSync(path.join(tmpdir(), 'n3b-fetch-'));
  try {
    await publish(gcs.store, older, new Date('2026-11-01T04:00:00Z'));
    await publish(gcs.store, newer, new Date('2026-11-07T04:00:00Z'));
    gcs.objects.set('sets/garbage.json', Buffer.from('{}'));
    const fetched = await fetchNewestSet(gcs.store, target);
    assert.equal(fetched.name, 'sets/20261107T040000Z.json');
    assert.deepEqual(readdirSync(target).sort(), ['bytecode.cvd', 'daily.cvd', 'main.cvd']);
    assert.deepEqual(
      readFileSync(path.join(target, 'daily.cvd')),
      readFileSync(path.join(newer, 'daily.cvd')),
    );
    const daily = fetched.files.find((file) => file.name === 'daily.cvd')!;
    gcs.objects.set(daily.object, Buffer.from('swapped'));
    await assert.rejects(fetchNewestSet(gcs.store, tampered), /differs from its set/u);
    // A non-empty target is never merged into.
    await assert.rejects(fetchNewestSet(gcs.store, target), /not empty/u);
  } finally {
    for (const dir of [older, newer, target, tampered])
      rmSync(dir, { recursive: true, force: true });
  }
});

void test('N4b: each reviewed project uses only its own mirror bucket', async () => {
  for (const project of ['recharge-dev-n2a01', 'recharge-staging-y9y2y']) {
    const gcs = fakeGcs(project);
    const dir = databaseDir(27801);
    const target = mkdtempSync(path.join(tmpdir(), 'n4b-fetch-'));
    try {
      await publish(gcs.store, dir, new Date('2026-11-15T18:00:00Z'));
      await fetchNewestSet(gcs.store, target);
      assert.deepEqual([...gcs.buckets], [`${project}-clamav-mirror`]);
      assert.equal(mirrorBucketFor(project), `${project}-clamav-mirror`);
    } finally {
      for (const d of [dir, target]) rmSync(d, { recursive: true, force: true });
    }
  }
});

void test('N4b: an unreviewed project never reaches any bucket', async () => {
  for (const project of ['recharge-prod', '', 'recharge-dev-n2a01-x']) {
    const gcs = fakeGcs(project);
    const dir = databaseDir(27801);
    try {
      await assert.rejects(
        publish(gcs.store, dir, new Date('2026-11-15T18:00:00Z')),
        /project not reviewed/u,
      );
      assert.equal(gcs.buckets.size, 0);
      assert.ok(gcs.calls.every((call) => !call.includes('/storage/')));
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
    assert.throws(() => mirrorBucketFor(project), /project not reviewed/u);
  }
});

void test('N4b: the mirror list matches the reviewed cloud projects of the functions', () => {
  const source = readFileSync(
    // Compiled to build/media-tools-runtime/test/: four levels up is apps/backend.
    new URL('../../../../functions/src/shared/cloud_runtime_projects.ts', import.meta.url),
    'utf8',
  );
  const declared = [...source.matchAll(/CloudProject = '([^']+)'/gu)].map((m) => m[1]);
  assert.deepEqual(declared, ['recharge-dev-n2a01', 'recharge-staging-y9y2y']);
  for (const project of declared) assert.doesNotThrow(() => mirrorBucketFor(project!));
});
