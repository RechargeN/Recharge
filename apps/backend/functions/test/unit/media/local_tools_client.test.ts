import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { after, before, test } from 'node:test';

import type { EntityId } from '../../../src/shared/ids.js';
import { FakeObjectStore } from '../../../src/modules/media/infrastructure/fake_object_store.js';
import {
  cleanAccepted,
  LocalToolsProcessor,
  LocalToolsScanner,
  localToolsConfigFrom,
  type LocalToolsConfig,
} from '../../../src/modules/media/infrastructure/local_tools_client.js';

const token = 'ab'.repeat(32);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

void test('the switch: absent keeps the fakes; anything invalid refuses to start', () => {
  assert.equal(localToolsConfigFrom({}), null);
  const valid = {
    RECHARGE_MEDIA_TOOLS: 'local-real',
    RECHARGE_MEDIA_TOOLS_PORT: '50123',
    RECHARGE_MEDIA_TOOLS_TOKEN: token,
  };
  assert.deepEqual(localToolsConfigFrom(valid), { port: 50123, token, standSignaturesOnly: false });
  assert.equal(
    localToolsConfigFrom({ ...valid, RECHARGE_MEDIA_TOOLS_DATABASE: 'stand-signatures-only' })
      ?.standSignaturesOnly,
    true,
  );
  for (const broken of [
    { ...valid, RECHARGE_MEDIA_TOOLS: 'cloud' },
    { ...valid, RECHARGE_MEDIA_TOOLS_PORT: '80' },
    { ...valid, RECHARGE_MEDIA_TOOLS_TOKEN: 'short' },
    { ...valid, RECHARGE_MEDIA_TOOLS_DATABASE: 'official-missing-is-fine' },
  ])
    assert.throws(() => localToolsConfigFrom(broken));
});

void test('the client accepts clean on an absent database only with the stand exemption on both sides', () => {
  const normal: LocalToolsConfig = { port: 1, token, standSignaturesOnly: false };
  const stand: LocalToolsConfig = { ...normal, standSignaturesOnly: true };
  const exempt = {
    state: 'absent',
    reason: 'no_official_daily',
    exemption: 'stand-signatures-only',
  } as const;
  assert.equal(cleanAccepted(exempt, normal), false);
  assert.equal(cleanAccepted(exempt, stand), true);
  assert.equal(cleanAccepted({ state: 'absent', reason: 'no_official_daily' }, stand), false);
  assert.equal(cleanAccepted({ state: 'stale', daily: 1, builtAt: 'x' }, stand), false);
  assert.equal(cleanAccepted({ state: 'fresh', daily: 1, builtAt: 'x' }, normal), true);
});

// A programmable stand-in for the service.
let answer: { status: number; body: string } = { status: 200, body: '{}' };
const seen: { path: string; headers: Record<string, unknown>; length: number }[] = [];
let server: Server;
let port = 0;
before(async () => {
  server = createServer((request, response) => {
    const chunks: Buffer[] = [];
    request.on('data', (chunk: Buffer) => chunks.push(chunk));
    request.on('end', () => {
      seen.push({
        path: request.url ?? '',
        headers: request.headers,
        length: Buffer.concat(chunks).length,
      });
      response.writeHead(answer.status, { 'content-type': 'application/json' });
      response.end(answer.body);
    });
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  port = (server.address() as AddressInfo).port;
});
after(() => server.close());

const source = Buffer.from('source bytes of a picture');
function store() {
  const objects = new FakeObjectStore();
  objects.putBytes('objk:source', 'gen-1', source);
  return objects;
}
const scanRequest = {
  assetId: 'a' as EntityId,
  objectKeyHandle: 'objk:source',
  providerGeneration: 'gen-1',
  sha256: sha256(source),
  policyRevision: 'p',
};

void test('scanner: the service is asked only about the exact finalized bytes', async () => {
  const config: LocalToolsConfig = { port, token, standSignaturesOnly: false };
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'clean',
      toolRevision: 'clamav-1.5.4/daily-1',
      database: { state: 'fresh', daily: 1, builtAt: 'x' },
    }),
  };
  const before = seen.length;
  assert.deepEqual(await new LocalToolsScanner(config, store()).scan(scanRequest), {
    toolRevision: 'clamav-1.5.4/daily-1',
    result: 'clean',
  });
  assert.equal(seen.at(-1)?.headers['x-recharge-sha256'], sha256(source));
  assert.equal(seen.at(-1)?.headers.authorization, `Bearer ${token}`);
  // Another generation or other bytes: not sent, inconclusive.
  const changed = await new LocalToolsScanner(config, store()).scan({
    ...scanRequest,
    providerGeneration: 'gen-2',
  });
  const missing = await new LocalToolsScanner(config, new FakeObjectStore()).scan(scanRequest);
  assert.equal(changed.result, 'inconclusive');
  assert.equal(missing.result, 'inconclusive');
  assert.equal(seen.length, before + 1);
});

void test('scanner: an exempt clean answer becomes inconclusive without the client exemption', async () => {
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'clean',
      toolRevision: 'clamav-1.5.4/stand-marker-1/official-db-absent',
      database: {
        state: 'absent',
        reason: 'no_official_daily',
        exemption: 'stand-signatures-only',
      },
    }),
  };
  const normal = await new LocalToolsScanner(
    { port, token, standSignaturesOnly: false },
    store(),
  ).scan(scanRequest);
  const stand = await new LocalToolsScanner(
    { port, token, standSignaturesOnly: true },
    store(),
  ).scan(scanRequest);
  assert.equal(normal.result, 'inconclusive');
  assert.equal(stand.result, 'clean');
});

void test('scanner: busy, garbage and no service are inconclusive', async () => {
  const config: LocalToolsConfig = { port, token, standSignaturesOnly: true };
  for (const response of [
    { status: 503, body: '{"reason":"busy"}' },
    { status: 200, body: 'not json' },
    { status: 200, body: '{"schemaVersion":1,"result":"clean"}' },
  ]) {
    answer = response;
    assert.equal(
      (await new LocalToolsScanner(config, store()).scan(scanRequest)).result,
      'inconclusive',
    );
  }
  const closed = await new LocalToolsScanner({ ...config, port: 1 }, store()).scan(scanRequest);
  assert.equal(closed.result, 'inconclusive');
});

const processRequest = {
  assetId: 'a' as EntityId,
  objectKeyHandle: 'objk:source',
  family: 'image' as const,
  sourceProviderGeneration: 'gen-1',
  sourceSha256: sha256(source),
  policyRevision: 'p',
  mandatoryVariantProfiles: ['display', 'thumb'],
};
const webp = (text: string) => Buffer.from(text);
const variantOf = (profile: string, bytes: Buffer, overrides: Record<string, unknown> = {}) => ({
  profile,
  format: 'image/webp',
  width: 16,
  height: 8,
  byteLength: bytes.length,
  sha256: sha256(bytes),
  bytesBase64: bytes.toString('base64'),
  ...overrides,
});

void test('processor: variants are re-hashed here and stored with the store generation', async () => {
  const objects = store();
  let next = 0;
  const ids = ['11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222'];
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: 'sharp-0.35.5/libvips-8.18.7/win32-x64-native',
      transformProfileRevision: 'd1-local-1',
      variants: [
        variantOf('display', webp('display-bytes')),
        variantOf('thumb', webp('thumb-bytes')),
      ],
    }),
  };
  const outcome = await new LocalToolsProcessor(
    { port, token, standSignaturesOnly: false },
    objects,
    () => ids[next++] as EntityId,
  ).process(processRequest);
  assert.equal(outcome.result, 'succeeded');
  if (outcome.result !== 'succeeded') return;
  assert.deepEqual(
    outcome.variants.map((variant) => variant.variantId),
    ids,
  );
  assert.ok(
    outcome.variants.every((variant) =>
      variant.providerGeneration.startsWith('fake-variant-generation-'),
    ),
  );
  assert.ok(outcome.variants.every((variant) => variant.sourceProviderGeneration === 'gen-1'));
  assert.equal(objects.variantBytes.get(ids[0] ?? '')?.toString(), 'display-bytes');
  assert.equal(seen.at(-1)?.headers['x-recharge-profiles'], 'display,thumb');
});

void test('processor: a variant whose bytes do not match its hash is not stored', async () => {
  const objects = store();
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: 't',
      transformProfileRevision: 'd1-local-1',
      variants: [
        variantOf('display', webp('display-bytes'), { sha256: sha256(webp('other')) }),
        variantOf('thumb', webp('thumb-bytes')),
      ],
    }),
  };
  const outcome = await new LocalToolsProcessor(
    { port, token, standSignaturesOnly: false },
    objects,
  ).process(processRequest);
  assert.equal(outcome.result, 'failed');
  assert.equal(objects.variantBytes.size, 0);
});

void test('processor: rejected passes through; busy and no service fail', async () => {
  const config: LocalToolsConfig = { port, token, standSignaturesOnly: false };
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'rejected',
      toolRevision: 't',
      reason: 'decode_failed',
    }),
  };
  assert.equal(
    (await new LocalToolsProcessor(config, store()).process(processRequest)).result,
    'rejected',
  );
  answer = { status: 503, body: '{"reason":"busy"}' };
  assert.equal(
    (await new LocalToolsProcessor(config, store()).process(processRequest)).result,
    'failed',
  );
  assert.equal(
    (await new LocalToolsProcessor({ ...config, port: 1 }, store()).process(processRequest)).result,
    'failed',
  );
  assert.equal(
    (await new LocalToolsProcessor(config, store()).process({ ...processRequest, family: 'video' }))
      .result,
    'failed',
  );
});
