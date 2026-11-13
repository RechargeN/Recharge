export const reviewPolicyRevision = 'local-owner-2026-10-15-v1';
export const reviewCollections = Object.freeze({
  reviews: 'reviews',
  uniqueness: 'reviewAuthorTargets',
  receipts: 'reviewReceipts',
  projections: 'ratingProjections',
  audit: 'reviewAudit',
});
export interface ReviewRecord {
  schemaVersion: 1;
  reviewId: string;
  authorId: string;
  contentId: string;
  typeId: 'event' | 'place' | 'activity';
  marketId: 'LV';
  revision: number;
  rating: number;
  text: string;
  edited: boolean;
  deleted: boolean;
  moderationHold: string | null;
  policyRevision: string;
  evidence: unknown;
  createdAtUtc: string;
  updatedAtUtc: string;
  verified: false;
}
export function ratingProjection(rows: readonly ReviewRecord[]) {
  const distribution = [0, 0, 0, 0, 0];
  let count = 0,
    sum = 0;
  for (const row of rows) {
    if (row.deleted || row.moderationHold !== null) continue;
    if (!Number.isInteger(row.rating) || row.rating < 1 || row.rating > 5)
      throw new TypeError('invalid_rating_source');
    distribution[row.rating - 1] = distribution[row.rating - 1]! + 1;
    count++;
    sum += row.rating;
  }
  return {
    count,
    sum,
    distribution,
    averageScaled: count >= 3 ? Math.floor((sum * 1000) / count) : null,
    scaleFactor: 1000,
    policyRevision: reviewPolicyRevision,
  };
}
