import { createEnvironmentConfig } from '../../src/config/environment.js';
import { createDisabledFeatureFlag } from '../../src/config/feature_flags.js';
import {
  createMarketConfigRevision,
  type MarketPolicyPointers,
} from '../../src/modules/reference_data/domain/market_config.js';
import { createDisabledRegionPolicy } from '../../src/config/region_policy.js';
import { createDisabledReleaseManifest } from '../../src/config/release_manifest.js';
import { createUnboundSecretReference } from '../../src/config/secret_refs.js';

export const fixtureIds = Object.freeze({
  first: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
  second: '01BX5ZZKBKACTAV9WEVGEMMVRZ',
  third: '01BX5ZZKBKACTAV9WEVGEMMVS0',
});

export const emptyPolicyPointers: MarketPolicyPointers = Object.freeze({
  mandatoryCopyManifestRevision: null,
  privacyPolicyRevision: null,
  minorsPolicyRevision: null,
  trustSafetyPolicyRevision: null,
  retentionDsrPolicyRevision: null,
  supportPolicyRevision: null,
});

export function buildMarketConfig(
  overrides: {
    readonly id?: string;
    readonly revision?: number;
    readonly marketId?: 'LV' | 'EE' | 'LT';
    readonly supersedesRevisionId?: string | null;
  } = {},
) {
  const marketId = overrides.marketId ?? 'LV';
  const locale = marketId === 'LV' ? 'lv-LV' : marketId === 'EE' ? 'et-EE' : 'lt-LT';
  const timezone =
    marketId === 'LV' ? 'Europe/Riga' : marketId === 'EE' ? 'Europe/Tallinn' : 'Europe/Vilnius';
  return createMarketConfigRevision({
    revisionId: overrides.id ?? fixtureIds.first,
    revisionNumber: overrides.revision ?? 1,
    environmentId: 'local',
    marketId,
    countryCode: marketId,
    status: 'disabled',
    primaryLocale: locale,
    supportedLocales: [locale, 'en'],
    fallbackLocaleOrder: ['en'],
    languageFallbacks: { [locale]: ['en'] },
    currencyCodes: ['EUR'],
    defaultIanaZone: timezone,
    allowedIanaZones: [timezone],
    taxonomyRevisionRef: { taxonomyId: 'category-system', revision: '1.4.3' },
    mandatoryCopyManifestRevision: null,
    sourceRecordIds: [],
    policyPointers: emptyPolicyPointers,
    capabilityMatrix: [
      {
        capabilityId: 'platform.foundation',
        status: 'disabled',
        requiresMandatoryCopy: false,
        mandatoryCopyPurposeId: null,
        requiresEligibleSources: false,
      },
    ],
    compatibilityKey: 'reference-data-v1',
    contentHash: `sha256:${'b'.repeat(64)}`,
    supersedesRevisionId: overrides.supersedesRevisionId ?? null,
    createdAtUtc: '2026-09-21T10:00:00.000Z',
  });
}

export function buildFeatureFlag(revision = 1) {
  return createDisabledFeatureFlag({
    revision,
    environmentId: 'local',
    marketId: 'LV',
    capabilityId: 'platform.foundation',
    createdAtUtc: '2026-09-21T10:00:00.000Z',
  });
}

export function buildRelease(
  overrides: {
    readonly id?: string;
    readonly revision?: number;
    readonly rollbackTargetManifestId?: string | null;
    readonly apiSchemaRevision?: string;
  } = {},
) {
  return createDisabledReleaseManifest({
    manifestId: overrides.id ?? fixtureIds.first,
    revision: overrides.revision ?? 1,
    environmentId: 'local',
    marketId: 'LV',
    capabilityId: 'platform.foundation',
    artifactDigest: `sha256:${'a'.repeat(64)}`,
    apiSchemaRevision: overrides.apiSchemaRevision ?? 'platform-v1',
    marketConfigRevision: 'market-r1',
    securityPrivacyEvidenceRevision: 'security-r1',
    retentionDsrRevision: 'retention-r1',
    residencyTransferRevision: 'residency-r1',
    observabilityPolicyRevision: 'observability-r1',
    rollbackTargetManifestId: overrides.rollbackTargetManifestId ?? null,
    createdAtUtc: '2026-09-21T10:00:00.000Z',
    effectiveAtUtc: '2026-09-21T10:00:00.000Z',
    approvedBy: [],
  });
}

export function buildPlatformBundle() {
  return {
    environment: createEnvironmentConfig('local'),
    regionPolicy: createDisabledRegionPolicy(fixtureIds.first, 1, 'local'),
    marketCapabilities: [buildMarketConfig()],
    featureFlags: [buildFeatureFlag()],
    secretReferences: [
      createUnboundSecretReference({
        environmentId: 'local',
        logicalName: 'PROVIDER_API_KEY',
        referenceName: 'provider-api-key',
      }),
    ],
  } as const;
}
