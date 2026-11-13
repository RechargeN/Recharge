import type { VerificationDecisionPort } from '../application/ports/verification_decision_port.js';

export class LocalVerificationDecisionAdapter implements VerificationDecisionPort {
  constructor(private readonly reviewerIds: ReadonlySet<string>) {}

  mayDecide(reviewerId: string): Promise<boolean> {
    return Promise.resolve(this.reviewerIds.has(reviewerId));
  }
}
