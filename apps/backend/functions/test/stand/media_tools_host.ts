// D1 local Media tools service (amendment §4). STAND CODE: started only by
// scripts/media-tools.mjs inside a Windows Job Object; never imported by the
// Functions runtime. HTTP on 127.0.0.1, bearer tokens, global admission with an
// immediate 503, scans forwarded to clamd, images processed in one supervised
// worker process with a hard deadline.
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { fork, type ChildProcess } from 'node:child_process';
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { connect } from 'node:net';
import { readFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  databaseState,
  instreamFrames,
  parseScanReply,
  parseVersion,
  scanVerdict,
  type ClamdVersion,
  type ScanReply,
} from '../../src/modules/media/infrastructure/clamd_protocol.js';
import {
  toolsHeaders,
  toolsPaths,
  type ToolsDatabase,
  type ToolsHealth,
} from '../../src/modules/media/infrastructure/local_tools_protocol.js';
import {
  admissionLimits,
  imageInputLimits,
  processorDeadlines,
  scannerDeadlines,
  variantProfiles,
} from '../../src/modules/media/infrastructure/media_tool_limits.js';
import type { PipelineOutcome } from '../../src/modules/media/infrastructure/image_pipeline.js';

export interface HostOptions {
  readonly port: number;
  readonly token: string;
  readonly controlToken: string;
  readonly clamdPort: number;
  readonly instanceId: string;
  readonly standSignaturesOnly: boolean;
  readonly selftestProbes: boolean;
  readonly workerModule: string;
  readonly now?: () => Date;
  /** What happens once drained; the real service exits. */
  readonly onDrained?: () => void;
}

// ---------- admission ----------

export class Admission {
  #active = 0;
  readonly #waiting: { resolve: () => void; timer: ReturnType<typeof setTimeout> }[] = [];

  constructor(
    private readonly maxActive: number,
    private readonly maxWaiting: number,
    private readonly waitMs: number,
  ) {}

  get active(): number {
    return this.#active;
  }

  get waiting(): number {
    return this.#waiting.length;
  }

  /** Resolves with a release function, or `null` at once when the queue is full or the wait expires. */
  enter(): Promise<(() => void) | null> {
    const release = () => {
      const next = this.#waiting.shift();
      if (next !== undefined) {
        clearTimeout(next.timer);
        next.resolve();
      } else this.#active -= 1;
    };
    if (this.#active < this.maxActive) {
      this.#active += 1;
      return Promise.resolve(release);
    }
    if (this.#waiting.length >= this.maxWaiting) return Promise.resolve(null);
    return new Promise((resolve) => {
      const entry = {
        resolve: () => resolve(release),
        timer: setTimeout(() => {
          const index = this.#waiting.indexOf(entry);
          if (index >= 0) this.#waiting.splice(index, 1);
          resolve(null);
        }, this.waitMs),
      };
      this.#waiting.push(entry);
    });
  }
}

// ---------- clamd ----------

function clamdCommand(port: number, frames: readonly Buffer[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = connect({ host: '127.0.0.1', port });
    const chunks: Buffer[] = [];
    let settled = false;
    const finish = (error: Error | null, text?: string) => {
      if (settled) return;
      settled = true;
      clearTimeout(total);
      socket.destroy();
      if (error === null) resolve(text ?? '');
      else reject(error);
    };
    const total = setTimeout(
      () => finish(new Error('clamd total deadline')),
      scannerDeadlines.totalMs,
    );
    socket.setTimeout(scannerDeadlines.connectMs);
    socket.on('timeout', () => finish(new Error('clamd timeout')));
    socket.on('error', (error) => finish(error));
    socket.on('connect', () => {
      socket.setTimeout(scannerDeadlines.replyMs);
      for (const frame of frames) socket.write(frame);
    });
    socket.on('data', (chunk: Buffer) => {
      chunks.push(chunk);
      if (chunk.includes(0)) finish(null, Buffer.concat(chunks).toString('utf8'));
    });
    socket.on('end', () => finish(null, Buffer.concat(chunks).toString('utf8')));
  });
}

export async function clamdVersion(port: number): Promise<ClamdVersion | null> {
  return parseVersion(await clamdCommand(port, [Buffer.from('zVERSION\0', 'ascii')]));
}

export async function clamdScan(port: number, bytes: Buffer): Promise<ScanReply> {
  return parseScanReply(
    await clamdCommand(port, instreamFrames(bytes, scannerDeadlines.chunkBytes)),
  );
}

// ---------- worker supervision ----------

type WorkerAnswer =
  | { readonly kind: 'result'; readonly id: string; readonly outcome: PipelineOutcome }
  | {
      readonly kind: 'probe';
      readonly id: string;
      readonly reached: number;
      readonly refused: boolean;
    };

class Supervisor {
  #child: ChildProcess | null = null;
  #exited: Promise<void> = Promise.resolve();
  #jobs = 0;
  #toolRevision: string | null = null;
  readonly #pending = new Map<string, (answer: WorkerAnswer | { kind: 'exit' }) => void>();

  constructor(
    private readonly module: string,
    private readonly probes: boolean,
  ) {}

  get pid(): number | null {
    return this.#child?.pid ?? null;
  }

  get toolRevision(): string | null {
    return this.#toolRevision;
  }

  /** A new worker starts only after the previous one has exited (§4.2). */
  async ensure(): Promise<ChildProcess> {
    if (this.#child !== null) return this.#child;
    await this.#exited;
    const child = fork(this.module, this.probes ? ['--selftest-probes'] : [], {
      serialization: 'advanced',
      execArgv: [],
      stdio: ['ignore', 'ignore', 'inherit', 'ipc'],
    });
    this.#child = child;
    this.#jobs = 0;
    this.#exited = new Promise((resolve) => child.once('exit', () => resolve()));
    child.once('exit', () => {
      if (this.#child === child) this.#child = null;
      for (const settle of this.#pending.values()) settle({ kind: 'exit' });
      this.#pending.clear();
    });
    child.on('message', (message: { kind: string; id?: string; toolRevision?: string }) => {
      if (message.kind === 'ready' && typeof message.toolRevision === 'string')
        this.#toolRevision = message.toolRevision;
      if (typeof message.id === 'string') {
        const settle = this.#pending.get(message.id);
        this.#pending.delete(message.id);
        settle?.(message as WorkerAnswer);
      }
    });
    await new Promise<void>((resolve, reject) => {
      const onMessage = (message: { kind: string }) => {
        if (message.kind === 'ready') {
          child.off('message', onMessage);
          resolve();
        }
      };
      child.on('message', onMessage);
      child.once('exit', () => reject(new Error('worker exited before ready')));
    });
    return child;
  }

  /** Runs one job; on the hard deadline the worker is terminated and awaited. */
  async run(
    message: Record<string, unknown>,
  ): Promise<WorkerAnswer | { kind: 'exit' | 'timeout' }> {
    const child = await this.ensure();
    const id = randomUUID();
    this.#jobs += 1;
    const answer = new Promise<WorkerAnswer | { kind: 'exit' }>((resolve) =>
      this.#pending.set(id, resolve),
    );
    child.send({ ...message, id });
    let timer: ReturnType<typeof setTimeout> | undefined;
    const expired = new Promise<{ kind: 'timeout' }>((resolve) => {
      timer = setTimeout(() => resolve({ kind: 'timeout' }), processorDeadlines.jobMs);
    });
    const result = await Promise.race([answer, expired]);
    clearTimeout(timer);
    if (result.kind === 'timeout') {
      this.#pending.delete(id);
      await this.stop();
    } else if (this.#jobs >= processorDeadlines.recycleAfterJobs) await this.stop();
    return result;
  }

  async stop(): Promise<void> {
    const child = this.#child;
    if (child === null) return;
    child.kill();
    await this.#exited;
  }
}

// ---------- HTTP ----------

const secretEquals = (given: string, expected: string) => {
  const left = Buffer.from(given);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
};

function bearer(request: IncomingMessage): string {
  const header = request.headers.authorization ?? '';
  return header.startsWith('Bearer ') ? header.slice('Bearer '.length) : '';
}

function send(
  response: ServerResponse,
  status: number,
  body?: unknown,
  extra: Record<string, string> = {},
) {
  const payload = body === undefined ? Buffer.alloc(0) : Buffer.from(JSON.stringify(body));
  response.writeHead(status, {
    connection: 'close',
    'content-type': 'application/json',
    'content-length': String(payload.length),
    ...extra,
  });
  response.end(payload);
}

function readBody(
  request: IncomingMessage,
  max: number,
): Promise<Buffer | 'too_large' | 'bad_length'> {
  const declared = Number(request.headers['content-length']);
  if (!Number.isSafeInteger(declared) || declared < 0) return Promise.resolve('bad_length');
  if (declared > max) return Promise.resolve('too_large');
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    request.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > declared) {
        request.destroy();
        resolve('bad_length');
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => resolve(size === declared ? Buffer.concat(chunks) : 'bad_length'));
    request.on('error', reject);
  });
}

export function startHost(options: HostOptions) {
  const now = options.now ?? (() => new Date());
  const scanGate = new Admission(
    admissionLimits.scan.active,
    admissionLimits.scan.waiting,
    admissionLimits.scan.waitMs,
  );
  const processGate = new Admission(
    admissionLimits.process.active,
    admissionLimits.process.waiting,
    admissionLimits.process.waitMs,
  );
  const supervisor = new Supervisor(options.workerModule, options.selftestProbes);
  let state: ToolsHealth['state'] = 'starting';
  let version: { value: ClamdVersion | null; at: number } | null = null;
  let scannerRevision: string | null = null;

  const database = async (): Promise<{ database: ToolsDatabase; engine: string } | null> => {
    if (version === null || Date.now() - version.at > 60_000) {
      try {
        version = { value: await clamdVersion(options.clamdPort), at: Date.now() };
      } catch {
        return null;
      }
    }
    const current = databaseState(version.value, now());
    const db: ToolsDatabase =
      current.state === 'absent'
        ? {
            state: 'absent',
            reason: current.reason,
            ...(options.standSignaturesOnly ? { exemption: 'stand-signatures-only' as const } : {}),
          }
        : current;
    return { database: db, engine: version.value?.engine ?? 'unknown' };
  };

  const health = async (): Promise<ToolsHealth> => {
    const db = await database();
    return {
      schemaVersion: 1,
      state: state === 'ready' && db === null ? 'degraded' : state,
      instanceId: options.instanceId,
      toolRevision: { scanner: scannerRevision, processor: supervisor.toolRevision },
      database: db?.database ?? null,
      queues: {
        scan: { active: scanGate.active, waiting: scanGate.waiting },
        process: { active: processGate.active, waiting: processGate.waiting },
      },
      worker: supervisor.pid === null ? null : { pid: supervisor.pid },
    };
  };

  const scan = async (bytes: Buffer) => {
    const db = await database();
    if (db === null)
      return {
        schemaVersion: 1,
        result: 'inconclusive',
        toolRevision: 'clamav-unavailable',
        database: { state: 'absent', reason: 'clamd_unavailable' },
        reason: 'scanner_unavailable',
      };
    let reply: ScanReply;
    try {
      reply = await clamdScan(options.clamdPort, bytes);
    } catch {
      reply = { kind: 'error', reason: 'clamd_unreachable' };
    }
    const verdict = scanVerdict({
      reply,
      database: databaseState(version?.value ?? null, now()),
      engine: db.engine,
      standSignaturesOnly: options.standSignaturesOnly,
    });
    scannerRevision = verdict.toolRevision;
    return { schemaVersion: 1, ...verdict, database: db.database };
  };

  const processJob = async (bytes: Buffer, profiles: readonly string[]) => {
    const answer = await supervisor.run({ kind: 'process', bytes, profiles });
    if (answer.kind === 'timeout')
      return {
        schemaVersion: 1,
        result: 'failed',
        toolRevision: supervisor.toolRevision ?? 'sharp-unknown',
        reason: 'job_deadline',
      };
    if (answer.kind !== 'result')
      return {
        schemaVersion: 1,
        result: 'failed',
        toolRevision: supervisor.toolRevision ?? 'sharp-unknown',
        reason: 'worker_exit',
      };
    const outcome = answer.outcome;
    if (outcome.result !== 'succeeded')
      return {
        schemaVersion: 1,
        result: outcome.result,
        toolRevision: outcome.toolRevision,
        reason: outcome.reason,
      };
    return {
      schemaVersion: 1,
      result: 'succeeded',
      toolRevision: outcome.toolRevision,
      transformProfileRevision: outcome.transformProfileRevision,
      variants: outcome.variants.map((variant) => ({
        profile: variant.profile,
        format: variant.format,
        width: variant.width,
        height: variant.height,
        byteLength: variant.byteLength,
        sha256: variant.sha256,
        bytesBase64: Buffer.from(variant.bytes).toString('base64'),
      })),
    };
  };

  const handle = async (request: IncomingMessage, response: ServerResponse): Promise<void> => {
    try {
      const route = `${request.method} ${request.url}`;
      const token = bearer(request);
      const isControl = secretEquals(token, options.controlToken);
      const isAccess = secretEquals(token, options.token);
      if (!isControl && !isAccess) return send(response, 401, { reason: 'unauthorized' });

      if (route === `GET ${toolsPaths.health}`) return send(response, 200, await health());

      if (route === `POST ${toolsPaths.arm}`) {
        if (!isControl) return send(response, 401, { reason: 'unauthorized' });
        if (state !== 'starting') return send(response, 409, { reason: state });
        await supervisor.ensure();
        state = 'ready';
        return send(response, 204);
      }

      if (route === `POST ${toolsPaths.drain}`) {
        if (!isControl) return send(response, 401, { reason: 'unauthorized' });
        state = 'draining';
        send(response, 202);
        const quiet = async () => {
          while (scanGate.active + scanGate.waiting + processGate.active + processGate.waiting > 0)
            await new Promise((resolve) => setTimeout(resolve, 100));
        };
        await Promise.race([quiet(), new Promise((resolve) => setTimeout(resolve, 20_000))]);
        await supervisor.stop();
        server.close(() => (options.onDrained ?? (() => process.exit(0)))());
        return;
      }

      if (route === `POST ${toolsPaths.probe}`) {
        if (!options.selftestProbes || !isControl)
          return send(response, 403, { reason: 'probes_disabled' });
        const body = await readBody(request, 4096);
        if (!Buffer.isBuffer(body)) return send(response, 400, { reason: body });
        const probe = JSON.parse(body.toString('utf8')) as { kind?: string; mib?: number };
        if (
          (probe.kind !== 'allocate' && probe.kind !== 'hang') ||
          !Number.isSafeInteger(probe.mib)
        )
          return send(response, 400, { reason: 'bad_probe' });
        const release = await processGate.enter();
        if (release === null)
          return send(response, 503, { reason: 'busy' }, { 'retry-after': '1' });
        try {
          const workerPid = (await supervisor.ensure()).pid ?? null;
          const answer = await supervisor.run({ kind: 'probe', probe: probe.kind, mib: probe.mib });
          return send(response, 200, { workerPid, answer });
        } finally {
          release();
        }
      }

      if (route !== `POST ${toolsPaths.scan}` && route !== `POST ${toolsPaths.process}`)
        return send(response, 404, { reason: 'not_found' });
      if (state === 'starting')
        return send(response, 503, { reason: 'not-ready' }, { 'retry-after': '1' });
      if (state === 'draining')
        return send(response, 503, { reason: 'draining' }, { 'retry-after': '1' });
      const body = await readBody(request, imageInputLimits.maxBytes);
      if (body === 'too_large') return send(response, 413, { reason: 'too_large' });
      if (!Buffer.isBuffer(body)) return send(response, 400, { reason: body });
      const declaredSha = request.headers[toolsHeaders.sha256];
      if (createHash('sha256').update(body).digest('hex') !== declaredSha)
        return send(response, 400, { reason: 'sha256_mismatch' });

      if (route === `POST ${toolsPaths.scan}`) {
        const release = await scanGate.enter();
        if (release === null)
          return send(response, 503, { reason: 'busy' }, { 'retry-after': '1' });
        try {
          return send(response, 200, await scan(body));
        } finally {
          release();
        }
      }
      const profilesHeader = request.headers[toolsHeaders.profiles];
      const profiles = typeof profilesHeader === 'string' ? profilesHeader.split(',') : [];
      if (
        profiles.length === 0 ||
        profiles.some((profile) => variantProfiles[profile] === undefined)
      )
        return send(response, 400, { reason: 'bad_profiles' });
      const release = await processGate.enter();
      if (release === null) return send(response, 503, { reason: 'busy' }, { 'retry-after': '1' });
      try {
        return send(response, 200, await processJob(body, profiles));
      } finally {
        release();
      }
    } catch {
      if (!response.headersSent) send(response, 500, { reason: 'internal' });
    }
  };
  const server = createServer((request, response) => {
    void handle(request, response);
  });
  server.maxConnections = admissionLimits.maxConnections;
  server.headersTimeout = 2_000;
  server.requestTimeout = 10_000;
  server.keepAliveTimeout = 0;
  return {
    server,
    supervisor,
    listen: () =>
      new Promise<void>((resolve) => server.listen(options.port, '127.0.0.1', () => resolve())),
  };
}

// ---------- entry ----------

function hex64(value: string | undefined, name: string): string {
  if (value === undefined || !/^[0-9a-f]{64}$/u.test(value)) throw new Error(`${name} missing`);
  return value;
}

if (
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const env = process.env;
  // On Linux the tokens arrive in a file only the user can read; it is removed
  // at once, so they never sit in a command line or a parent's environment.
  const secretsFile = env.RECHARGE_TOOLS_SECRETS_FILE;
  const secrets =
    secretsFile === undefined
      ? { token: env.RECHARGE_TOOLS_TOKEN, controlToken: env.RECHARGE_TOOLS_CONTROL_TOKEN }
      : (JSON.parse(readFileSync(secretsFile, 'utf8')) as {
          token?: string;
          controlToken?: string;
        });
  if (secretsFile !== undefined) unlinkSync(secretsFile);
  const host = startHost({
    port: Number(env.RECHARGE_TOOLS_PORT),
    token: hex64(secrets.token, 'RECHARGE_TOOLS_TOKEN'),
    controlToken: hex64(secrets.controlToken, 'RECHARGE_TOOLS_CONTROL_TOKEN'),
    clamdPort: Number(env.RECHARGE_TOOLS_CLAMD_PORT),
    instanceId: env.RECHARGE_TOOLS_INSTANCE ?? 'unknown',
    standSignaturesOnly: process.argv.includes('--stand-signatures-only'),
    selftestProbes: process.argv.includes('--selftest-probes'),
    workerModule: path.join(path.dirname(fileURLToPath(import.meta.url)), 'media_tools_worker.js'),
  });
  // The tokens are not needed in the environment after start.
  delete env.RECHARGE_TOOLS_TOKEN;
  delete env.RECHARGE_TOOLS_CONTROL_TOKEN;
  await host.listen();
}
