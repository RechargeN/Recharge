import type { Firestore } from 'firebase-admin/firestore';

import {
  applyShareRestriction,
  scenarioPublicationCollections,
  type ScenarioShareRecord,
  type ShareRestrictionAuthority,
} from '../../quick_plan/scenario_publication.js';
import type { EnforcementOutcome, ShareModerationPort } from '../application/ports.js';
import { attest, moderationPolicyRevision } from '../domain/moderation.js';
import type { ModerationRepository } from '../domain/repositories.js';

/**
 * SCN-PUB-01 (SP-03), by the D2 pattern: Planning's restriction authority is
 * answered by this module. An instruction is verified only if it matches a
 * recorded staff decision exactly — action, share, current policy and the
 * attestation recomputed from the stored decision. TEST-ONLY: a hash check,
 * not a signature.
 */
export class ShareRestrictionVerifier implements ShareRestrictionAuthority {
  constructor(private readonly repository: ModerationRepository) {}

  async verifyShareRestriction(input: {
    readonly shareId: string;
    readonly decisionRef: string;
    readonly restricted: boolean;
  }): Promise<{ readonly verified: boolean; readonly restoresDecisionRef?: string }> {
    const decision = await this.repository.transact((tx) => tx.decision(input.decisionRef));
    if (decision === null) return { verified: false };
    const { attestation, ...unsigned } = decision;
    const matches =
      decision.action === (input.restricted ? 'restrict_share' : 'restore_share') &&
      decision.target.shareId === input.shareId &&
      decision.policyRevision === moderationPolicyRevision &&
      attestation === attest(unsigned);
    if (!matches) return { verified: false };
    return decision.restoresDecisionId === undefined
      ? { verified: true }
      : { verified: true, restoresDecisionRef: decision.restoresDecisionId };
  }
}

/** Moderation's window onto one share: ids only; the write is Planning's verified path. */
export class ScenarioShareModerationAdapter implements ShareModerationPort {
  constructor(
    private readonly firestore: Firestore,
    private readonly repository: ModerationRepository,
  ) {}

  async share(shareId: string) {
    const share = (
      await this.firestore.collection(scenarioPublicationCollections.shares).doc(shareId).get()
    ).data() as ScenarioShareRecord | undefined;
    return share === undefined ? null : { shareId, scenarioId: share.scenarioId };
  }

  async enforce(instruction: {
    readonly decisionId: string;
    readonly shareId: string;
    readonly restricted: boolean;
  }): Promise<EnforcementOutcome> {
    const result = await applyShareRestriction(
      this.firestore,
      new ShareRestrictionVerifier(this.repository),
      instruction,
    );
    return result.kind === 'applied'
      ? { kind: 'applied', outcome: result.outcome, pointerRevision: null }
      : result;
  }
}
