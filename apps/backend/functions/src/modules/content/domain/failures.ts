import type {
  ContentFailureCode,
  ContentValidationViolationV1,
} from '../../../contracts/content_v1.js';

export type ContentResult<T> =
  | Readonly<{ kind: 'succeeded'; data: T }>
  | Readonly<{
      kind: 'rejected';
      code: ContentFailureCode;
      violations?: readonly ContentValidationViolationV1[];
    }>
  | Readonly<{
      kind: 'unsupportedContract';
      code: 'unsupported_version' | 'content_type_unsupported';
    }>;

export const succeeded = <T>(data: T): ContentResult<T> => ({ kind: 'succeeded', data });
export const rejected = <T = never>(
  code: ContentFailureCode,
  violations?: readonly ContentValidationViolationV1[],
): ContentResult<T> => ({
  kind: 'rejected',
  code,
  ...(code === 'validation_failed' && violations !== undefined && violations.length > 0
    ? { violations }
    : {}),
});
export const unsupported = <T = never>(
  code: 'unsupported_version' | 'content_type_unsupported',
): ContentResult<T> => ({ kind: 'unsupportedContract', code });

/** Thrown inside a transaction to abort it with a typed, non-mutating outcome. */
export class ContentDomainRefusal extends Error {
  constructor(
    readonly code: ContentFailureCode,
    readonly violations?: readonly ContentValidationViolationV1[],
  ) {
    super(code);
    this.name = 'ContentDomainRefusal';
  }
}

/** Raised by repositories when an optimistic/immutability guard fails. */
export class ContentRepositoryConflict extends Error {
  constructor(readonly reason: 'pointer_revision' | 'immutable_revision' | 'duplicate_id') {
    super(reason);
    this.name = 'ContentRepositoryConflict';
  }
}

export type ContentResultType =
  | 'draft'
  | 'submission'
  | 'publishedRevision'
  | 'publicationStatus'
  | 'publicationPointer'
  | 'moderationAcknowledgement';

export function toContentWireResult<T>(
  resultType: ContentResultType,
  result: ContentResult<T>,
): Readonly<Record<string, unknown>> {
  if (result.kind === 'succeeded')
    return { schemaVersion: 1, kind: 'succeeded', resultType, data: result.data };
  return {
    schemaVersion: 1,
    kind: result.kind,
    code: result.code,
    ...(result.kind === 'rejected' &&
    result.code === 'validation_failed' &&
    result.violations !== undefined
      ? { violations: result.violations }
      : {}),
  };
}
