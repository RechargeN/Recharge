import { randomUUID } from 'node:crypto';
import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';

import type { EntityId } from '../../../shared/ids.js';
import type { ObjectBytesPort } from '../application/ports/object_store_port.js';
import type {
  ProcessOutcome,
  ProcessorPort,
  ProcessRequest,
} from '../application/ports/processor_port.js';
import type { ScanOutcome, ScannerPort, ScanRequest } from '../application/ports/scanner_port.js';
import {
  processThroughTools,
  scanThroughTools,
  type HttpAnswer,
  type ToolsTransport,
} from './local_tools_client.js';
import { clientDeadlines } from './media_tool_limits.js';

/**
 * N3b adapters behind `ScannerPort` and `ProcessorPort` for recharge-dev-n2a01
 * only: the same checks as the D1 local client (shared core in
 * local_tools_client.ts), but over HTTPS to the two private Cloud Run services,
 * with a Google ID token for Cloud Run IAM and the per-service secret header.
 * Fail-closed: no token, network error, deadline, any non-200, a foreign
 * answer or a database that is not `fresh` is `inconclusive` / `failed`.
 * There is no stand exemption here.
 */
export const devCloudToolsProject = 'recharge-dev-n2a01';
export const devCloudToolsUrls = Object.freeze({
  scanner: 'https://media-scanner-420479958348.europe-west1.run.app',
  processor: 'https://media-processor-420479958348.europe-west1.run.app',
});
export const toolsTokenHeader = 'x-recharge-tools-token';

/** Google ID token for an audience (the service URL). */
export type IdTokenSource = (audience: string) => Promise<string>;

export interface CloudToolsConfig {
  readonly url: string;
  readonly token: string;
  readonly idToken: IdTokenSource;
  /** Tests only: a plain-HTTP stand-in; production is always HTTPS on 443. */
  readonly request?: typeof httpsRequest;
}

const unavailable = 'cloud-tools-unavailable';
const emulatorVariables = [
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
  'STORAGE_EMULATOR_HOST',
] as const;

function cloudCall(
  config: CloudToolsConfig,
  idToken: string,
  path: string,
  body: Buffer,
  headers: Readonly<Record<string, string>>,
  totalMs: number,
): Promise<HttpAnswer> {
  const target = new URL(path, config.url);
  return new Promise((resolve, reject) => {
    const req = (config.request ?? httpsRequest)({
      host: target.hostname,
      port: config.request === undefined ? 443 : Number(target.port),
      method: 'POST',
      path: target.pathname,
      agent: false,
      headers: {
        connection: 'close',
        authorization: `Bearer ${idToken}`,
        [toolsTokenHeader]: config.token,
        'content-type': 'application/octet-stream',
        'content-length': String(body.length),
        ...headers,
      },
    });
    const deadline = setTimeout(
      () => req.destroy(new Error('cloud tools deadline exceeded')),
      totalMs,
    );
    req.on('response', (response) => {
      const chunks: Buffer[] = [];
      let size = 0;
      response.on('data', (chunk: Buffer) => {
        size += chunk.length;
        if (size > clientDeadlines.maxResponseBytes) {
          req.destroy(new Error('cloud tools answer too large'));
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
      reject(error);
    });
    req.end(body);
  });
}

function transportFor(config: CloudToolsConfig): ToolsTransport {
  return async (path, body, headers, totalMs) => {
    const started = Date.now();
    const idToken = await config.idToken(config.url);
    const left = totalMs - (Date.now() - started);
    if (left <= 0) throw new Error('cloud tools deadline exceeded');
    return cloudCall(config, idToken, path, body, headers, left);
  };
}

/** `clean` only on a fresh official database. */
const freshOnly = (database: { readonly state: string }) => database.state === 'fresh';

export class CloudToolsScanner implements ScannerPort {
  constructor(
    private readonly config: CloudToolsConfig,
    private readonly store: ObjectBytesPort,
  ) {}

  scan(input: ScanRequest): Promise<ScanOutcome> {
    return scanThroughTools(transportFor(this.config), this.store, input, freshOnly, unavailable);
  }
}

export class CloudToolsProcessor implements ProcessorPort {
  constructor(
    private readonly config: CloudToolsConfig,
    private readonly store: ObjectBytesPort,
    private readonly newVariantId: () => EntityId = () => randomUUID() as EntityId,
  ) {}

  process(input: ProcessRequest): Promise<ProcessOutcome> {
    return processThroughTools(
      transportFor(this.config),
      this.store,
      input,
      this.newVariantId,
      unavailable,
    );
  }
}

/**
 * ID tokens from the metadata server of the Functions/Cloud Run instance,
 * cached per audience for 45 minutes (they live one hour).
 */
export function metadataIdTokenSource(
  host = 'metadata.google.internal',
  now: () => number = Date.now,
  port = 80,
): IdTokenSource {
  const cache = new Map<string, { token: string; until: number }>();
  return (audience) => {
    const hit = cache.get(audience);
    if (hit !== undefined && hit.until > now()) return Promise.resolve(hit.token);
    return new Promise((resolve, reject) => {
      const req = httpRequest({
        host,
        port,
        method: 'GET',
        path: `/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encodeURIComponent(audience)}`,
        agent: false,
        headers: { 'metadata-flavor': 'Google', connection: 'close' },
      });
      const deadline = setTimeout(() => req.destroy(new Error('metadata deadline')), 3_000);
      req.on('response', (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => {
          if (chunks.reduce((sum, item) => sum + item.length, 0) > 8_192)
            req.destroy(new Error('metadata answer too large'));
          else chunks.push(chunk);
        });
        response.on('end', () => {
          clearTimeout(deadline);
          const token = Buffer.concat(chunks).toString('utf8').trim();
          if (response.statusCode !== 200 || !/^[\w-]+\.[\w-]+\.[\w-]+$/u.test(token)) {
            reject(new Error('metadata identity refused'));
            return;
          }
          cache.set(audience, { token, until: now() + 45 * 60 * 1000 });
          resolve(token);
        });
      });
      req.on('error', (error) => {
        clearTimeout(deadline);
        reject(error);
      });
      req.end();
    });
  };
}

/**
 * The N3b switch. Absent → null. `dev-cloud` needs exactly recharge-dev-n2a01,
 * no Emulator variable and a 64-hex secret; anything else set throws, so Media
 * does not start (fail-closed, never a fallback to fakes or local tools).
 */
export function cloudToolsConfigFrom(
  environment: NodeJS.ProcessEnv,
  idToken: IdTokenSource = metadataIdTokenSource(),
): { readonly scanner: CloudToolsConfig; readonly processor: CloudToolsConfig } | null {
  const mode = environment.RECHARGE_MEDIA_TOOLS;
  if (mode === undefined || mode === '') return null;
  if (mode !== 'dev-cloud') throw new Error('RECHARGE_MEDIA_TOOLS: not dev-cloud');
  if (environment.GCLOUD_PROJECT !== devCloudToolsProject)
    throw new Error('RECHARGE_MEDIA_TOOLS: dev-cloud is bound to recharge-dev-n2a01');
  for (const name of emulatorVariables)
    if ((environment[name] ?? '') !== '')
      throw new Error(`RECHARGE_MEDIA_TOOLS: dev-cloud with ${name} set`);
  const token = environment.RECHARGE_MEDIA_TOOLS_TOKEN ?? '';
  if (!/^[0-9a-f]{64}$/u.test(token)) throw new Error('RECHARGE_MEDIA_TOOLS_TOKEN: invalid');
  return {
    scanner: { url: devCloudToolsUrls.scanner, token, idToken },
    processor: { url: devCloudToolsUrls.processor, token, idToken },
  };
}
