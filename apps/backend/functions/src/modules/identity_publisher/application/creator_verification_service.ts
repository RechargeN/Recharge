import { setCreatorRole } from '../domain/account.js';
import {
  decideCreatorVerification,
  submitCreatorVerification,
  type CreatorVerification,
} from '../domain/creator_verification.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import type { VerificationDecisionPort } from './ports/verification_decision_port.js';

export class CreatorVerificationService {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly decisionPort: VerificationDecisionPort,
  ) {}

  submit(input: {
    readonly userId: string;
    readonly verificationId: string;
    readonly evidenceRefIds: readonly string[];
    readonly nowUtc: string;
  }): Promise<CreatorVerification> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      const existing = await transaction.verificationForUser(input.userId);
      if (existing !== null && !['rejected', 'revoked'].includes(existing.status))
        throw new IdentityFailure('invalid_transition');
      const verification = submitCreatorVerification({
        verificationId: input.verificationId,
        userId: input.userId,
        evidenceRefIds: input.evidenceRefIds,
        submittedAtUtc: input.nowUtc,
      });
      transaction.putVerification(verification);
      return verification;
    });
  }

  async decide(input: {
    readonly reviewerId: string;
    readonly userId: string;
    readonly status: 'verified' | 'rejected' | 'suspended' | 'revoked';
    readonly nowUtc: string;
  }): Promise<CreatorVerification> {
    if (!(await this.decisionPort.mayDecide(input.reviewerId)))
      throw new IdentityFailure('not_found_or_not_accessible');
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      const current = await transaction.verificationForUser(input.userId);
      if (account === null || current === null)
        throw new IdentityFailure('not_found_or_not_accessible');
      const next = decideCreatorVerification(current, input.status, input.nowUtc);
      transaction.putVerification(next);
      const nextAccount = setCreatorRole(account, input.status === 'verified', input.nowUtc);
      transaction.putAccount(nextAccount);
      return next;
    });
  }
}
