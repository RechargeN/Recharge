export type BookingFailureCode =
  | 'feature_disabled'
  | 'unauthenticated'
  | 'permission_denied'
  | 'invalid_contract'
  | 'unsupported_schema'
  | 'unsupported_flow'
  | 'event_unavailable'
  | 'registration_not_open'
  | 'registration_closed'
  | 'cancellation_deadline_passed'
  | 'sold_out'
  | 'already_active'
  | 'concurrency_cap_reached'
  | 'revision_conflict'
  | 'idempotency_conflict'
  | 'contention'
  | 'temporarily_unavailable';

export type BookingResult<T> =
  | Readonly<{ kind: 'succeeded'; data: T }>
  | Readonly<{ kind: 'rejected'; code: BookingFailureCode }>
  | Readonly<{ kind: 'retryableFailure'; code: 'contention' | 'temporarily_unavailable' }>
  | Readonly<{ kind: 'unsupportedContract'; code: 'unsupported_schema' | 'unsupported_flow' }>;

export const succeeded = <T>(data: T): BookingResult<T> => ({ kind: 'succeeded', data });
export const rejected = <T = never>(code: BookingFailureCode): BookingResult<T> => ({
  kind: 'rejected',
  code,
});
export const retryable = <T = never>(
  code: 'contention' | 'temporarily_unavailable',
): BookingResult<T> => ({ kind: 'retryableFailure', code });
export const unsupported = <T = never>(
  code: 'unsupported_schema' | 'unsupported_flow',
): BookingResult<T> => ({ kind: 'unsupportedContract', code });

export class BookingDomainRefusal extends Error {
  constructor(readonly code: BookingFailureCode) {
    super(code);
    this.name = 'BookingDomainRefusal';
  }
}

export function toBookingCommandWireResult<T extends Readonly<{ booking: unknown }>>(
  result: BookingResult<T>,
  requestId: string,
  serverTime: string,
): Readonly<Record<string, unknown>> {
  const base = {
    schemaVersion: 1,
    kind: result.kind,
    requestId,
    correlationId: requestId,
    serverTime,
  } as const;
  if (result.kind === 'succeeded') return { ...base, booking: result.data.booking };
  if (result.kind === 'unsupportedContract') {
    return { ...base, unsupportedPayload: { reason: result.code } };
  }
  const code = wireErrorCode(result.code);
  return {
    ...base,
    error: {
      schemaVersion: 1,
      code,
      retryable: result.kind === 'retryableFailure',
      correlationId: requestId,
    },
  };
}

function wireErrorCode(code: BookingFailureCode): string {
  if (code === 'unauthenticated') return 'not_authenticated';
  if (code === 'permission_denied') return 'not_authorized';
  return code;
}
