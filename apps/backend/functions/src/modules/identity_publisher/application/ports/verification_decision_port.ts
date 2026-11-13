export interface VerificationDecisionPort {
  mayDecide(reviewerId: string): Promise<boolean>;
}
