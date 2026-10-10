import type { ModerationAction } from '../domain/moderation.js';

export interface StaffActor {
  readonly userId: string;
  readonly sessionId: string;
}

export type StaffAuthorityResult =
  | { readonly allowed: true }
  | { readonly allowed: false; readonly reason: 'session_invalid' | 'staff_denied' };

/**
 * Who may moderate. Evaluated on every command from backend state: a current
 * Session plus an explicit staff grant. A user label or a client claim is never
 * authority, and a missing grant is a refusal.
 */
export interface StaffAuthorityPort {
  evaluate(request: {
    readonly actor: StaffActor;
    readonly nowUtc: string;
  }): Promise<StaffAuthorityResult>;
}

export interface SubmissionView {
  readonly submissionId: string;
  readonly contentId: string;
  readonly state: string;
  readonly revision: number;
  readonly draftRevision: number;
  readonly typeId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
}

export interface PublicationView {
  readonly contentId: string;
  readonly pointerRevision: number;
  readonly currentPublishedRevisionId: string | null;
  readonly visibility: string;
  readonly ownerHold: string | null;
  readonly moderationHold: { readonly kind: string; readonly decisionId: string } | null;
}

export interface EnforcementInstruction {
  readonly instructionId: string;
  readonly decisionId: string;
  readonly policyRevision: string;
  readonly disposition: ModerationAction;
  readonly target: {
    readonly contentId: string;
    readonly submissionId?: string;
    readonly publishedRevisionId?: string;
  };
  readonly reasonCategory: string;
  readonly restoresDecisionId?: string;
  readonly effectiveAtUtc: string;
  readonly attestation: string;
}

export type EnforcementOutcome =
  | {
      readonly kind: 'applied';
      readonly outcome: 'applied' | 'already_applied';
      readonly pointerRevision: number | null;
    }
  | { readonly kind: 'refused'; readonly code: string };

/** D2: what Moderation may know about one Media asset (ids and revision only). */
export interface MediaAssetView {
  readonly assetId: string;
  /** The Content the asset is bound to; `null` for an unbound asset. */
  readonly contentId: string | null;
  readonly assetRevision: number;
}

/**
 * D2: Moderation's view of Media. The one write path is Media's own verified
 * `applyRestriction`, which checks the recorded decision again; Moderation never
 * edits Media records.
 */
export interface MediaModerationPort {
  asset(assetId: string): Promise<MediaAssetView | null>;
  enforce(instruction: {
    readonly decisionId: string;
    readonly assetId: string;
    readonly restricted: boolean;
  }): Promise<EnforcementOutcome>;
}

/**
 * Moderation's view of Content: read-only state of the exact target, and the
 * one write path, which is Content's own verified `applyModerationDisposition`.
 * Moderation never edits Content documents.
 */
export interface ContentModerationPort {
  reviewQueue(limit: number): Promise<readonly SubmissionView[]>;
  submission(submissionId: string): Promise<SubmissionView | null>;
  publication(contentId: string): Promise<PublicationView | null>;
  enforce(instruction: EnforcementInstruction): Promise<EnforcementOutcome>;
}
