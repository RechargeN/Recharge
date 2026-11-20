import type { IdentitySessionV1, IdentitySessionStatus } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import type { Account } from './account.js';
import { IdentityFailure } from './failures.js';
import { createHash } from 'node:crypto';

export type IdentitySession = IdentitySessionV1;

const terminalStates = new Set<IdentitySessionStatus>(['revoked', 'expired', 'compromised']);
export const identitySessionIdleLifetimeMs = 30 * 24 * 60 * 60 * 1000;

export function createSession(input: {
  readonly sessionId: string;
  readonly userId: string;
  readonly issuedAtUtc: string;
  readonly authzRevision: number;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly sessionHandle: string;
}): IdentitySession {
  const issuedAtUtc = parseUtcInstant(input.issuedAtUtc);
  return deepFreeze({
    schemaVersion: 1,
    sessionId: parseEntityId(input.sessionId),
    userId: parseEntityId(input.userId),
    status: 'active',
    revision: 1,
    authzRevision: input.authzRevision,
    firebaseUid: parseTransportBinding(input.firebaseUid, 'firebase_uid_invalid'),
    installationId: parseTransportBinding(input.installationId, 'installation_id_invalid'),
    handleHash: hashSessionHandle(input.sessionHandle),
    issuedAtUtc,
    lastActiveAtUtc: issuedAtUtc,
    idleExpiresAtUtc: parseUtcInstant(
      new Date(Date.parse(issuedAtUtc) + identitySessionIdleLifetimeMs).toISOString(),
    ),
  });
}

export function changeSessionStatus(
  session: IdentitySession,
  status: Exclude<IdentitySessionStatus, 'active'>,
  nowUtc: string,
  reason?: IdentitySession['revocationReason'],
): IdentitySession {
  if (terminalStates.has(session.status)) throw new IdentityFailure('invalid_transition');
  return deepFreeze({
    ...session,
    status,
    revision: session.revision + 1,
    lastActiveAtUtc: parseUtcInstant(nowUtc),
    revokedAtUtc: parseUtcInstant(nowUtc),
    ...(reason === undefined ? {} : { revocationReason: reason }),
  });
}

export function assertCurrentSession(
  session: IdentitySession,
  account: Account,
  nowUtc: string = session.lastActiveAtUtc,
): void {
  const now = Date.parse(parseUtcInstant(nowUtc));
  if (session.userId !== account.userId) throw new IdentityFailure('unauthenticated');
  if (session.status === 'revoked' || session.status === 'compromised')
    throw new IdentityFailure('session_revoked');
  if (session.status !== 'active') throw new IdentityFailure('session_expired');
  if (
    !Number.isFinite(Date.parse(session.idleExpiresAtUtc)) ||
    now >= Date.parse(session.idleExpiresAtUtc)
  )
    throw new IdentityFailure('session_expired');
  if (session.authzRevision < account.revokeBeforeSecurityRevision)
    throw new IdentityFailure('session_revoked');
  if (session.authzRevision !== account.securityRevision)
    throw new IdentityFailure('snapshot_stale');
  if (account.status === 'restricted') throw new IdentityFailure('account_restricted');
  if (account.status !== 'active') throw new IdentityFailure('account_blocked');
}

/** Whether [handleHash] is the still-valid previous handle of [session]. */
export function isPreviousSessionHandle(
  session: IdentitySession,
  handleHash: string,
  nowUtc: string,
): boolean {
  return (
    session.previousHandleHash !== undefined &&
    session.previousHandleHash === handleHash &&
    session.previousHandleValidUntilUtc !== undefined &&
    Date.parse(session.previousHandleValidUntilUtc) > Date.parse(nowUtc)
  );
}

/** The session once its current handle has been used: no previous handle. */
export function withoutPreviousSessionHandle(session: IdentitySession): IdentitySession {
  const rest = { ...session };
  delete (rest as { previousHandleHash?: string }).previousHandleHash;
  delete (rest as { previousHandleValidUntilUtc?: string }).previousHandleValidUntilUtc;
  return deepFreeze(rest);
}

export function hashSessionHandle(value: string): string {
  if (!/^[A-Za-z0-9_-]{43}$/u.test(value)) throw new TypeError('session_handle_invalid');
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function parseTransportBinding(value: string, code: string): string {
  if (!/^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u.test(value)) throw new TypeError(code);
  return value;
}

export function refreshSessionAuthorization(
  session: IdentitySession,
  authzRevision: number,
  nowUtc: string,
): IdentitySession {
  if (session.status !== 'active') throw new IdentityFailure('session_revoked');
  return deepFreeze({
    ...session,
    revision: session.revision + 1,
    authzRevision,
    lastActiveAtUtc: parseUtcInstant(nowUtc),
    idleExpiresAtUtc: parseUtcInstant(
      new Date(Date.parse(nowUtc) + identitySessionIdleLifetimeMs).toISOString(),
    ),
  });
}

/**
 * A rotation keeps the handle it replaces as the previous handle until the
 * client uses the new one, so a lost rotation answer can be repaired by
 * rotating again with the old handle. A rotation made with the previous handle
 * keeps that same previous handle and its deadline (the client still holds it).
 */
export function rotateSessionHandle(
  session: IdentitySession,
  sessionHandle: string,
  nowUtc: string,
  viaPreviousHandle = false,
): IdentitySession {
  if (session.status !== 'active') throw new IdentityFailure('session_revoked');
  const idleExpiresAtUtc = parseUtcInstant(
    new Date(Date.parse(nowUtc) + identitySessionIdleLifetimeMs).toISOString(),
  );
  return deepFreeze({
    ...session,
    revision: session.revision + 1,
    handleHash: hashSessionHandle(sessionHandle),
    previousHandleHash: viaPreviousHandle ? session.previousHandleHash! : session.handleHash,
    previousHandleValidUntilUtc: viaPreviousHandle
      ? session.previousHandleValidUntilUtc!
      : idleExpiresAtUtc,
    lastActiveAtUtc: parseUtcInstant(nowUtc),
    idleExpiresAtUtc: parseUtcInstant(
      new Date(Date.parse(nowUtc) + identitySessionIdleLifetimeMs).toISOString(),
    ),
  });
}

export function isLiveSession(session: IdentitySession, nowUtc: string): boolean {
  return (
    (session.status === 'active' || session.status === 'stepUpRequired') &&
    Number.isFinite(Date.parse(session.idleExpiresAtUtc)) &&
    Date.parse(session.idleExpiresAtUtc) > Date.parse(nowUtc)
  );
}
