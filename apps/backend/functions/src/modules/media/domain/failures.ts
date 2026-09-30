import type { MediaFailureCode } from '../../../contracts/media_v1.js';

export type MediaResult<T> =
  | Readonly<{ kind: 'succeeded'; data: T }>
  | Readonly<{ kind: 'rejected'; code: MediaFailureCode }>
  | Readonly<{ kind: 'unsupportedContract'; code: 'unsupported_version' }>;

export const succeeded = <T>(data: T): MediaResult<T> => ({ kind: 'succeeded', data });
export const rejected = <T = never>(code: MediaFailureCode): MediaResult<T> => ({
  kind: 'rejected',
  code,
});
export const unsupported = <T = never>(): MediaResult<T> => ({
  kind: 'unsupportedContract',
  code: 'unsupported_version',
});

/** Thrown inside a transaction to abort it with a typed, non-mutating outcome. */
export class MediaDomainRefusal extends Error {
  constructor(readonly code: MediaFailureCode) {
    super(code);
    this.name = 'MediaDomainRefusal';
  }
}

/** Raised by repositories when an optimistic/immutability guard fails. */
export class MediaRepositoryConflict extends Error {
  constructor(
    readonly reason: 'asset_revision' | 'session_revision' | 'immutable_receipt' | 'duplicate_id',
  ) {
    super(reason);
    this.name = 'MediaRepositoryConflict';
  }
}

export type MediaResultType = 'uploadSession' | 'assetStatus' | 'processingReceipt';

export function toMediaWireResult<T>(
  resultType: MediaResultType,
  result: MediaResult<T>,
): Readonly<Record<string, unknown>> {
  if (result.kind === 'succeeded')
    return { schemaVersion: 1, kind: 'succeeded', resultType, data: result.data };
  return { schemaVersion: 1, kind: result.kind, code: result.code };
}
