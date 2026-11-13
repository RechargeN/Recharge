// D1 service behaviour (amendment §4.3, §4.10, §4.13) with the real worker and
// a scripted stand-in for clamd. The Job Object side is covered by
// `media-tools selftest` (J1–J6).
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  createServer as createTcpServer,
  type AddressInfo,
  type Server as TcpServer,
} from 'node:net';
import path from 'node:path';
import { after, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { startHost } from '../stand/media_tools_host.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const workerModule = path.join(here, '..', 'stand', 'media_tools_worker.js');
const token = 'a1'.repeat(32);
const controlToken = 'c2'.repeat(32);
const tinyJpeg = Buffer.from(
  '/9j/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAQABADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAABf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKAATb//2Q==',
  'base64',
);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

/** A clamd stand-in: answers VERSION and INSTREAM, or stays silent. */
async function fakeClamd(mode: 'ok' | 'silent'): Promise<{ server: TcpServer; port: number }> {
  const server = createTcpServer((socket) => {
    let buffered = Buffer.alloc(0);
    socket.on('data', (chunk: Buffer) => {
      buffered = Buffer.concat([buffered, chunk]);
      if (mode === 'silent') return;
      if (buffered.toString('ascii').startsWith('zVERSION\0')) socket.end('ClamAV 1.5.4\0');
      else if (buffered.subarray(-4).equals(Buffer.alloc(4))) socket.end('stream: OK\0');
    });
    socket.on('error', () => undefined);
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  return { server, port: (server.address() as AddressInfo).port };
}

async function freePort(): Promise<number> {
  const probe = createTcpServer();
  await new Promise<void>((resolve) => probe.listen(0, '127.0.0.1', () => resolve()));
  const { port } = probe.address() as AddressInfo;
  await new Promise<void>((resolve) => probe.close(() => resolve()));
  return port;
}

const closers: (() => Promise<void> | void)[] = [];
after(async () => {
  for (const close of closers.reverse()) await close();
});

async function host(options: {
  clamdPort: number;
  standSignaturesOnly?: boolean;
  probes?: boolean;
}) {
  const port = await freePort();
  let drained = false;
  const service = startHost({
    port,
    token,
    controlToken,
    clamdPort: options.clamdPort,
    instanceId: 'test',
    standSignaturesOnly: options.standSignaturesOnly ?? false,
    selftestProbes: options.probes ?? false,
    workerModule,
    onDrained: () => {
      drained = true;
    },
  });
  await service.listen();
  closers.push(async () => {
    await service.supervisor.stop();
    service.server.close();
  });
  const call = async (
    method: string,
    route: string,
    secret: string,
    body?: Buffer,
    headers: Record<string, string> = {},
  ) => {
    const started = Date.now();
    const response = await fetch(`http://127.0.0.1:${port}${route}`, {
      method,
      headers: { authorization: `Bearer ${secret}`, connection: 'close', ...headers },
      ...(body === undefined ? {} : { body }),
    });
    const text = await response.text();
    return {
      status: response.status,
      json: text ? (JSON.parse(text) as Record<string, unknown>) : null,
      ms: Date.now() - started,
    };
  };
  const scan = (bytes: Buffer) =>
    call('POST', '/v1/scan', token, bytes, {
      'x-recharge-sha256': sha256(bytes),
      'x-recharge-request-id': 'r1',
    });
  const processImage = (bytes: Buffer, profiles = 'display,thumb') =>
    call('POST', '/v1/process', token, bytes, {
      'x-recharge-sha256': sha256(bytes),
      'x-recharge-request-id': 'r2',
      'x-recharge-profiles': profiles,
    });
  return { call, scan, processImage, isDrained: () => drained };
}

void test('tokens, readiness and request checks', { timeout: 60_000 }, async () => {
  const clamd = await fakeClamd('ok');
  closers.push(() => void clamd.server.close());
  const service = await host({ clamdPort: clamd.port });
  assert.equal((await service.call('GET', '/v1/health', 'f'.repeat(64))).status, 401);
  assert.equal((await service.scan(tinyJpeg)).status, 503, 'not ready before arm');
  assert.equal(
    (await service.call('POST', '/v1/control/arm', token)).status,
    401,
    'arm needs the control token',
  );
  assert.equal((await service.call('POST', '/v1/control/arm', controlToken)).status, 204);
  const health = await service.call('GET', '/v1/health', token);
  assert.equal(health.json?.state, 'ready');
  assert.ok((health.json?.worker as { pid: number } | null)?.pid);
  const bad = await service.call('POST', '/v1/scan', token, tinyJpeg, {
    'x-recharge-sha256': '0'.repeat(64),
  });
  assert.equal(bad.status, 400);
  const big = Buffer.alloc(1_048_577);
  assert.equal(
    (await service.call('POST', '/v1/scan', token, big, { 'x-recharge-sha256': sha256(big) }))
      .status,
    413,
  );
  assert.equal((await service.processImage(tinyJpeg, 'display,poster')).status, 400);
  assert.equal(
    (await service.call('POST', '/v1/selftest/probe', controlToken, Buffer.from('{}'))).status,
    403,
    'probes off',
  );
  const processed = await service.processImage(tinyJpeg);
  assert.equal(processed.json?.result, 'succeeded');
});

void test(
  'normal mode keeps an absent database inconclusive; only the stand exemption makes it clean',
  { timeout: 60_000 },
  async () => {
    const clamd = await fakeClamd('ok');
    closers.push(() => void clamd.server.close());
    const normal = await host({ clamdPort: clamd.port });
    const stand = await host({ clamdPort: clamd.port, standSignaturesOnly: true });
    for (const service of [normal, stand])
      await service.call('POST', '/v1/control/arm', controlToken);
    const n = await normal.scan(tinyJpeg);
    assert.equal(n.json?.result, 'inconclusive');
    assert.equal(n.json?.reason, 'database_absent');
    assert.deepEqual(n.json?.database, { state: 'absent', reason: 'no_official_daily' });
    const s = await stand.scan(tinyJpeg);
    assert.equal(s.json?.result, 'clean');
    assert.equal(s.json?.toolRevision, 'clamav-1.5.4/stand-marker-1/official-db-absent');
    assert.deepEqual(s.json?.database, {
      state: 'absent',
      reason: 'no_official_daily',
      exemption: 'stand-signatures-only',
    });
  },
);

void test(
  'a silent or missing clamd is inconclusive within the deadline',
  { timeout: 60_000 },
  async () => {
    const silent = await fakeClamd('silent');
    closers.push(() => void silent.server.close());
    const quiet = await host({ clamdPort: silent.port, standSignaturesOnly: true });
    await quiet.call('POST', '/v1/control/arm', controlToken);
    const slow = await quiet.scan(tinyJpeg);
    assert.equal(slow.json?.result, 'inconclusive');
    assert.ok(slow.ms < 25_000, `answered in ${slow.ms} ms`);
    const gone = await host({ clamdPort: await freePort(), standSignaturesOnly: true });
    await gone.call('POST', '/v1/control/arm', controlToken);
    const missing = await gone.scan(tinyJpeg);
    assert.equal(missing.json?.result, 'inconclusive');
    assert.equal(missing.json?.reason, 'scanner_unavailable');
    assert.equal((await gone.call('GET', '/v1/health', token)).json?.state, 'degraded');
  },
);

void test(
  'a full queue answers 503 at once; waiting requests do not pile up',
  { timeout: 90_000 },
  async () => {
    const clamd = await fakeClamd('ok');
    closers.push(() => void clamd.server.close());
    const service = await host({ clamdPort: clamd.port, probes: true });
    await service.call('POST', '/v1/control/arm', controlToken);
    const hang = service.call(
      'POST',
      '/v1/selftest/probe',
      controlToken,
      Buffer.from(JSON.stringify({ kind: 'hang', mib: 32 })),
    );
    await new Promise((resolve) => setTimeout(resolve, 500));
    const waiting = [service.processImage(tinyJpeg), service.processImage(tinyJpeg)];
    await new Promise((resolve) => setTimeout(resolve, 200));
    const overflow = await service.processImage(tinyJpeg);
    assert.equal(overflow.status, 503);
    assert.equal(overflow.json?.reason, 'busy');
    assert.ok(overflow.ms < 1_000, `refused in ${overflow.ms} ms`);
    for (const result of await Promise.all(waiting)) {
      assert.equal(result.status, 503, 'a waiting request leaves after its 5 s wait');
      assert.ok(result.ms < 7_000);
    }
    const hung = await hang;
    assert.equal(
      (hung.json?.answer as { kind: string }).kind,
      'timeout',
      'the worker was ended at 15 s',
    );
    const after = await service.processImage(tinyJpeg);
    assert.equal(after.json?.result, 'succeeded', 'a new worker took the next job');
  },
);

void test('drain refuses new work and closes', { timeout: 60_000 }, async () => {
  const clamd = await fakeClamd('ok');
  closers.push(() => void clamd.server.close());
  const service = await host({ clamdPort: clamd.port });
  await service.call('POST', '/v1/control/arm', controlToken);
  assert.equal((await service.call('POST', '/v1/control/drain', token)).status, 401);
  assert.equal((await service.call('POST', '/v1/control/drain', controlToken)).status, 202);
  const deadline = Date.now() + 10_000;
  while (!service.isDrained() && Date.now() < deadline)
    await new Promise((resolve) => setTimeout(resolve, 100));
  assert.equal(service.isDrained(), true);
});
