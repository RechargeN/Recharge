import type { AccountV1, AccountStatus } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { IdentityFailure } from './failures.js';

export type Account = AccountV1;

export function createAccount(
  userId: string,
  nowUtc: string,
  systemRoles: readonly ('User' | 'Admin')[] = ['User'],
): Account {
  const instant = parseUtcInstant(nowUtc);
  return deepFreeze({
    schemaVersion: 1,
    userId: parseEntityId(userId),
    status: 'active',
    systemRoles: [...new Set(['User' as const, ...systemRoles])],
    revision: 1,
    securityRevision: 1,
    revokeBeforeSecurityRevision: 0,
    createdAtUtc: instant,
    updatedAtUtc: instant,
  });
}

/**
 * ADR 0023: global roles are `User` and `Admin`. A legacy `Creator` (written
 * before ADR 0023) reads as `User` and grants nothing more.
 */
export function normalizeSystemRoles(roles: readonly string[]): readonly ('User' | 'Admin')[] {
  return roles.includes('Admin') ? ['Admin', 'User'] : ['User'];
}

export function normalizeLegacyAccount(account: Account): Account {
  const roles = account.systemRoles as readonly string[];
  if (!roles.includes('Creator')) return account;
  return deepFreeze({ ...account, systemRoles: normalizeSystemRoles(roles) });
}

/**
 * A verification decision changes publishing authority: the security revision
 * moves (old snapshots end) and a legacy `Creator` role is dropped. It never
 * grants a role (ADR 0023: verification is a fact, not a role).
 */
export function recordVerificationDecision(account: Account, nowUtc: string): Account {
  return deepFreeze({
    ...account,
    systemRoles: [...normalizeSystemRoles(account.systemRoles)],
    revision: account.revision + 1,
    securityRevision: account.securityRevision + 1,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}

export function changeAccountStatus(
  account: Account,
  status: Exclude<AccountStatus, 'deleted'> | 'deleted',
  nowUtc: string,
): Account {
  if (account.status === 'deleted') throw new IdentityFailure('invalid_transition');
  if (account.status === status) return account;
  const nextSecurityRevision = account.securityRevision + 1;
  return deepFreeze({
    ...account,
    status,
    revision: account.revision + 1,
    securityRevision: nextSecurityRevision,
    revokeBeforeSecurityRevision:
      status === 'active' ? account.revokeBeforeSecurityRevision : nextSecurityRevision,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}

export function advanceRevocationFence(account: Account, nowUtc: string): Account {
  if (account.status === 'deleted') throw new IdentityFailure('account_blocked');
  const nextSecurityRevision = account.securityRevision + 1;
  return deepFreeze({
    ...account,
    revision: account.revision + 1,
    securityRevision: nextSecurityRevision,
    revokeBeforeSecurityRevision: nextSecurityRevision,
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}
