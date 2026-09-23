import type { EntityId } from '../../../shared/ids.js';
import type { Account } from './account.js';

export interface User {
  readonly userId: EntityId;
  readonly roles: readonly ('User' | 'Creator' | 'Admin')[];
  readonly active: boolean;
  readonly sourceAccountRevision: number;
}

export function projectUser(account: Account): User {
  return Object.freeze({
    userId: account.userId,
    roles: account.systemRoles,
    active: account.status === 'active',
    sourceAccountRevision: account.revision,
  });
}
