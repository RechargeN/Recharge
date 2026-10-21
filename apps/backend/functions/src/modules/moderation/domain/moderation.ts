import { createHash } from 'node:crypto';

/**
 * TEST-ONLY minimal moderation (BCK-22 slice C2). It is an Emulator operator
 * path, not product moderation policy: no reports, sanctions, appeals, AI review
 * or Admin UI, and the staff source below is not production IAM.
 */
export const moderationPolicyRevision = 'test-only-emulator-moderation-policy-1';
export const moderationIssuer = 'test-only-emulator-moderation';
export const moderationEvidence =
  'Emulator operator moderation: staff authority comes from the stand bootstrap registry, not from production IAM';

export type ModerationAction =
  | 'approve'
  | 'reject'
  | 'restrict'
  | 'withdraw'
  | 'restore'
  /** D2: restrict or restore one Media asset (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §7). */
  | 'restrict_media'
  | 'restore_media'
  /** SCN-PUB-01 SP-03: restrict or restore one unlisted Scenario share. */
  | 'restrict_share'
  | 'restore_share';

export const moderationActions: readonly ModerationAction[] = Object.freeze([
  'approve',
  'reject',
  'restrict',
  'withdraw',
  'restore',
  'restrict_media',
  'restore_media',
  'restrict_share',
  'restore_share',
]);

/** Actions that act on a Media asset instead of a Content publication. */
export function isMediaAction(action: ModerationAction): boolean {
  return action === 'restrict_media' || action === 'restore_media';
}

/** Actions that act on an unlisted Scenario share; `contentId` holds its Scenario. */
export function isShareAction(action: ModerationAction): boolean {
  return action === 'restrict_share' || action === 'restore_share';
}

/**
 * J2 / RTE-PUB-01 RP-06: reason classes of a Route decision that finds a
 * violation. A staff `reject`, `restrict` or `withdraw` of a Route names one;
 * other types and actions carry none.
 */
export const routeReasonCodes = Object.freeze([
  'route.unsafe_or_private_location',
  'route.misleading_difficulty_or_conditions',
  'route.prohibited_content',
  'route.mass_duplicate',
  'route.provenance_or_license',
]);

/** Actions that find a violation of the publisher (RP-06). */
export function isViolationAction(action: ModerationAction): boolean {
  return action === 'reject' || action === 'restrict' || action === 'withdraw';
}

/**
 * RP-06: whether the publisher's next Route submissions skip manual review.
 * Earned by a staff `approve`, lost only by a staff-confirmed violation
 * (`reject`, `restrict`, `withdraw`); the author's own withdraw or archive and
 * anything that is not a staff decision never change it. Moderation is the
 * only writer; the newest decision wins.
 */
export interface PublisherTrustRecord {
  readonly schemaVersion: 1;
  readonly trustKey: string;
  readonly typeId: 'route';
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly state: 'trusted' | 'untrusted';
  readonly decisionId: string;
  readonly action: ModerationAction;
  readonly decidedAtUtc: string;
}

export function publisherTrustKey(
  typeId: string,
  publisherRef: { readonly type: string; readonly id: string },
): string {
  return `${typeId}:${publisherRef.type}:${publisherRef.id}`;
}

export type ModerationFailureCode =
  | 'invalid_contract'
  | 'unauthenticated'
  | 'staff_denied'
  | 'target_not_found'
  | 'target_stale'
  | 'idempotency_conflict'
  | 'unknown_outcome';

export type ModerationResult<T> =
  | Readonly<{ kind: 'succeeded'; data: T }>
  | Readonly<{ kind: 'rejected'; code: ModerationFailureCode }>;

export const moderationSucceeded = <T>(data: T): ModerationResult<T> => ({
  kind: 'succeeded',
  data,
});
export const moderationRejected = <T = never>(
  code: ModerationFailureCode,
): ModerationResult<T> => ({
  kind: 'rejected',
  code,
});

/** The exact thing a decision acted on, as it was when the staff member decided. */
export interface ModerationTarget {
  readonly marketId?: string;
  readonly typeId?: string;
  readonly contentId: string;
  /** Review actions: the exact submission under review. */
  readonly submissionId?: string;
  readonly submissionRevision?: number;
  readonly draftRevision?: number;
  /** Enforcement actions: the exact published revision and pointer revision. */
  readonly publishedRevisionId?: string;
  readonly pointerRevision?: number;
  /** Media actions: the asset and its revision; `contentId` is its Content binding. */
  readonly assetId?: string;
  readonly assetRevision?: number;
  /** Share actions: the share id (hash of its token, never the token). */
  readonly shareId?: string;
}

export interface StaffModerationCommand {
  readonly schemaVersion: 1;
  readonly action: ModerationAction;
  readonly idempotencyKey: string;
  /** Operator reason; kept in the decision, the receipt and the audit. */
  readonly reason: string;
  /** Content actions name `contentId`; Media actions name only `assetId`. */
  readonly target: {
    readonly contentId?: string;
    readonly expectedRevision?: number;
    readonly submissionId?: string;
    readonly assetId?: string;
    readonly shareId?: string;
  };
  /** `restore` / `restore_media` only: the exact decision that is lifted. */
  readonly restoresDecisionId?: string;
  /** RP-06: the reason class of a Route violation decision. */
  readonly reasonCode?: string;
}

export interface ModerationDecision {
  readonly schemaVersion: 1;
  readonly decisionId: string;
  readonly action: ModerationAction;
  readonly staffUserId: string;
  readonly staffSessionId: string;
  readonly reason: string;
  readonly reasonCategory: 'operator_decision';
  /** RP-06: present exactly on a Route violation decision. */
  readonly reasonCode?: string;
  readonly target: ModerationTarget;
  readonly restoresDecisionId?: string;
  readonly policyRevision: string;
  readonly attestation: string;
  readonly decidedAtUtc: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
}

/** What Content answered; written once and never changed. */
export interface EnforcementReceipt {
  readonly schemaVersion: 1;
  readonly receiptId: string;
  readonly decisionId: string;
  readonly action: ModerationAction;
  readonly outcome: 'applied' | 'already_applied' | 'refused';
  readonly refusalCode?: string;
  readonly contentId: string;
  readonly pointerRevision: number | null;
  readonly staffUserId: string;
  readonly target: ModerationTarget;
  readonly reason: string;
  readonly issuer: string;
  readonly recordedAtUtc: string;
}

export interface ModerationAuditEntry {
  readonly auditId: string;
  readonly kind: 'moderation.decision.recorded' | 'moderation.enforcement.recorded';
  readonly decisionId: string;
  readonly actorUserId: string;
  readonly action: ModerationAction;
  readonly outcome?: string;
  readonly atUtc: string;
}

export interface ModerationDecisionView {
  readonly decision: ModerationDecision;
  readonly receipt: EnforcementReceipt;
}

export const maxReasonLength = 500;

/** Single-line operator reason: 3..500 characters, no control characters. */
export function validReason(reason: unknown): reason is string {
  return (
    typeof reason === 'string' &&
    reason.trim() === reason &&
    reason.length >= 3 &&
    reason.length <= maxReasonLength &&
    !/[\u0000-\u001f\u007f]/u.test(reason)
  );
}

export function canonical(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map((item) => canonical(item)).join(',')}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .filter((key) => record[key] !== undefined)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonical(record[key])}`)
    .join(',')}}`;
}

export function sha256(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/** What the same command means: the same key with other content is a conflict. */
export function commandHash(command: StaffModerationCommand): string {
  return sha256(
    canonical({
      algorithm: 'moderation_command_hash_v1',
      action: command.action,
      reason: command.reason,
      target: command.target,
      restoresDecisionId: command.restoresDecisionId ?? null,
      // Absent for every earlier command, so their hashes are unchanged.
      reasonCode: command.reasonCode,
    }),
  );
}

type Attested = Omit<ModerationDecision, 'attestation'>;

/**
 * The attestation binds a decision to its exact content. Content's verification
 * port recomputes it from the stored decision, so an instruction that does not
 * match a recorded staff decision is refused. TEST-ONLY: a hash, not a signature.
 */
export function attest(decision: Attested): string {
  return sha256(canonical({ algorithm: 'moderation_attestation_v1_test_only', decision }));
}
