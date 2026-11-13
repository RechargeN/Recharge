import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer, request as httpRequest, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { after, before, test } from 'node:test';

import type { EntityId } from '../../../src/shared/ids.js';
import { FakeObjectStore } from '../../../src/modules/media/infrastructure/fake_object_store.js';
import {
  CloudToolsProcessor,
  CloudToolsScanner,
  cloudToolsConfigFrom,
  devCloudToolsUrls,
  metadataIdTokenSource,
  toolsTokenHeader,
  type CloudToolsConfig,
} from '../../../src/modules/media/infrastructure/cloud_tools_client.js';
import {
  LocalToolsScanner,
  type LocalToolsConfig,
} from '../../../src/modules/media/infrastructure/local_tools_client.js';

const token = 'cd'.repeat(32);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const idToken = 'header.payload.signature';

void test('the switch: absent → null; dev-cloud only for recharge-dev-n2a01 without Emulators', () => {
  const source = () => Promise.resolve(idToken);
  assert.equal(cloudToolsConfigFrom({}, source), null);
  const valid = {
    RECHARGE_MEDIA_TOOLS: 'dev-cloud',
    GCLOUD_PROJECT: 'recharge-dev-n2a01',
    RECHARGE_MEDIA_TOOLS_TOKEN: token,
  };
  const config = cloudToolsConfigFrom(valid, source);
  assert.equal(config?.scanner.url, devCloudToolsUrls.scanner);
  assert.equal(config?.processor.url, devCloudToolsUrls.processor);
  assert.equal(config?.scanner.request, undefined);
  for (const broken of [
    { ...valid, RECHARGE_MEDIA_TOOLS: 'local-real' },
    { ...valid, GCLOUD_PROJECT: 'recharge-prod' },
    { ...valid, RECHARGE_MEDIA_TOOLS_TOKEN: 'short' },
    { ...valid, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
    { ...valid, FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199' },
  ])
    assert.throws(() => cloudToolsConfigFrom(broken, source));
});

// A programmable stand-in for the Cloud Run service (plain HTTP in tests only).
let answer: { status: number; body: string } = { status: 200, body: '{}' };
const seen: { path: string; headers: Record<string, unknown> }[] = [];
let server: Server;
let base = '';
before(async () => {
  server = createServer((request, response) => {
    request.on('data', () => undefined);
    request.on('end', () => {
      seen.push({ path: request.url ?? '', headers: request.headers });
      response.writeHead(answer.status, { 'content-type': 'application/json' });
      response.end(answer.body);
    });
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
after(() => server.close());

const config = (overrides: Partial<CloudToolsConfig> = {}): CloudToolsConfig => ({
  url: base,
  token,
  idToken: () => Promise.resolve(idToken),
  request: httpRequest,
  ...overrides,
});

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
const scanAnswer = (result: string, database: Record<string, unknown>) =>
  JSON.stringify({ schemaVersion: 1, result, toolRevision: 'clamav-1.5.4/daily-1', database });

void test('scanner: ID token for Cloud Run IAM and the service secret in its own header', async () => {
  answer = { status: 200, body: scanAnswer('clean', { state: 'fresh', daily: 1, builtAt: 'x' }) };
  const audiences: string[] = [];
  const outcome = await new CloudToolsScanner(
    config({
      idToken: (audience) => {
        audiences.push(audience);
        return Promise.resolve(idToken);
      },
    }),
    store(),
  ).scan(scanRequest);
  assert.deepEqual(outcome, { toolRevision: 'clamav-1.5.4/daily-1', result: 'clean' });
  const last = seen.at(-1);
  assert.equal(last?.path, '/v1/scan');
  assert.equal(last?.headers.authorization, `Bearer ${idToken}`);
  assert.equal(last?.headers[toolsTokenHeader], token);
  assert.equal(last?.headers['x-recharge-sha256'], sha256(source));
  assert.deepEqual(audiences, [base]);
});

void test('scanner: no stand exemption, stale/absent databases and every failure are inconclusive', async () => {
  for (const database of [
    { state: 'absent', reason: 'no_official_daily', exemption: 'stand-signatures-only' },
    { state: 'absent', reason: 'no_official_daily' },
    { state: 'stale', daily: 1, builtAt: 'x' },
  ]) {
    answer = { status: 200, body: scanAnswer('clean', database) };
    assert.equal(
      (await new CloudToolsScanner(config(), store()).scan(scanRequest)).result,
      'inconclusive',
      JSON.stringify(database),
    );
  }
  for (const response of [
    { status: 401, body: '{"reason":"unauthorized"}' },
    { status: 403, body: 'Forbidden' },
    { status: 429, body: 'Rate exceeded' },
    { status: 503, body: '{"reason":"busy"}' },
    { status: 504, body: 'upstream request timeout' },
    { status: 200, body: 'not json' },
    { status: 200, body: '{"schemaVersion":1,"result":"clean"}' },
  ]) {
    answer = response;
    assert.equal(
      (await new CloudToolsScanner(config(), store()).scan(scanRequest)).result,
      'inconclusive',
      String(response.status),
    );
  }
  const noToken = await new CloudToolsScanner(
    config({ idToken: () => Promise.reject(new Error('metadata down')) }),
    store(),
  ).scan(scanRequest);
  assert.equal(noToken.result, 'inconclusive');
  assert.equal(noToken.toolRevision, 'cloud-tools-unavailable');
  const closed = await new CloudToolsScanner(config({ url: 'http://127.0.0.1:1' }), store()).scan(
    scanRequest,
  );
  assert.equal(closed.result, 'inconclusive');
  // FOUND still blocks whatever the database.
  answer = {
    status: 200,
    body: scanAnswer('rejected', { state: 'stale', daily: 1, builtAt: 'x' }),
  };
  assert.equal(
    (await new CloudToolsScanner(config(), store()).scan(scanRequest)).result,
    'rejected',
  );
});

void test('parity: a fresh clean answer reads the same through the local and the cloud client', async () => {
  answer = { status: 200, body: scanAnswer('clean', { state: 'fresh', daily: 7, builtAt: 'x' }) };
  const port = Number(new URL(base).port);
  const local: LocalToolsConfig = { port, token, standSignaturesOnly: false };
  assert.deepEqual(
    await new CloudToolsScanner(config(), store()).scan(scanRequest),
    await new LocalToolsScanner(local, store()).scan(scanRequest),
  );
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

void test('processor: variants re-hashed and written create-only by Functions; failures fail', async () => {
  const objects = store();
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: 'sharp-0.35.5/libvips-8.18.7/linux-x64-native',
      transformProfileRevision: 'd1-local-1',
      variants: [
        variantOf('display', Buffer.from('display')),
        variantOf('thumb', Buffer.from('thumb')),
      ],
    }),
  };
  const outcome = await new CloudToolsProcessor(config(), objects).process(processRequest);
  assert.equal(outcome.result, 'succeeded');
  assert.equal(objects.variantBytes.size, 2);
  assert.equal(seen.at(-1)?.path, '/v1/process');
  assert.equal(seen.at(-1)?.headers['x-recharge-profiles'], 'display,thumb');
  answer = {
    status: 200,
    body: JSON.stringify({
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: 't',
      transformProfileRevision: 'd1-local-1',
      variants: [
        variantOf('display', Buffer.from('display'), { sha256: sha256(Buffer.from('x')) }),
        variantOf('thumb', Buffer.from('thumb')),
      ],
    }),
  };
  const tampered = store();
  assert.equal(
    (await new CloudToolsProcessor(config(), tampered).process(processRequest)).result,
    'failed',
  );
  assert.equal(tampered.variantBytes.size, 0);
  answer = { status: 503, body: '{"reason":"busy"}' };
  assert.equal(
    (await new CloudToolsProcessor(config(), store()).process(processRequest)).result,
    'failed',
  );
});

void test('metadata ID tokens: Google flavor header, audience per call, cached, refused when malformed', async () => {
  const calls: { path: string; flavor: unknown }[] = [];
  let reply = idToken;
  const metadata = createServer((request, response) => {
    calls.push({ path: request.url ?? '', flavor: request.headers['metadata-flavor'] });
    response.writeHead(200);
    response.end(reply);
  });
  await new Promise<void>((resolve) => metadata.listen(0, '127.0.0.1', () => resolve()));
  try {
    const port = (metadata.address() as AddressInfo).port;
    let clock = 0;
    const tokens = metadataIdTokenSource(`127.0.0.1`, () => clock, port);
    assert.equal(await tokens(devCloudToolsUrls.scanner), idToken);
    assert.equal(await tokens(devCloudToolsUrls.scanner), idToken);
    assert.equal(calls.length, 1);
    assert.equal(calls[0]?.flavor, 'Google');
    assert.match(calls[0]?.path ?? '', /audience=https%3A%2F%2Fmedia-scanner-/u);
    clock = 46 * 60 * 1000;
    reply = 'not-a-jwt';
    await assert.rejects(tokens(devCloudToolsUrls.scanner));
  } finally {
    metadata.close();
  }
});
