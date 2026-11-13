export const sanctionReasonLabels = Object.freeze({
  spam: 'Spam',
  misleading: 'Misleading content',
  safety: 'Safety violation',
  harassment: 'Harassment',
  illegalContent: 'Illegal content',
  other: 'Other policy violation',
});
export const safetyPolicyRevision = 'local-owner-2026-10-15-v1';
export const safetyCollections = Object.freeze({
  relations: 'safetyRelations',
  receipts: 'safetyReceipts',
  sanctions: 'safetySanctions',
  appeals: 'safetyAppeals',
  audit: 'safetyAudit',
  notices: 'safetyNotices',
  limits: 'safetyAttemptLimits',
  authority: 'safetyOwnerAuthority',
});
export function appealDeadline(issuedAtUtc: string): string {
  const d = new Date(issuedAtUtc),
    day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + 6);
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, last));
  return d.toISOString();
}
/** One block/mute relation as the owner command writes it. */
export function relationRecord(input: {
  readonly ownerId: string;
  readonly targetUserId: string;
  readonly kind: string;
  readonly active: boolean;
  readonly revision: number;
  readonly nowUtc: string;
}) {
  return {
    ownerId: input.ownerId,
    targetUserId: input.targetUserId,
    kind: input.kind,
    active: input.active,
    revision: input.revision,
    policyRevision: safetyPolicyRevision,
    updatedAtUtc: input.nowUtc,
  };
}
export function notificationSuppressed(kind: string, muted: boolean, blocked: boolean): boolean {
  return kind === 'newPublication' && (muted || blocked);
}
