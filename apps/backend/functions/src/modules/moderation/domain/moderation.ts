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
  | 'restore_media';

export const moderationActions: readonly ModerationAction[] = Object.freeze([
  'approve',
  'reject',
  'restrict',
  'withdraw',
  'restore',
  'restrict_media',
  'restore_media',
]);

/** Actions that act on a Media asset instead of a Content publication. */
export function isMediaAction(action: ModerationAction): boolean {
  return action === 'restrict_media' || action === 'restore_media';
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
    readonly submissionId?: string;
    readonly assetId?: string;
  };
  /** `restore` / `restore_media` only: the exact decision that is lifted. */
  readonly restoresDecisionId?: string;
}

export interface ModerationDecision {
  readonly schemaVersion: 1;
  readonly decisionId: string;
  readonly action: ModerationAction;
  readonly staffUserId: string;
  readonly staffSessionId: string;
  readonly reason: string;
  readonly reasonCategory: 'operator_decision';
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
