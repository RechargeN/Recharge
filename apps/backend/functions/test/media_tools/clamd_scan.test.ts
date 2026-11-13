// D1 scanning on the real ClamAV 1.5.4 (amendment §3.5, §7, §8, §9, §15),
// driven through the real client. Two database modes:
// - `stand` (Windows, L1): no official database; a normal instance and the L1
//   local test mode instance;
// - `official` (the Linux CI gate): the official databases plus the stand
//   signature, no exemption anywhere.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { pathToFileURL } from 'node:url';

import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { LocalToolsScanner } from '../../src/modules/media/infrastructure/local_tools_client.js';
import * as samples from '../support/media_samples.js';

interface Started {
  readonly port: number;
  readonly token: string;
}
interface MediaTools {
  start(options: {
    instance: string;
    standSignaturesOnly: boolean;
    databaseMode?: 'stand' | 'official';
  }): Promise<Started>;
  stop(options: { instance: string }): Promise<void>;
}

/** Skip reasons the D1 gates accept; any other skip fails a gate. */
export const skipReasons = Object.freeze({
  defender:
    'Defender real-time protection active: clamd writes INSTREAM data to a temporary file (amendment §8); runs in the Linux gate',
  linuxGate: 'Linux gate only: needs the official databases (amendment §15)',
  l1Only: 'L1 only: the Linux gate loads the official databases',
});

const mode = process.env.RECHARGE_MEDIA_TOOLS_DATABASE_MODE === 'official' ? 'official' : 'stand';
const official = mode === 'official';
const tools = (await import(
  pathToFileURL(path.resolve(process.cwd(), '..', 'scripts', 'media-tools.mjs')).href
)) as MediaTools;
const suffix = Date.now().toString(36);
const names = official
  ? { normal: `scan-official-${suffix}` }
  : { normal: `scan-normal-${suffix}`, stand: `scan-stand-${suffix}` };
let normal: Started;
/** The instance the shared checks use: L1 test mode, or the official one. */
let scanner: Started;
/** Whether the client accepts the stand exemption in the shared checks. */
const sharedExemption = !official;

const largeJpeg = await samples.jpeg(256, 256);
const largePng = await samples.png(256, 256);
const built = {
  jpeg: await samples.jpeg(),
  zipped: await samples.jpegWithZippedMarker(),
  // Structural damage clamd recognises; damage inside the compressed image
  // data is left to the decoder (failOn), see image_pipeline.test.ts.
  broken: [
    samples.truncated(largeJpeg, 0.2),
    samples.corruptHeader(largeJpeg),
    samples.truncated(largePng),
  ],
};

before(async () => {
  normal = await tools.start({
    instance: names.normal,
    standSignaturesOnly: false,
    databaseMode: mode,
  });
  scanner =
    names.stand === undefined
      ? normal
      : await tools.start({ instance: names.stand, standSignaturesOnly: true });
});
after(async () => {
  for (const instance of Object.values(names))
    await tools.stop({ instance }).catch(() => undefined);
});

async function scan(service: Started, bytes: Buffer, clientExemption: boolean) {
  const store = new FakeObjectStore();
  store.putBytes('objk:sample', 'gen-1', bytes);
  return new LocalToolsScanner(
    { port: service.port, token: service.token, standSignaturesOnly: clientExemption },
    store,
  ).scan({
    assetId: 'a',
    objectKeyHandle: 'objk:sample',
    providerGeneration: 'gen-1',
    sha256: createHash('sha256').update(bytes).digest('hex'),
    policyRevision: 'p',
  });
}

void test(
  'normal mode: no official database keeps a clean file in quarantine',
  { skip: official ? skipReasons.l1Only : false },
  async () => {
    const outcome = await scan(normal, built.jpeg, false);
    assert.deepEqual(outcome, {
      toolRevision: 'clamav-1.5.4/no-database/official-db-absent',
      result: 'inconclusive',
    });
    // Even a client that would accept the exemption gets no clean from a normal service.
    assert.equal((await scan(normal, built.jpeg, true)).result, 'inconclusive');
  },
);

void test(
  'L1 test mode: clean only with the exemption on both sides, and labelled',
  { skip: official ? skipReasons.l1Only : false },
  async () => {
    const outcome = await scan(scanner, built.jpeg, true);
    assert.deepEqual(outcome, {
      toolRevision: 'clamav-1.5.4/stand-marker-1/official-db-absent',
      result: 'clean',
    });
    assert.equal((await scan(scanner, built.jpeg, false)).result, 'inconclusive');
  },
);

void test(
  'official databases: a clean file is clean without any exemption, labelled with the daily',
  { skip: official ? false : skipReasons.linuxGate },
  async () => {
    const outcome = await scan(normal, built.jpeg, false);
    assert.equal(outcome.result, 'clean');
    assert.match(outcome.toolRevision, /^clamav-1\.5\.4\/daily-\d+$/u);
  },
);

void test('normal mode: the stand signature still blocks', async () => {
  const outcome = await scan(normal, Buffer.concat([built.jpeg, samples.markerText]), false);
  assert.equal(outcome.result, 'rejected');
});

void test('the marker inside a deflated ZIP behind a JPEG is found by unpacking', async () => {
  assert.equal(
    built.zipped.includes(Buffer.from('RECHARGE-D1-STAND-MARKER')),
    false,
    'not in plain bytes',
  );
  assert.equal((await scan(scanner, built.zipped, sharedExemption)).result, 'rejected');
});

void test('nesting beyond MaxRecursion is a scan limit: inconclusive, never clean', async () => {
  const deep = Buffer.concat([built.jpeg, samples.nestedZip(12)]);
  assert.equal((await scan(scanner, deep, sharedExemption)).result, 'inconclusive');
});

void test('structurally broken JPEG and PNG are flagged by AlertBrokenMedia', async () => {
  for (const bytes of built.broken)
    assert.equal((await scan(scanner, bytes, sharedExemption)).result, 'rejected');
});

void test(
  'EICAR is rejected by the official signatures (built in memory only)',
  { skip: official ? false : skipReasons.defender },
  async () => {
    const outcome = await scan(normal, samples.eicarInMemory(), false);
    assert.equal(outcome.result, 'rejected');
  },
);
