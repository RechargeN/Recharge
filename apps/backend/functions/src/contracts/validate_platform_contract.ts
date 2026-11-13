import { createHash } from 'node:crypto';

import type {
  ClientCompatibilityDecision,
  ClientContext,
  IdempotencyDecision,
  JsonValue,
  MinimumClientPolicy,
  SemanticCommandInput,
  SemanticPayloadHash,
} from './platform_v1.js';
import {
  boundedValidationIssues,
  createPlatformSchemaRegistry,
  type PlatformContractTarget,
} from './schema_registry.js';
import type { IdempotencyKey } from '../shared/ids.js';

export type ContractValidationResult<T> =
  Readonly<{ ok: true; value: T }> | Readonly<{ ok: false; issues: readonly string[] }>;

let registryPromise: ReturnType<typeof createPlatformSchemaRegistry> | undefined;

export async function validatePlatformContract<T>(
  target: PlatformContractTarget,
  value: unknown,
): Promise<ContractValidationResult<T>> {
  registryPromise ??= createPlatformSchemaRegistry();
  const registry = await registryPromise;
  const validator = registry.validator(target);
  if (!validator(value)) {
    return { ok: false, issues: boundedValidationIssues(validator.errors) };
  }
  return { ok: true, value: value as T };
}

export function createSemanticPayloadHash(input: SemanticCommandInput): SemanticPayloadHash {
  const canonical = canonicalizeJson({
    actorScope: input.actorScope,
    commandType: input.commandType,
    commandVersion: input.commandVersion,
    payload: input.payload,
  });
  return `sha256:${createHash('sha256').update(canonical, 'utf8').digest('hex')}` as SemanticPayloadHash;
}

export interface StoredIdempotencyResult {
  readonly scopeKey: string;
  readonly idempotencyKey: IdempotencyKey;
  readonly semanticPayloadHash: SemanticPayloadHash;
  readonly state: 'inProgress' | 'committed';
  readonly result?: JsonValue;
}

export function decideIdempotency(
  scopeKey: string,
  idempotencyKey: IdempotencyKey,
  semanticPayloadHash: SemanticPayloadHash,
  stored: StoredIdempotencyResult | undefined,
): IdempotencyDecision {
  if (
    stored === undefined ||
    stored.scopeKey !== scopeKey ||
    stored.idempotencyKey !== idempotencyKey
  ) {
    return { kind: 'execute', semanticPayloadHash };
  }
  if (stored.semanticPayloadHash !== semanticPayloadHash) {
    return { kind: 'reject', code: 'idempotency_conflict', semanticPayloadHash };
  }
  if (stored.state === 'inProgress') return { kind: 'inProgress', semanticPayloadHash };
  if (stored.result === undefined) {
    throw new TypeError('Committed idempotency result must contain a typed result');
  }
  return { kind: 'replay', semanticPayloadHash, result: stored.result };
}

export function evaluateClientCompatibility(
  client: ClientContext,
  contractMajor: number,
  policy: MinimumClientPolicy,
): ClientCompatibilityDecision {
  if (client.platform !== policy.platform || client.buildNumber < policy.minSupportedBuild) {
    return { kind: 'rejected', code: 'unsupported_client' };
  }
  if (!policy.supportedContractMajors.includes(contractMajor)) {
    return { kind: 'rejected', code: 'unsupported_contract' };
  }
  return {
    kind: 'supported',
    updateRecommended: client.buildNumber < policy.recommendedBuild,
  };
}

export function canonicalizeJson(value: JsonValue): string {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('Semantic JSON numbers must be finite');
    return JSON.stringify(Object.is(value, -0) ? 0 : value);
  }
  if (isJsonArray(value)) return `[${value.map((item) => canonicalizeJson(item)).join(',')}]`;

  const entries = Object.entries(value).sort(([left], [right]) =>
    left < right ? -1 : left > right ? 1 : 0,
  );
  return `{${entries
    .map(([key, item]) => `${JSON.stringify(key)}:${canonicalizeJson(item)}`)
    .join(',')}}`;
}

function isJsonArray(value: JsonValue): value is readonly JsonValue[] {
  return Array.isArray(value);
}
