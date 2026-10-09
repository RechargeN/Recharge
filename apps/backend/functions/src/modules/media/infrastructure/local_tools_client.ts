import { createHash, randomUUID } from 'node:crypto';
import { request } from 'node:http';

import type { MediaVariantRefV1 } from '../../../contracts/media_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import type { ObjectBytesPort } from '../application/ports/object_store_port.js';
import type {
  ProcessOutcome,
  ProcessorPort,
  ProcessRequest,
} from '../application/ports/processor_port.js';
import type { ScanOutcome, ScannerPort, ScanRequest } from '../application/ports/scanner_port.js';
import {
  parseProcessResponse,
  parseScanResponse,
  toolsHeaders,
  toolsPaths,
  type ToolsDatabase,
} from './local_tools_protocol.js';
import { clientDeadlines, imageInputLimits, maxVariantBytes } from './media_tool_limits.js';

/**
 * D1 adapters behind `ScannerPort` and `ProcessorPort`: thin clients of the
 * local tools service on 127.0.0.1 (amendment §4.10). sharp and ClamAV never
 * load in the Functions runtime. Every failure here is fail-closed: a scan is
 * `inconclusive`, a processing run `failed`; the asset stays quarantined.
 */
export interface LocalToolsConfig {
  readonly port: number;
  readonly token: string;
  /**
   * L1 local test mode only: accept `clean` on an absent official database
   * when the service reports the same stand exemption. Off by default.
   */
  readonly standSignaturesOnly: boolean;
}

const unavailable = 'local-tools-unavailable';

interface HttpAnswer {
  readonly status: number;
  readonly body: Buffer;
}

function call(
  config: LocalToolsConfig,
  path: string,
  body: Buffer,
  headers: Readonly<Record<string, string>>,
  totalMs: number,
): Promise<HttpAnswer> {
  return new Promise((resolve, reject) => {
    const req = request({
      host: '127.0.0.1',
      port: config.port,
      method: 'POST',
      path,
      agent: false,
      headers: {
        connection: 'close',
        authorization: `Bearer ${config.token}`,
        'content-type': 'application/octet-stream',
        'content-length': String(body.length),
        ...headers,
      },
    });
    const deadline = setTimeout(
      () => req.destroy(new Error('local tools deadline exceeded')),
      totalMs,
    );
    const connect = setTimeout(
      () => req.destroy(new Error('local tools connect timeout')),
      clientDeadlines.connectMs,
    );
    req.on('socket', (socket) => {
      if (!socket.connecting) clearTimeout(connect);
      else socket.once('connect', () => clearTimeout(connect));
    });
    req.on('response', (response) => {
      const chunks: Buffer[] = [];
      let size = 0;
      response.on('data', (chunk: Buffer) => {
        size += chunk.length;
        if (size > clientDeadlines.maxResponseBytes) {
          req.destroy(new Error('local tools answer too large'));
          return;
        }
        chunks.push(chunk);
      });
      response.on('end', () => {
        clearTimeout(deadline);
        resolve({ status: response.statusCode ?? 0, body: Buffer.concat(chunks) });
      });
      response.on('error', (error) => {
        clearTimeout(deadline);
        reject(error);
      });
    });
    req.on('error', (error) => {
      clearTimeout(deadline);
      clearTimeout(connect);
      reject(error);
    });
    req.end(body);
  });
}

const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

/** The source bytes, only if they are still exactly the finalized generation. */
async function sourceBytes(
  store: ObjectBytesPort,
  objectKeyHandle: string,
  providerGeneration: string,
  expectedSha256: string,
): Promise<Buffer | null> {
  const read = await store.read(objectKeyHandle, imageInputLimits.maxBytes);
  if (read.kind !== 'complete') return null;
  if (read.providerGeneration !== providerGeneration) return null;
  if (sha256(read.bytes) !== expectedSha256) return null;
  return read.bytes;
}

/** The client's own check of the database answer (defence in depth, §7). */
export function cleanAccepted(database: ToolsDatabase, config: LocalToolsConfig): boolean {
  if (database.state === 'fresh') return true;
  return (
    database.state === 'absent' &&
    database.exemption === 'stand-signatures-only' &&
    config.standSignaturesOnly
  );
}

export class LocalToolsScanner implements ScannerPort {
  constructor(
    private readonly config: LocalToolsConfig,
    private readonly store: ObjectBytesPort,
  ) {}

  async scan(input: ScanRequest): Promise<ScanOutcome> {
    const bytes = await sourceBytes(
      this.store,
      input.objectKeyHandle,
      input.providerGeneration,
      input.sha256,
    );
    if (bytes === null) return { toolRevision: unavailable, result: 'inconclusive' };
    let answer: HttpAnswer;
    try {
      answer = await call(
        this.config,
        toolsPaths.scan,
        bytes,
        { [toolsHeaders.requestId]: randomUUID(), [toolsHeaders.sha256]: input.sha256 },
        clientDeadlines.scanMs,
      );
    } catch {
      return { toolRevision: unavailable, result: 'inconclusive' };
    }
    if (answer.status !== 200) return { toolRevision: unavailable, result: 'inconclusive' };
    try {
      const response = parseScanResponse(JSON.parse(answer.body.toString('utf8')));
      if (response.result === 'clean' && !cleanAccepted(response.database, this.config))
        return { toolRevision: response.toolRevision, result: 'inconclusive' };
      return { toolRevision: response.toolRevision, result: response.result };
    } catch {
      return { toolRevision: unavailable, result: 'inconclusive' };
    }
  }
}

export class LocalToolsProcessor implements ProcessorPort {
  constructor(
    private readonly config: LocalToolsConfig,
    private readonly store: ObjectBytesPort,
    private readonly newVariantId: () => EntityId = () => randomUUID() as EntityId,
  ) {}

  async process(input: ProcessRequest): Promise<ProcessOutcome> {
    if (input.family !== 'image') return { toolRevision: unavailable, result: 'failed' };
    const bytes = await sourceBytes(
      this.store,
      input.objectKeyHandle,
      input.sourceProviderGeneration,
      input.sourceSha256,
    );
    if (bytes === null) return { toolRevision: unavailable, result: 'failed' };
    let answer: HttpAnswer;
    try {
      answer = await call(
        this.config,
        toolsPaths.process,
        bytes,
        {
          [toolsHeaders.requestId]: randomUUID(),
          [toolsHeaders.sha256]: input.sourceSha256,
          [toolsHeaders.profiles]: input.mandatoryVariantProfiles.join(','),
        },
        clientDeadlines.processMs,
      );
    } catch {
      return { toolRevision: unavailable, result: 'failed' };
    }
    if (answer.status !== 200) return { toolRevision: unavailable, result: 'failed' };
    let response;
    try {
      response = parseProcessResponse(JSON.parse(answer.body.toString('utf8')), {
        maxVariantBytes,
        profiles: input.mandatoryVariantProfiles,
      });
    } catch {
      return { toolRevision: unavailable, result: 'failed' };
    }
    if (response.result !== 'succeeded')
      return { toolRevision: response.toolRevision, result: response.result };
    const variants: MediaVariantRefV1[] = [];
    for (const variant of response.variants ?? []) {
      const data = Buffer.from(variant.bytesBase64, 'base64');
      // The service is not trusted blindly: length and hash are recomputed here.
      if (data.length !== variant.byteLength || sha256(data) !== variant.sha256)
        return { toolRevision: response.toolRevision, result: 'failed' };
      const variantId = this.newVariantId();
      let stored: { readonly providerGeneration: string };
      try {
        stored = await this.store.writeVariant(variantId, data, variant.format);
      } catch {
        return { toolRevision: response.toolRevision, result: 'failed' };
      }
      variants.push({
        variantId,
        profile: variant.profile,
        format: variant.format,
        providerGeneration: stored.providerGeneration,
        sha256: variant.sha256,
        byteLength: variant.byteLength,
        transformProfileRevision: response.transformProfileRevision ?? '',
        sourceProviderGeneration: input.sourceProviderGeneration,
        width: variant.width,
        height: variant.height,
      });
    }
    return { toolRevision: response.toolRevision, result: 'succeeded', variants };
  }
}

/**
 * Reads the stand's switch (§10). Absent → null (the fakes stay). Anything
 * set but not exactly valid throws, so Media does not start (fail-closed).
 */
export function localToolsConfigFrom(environment: NodeJS.ProcessEnv): LocalToolsConfig | null {
  const mode = environment.RECHARGE_MEDIA_TOOLS;
  if (mode === undefined || mode === '') return null;
  if (mode !== 'local-real') throw new Error('RECHARGE_MEDIA_TOOLS: unknown mode');
  const port = Number(environment.RECHARGE_MEDIA_TOOLS_PORT);
  if (!Number.isSafeInteger(port) || port < 1024 || port > 65535)
    throw new Error('RECHARGE_MEDIA_TOOLS_PORT: invalid');
  const token = environment.RECHARGE_MEDIA_TOOLS_TOKEN ?? '';
  if (!/^[0-9a-f]{64}$/u.test(token)) throw new Error('RECHARGE_MEDIA_TOOLS_TOKEN: invalid');
  const database = environment.RECHARGE_MEDIA_TOOLS_DATABASE;
  if (database !== undefined && database !== '' && database !== 'stand-signatures-only')
    throw new Error('RECHARGE_MEDIA_TOOLS_DATABASE: unknown value');
  return { port, token, standSignaturesOnly: database === 'stand-signatures-only' };
}
