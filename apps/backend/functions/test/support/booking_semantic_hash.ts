import { createHash } from 'node:crypto';

import { StrictJsonReader, validateSafeJson, validateUnicode } from './booking_raw_json.js';

type JsonObject = Record<string, unknown>;

export interface BookingSemanticHashResult {
  readonly projection: JsonObject;
  readonly canonicalHex: string;
  readonly digest: string;
  readonly logicalIdentity: string;
}

export function computeBookingSemanticHash(
  rawCommandJson: string,
  resolvedActorScope: JsonObject,
  validateCommand: (value: unknown) => boolean,
): BookingSemanticHashResult {
  const decoded = new StrictJsonReader(rawCommandJson).read();
  const command = asObject(decoded, 'command_root_not_object');
  if (!validateCommand(command)) throw new TypeError('invalid_contract');
  validateCommandEnvelope(command);
  validateActor(resolvedActorScope);
  validateSafeJson(command);

  const projection: JsonObject = {
    algorithmVersion: 'booking_semantic_hash_v1',
    commandType: command.commandType,
    commandSchemaVersion: command.schemaVersion,
    resolvedActorScope: { kind: resolvedActorScope.kind, id: resolvedActorScope.id },
    ...(command.expectedBookingRevision === undefined
      ? {}
      : { expectedBookingRevision: command.expectedBookingRevision }),
    ...(command.occurredAgainstEventRevision === undefined
      ? {}
      : { occurredAgainstEventRevision: command.occurredAgainstEventRevision }),
    payload: JSON.parse(JSON.stringify(command.payload)) as unknown,
  };
  const canonical = canonicalJson(projection);
  const bytes = Buffer.from(canonical, 'utf8');
  return {
    projection,
    canonicalHex: bytes.toString('hex'),
    digest: createHash('sha256').update(bytes).digest('hex'),
    logicalIdentity: `${String(resolvedActorScope.kind)}:${String(resolvedActorScope.id)}|${String(command.commandType)}|${String(command.idempotencyKey)}`,
  };
}

function validateActor(actor: JsonObject): void {
  if (
    Object.keys(actor).length !== 2 ||
    actor.kind !== 'user' ||
    typeof actor.id !== 'string' ||
    actor.id.length === 0
  ) {
    throw new TypeError('invalid_actor_scope');
  }
  validateUnicode(actor.id);
}

function validateCommandEnvelope(command: JsonObject): void {
  const allowed = new Set([
    'schemaVersion',
    'commandType',
    'requestId',
    'idempotencyKey',
    'expectedBookingRevision',
    'occurredAgainstEventRevision',
    'payload',
  ]);
  for (const key of Object.keys(command)) {
    if (!allowed.has(key)) throw new TypeError(`unknown_command_field:${key}`);
  }
  if (
    command.schemaVersion !== 1 ||
    typeof command.commandType !== 'string' ||
    typeof command.requestId !== 'string' ||
    typeof command.idempotencyKey !== 'string'
  ) {
    throw new TypeError('invalid_command_envelope');
  }
  asObject(command.payload, 'invalid_command_payload');
  for (const revision of ['expectedBookingRevision', 'occurredAgainstEventRevision'] as const) {
    if (Object.hasOwn(command, revision) && !Number.isSafeInteger(command[revision])) {
      throw new TypeError(`invalid_revision:${revision}`);
    }
  }
}

function canonicalJson(value: unknown): string {
  if (value === null) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return Object.is(value, -0) ? '0' : String(value);
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (typeof value === 'object') {
    const object = value as JsonObject;
    const keys = Object.keys(object).sort(compareUtf16);
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(object[key])}`).join(',')}}`;
  }
  throw new TypeError('unsupported_canonical_value');
}

function compareUtf16(left: string, right: string): number {
  const length = Math.min(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    const difference = left.charCodeAt(index) - right.charCodeAt(index);
    if (difference !== 0) return difference;
  }
  return left.length - right.length;
}

function asObject(value: unknown, reason: string): JsonObject {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError(reason);
  }
  return value as JsonObject;
}
