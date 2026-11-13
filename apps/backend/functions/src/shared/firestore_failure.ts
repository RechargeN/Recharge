import { rejected, retryable, type BookingResult } from './failures.js';

export interface FirestoreFailureLogRecord {
  readonly eventName: 'booking.firestore_failure';
  readonly correlationId: string;
  readonly operationName: string;
  readonly safeErrorType: string;
  readonly code: 'unexpected_firestore_failure';
}

export interface FirestoreFailureLogger {
  error(record: FirestoreFailureLogRecord): void;
}

export interface FirestoreFailureContext {
  readonly correlationId: string;
  readonly operationName: string;
  readonly logger?: FirestoreFailureLogger;
}

export function classifyFirestoreFailure<T = never>(
  error: unknown,
  context: FirestoreFailureContext,
): BookingResult<T> {
  const code = firestoreStatusCode(error);
  if (code === 'ABORTED') return retryable('contention');
  if (code === 'UNAVAILABLE' || code === 'DEADLINE_EXCEEDED') {
    return retryable('temporarily_unavailable');
  }

  context.logger?.error({
    eventName: 'booking.firestore_failure',
    correlationId: context.correlationId,
    operationName: context.operationName,
    safeErrorType: safeErrorType(error),
    code: 'unexpected_firestore_failure',
  });
  return rejected('temporarily_unavailable');
}

function firestoreStatusCode(error: unknown): string | undefined {
  if (typeof error !== 'object' || error === null || Array.isArray(error)) return undefined;
  const code = (error as Readonly<Record<string, unknown>>).code;
  if (typeof code === 'number') return grpcCodeName(code);
  if (typeof code !== 'string') return undefined;
  if (/^\d+$/u.test(code)) return grpcCodeName(Number(code));
  const normalized = code
    .toUpperCase()
    .replace(/^FIRESTORE[\/-]/u, '')
    .replace(/-/gu, '_');
  return normalized;
}

function grpcCodeName(code: number): string | undefined {
  if (code === 4) return 'DEADLINE_EXCEEDED';
  if (code === 10) return 'ABORTED';
  if (code === 14) return 'UNAVAILABLE';
  return undefined;
}

function safeErrorType(error: unknown): string {
  if (error instanceof Error && /^[A-Za-z][A-Za-z0-9_.-]{0,63}$/u.test(error.name)) {
    return error.name;
  }
  return typeof error;
}
