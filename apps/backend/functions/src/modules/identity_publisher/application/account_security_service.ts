import { changeAccountStatus } from '../domain/account.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import { changeSessionStatus } from '../domain/session.js';

export class AccountSecurityService {
  constructor(private readonly repository: IdentityAuthorityRepository) {}

  setStatus(input: {
    readonly userId: string;
    readonly status: 'active' | 'restricted' | 'blocked' | 'deleted';
    readonly nowUtc: string;
  }): Promise<void> {
    return this.repository.transact((transaction) => {
      const account = transaction.account(input.userId);
      if (account === null) throw new IdentityFailure('not_found_or_not_accessible');
      transaction.putAccount(changeAccountStatus(account, input.status, input.nowUtc));
      if (input.status !== 'active') {
        for (const session of transaction.sessionsForUser(input.userId)) {
          if (session.status === 'active' || session.status === 'stepUpRequired')
            transaction.putSession(changeSessionStatus(session, 'revoked', input.nowUtc));
        }
      }
    });
  }
}
