import type { ApplyModerationDispositionCommandV1 } from '../../../contracts/content_v1.js';
import type {
  ModerationDispositionPort,
  ModerationProfileResolution,
  VerifiedDisposition,
} from '../../content/application/ports/moderation_disposition_port.js';
import { attest, moderationIssuer, moderationPolicyRevision } from '../domain/moderation.js';
import type { ModerationRepository } from '../domain/repositories.js';

/**
 * Content's moderation port, answered by this module. Review is required before
 * publication, and an instruction is verified only if it matches a recorded
 * staff decision exactly (kind, target, policy, reason category and attestation
 * recomputed from the stored decision). Anything else is `verified: false` and
 * creates no Content mutation. TEST-ONLY: a hash check, not a signature.
 */
export class ModerationDecisionVerifier implements ModerationDispositionPort {
  constructor(private readonly repository: ModerationRepository) {}

  profileFor(): Promise<ModerationProfileResolution> {
    return Promise.resolve({
      available: true,
      profileId: 'emulator.operator-review',
      requiresPrePublicationModeration: true,
      policyRevision: moderationPolicyRevision,
    });
  }

  async verifyDisposition(input: {
    readonly payload: ApplyModerationDispositionCommandV1['payload'];
    readonly nowUtc: string;
  }): Promise<VerifiedDisposition> {
    const { payload } = input;
    const decision = await this.repository.transact((tx) => tx.decision(payload.decisionId));
    if (decision === null) return { verified: false };
    const { attestation, ...unsigned } = decision;
    const target = decision.target;
    const matches =
      payload.disposition === decision.action &&
      payload.policyRevision === decision.policyRevision &&
      payload.policyRevision === moderationPolicyRevision &&
      payload.reasonCategory === decision.reasonCategory &&
      payload.restoresDecisionId === decision.restoresDecisionId &&
      payload.target.contentId === target.contentId &&
      payload.target.submissionId === target.submissionId &&
      payload.target.publishedRevisionId === target.publishedRevisionId &&
      payload.effectiveAtUtc === decision.decidedAtUtc &&
      payload.attestation === attestation &&
      attestation === attest(unsigned);
    return matches ? { verified: true, issuer: moderationIssuer } : { verified: false };
  }
}
