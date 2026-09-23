import type { Account } from '../domain/account.js';
import { createAccount } from '../domain/account.js';
import { createAuthIdentity, providerSubjectKey } from '../domain/auth_identity.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import type {
  ProviderIdentityProof,
  ProviderIdentityVerifier,
} from './ports/provider_identity_verifier.js';

export class AccountLinkingService {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly verifier: ProviderIdentityVerifier,
  ) {}

  async ensureAccount(input: {
    readonly proof: ProviderIdentityProof;
    readonly proposedUserId: string;
    readonly proposedIdentityId: string;
    readonly nowUtc: string;
    readonly accountCreationEnabled: boolean;
  }): Promise<Account> {
    const assertion = await this.verifier.verify(input.proof, input.nowUtc);
    if (assertion === null) throw new IdentityFailure('provider_assertion_invalid');
    const subjectHash = providerSubjectKey(assertion);
    return this.repository.transact((transaction) => {
      const existingIdentity = transaction.identityBySubjectHash(subjectHash);
      if (existingIdentity !== null) {
        const existingAccount = transaction.account(existingIdentity.userId);
        if (existingAccount === null) throw new IdentityFailure('not_found_or_not_accessible');
        return existingAccount;
      }
      if (!input.accountCreationEnabled) throw new IdentityFailure('account_creation_disabled');
      if (transaction.account(input.proposedUserId) !== null)
        throw new IdentityFailure('provider_subject_conflict');
      const account = createAccount(input.proposedUserId, input.nowUtc);
      transaction.putAccount(account);
      transaction.putIdentity(
        createAuthIdentity({
          identityId: input.proposedIdentityId,
          userId: input.proposedUserId,
          assertion,
          linkedAtUtc: input.nowUtc,
        }),
      );
      return account;
    });
  }

  async linkIdentity(input: {
    readonly actorUserId: string;
    readonly proof: ProviderIdentityProof;
    readonly identityId: string;
    readonly nowUtc: string;
  }): Promise<void> {
    const assertion = await this.verifier.verify(input.proof, input.nowUtc);
    if (assertion === null) throw new IdentityFailure('provider_assertion_invalid');
    const subjectHash = providerSubjectKey(assertion);
    await this.repository.transact((transaction) => {
      const account = transaction.account(input.actorUserId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      const existing = transaction.identityBySubjectHash(subjectHash);
      if (existing !== null) {
        if (existing.userId === account.userId) return;
        throw new IdentityFailure('provider_subject_conflict');
      }
      transaction.putIdentity(
        createAuthIdentity({
          identityId: input.identityId,
          userId: account.userId,
          assertion,
          linkedAtUtc: input.nowUtc,
        }),
      );
    });
  }
}
