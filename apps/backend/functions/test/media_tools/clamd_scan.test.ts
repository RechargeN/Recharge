// D1 scanning on the real ClamAV 1.5.4 (amendment §3.5, §7, §8, §9): two
// instances started by scripts/media-tools.mjs — normal mode (no database
// exemption) and the L1 local test mode — driven through the real client.
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
  start(options: { instance: string; standSignaturesOnly: boolean }): Promise<Started>;
  stop(options: { instance: string }): Promise<void>;
}

const tools = (await import(
  pathToFileURL(path.resolve(process.cwd(), '..', 'scripts', 'media-tools.mjs')).href
)) as MediaTools;
const suffix = Date.now().toString(36);
const normalName = `scan-normal-${suffix}`;
const standName = `scan-stand-${suffix}`;
let normal: Started;
let stand: Started;

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
  normal = await tools.start({ instance: normalName, standSignaturesOnly: false });
  stand = await tools.start({ instance: standName, standSignaturesOnly: true });
});
after(async () => {
  for (const instance of [normalName, standName])
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

void test('normal mode: no official database keeps a clean file in quarantine', async () => {
  const outcome = await scan(normal, built.jpeg, false);
  assert.deepEqual(outcome, {
    toolRevision: 'clamav-1.5.4/no-database/official-db-absent',
    result: 'inconclusive',
  });
  // Even a client that would accept the exemption gets no clean from a normal service.
  assert.equal((await scan(normal, built.jpeg, true)).result, 'inconclusive');
});

void test('normal mode: the stand signature still blocks', async () => {
  const outcome = await scan(normal, Buffer.concat([built.jpeg, samples.markerText]), false);
  assert.equal(outcome.result, 'rejected');
});

void test('L1 test mode: clean only with the exemption on both sides, and labelled', async () => {
  const outcome = await scan(stand, built.jpeg, true);
  assert.deepEqual(outcome, {
    toolRevision: 'clamav-1.5.4/stand-marker-1/official-db-absent',
    result: 'clean',
  });
  assert.equal((await scan(stand, built.jpeg, false)).result, 'inconclusive');
});

void test('the marker inside a deflated ZIP behind a JPEG is found by unpacking', async () => {
  assert.equal(
    built.zipped.includes(Buffer.from('RECHARGE-D1-STAND-MARKER')),
    false,
    'not in plain bytes',
  );
  assert.equal((await scan(stand, built.zipped, true)).result, 'rejected');
});

void test('nesting beyond MaxRecursion is a scan limit: inconclusive, never clean', async () => {
  const deep = Buffer.concat([built.jpeg, samples.nestedZip(12)]);
  assert.equal((await scan(stand, deep, true)).result, 'inconclusive');
});

void test('structurally broken JPEG and PNG are flagged by AlertBrokenMedia', async () => {
  for (const bytes of built.broken)
    assert.equal((await scan(stand, bytes, true)).result, 'rejected');
});

void test(
  'EICAR (Linux gate only, §8)',
  {
    skip:
      process.platform === 'win32'
        ? 'Defender real-time protection active: clamd writes INSTREAM data to a temporary file (amendment §8)'
        : false,
  },
  async () => {
    assert.equal((await scan(stand, samples.eicarInMemory(), true)).result, 'rejected');
  },
);
