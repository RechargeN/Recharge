/**
 * Wire protocol of the D1 local Media tools service (amendment §4.10), shared
 * by the Functions client and the stand service. HTTP/1.1 on 127.0.0.1 only,
 * no keep-alive, bearer token per run. Everything that crosses the wire is
 * checked here; anything unexpected is a protocol error.
 */

export const toolsPaths = Object.freeze({
  health: '/v1/health',
  scan: '/v1/scan',
  process: '/v1/process',
  arm: '/v1/control/arm',
  drain: '/v1/control/drain',
  probe: '/v1/selftest/probe',
});

export const toolsHeaders = Object.freeze({
  requestId: 'x-recharge-request-id',
  sha256: 'x-recharge-sha256',
  profiles: 'x-recharge-profiles',
});

export class ToolsProtocolError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'ToolsProtocolError';
  }
}

export type ToolsDatabase =
  | { readonly state: 'fresh' | 'stale'; readonly daily: number; readonly builtAt: string }
  | {
      readonly state: 'absent';
      readonly reason: string;
      readonly exemption?: 'stand-signatures-only';
    };

export interface ToolsScanResponse {
  readonly schemaVersion: 1;
  readonly result: 'clean' | 'rejected' | 'inconclusive';
  readonly toolRevision: string;
  readonly database: ToolsDatabase;
  readonly signature?: string;
  readonly reason?: string;
}

export interface ToolsVariant {
  readonly profile: string;
  readonly format: 'image/webp';
  readonly width: number;
  readonly height: number;
  readonly byteLength: number;
  readonly sha256: string;
  readonly bytesBase64: string;
}

export interface ToolsProcessResponse {
  readonly schemaVersion: 1;
  readonly result: 'succeeded' | 'rejected' | 'failed';
  readonly toolRevision: string;
  readonly transformProfileRevision?: string;
  readonly variants?: readonly ToolsVariant[];
  readonly reason?: string;
}

export interface ToolsHealth {
  readonly schemaVersion: 1;
  readonly state: 'starting' | 'ready' | 'degraded' | 'draining';
  readonly instanceId: string;
  readonly toolRevision: { readonly scanner: string | null; readonly processor: string | null };
  readonly database: ToolsDatabase | null;
  readonly queues: {
    readonly scan: { readonly active: number; readonly waiting: number };
    readonly process: { readonly active: number; readonly waiting: number };
  };
  readonly worker: { readonly pid: number } | null;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const sha256Pattern = /^[0-9a-f]{64}$/u;
const textPattern = /^[\x20-\x7e]{1,200}$/u;

function text(value: unknown, field: string): string {
  if (typeof value !== 'string' || !textPattern.test(value))
    throw new ToolsProtocolError(`invalid ${field}`);
  return value;
}
function optionalText(value: unknown, field: string): string | undefined {
  return value === undefined ? undefined : text(value, field);
}
function count(value: unknown, field: string, max: number): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0 || (value as number) > max)
    throw new ToolsProtocolError(`invalid ${field}`);
  return value as number;
}

export function parseDatabase(value: unknown): ToolsDatabase {
  if (!isRecord(value)) throw new ToolsProtocolError('invalid database');
  if (value.state === 'fresh' || value.state === 'stale')
    return {
      state: value.state,
      daily: count(value.daily, 'daily', 10_000_000),
      builtAt: text(value.builtAt, 'builtAt'),
    };
  if (value.state === 'absent') {
    const exemption = value.exemption;
    if (exemption !== undefined && exemption !== 'stand-signatures-only')
      throw new ToolsProtocolError('invalid exemption');
    return {
      state: 'absent',
      reason: text(value.reason, 'reason'),
      ...(exemption === undefined ? {} : { exemption }),
    };
  }
  throw new ToolsProtocolError('invalid database state');
}

export function parseScanResponse(value: unknown): ToolsScanResponse {
  if (!isRecord(value) || value.schemaVersion !== 1) throw new ToolsProtocolError('invalid scan');
  if (value.result !== 'clean' && value.result !== 'rejected' && value.result !== 'inconclusive')
    throw new ToolsProtocolError('invalid scan result');
  const signature = optionalText(value.signature, 'signature');
  const reason = optionalText(value.reason, 'reason');
  return {
    schemaVersion: 1,
    result: value.result,
    toolRevision: text(value.toolRevision, 'toolRevision'),
    database: parseDatabase(value.database),
    ...(signature === undefined ? {} : { signature }),
    ...(reason === undefined ? {} : { reason }),
  };
}

export function parseProcessResponse(
  value: unknown,
  limits: { readonly maxVariantBytes: number; readonly profiles: readonly string[] },
): ToolsProcessResponse {
  if (!isRecord(value) || value.schemaVersion !== 1)
    throw new ToolsProtocolError('invalid process');
  if (value.result !== 'succeeded' && value.result !== 'rejected' && value.result !== 'failed')
    throw new ToolsProtocolError('invalid process result');
  const toolRevision = text(value.toolRevision, 'toolRevision');
  const reason = optionalText(value.reason, 'reason');
  if (value.result !== 'succeeded')
    return {
      schemaVersion: 1,
      result: value.result,
      toolRevision,
      ...(reason === undefined ? {} : { reason }),
    };
  if (!Array.isArray(value.variants) || value.variants.length !== limits.profiles.length)
    throw new ToolsProtocolError('invalid variants');
  const seen = new Set<string>();
  const variants = value.variants.map((raw: unknown): ToolsVariant => {
    if (!isRecord(raw)) throw new ToolsProtocolError('invalid variant');
    const profile = text(raw.profile, 'profile');
    if (!limits.profiles.includes(profile) || seen.has(profile))
      throw new ToolsProtocolError('unexpected variant profile');
    seen.add(profile);
    if (raw.format !== 'image/webp') throw new ToolsProtocolError('invalid variant format');
    if (typeof raw.sha256 !== 'string' || !sha256Pattern.test(raw.sha256))
      throw new ToolsProtocolError('invalid variant sha256');
    if (typeof raw.bytesBase64 !== 'string') throw new ToolsProtocolError('invalid variant bytes');
    return {
      profile,
      format: 'image/webp',
      width: count(raw.width, 'width', 10_000),
      height: count(raw.height, 'height', 10_000),
      byteLength: count(raw.byteLength, 'byteLength', limits.maxVariantBytes),
      sha256: raw.sha256,
      bytesBase64: raw.bytesBase64,
    };
  });
  return {
    schemaVersion: 1,
    result: 'succeeded',
    toolRevision,
    transformProfileRevision: text(value.transformProfileRevision, 'transformProfileRevision'),
    variants,
  };
}
