import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer as createTcpServer, type Server, type Socket } from 'node:net';
import { request } from 'node:http';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  readHostEnvironment,
  startCloudHost,
  toolsTokenHeader,
  type ToolsMode,
} from '../src/cloud_tools_host.js';

const token = 'a'.repeat(64);
const here = path.dirname(fileURLToPath(import.meta.url));
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const pad = (value: number) => String(value).padStart(2, '0');
/** clamd's local-time ctime text. */
const ctime = (at: Date) =>
  `${days[at.getDay()]} ${months[at.getMonth()]} ${String(at.getDate()).padStart(2, ' ')} ${pad(at.getHours())}:${pad(at.getMinutes())}:${pad(at.getSeconds())} ${at.getFullYear()}`;

const builtAt = new Date(2026, 10, 6, 9, 0, 0);

/** Minimal clamd: VERSION and INSTREAM; `MALWARE` in the stream is FOUND. */
function fakeClamd(): Promise<{ server: Server; port: number }> {
  const server = createTcpServer((socket: Socket) => {
    let buffer = Buffer.alloc(0);
    socket.on('data', (chunk: Buffer) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.toString('latin1').startsWith('zVERSION\0')) {
        socket.end(`ClamAV 1.5.4/27800/${ctime(builtAt)}\0`);
        return;
      }
      if (!buffer.toString('latin1').startsWith('zINSTREAM\0')) return;
      let offset = 'zINSTREAM\0'.length;
      const payload: Buffer[] = [];
      while (offset + 4 <= buffer.length) {
        const length = buffer.readUInt32BE(offset);
        if (length === 0) {
          const found = Buffer.concat(payload).includes('MALWARE');
          socket.end(found ? 'stream: Test.Signature FOUND\0' : 'stream: OK\0');
          return;
        }
        if (offset + 4 + length > buffer.length) return;
        payload.push(buffer.subarray(offset + 4, offset + 4 + length));
        offset += 4 + length;
      }
    });
  });
  return new Promise((resolve) =>
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({
        server,
        port: typeof address === 'object' && address !== null ? address.port : 0,
      });
    }),
  );
}

async function host(
  mode: ToolsMode,
  options: { clamdPort?: number; now?: Date; jobMs?: number; onUnrecoverable?: () => void } = {},
) {
  const logs: Record<string, unknown>[] = [];
  const started = startCloudHost({
    mode,
    port: 0,
    host: '127.0.0.1',
    token,
    clamdPort: options.clamdPort ?? 1,
    instanceId: 'test',
    workerModule: path.join(here, 'stub_worker.js'),
    now: () => options.now ?? new Date(2026, 10, 7, 9, 0, 0),
    log: (line) => logs.push(line),
    ...(options.jobMs === undefined ? {} : { processorJobMs: options.jobMs }),
    ...(options.onUnrecoverable === undefined ? {} : { onUnrecoverable: options.onUnrecoverable }),
  });
  await started.listen();
  const address = started.server.address();
  const port = typeof address === 'object' && address !== null ? address.port : 0;
  return { ...started, port, logs };
}

function call(
  port: number,
  method: string,
  route: string,
  body: Buffer = Buffer.alloc(0),
  headers: Record<string, string> = {},
): Promise<{ status: number; json: Record<string, unknown> }> {
  return new Promise((resolve, reject) => {
    const req = request(
      {
        host: '127.0.0.1',
        port,
        method,
        path: route,
        agent: false,
        headers: { 'content-length': String(body.length), ...headers },
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => chunks.push(chunk));
        response.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          resolve({
            status: response.statusCode ?? 0,
            json: text === '' ? {} : (JSON.parse(text) as Record<string, unknown>),
          });
        });
      },
    );
    req.on('error', reject);
    req.end(body);
  });
}

const sha = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const authorized = (bytes: Buffer, extra: Record<string, string> = {}) => ({
  [toolsTokenHeader]: token,
  'x-recharge-sha256': sha(bytes),
  ...extra,
});

void test('environment: mode, port and secret are mandatory and exact', () => {
  const base = {
    RECHARGE_TOOLS_MODE: 'scanner',
    PORT: '8080',
    RECHARGE_TOOLS_TOKEN: token,
  };
  assert.equal(readHostEnvironment(base).mode, 'scanner');
  assert.equal(readHostEnvironment(base).clamdPort, 3310);
  assert.throws(() => readHostEnvironment({ ...base, RECHARGE_TOOLS_MODE: 'both' }));
  assert.throws(() => readHostEnvironment({ ...base, RECHARGE_TOOLS_TOKEN: 'short' }));
  assert.throws(() => readHostEnvironment({ ...base, PORT: 'x' }));
  assert.throws(() => readHostEnvironment({ ...base, RECHARGE_TOOLS_CLAMD_PORT: '8080' }));
});

void test('scanner: secret header required; no control, selftest or processor routes', async () => {
  const clamd = await fakeClamd();
  const service = await host('scanner', { clamdPort: clamd.port });
  await service.arm();
  try {
    const bytes = Buffer.from('clean bytes');
    assert.equal((await call(service.port, 'GET', '/v1/health')).status, 401);
    assert.equal(
      (
        await call(service.port, 'GET', '/v1/health', undefined, {
          [toolsTokenHeader]: 'b'.repeat(64),
        })
      ).status,
      401,
    );
    // A Google ID token in Authorization is not the service secret.
    assert.equal(
      (
        await call(service.port, 'POST', '/v1/scan', bytes, {
          authorization: `Bearer ${token}`,
        })
      ).status,
      401,
    );
    for (const route of [
      '/v1/control/arm',
      '/v1/control/drain',
      '/v1/selftest/probe',
      '/v1/process',
    ])
      assert.equal(
        (await call(service.port, 'POST', route, bytes, authorized(bytes))).status,
        404,
        route,
      );
    const health = await call(service.port, 'GET', '/v1/health', undefined, {
      [toolsTokenHeader]: token,
    });
    assert.equal(health.status, 200);
    assert.equal(health.json.state, 'ready');
    assert.deepEqual(health.json.database, {
      state: 'fresh',
      daily: 27800,
      builtAt: builtAt.toISOString(),
    });
    assert.ok(service.logs.every((line) => !JSON.stringify(line).includes(token)));
  } finally {
    await service.close();
    clamd.server.close();
  }
});

void test('scanner: clean only on OK with a fresh database; FOUND rejects; stale or no clamd is inconclusive', async () => {
  const clamd = await fakeClamd();
  const fresh = await host('scanner', { clamdPort: clamd.port });
  const stale = await host('scanner', {
    clamdPort: clamd.port,
    now: new Date(2026, 10, 20),
  });
  const down = await host('scanner', { clamdPort: 1 });
  for (const service of [fresh, stale, down]) await service.arm();
  try {
    const clean = Buffer.from('plain');
    const bad = Buffer.from('xx MALWARE xx');
    const ok = await call(fresh.port, 'POST', '/v1/scan', clean, authorized(clean));
    assert.equal(ok.status, 200);
    assert.equal(ok.json.result, 'clean');
    assert.equal(ok.json.toolRevision, 'clamav-1.5.4/daily-27800');
    const found = await call(fresh.port, 'POST', '/v1/scan', bad, authorized(bad));
    assert.equal(found.json.result, 'rejected');
    const old = await call(stale.port, 'POST', '/v1/scan', clean, authorized(clean));
    assert.equal(old.json.result, 'inconclusive');
    assert.equal(old.json.reason, 'database_stale');
    const none = await call(down.port, 'POST', '/v1/scan', clean, authorized(clean));
    assert.equal(none.json.result, 'inconclusive');
    assert.equal(none.json.reason, 'scanner_unavailable');
    const log = fresh.logs.find((line) => line.result === 'rejected');
    assert.ok(log !== undefined);
    assert.equal(
      JSON.stringify(log).includes('Test.Signature'),
      false,
      'no signature names in logs',
    );
    assert.equal(log.bytesBucket, '<=64KiB');
  } finally {
    for (const service of [fresh, stale, down]) await service.close();
    clamd.server.close();
  }
});

void test('scanner: hash mismatch, oversized body and not-ready are refused', async () => {
  const clamd = await fakeClamd();
  const service = await host('scanner', { clamdPort: clamd.port });
  try {
    const bytes = Buffer.from('plain');
    assert.equal(
      (await call(service.port, 'POST', '/v1/scan', bytes, authorized(bytes))).status,
      503,
    );
    await service.arm();
    const mismatch = await call(service.port, 'POST', '/v1/scan', bytes, {
      ...authorized(bytes),
      'x-recharge-sha256': sha(Buffer.from('other')),
    });
    assert.equal(mismatch.status, 400);
    const large = Buffer.alloc(1_048_577);
    assert.equal(
      (await call(service.port, 'POST', '/v1/scan', large, authorized(large))).status,
      413,
    );
  } finally {
    await service.close();
    clamd.server.close();
  }
});

void test('processor: variants pass through; bad profiles refused; a hung job fails at the deadline', async () => {
  const service = await host('processor', { jobMs: 300 });
  await service.arm();
  try {
    const image = Buffer.from('image bytes');
    const done = await call(
      service.port,
      'POST',
      '/v1/process',
      image,
      authorized(image, { 'x-recharge-profiles': 'display,thumb' }),
    );
    assert.equal(done.status, 200);
    assert.equal(done.json.result, 'succeeded');
    assert.equal((done.json.variants as unknown[]).length, 2);
    const bad = await call(
      service.port,
      'POST',
      '/v1/process',
      image,
      authorized(image, { 'x-recharge-profiles': 'display,original' }),
    );
    assert.equal(bad.status, 400);
    assert.equal(
      (await call(service.port, 'POST', '/v1/scan', image, authorized(image))).status,
      404,
    );
    const hang = Buffer.from('HANG please');
    const timedOut = await call(
      service.port,
      'POST',
      '/v1/process',
      hang,
      authorized(hang, { 'x-recharge-profiles': 'thumb' }),
    );
    assert.equal(timedOut.json.result, 'failed');
    assert.equal(timedOut.json.reason, 'job_deadline');
    // A fresh worker serves the next job.
    const again = await call(
      service.port,
      'POST',
      '/v1/process',
      image,
      authorized(image, { 'x-recharge-profiles': 'thumb' }),
    );
    assert.equal(again.json.result, 'succeeded');
  } finally {
    await service.close();
  }
});

void test('scanner without clamd answers fail-closed, then leaves once so Cloud Run restarts it', async () => {
  let leaves = 0;
  const service = await host('scanner', { clamdPort: 1, onUnrecoverable: () => (leaves += 1) });
  await service.arm();
  try {
    const bytes = Buffer.from('plain');
    const health = await call(service.port, 'GET', '/v1/health', undefined, {
      [toolsTokenHeader]: token,
    });
    assert.equal(health.json.state, 'degraded');
    const scan = await call(service.port, 'POST', '/v1/scan', bytes, authorized(bytes));
    assert.equal(scan.json.result, 'inconclusive');
    assert.equal(leaves, 1);
    assert.ok(service.logs.some((line) => line.failureClass === 'db_absent'));
  } finally {
    await service.close();
  }
});

void test('a healthy scanner never leaves', async () => {
  const clamd = await fakeClamd();
  let leaves = 0;
  const service = await host('scanner', {
    clamdPort: clamd.port,
    onUnrecoverable: () => (leaves += 1),
  });
  await service.arm();
  try {
    const bytes = Buffer.from('plain');
    assert.equal(
      (await call(service.port, 'POST', '/v1/scan', bytes, authorized(bytes))).json.result,
      'clean',
    );
    assert.equal(leaves, 0);
  } finally {
    await service.close();
    clamd.server.close();
  }
});
