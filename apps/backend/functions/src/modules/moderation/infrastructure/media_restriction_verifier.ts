import type {
  MediaRestrictionAuthority,
  MediaRestrictionVerdict,
} from '../../media/application/ports/actor_authority_port.js';
import { attest, moderationPolicyRevision } from '../domain/moderation.js';
import type { ModerationRepository } from '../domain/repositories.js';

/**
 * Media's restriction authority, answered by this module (D2 §7). An
 * instruction is verified only if it matches a recorded staff decision exactly
 * — the action, the asset, the current policy and the attestation recomputed
 * from the stored decision — and a restore names the decision it lifts.
 * Anything else is unverified and Media changes nothing. TEST-ONLY: a hash
 * check, not a signature.
 */
export class MediaRestrictionVerifier implements MediaRestrictionAuthority {
  constructor(private readonly repository: ModerationRepository) {}

  async verifyRestriction(input: {
    readonly assetId: string;
    readonly decisionRef: string;
    readonly restricted: boolean;
  }): Promise<MediaRestrictionVerdict> {
    const decision = await this.repository.transact((tx) => tx.decision(input.decisionRef));
    if (decision === null) return { verified: false };
    const { attestation, ...unsigned } = decision;
    const matches =
      decision.action === (input.restricted ? 'restrict_media' : 'restore_media') &&
      decision.target.assetId === input.assetId &&
      decision.policyRevision === moderationPolicyRevision &&
      attestation === attest(unsigned);
    if (!matches) return { verified: false };
    if (input.restricted || decision.restoresDecisionId === undefined) return { verified: true };
    return { verified: true, restoresDecisionRef: decision.restoresDecisionId };
  }
}
