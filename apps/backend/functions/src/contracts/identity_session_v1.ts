import type { IdentityFailureCode } from '../modules/identity_publisher/domain/failures.js';

/**
 * L4.8: mirrors `$defs/failureCode` of `identity_session_result.schema.json`.
 * It holds every IdentityFailureCode, because any of them can be mapped to the
 * answer, plus the transport refusals.
 */
export const identitySessionFailureCodes = [
  'account_blocked',
  'account_creation_disabled',
  'account_restricted',
  'app_check_required',
  'capability_denied',
  'contention',
  'creator_verification_required',
  'creator_verification_unavailable',
  'feature_disabled',
  'invalid_contract',
  'invalid_transition',
  'membership_inactive',
  'not_found_or_not_accessible',
  'policy_unavailable',
  'provider_assertion_invalid',
  'provider_subject_conflict',
  'publisher_not_accessible',
  'rate_limited',
  'recent_auth_required',
  'revision_conflict',
  'session_expired',
  'session_limit_reached',
  'session_revoked',
  'snapshot_stale',
  'temporarily_unavailable',
  'unauthenticated',
  'unsupported_schema',
] as const;
export type IdentitySessionFailureCode = (typeof identitySessionFailureCodes)[number];
type _EveryIdentityFailureIsListed = IdentityFailureCode extends IdentitySessionFailureCode
  ? true
  : never;
export const everyIdentityFailureIsListed: _EveryIdentityFailureIsListed = true;

export interface EstablishIdentitySessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'establishIdentitySession';
  readonly requestId: string;
  readonly installationId: string;
}

export interface RefreshIdentitySessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'refreshIdentitySession';
  readonly requestId: string;
  readonly sessionContext: Readonly<{
    sessionId: string;
    sessionHandle: string;
    installationId: string;
  }>;
}

export interface RecoverIdentitySessionsCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'recoverIdentitySessions';
  readonly requestId: string;
  readonly installationId: string;
}

export type IdentitySessionCommandV1 =
  | EstablishIdentitySessionCommandV1
  | RefreshIdentitySessionCommandV1
  | RecoverIdentitySessionsCommandV1;

export type IdentitySessionCommandInspection =
  | Readonly<{ ok: true; value: IdentitySessionCommandV1 }>
  | Readonly<{ ok: false; reason: 'invalid_contract' | 'unsupported_schema' }>;

const boundedId = /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u;
const installationId = /^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u;

export function inspectIdentitySessionCommand(value: unknown): IdentitySessionCommandInspection {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return { ok: false, reason: 'invalid_contract' };
  }
  const record = value as Record<string, unknown>;
  if (record.schemaVersion !== 1) return { ok: false, reason: 'unsupported_schema' };
  if (typeof record.requestId !== 'string' || !boundedId.test(record.requestId)) {
    return { ok: false, reason: 'invalid_contract' };
  }
  if (
    (record.commandType === 'establishIdentitySession' ||
      record.commandType === 'recoverIdentitySessions') &&
    typeof record.installationId === 'string' &&
    installationId.test(record.installationId) &&
    Object.keys(record).every((key) =>
      ['schemaVersion', 'commandType', 'requestId', 'installationId'].includes(key),
    )
  ) {
    return { ok: true, value: record as unknown as IdentitySessionCommandV1 };
  }
  if (
    record.commandType === 'refreshIdentitySession' &&
    validSessionContext(record.sessionContext) &&
    Object.keys(record).every((key) =>
      ['schemaVersion', 'commandType', 'requestId', 'sessionContext'].includes(key),
    )
  ) {
    return { ok: true, value: record as unknown as RefreshIdentitySessionCommandV1 };
  }
  return { ok: false, reason: 'invalid_contract' };
}

function validSessionContext(value: unknown): boolean {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const context = value as Record<string, unknown>;
  return (
    Object.keys(context).every((key) =>
      ['sessionId', 'sessionHandle', 'installationId'].includes(key),
    ) &&
    typeof context.sessionId === 'string' &&
    boundedId.test(context.sessionId) &&
    typeof context.sessionHandle === 'string' &&
    /^[A-Za-z0-9_-]{43}$/u.test(context.sessionHandle) &&
    typeof context.installationId === 'string' &&
    installationId.test(context.installationId)
  );
}
