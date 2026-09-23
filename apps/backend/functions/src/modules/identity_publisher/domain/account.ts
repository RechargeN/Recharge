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
    revokeAllBeforeUtc: instant,
    createdAtUtc: instant,
    updatedAtUtc: instant,
  });
}

export function setCreatorRole(account: Account, granted: boolean, nowUtc: string): Account {
  const roles = new Set(account.systemRoles);
  if (granted) roles.add('Creator');
  else roles.delete('Creator');
  return deepFreeze({
    ...account,
    systemRoles: [...roles].sort(),
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
  return deepFreeze({
    ...account,
    status,
    revision: account.revision + 1,
    securityRevision: account.securityRevision + 1,
    revokeAllBeforeUtc: parseUtcInstant(nowUtc),
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}

export function advanceRevocationFence(account: Account, nowUtc: string): Account {
  if (account.status === 'deleted') throw new IdentityFailure('account_blocked');
  return deepFreeze({
    ...account,
    revision: account.revision + 1,
    securityRevision: account.securityRevision + 1,
    revokeAllBeforeUtc: parseUtcInstant(nowUtc),
    updatedAtUtc: parseUtcInstant(nowUtc),
  });
}
