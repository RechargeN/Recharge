import {
  policyRevisionPattern,
  productAnalyticsEventNames,
  productAnalyticsPurposeId,
  type ProductAnalyticsEventName,
} from './product_analytics_contract.js';

/**
 * L3 collection policy (amendment §5, §7). Purpose, legal basis, consent and
 * every retention number are owner decisions that are not accepted (PA-B01…
 * PA-B03), so the only source the code admits is `synthetic-test-only`, and
 * the production default resolves to no policy: nothing is collected or kept.
 */
export const productAnalyticsPolicySources = ['synthetic-test-only'] as const;

export interface ProductAnalyticsCollectionPolicy {
  readonly policyRevision: string;
  readonly purposeId: typeof productAnalyticsPurposeId;
  readonly marketId: 'LV';
  readonly legalBasisRef: string;
  readonly consentRequired: boolean;
  readonly eventNames: readonly ProductAnalyticsEventName[];
  readonly rawRetentionHours: number;
  readonly aggregateRetentionHours: number;
  readonly acceptanceWindowHours: number;
  readonly queueMaxAgeHours: number;
  readonly effectiveFromUtc: string;
  readonly expiresAtUtc: string;
  readonly source: (typeof productAnalyticsPolicySources)[number];
}

export interface ProductAnalyticsPolicyPort {
  effective(nowUtc: string): ProductAnalyticsCollectionPolicy | null;
}

/** Production default: no accepted policy exists (PA-B01, PA-B03). */
export const unresolvedProductAnalyticsPolicy: ProductAnalyticsPolicyPort = Object.freeze({
  effective: () => null,
});

export type ProductAnalyticsConsentState = 'granted' | 'withdrawn' | 'unknown';

/** Server-side consent truth; a client claim is never read (PA-B02). */
export interface ProductAnalyticsConsentPort {
  state(
    userId: string,
    purposeId: string,
    policyRevision: string,
  ): Promise<ProductAnalyticsConsentState>;
}

/** Production default: there is no consent source, which counts as refusal. */
export const absentProductAnalyticsConsent: ProductAnalyticsConsentPort = Object.freeze({
  state: () => Promise.resolve('unknown' as const),
});

const positiveHours = (value: unknown): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value > 0;

/**
 * The policy in force at `nowUtc`, or `null` when it is missing, expired, for
 * another market or purpose, from an unknown source or internally inconsistent:
 * an accepted event must outlive the window in which a replay is still taken,
 * and nothing may wait in a client queue longer than that window.
 */
export function acceptedProductAnalyticsPolicy(
  candidate: ProductAnalyticsCollectionPolicy | null,
  nowUtc: string,
): ProductAnalyticsCollectionPolicy | null {
  if (candidate === null) return null;
  const now = Date.parse(nowUtc);
  const from = Date.parse(candidate.effectiveFromUtc);
  const until = Date.parse(candidate.expiresAtUtc);
  if (
    !(productAnalyticsPolicySources as readonly string[]).includes(candidate.source) ||
    candidate.purposeId !== productAnalyticsPurposeId ||
    candidate.marketId !== 'LV' ||
    typeof candidate.legalBasisRef !== 'string' ||
    candidate.legalBasisRef.length === 0 ||
    typeof candidate.consentRequired !== 'boolean' ||
    !policyRevisionPattern.test(candidate.policyRevision) ||
    !Array.isArray(candidate.eventNames) ||
    !(candidate.eventNames as readonly unknown[]).every(
      (name) =>
        typeof name === 'string' &&
        (productAnalyticsEventNames as readonly string[]).includes(name),
    ) ||
    !positiveHours(candidate.rawRetentionHours) ||
    !positiveHours(candidate.aggregateRetentionHours) ||
    !positiveHours(candidate.acceptanceWindowHours) ||
    !positiveHours(candidate.queueMaxAgeHours) ||
    candidate.acceptanceWindowHours >= candidate.rawRetentionHours ||
    candidate.queueMaxAgeHours > candidate.acceptanceWindowHours ||
    !Number.isFinite(now) ||
    !Number.isFinite(from) ||
    !Number.isFinite(until) ||
    now < from ||
    now >= until
  )
    return null;
  return candidate;
}
