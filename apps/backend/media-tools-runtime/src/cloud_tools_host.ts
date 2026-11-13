// N3b dev-cloud Media tools service: one private Cloud Run service per mode
// (`scanner` or `processor`), derived from the D1 stand host
// (functions/test/stand/media_tools_host.ts) and speaking the same wire
// protocol (local_tools_protocol.ts). Differences from the stand: it listens
// on 0.0.0.0:$PORT behind Cloud Run IAM, the per-service secret arrives in the
// `x-recharge-tools-token` header (the Authorization header carries the Google
// ID token checked by Cloud Run), there are no control or selftest routes, and
// the official-database exemption of the stand does not exist here.
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { fork, type ChildProcess } from 'node:child_process';
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { connect } from 'node:net';
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
} from '../../functions/src/modules/media/infrastructure/clamd_protocol.js';
import {
  toolsHeaders,
  toolsPaths,
  type ToolsDatabase,
  type ToolsHealth,
} from '../../functions/src/modules/media/infrastructure/local_tools_protocol.js';
import {
  admissionLimits,
  imageInputLimits,
  processorDeadlines,
  scannerDeadlines,
  variantProfiles,
} from '../../functions/src/modules/media/infrastructure/media_tool_limits.js';
import type { PipelineOutcome } from '../../functions/src/modules/media/infrastructure/image_pipeline.js';

export type ToolsMode = 'scanner' | 'processor';

/** Header of the per-service secret; Authorization belongs to Cloud Run IAM. */
export const toolsTokenHeader = 'x-recharge-tools-token';

export interface CloudHostOptions {
  readonly mode: ToolsMode;
  readonly port: number;
  readonly host?: string;
  readonly token: string;
  readonly clamdPort: number;
  readonly instanceId: string;
  readonly workerModule: string;
  /** Hard deadline of one processor job; tests shorten it. */
  readonly processorJobMs?: number;
  readonly now?: () => Date;
  /** One JSON line per request; never bytes, hashes, tokens or signature names. */
  readonly log?: (line: Record<string, unknown>) => void;
  /**
   * Scanner without a reachable clamd (no mirror set at start, clamd died):
   * after the fail-closed answer the instance leaves, so Cloud Run starts a
   * fresh one that fetches the newest set. The entry exits the process.
   */
  readonly onUnrecoverable?: () => void;
}

// ---------- admission ----------

export class Admission {
  #active = 0;
  readonly #waiting: {
    resolve: () => void;
    timer: ReturnType<typeof setTimeout>;
  }[] = [];

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

// ---------- clamd (loopback only) ----------

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

// ---------- worker supervision (processor mode) ----------

type WorkerAnswer = {
  readonly kind: 'result';
  readonly id: string;
  readonly outcome: PipelineOutcome;
};

export class Supervisor {
  #child: ChildProcess | null = null;
  #exited: Promise<void> = Promise.resolve();
  #jobs = 0;
  #toolRevision: string | null = null;
  readonly #pending = new Map<string, (answer: WorkerAnswer | { kind: 'exit' }) => void>();

  constructor(
    private readonly module: string,
    private readonly jobMs: number = processorDeadlines.jobMs,
  ) {}

  get pid(): number | null {
    return this.#child?.pid ?? null;
  }

  get toolRevision(): string | null {
    return this.#toolRevision;
  }

  /** A new worker starts only after the previous one has exited. */
  async ensure(): Promise<ChildProcess> {
    if (this.#child !== null) return this.#child;
    await this.#exited;
    const child = fork(this.module, [], {
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
      timer = setTimeout(() => resolve({ kind: 'timeout' }), this.jobMs);
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
    'cache-control': 'no-store',
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

/** Size class for logs; the exact length is not logged. */
export function bytesBucket(length: number): string {
  if (length <= 64 * 1024) return '<=64KiB';
  if (length <= 256 * 1024) return '<=256KiB';
  return '<=1MiB';
}

export function startCloudHost(options: CloudHostOptions) {
  const now = options.now ?? (() => new Date());
  const log =
    options.log ??
    ((line: Record<string, unknown>) => process.stdout.write(`${JSON.stringify(line)}\n`));
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
  const supervisor = new Supervisor(options.workerModule, options.processorJobMs);
  let state: ToolsHealth['state'] = 'starting';
  let version: { value: ClamdVersion | null; at: number } | null = null;
  let scannerRevision: string | null = null;
  let firstRequest = true;
  let noDatabase = false;
  let leaving = false;

  const database = async (): Promise<{
    database: ToolsDatabase;
    engine: string;
  } | null> => {
    if (options.mode !== 'scanner') return null;
    if (version === null || Date.now() - version.at > 60_000) {
      try {
        version = {
          value: await clamdVersion(options.clamdPort),
          at: Date.now(),
        };
      } catch {
        version = null;
        noDatabase = true;
        return null;
      }
    }
    const current = databaseState(version.value, now());
    return { database: current, engine: version.value?.engine ?? 'unknown' };
  };

  const health = async (): Promise<ToolsHealth> => {
    const db = await database();
    const degraded = options.mode === 'scanner' ? db === null : supervisor.toolRevision === null;
    return {
      schemaVersion: 1,
      state: state === 'ready' && degraded ? 'degraded' : state,
      instanceId: options.instanceId,
      toolRevision: {
        scanner: scannerRevision,
        processor: supervisor.toolRevision,
      },
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
      // The stand exemption never applies in the cloud: `OK` is `clean` only on
      // a fresh official database.
      standSignaturesOnly: false,
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

  const ownRoute = options.mode === 'scanner' ? toolsPaths.scan : toolsPaths.process;

  const handle = async (
    request: IncomingMessage,
    response: ServerResponse,
    facts: Record<string, unknown>,
  ): Promise<void> => {
    const route = `${request.method} ${request.url}`;
    const header = request.headers[toolsTokenHeader];
    if (typeof header !== 'string' || !secretEquals(header, options.token)) {
      facts.failureClass = 'auth';
      return send(response, 401, { reason: 'unauthorized' });
    }
    if (route === `GET ${toolsPaths.health}`) {
      const body = await health();
      facts.dbState = body.database?.state ?? null;
      return send(response, 200, body);
    }
    if (route !== `POST ${ownRoute}`) return send(response, 404, { reason: 'not_found' });
    if (state !== 'ready') return send(response, 503, { reason: state }, { 'retry-after': '1' });
    const body = await readBody(request, imageInputLimits.maxBytes);
    if (body === 'too_large') {
      facts.failureClass = 'limits';
      return send(response, 413, { reason: 'too_large' });
    }
    if (!Buffer.isBuffer(body)) {
      facts.failureClass = 'schema';
      return send(response, 400, { reason: body });
    }
    facts.bytesBucket = bytesBucket(body.length);
    const declaredSha = request.headers[toolsHeaders.sha256];
    if (createHash('sha256').update(body).digest('hex') !== declaredSha) {
      facts.failureClass = 'schema';
      return send(response, 400, { reason: 'sha256_mismatch' });
    }
    if (options.mode === 'scanner') {
      const release = await scanGate.enter();
      if (release === null) {
        facts.failureClass = 'busy';
        return send(response, 503, { reason: 'busy' }, { 'retry-after': '1' });
      }
      try {
        const answer = await scan(body);
        facts.result = answer.result;
        facts.reason = answer.reason ?? null;
        facts.dbState = answer.database.state;
        return send(response, 200, answer);
      } finally {
        release();
      }
    }
    const profilesHeader = request.headers[toolsHeaders.profiles];
    const profiles = typeof profilesHeader === 'string' ? profilesHeader.split(',') : [];
    if (
      profiles.length === 0 ||
      profiles.some((profile) => variantProfiles[profile] === undefined)
    ) {
      facts.failureClass = 'schema';
      return send(response, 400, { reason: 'bad_profiles' });
    }
    const release = await processGate.enter();
    if (release === null) {
      facts.failureClass = 'busy';
      return send(response, 503, { reason: 'busy' }, { 'retry-after': '1' });
    }
    try {
      const answer = await processJob(body, profiles);
      facts.result = answer.result;
      facts.reason = answer.reason ?? null;
      return send(response, 200, answer);
    } finally {
      release();
    }
  };

  const server = createServer((request, response) => {
    const started = Date.now();
    const facts: Record<string, unknown> = {
      kind: 'media-tools-request',
      mode: options.mode,
      route: `${request.method} ${(request.url ?? '').slice(0, 40)}`,
      coldStart: firstRequest,
      instanceId: options.instanceId,
    };
    firstRequest = false;
    void handle(request, response, facts)
      .catch(() => {
        facts.failureClass = 'crash';
        if (!response.headersSent) send(response, 500, { reason: 'internal' });
      })
      .finally(() => {
        log({
          ...facts,
          status: response.statusCode,
          durationMs: Date.now() - started,
          ...(noDatabase ? { failureClass: facts.failureClass ?? 'db_absent' } : {}),
        });
        if (noDatabase && !leaving && options.onUnrecoverable !== undefined) {
          leaving = true;
          options.onUnrecoverable();
        }
      });
  });
  server.maxConnections = admissionLimits.maxConnections;
  server.headersTimeout = 5_000;
  server.requestTimeout = 15_000;
  server.keepAliveTimeout = 0;

  /** Processor: the worker is warm before the first job; scanner: clamd was started by the entry script. */
  const arm = async () => {
    if (options.mode === 'processor') await supervisor.ensure();
    state = 'ready';
  };

  return {
    server,
    supervisor,
    arm,
    listen: () =>
      new Promise<void>((resolve) =>
        server.listen(options.port, options.host ?? '0.0.0.0', () => resolve()),
      ),
    close: async () => {
      state = 'draining';
      await supervisor.stop();
      await new Promise<void>((resolve) => server.close(() => resolve()));
    },
  };
}

// ---------- entry ----------

export function readHostEnvironment(env: NodeJS.ProcessEnv): {
  mode: ToolsMode;
  port: number;
  token: string;
  clamdPort: number;
  instanceId: string;
} {
  const mode = env.RECHARGE_TOOLS_MODE;
  if (mode !== 'scanner' && mode !== 'processor') throw new Error('RECHARGE_TOOLS_MODE invalid');
  const port = Number(env.PORT);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65535) throw new Error('PORT invalid');
  const token = env.RECHARGE_TOOLS_TOKEN ?? '';
  if (!/^[0-9a-f]{64}$/u.test(token)) throw new Error('RECHARGE_TOOLS_TOKEN missing');
  const clamdPort = Number(env.RECHARGE_TOOLS_CLAMD_PORT ?? '3310');
  if (
    !Number.isSafeInteger(clamdPort) ||
    clamdPort < 1024 ||
    clamdPort > 65535 ||
    clamdPort === port
  )
    throw new Error('RECHARGE_TOOLS_CLAMD_PORT invalid');
  const instanceId = (env.K_REVISION ?? 'local').replace(/[^A-Za-z0-9_.-]/gu, '-').slice(0, 63);
  return {
    mode,
    port,
    token,
    clamdPort,
    instanceId: `${instanceId}-${randomUUID().slice(0, 8)}`,
  };
}

if (
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const settings = readHostEnvironment(process.env);
  // The secret is not needed in the environment after start.
  delete process.env.RECHARGE_TOOLS_TOKEN;
  const host = startCloudHost({
    ...settings,
    workerModule: path.join(path.dirname(fileURLToPath(import.meta.url)), 'cloud_tools_worker.js'),
    onUnrecoverable: () => {
      process.stdout
        .write(`${JSON.stringify({ kind: 'media-tools-exit', reason: 'clamd_unavailable' })}
`);
      setTimeout(() => process.exit(3), 200);
    },
  });
  // Ready before listening: the Cloud Run TCP startup probe passes only then.
  await host.arm();
  await host.listen();
  process.once('SIGTERM', () => {
    void host.close().then(() => process.exit(0));
  });
}
