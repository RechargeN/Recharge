import type { IdentitySessionV1, IdentitySessionStatus } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import type { Account } from './account.js';
import { IdentityFailure } from './failures.js';

export type IdentitySession = IdentitySessionV1;

const terminalStates = new Set<IdentitySessionStatus>(['revoked', 'expired', 'compromised']);

export function createSession(input: {
  readonly sessionId: string;
  readonly userId: string;
  readonly issuedAtUtc: string;
  readonly authzRevision: number;
}): IdentitySession {
  const issuedAtUtc = parseUtcInstant(input.issuedAtUtc);
  return deepFreeze({
    schemaVersion: 1,
    sessionId: parseEntityId(input.sessionId),
    userId: parseEntityId(input.userId),
    status: 'active',
    revision: 1,
    authzRevision: input.authzRevision,
    issuedAtUtc,
    lastActiveAtUtc: issuedAtUtc,
  });
}

export function changeSessionStatus(
  session: IdentitySession,
  status: Exclude<IdentitySessionStatus, 'active'>,
  nowUtc: string,
): IdentitySession {
  if (terminalStates.has(session.status)) throw new IdentityFailure('invalid_transition');
  return deepFreeze({
    ...session,
    status,
    revision: session.revision + 1,
    lastActiveAtUtc: parseUtcInstant(nowUtc),
    revokedAtUtc: parseUtcInstant(nowUtc),
  });
}

export function assertCurrentSession(session: IdentitySession, account: Account): void {
  if (session.userId !== account.userId) throw new IdentityFailure('unauthenticated');
  if (session.status === 'revoked' || session.status === 'compromised')
    throw new IdentityFailure('session_revoked');
  if (session.status !== 'active') throw new IdentityFailure('session_expired');
  if (Date.parse(session.issuedAtUtc) <= Date.parse(account.revokeAllBeforeUtc))
    throw new IdentityFailure('session_revoked');
  if (account.status === 'restricted') throw new IdentityFailure('account_restricted');
  if (account.status !== 'active') throw new IdentityFailure('account_blocked');
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
  });
}
