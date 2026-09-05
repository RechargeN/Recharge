import { createHash } from 'node:crypto';

interface IdempotencyBase {
  readonly schemaVersion: 1;
  readonly actorId: string;
  readonly commandType: 'createBooking' | 'cancelBooking';
  readonly semanticHash: string;
  readonly logicalMutationId: string;
  readonly requestAttemptId: string;
  readonly bookingId: string;
  readonly createdAt: string;
}

export interface LogicalIdempotencyRecord extends IdempotencyBase {
  readonly kind: 'logicalMutation';
  readonly outcome: unknown;
}

export interface RequestAttemptRecord extends IdempotencyBase {
  readonly kind: 'requestAttempt';
}

export type IdempotencyRecord = LogicalIdempotencyRecord | RequestAttemptRecord;

export function toRequestAttemptRecord(
  logical: LogicalIdempotencyRecord,
  nextRequestAttemptId: string,
): RequestAttemptRecord {
  return {
    schemaVersion: logical.schemaVersion,
    kind: 'requestAttempt',
    actorId: logical.actorId,
    commandType: logical.commandType,
    semanticHash: logical.semanticHash,
    logicalMutationId: logical.logicalMutationId,
    requestAttemptId: nextRequestAttemptId,
    bookingId: logical.bookingId,
    createdAt: logical.createdAt,
  };
}

export function logicalMutationId(
  actorId: string,
  commandType: string,
  idempotencyKey: string,
): string {
  return `m1_${lengthPrefixedHash('booking_logical_mutation_v1', actorId, commandType, idempotencyKey)}`;
}

export function requestAttemptId(actorId: string, requestId: string): string {
  return `r1_${lengthPrefixedHash('booking_request_attempt_v1', actorId, requestId)}`;
}

export function lengthPrefixedHash(...parts: readonly string[]): string {
  const hash = createHash('sha256');
  for (const part of parts) {
    const bytes = Buffer.from(part, 'utf8');
    const length = Buffer.allocUnsafe(4);
    length.writeUInt32BE(bytes.length, 0);
    hash.update(length);
    hash.update(bytes);
  }
  return hash.digest('hex');
}
