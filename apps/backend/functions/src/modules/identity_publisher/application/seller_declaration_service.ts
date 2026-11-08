import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import type { Account } from '../domain/account.js';
import { IdentityFailure } from '../domain/failures.js';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import { declareSeller, type SellerDeclaration } from '../domain/seller_declaration.js';
import type { VerificationDecisionPort } from './ports/verification_decision_port.js';

/**
 * ADR 0023, owner decision 2026-11-08 (marketplace rule): the author keeps their
 * own DSA Art. 30 seller declaration; Trust & Safety may require a step-up
 * identity verification on suspected fraud. Neither grants a role.
 */
export class SellerDeclarationService {
  constructor(
    private readonly repository: IdentityAuthorityRepository,
    private readonly decisionPort?: VerificationDecisionPort,
  ) {}

  /** Only the account owner, through their own current Session (checked by the caller). */
  declare(input: {
    readonly userId: string;
    readonly body: unknown;
    readonly expectedRevision: number;
    readonly nowUtc: string;
  }): Promise<SellerDeclaration> {
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      if (account === null || account.status !== 'active')
        throw new IdentityFailure('not_found_or_not_accessible');
      const next = declareSeller(await transaction.sellerDeclaration(input.userId), input);
      transaction.putSellerDeclaration(next);
      return next;
    });
  }

  read(userId: string): Promise<SellerDeclaration | null> {
    return this.repository.transact((transaction) => transaction.sellerDeclaration(userId));
  }

  /**
   * Suspected fraud: paid or bookable publishing of this account needs the
   * identity verification fact from now on. The security revision moves, so
   * cached snapshots end. Only a verification reviewer may set or clear it.
   */
  async setStepUpRequired(input: {
    readonly reviewerId: string;
    readonly userId: string;
    readonly required: boolean;
    readonly nowUtc: string;
  }): Promise<Account> {
    if (this.decisionPort === undefined || !(await this.decisionPort.mayDecide(input.reviewerId)))
      throw new IdentityFailure('not_found_or_not_accessible');
    return this.repository.transact(async (transaction) => {
      const account = await transaction.account(input.userId);
      if (account === null) throw new IdentityFailure('not_found_or_not_accessible');
      const rest = Object.fromEntries(
        Object.entries(account).filter(([key]) => key !== 'stepUpRequired'),
      ) as Omit<Account, 'stepUpRequired'>;
      const next: Account = deepFreeze({
        ...rest,
        ...(input.required ? { stepUpRequired: true } : {}),
        revision: account.revision + 1,
        securityRevision: account.securityRevision + 1,
        updatedAtUtc: parseUtcInstant(input.nowUtc),
      });
      transaction.putAccount(next);
      return next;
    });
  }
}
