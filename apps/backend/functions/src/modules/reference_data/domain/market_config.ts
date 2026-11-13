import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import {
  parseIanaTimezone,
  parseUtcInstant,
  type IanaTimezone,
  type UtcInstant,
} from '../../../shared/utc_instant.js';
import { createDisabledCapabilityMatrix, type MarketCapabilityEntry } from './capability_matrix.js';
import {
  parseCurrencyCode,
  parseLocaleId,
  parseMarketId,
  parseReferenceEnvironmentId,
  type CurrencyCode,
  type LocaleId,
  type MarketId,
  type ReferenceEnvironmentId,
} from './identifiers.js';

export const referenceDataCapabilityId = 'reference-data.bootstrap' as const;
export const referenceDataCompatibilityKey = 'reference-data-v1' as const;

export interface MarketPolicyPointers {
  readonly mandatoryCopyManifestRevision: string | null;
  readonly privacyPolicyRevision: string | null;
  readonly minorsPolicyRevision: string | null;
  readonly trustSafetyPolicyRevision: string | null;
  readonly retentionDsrPolicyRevision: string | null;
  readonly supportPolicyRevision: string | null;
}

export interface TaxonomyRevisionReference {
  readonly taxonomyId: string;
  readonly revision: string;
}

export interface MarketConfigRevision {
  readonly schemaVersion: 1;
  readonly revisionId: EntityId;
  readonly revisionNumber: number;
  readonly environmentId: ReferenceEnvironmentId;
  readonly marketId: MarketId;
  readonly countryCode: MarketId;
  readonly status: 'disabled';
  readonly primaryLocale: LocaleId;
  readonly supportedLocales: readonly LocaleId[];
  readonly fallbackLocaleOrder: readonly LocaleId[];
  readonly languageFallbacks: Readonly<Record<string, readonly LocaleId[]>>;
  readonly currencyCodes: readonly CurrencyCode[];
  readonly defaultIanaZone: IanaTimezone;
  readonly allowedIanaZones: readonly IanaTimezone[];
  readonly taxonomyRevisionRef: TaxonomyRevisionReference;
  readonly mandatoryCopyManifestRevision: string | null;
  readonly sourceRecordIds: readonly EntityId[];
  readonly policyPointers: MarketPolicyPointers;
  readonly capabilityMatrix: readonly MarketCapabilityEntry[];
  readonly compatibilityKey: typeof referenceDataCompatibilityKey;
  readonly contentHash: `sha256:${string}`;
  readonly supersedesRevisionId: EntityId | null;
  readonly createdAtUtc: UtcInstant;
}

export interface CreateMarketConfigRevisionInput {
  readonly revisionId: string;
  readonly revisionNumber: number;
  readonly environmentId: string;
  readonly marketId: string;
  readonly countryCode: string;
  readonly status: 'disabled';
  readonly primaryLocale: string;
  readonly supportedLocales: readonly string[];
  readonly fallbackLocaleOrder: readonly string[];
  readonly languageFallbacks: Readonly<Record<string, readonly string[]>>;
  readonly currencyCodes: readonly string[];
  readonly defaultIanaZone: string;
  readonly allowedIanaZones: readonly string[];
  readonly taxonomyRevisionRef: TaxonomyRevisionReference;
  readonly mandatoryCopyManifestRevision: string | null;
  readonly sourceRecordIds: readonly string[];
  readonly policyPointers: MarketPolicyPointers;
  readonly capabilityMatrix: readonly MarketCapabilityEntry[];
  readonly compatibilityKey: typeof referenceDataCompatibilityKey;
  readonly contentHash: string;
  readonly supersedesRevisionId: string | null;
  readonly createdAtUtc: string;
}

export function createMarketConfigRevision(
  input: CreateMarketConfigRevisionInput,
): DeepReadonly<MarketConfigRevision> {
  if (!Number.isSafeInteger(input.revisionNumber) || input.revisionNumber < 1) {
    throw new TypeError('reference_data_revision_invalid');
  }
  const marketId = parseMarketId(input.marketId);
  const countryCode = parseMarketId(input.countryCode);
  if (marketId !== countryCode || input.status !== 'disabled') {
    throw new TypeError('reference_data_market_scope_invalid');
  }
  const supportedLocales = uniqueMapped(input.supportedLocales, parseLocaleId, 'supported_locale');
  const primaryLocale = parseLocaleId(input.primaryLocale);
  if (!supportedLocales.includes(primaryLocale))
    throw new TypeError('reference_data_primary_locale_unsupported');
  const fallbackLocaleOrder = uniqueMapped(
    input.fallbackLocaleOrder,
    parseLocaleId,
    'fallback_locale',
  );
  if (fallbackLocaleOrder.some((locale) => !supportedLocales.includes(locale)))
    throw new TypeError('reference_data_fallback_locale_unsupported');
  const languageFallbacks: Record<string, readonly LocaleId[]> = {};
  for (const [rawLocale, rawFallbacks] of Object.entries(input.languageFallbacks)) {
    const locale = parseLocaleId(rawLocale);
    const fallbacks = uniqueMapped(rawFallbacks, parseLocaleId, 'language_fallback');
    if (
      !supportedLocales.includes(locale) ||
      fallbacks.includes(locale) ||
      fallbacks.some((item) => !supportedLocales.includes(item))
    ) {
      throw new TypeError('reference_data_language_fallback_invalid');
    }
    languageFallbacks[locale] = Object.freeze(fallbacks);
  }
  assertAcyclicFallbacks(languageFallbacks);
  const currencyCodes = uniqueMapped(input.currencyCodes, parseCurrencyCode, 'currency');
  const allowedIanaZones = uniqueMapped(input.allowedIanaZones, parseIanaTimezone, 'timezone');
  const defaultIanaZone = parseIanaTimezone(input.defaultIanaZone);
  if (!allowedIanaZones.includes(defaultIanaZone))
    throw new TypeError('reference_data_default_timezone_unsupported');
  if (!/^sha256:[0-9a-f]{64}$/.test(input.contentHash))
    throw new TypeError('reference_data_content_hash_invalid');
  if (
    input.taxonomyRevisionRef.taxonomyId.trim().length === 0 ||
    input.taxonomyRevisionRef.revision.trim().length === 0
  )
    throw new TypeError('reference_data_taxonomy_ref_invalid');
  assertRevisionReference(input.mandatoryCopyManifestRevision, 'mandatory_copy_manifest');
  const policyEntries = [
    ['mandatoryCopyManifestRevision', input.policyPointers.mandatoryCopyManifestRevision],
    ['privacyPolicyRevision', input.policyPointers.privacyPolicyRevision],
    ['minorsPolicyRevision', input.policyPointers.minorsPolicyRevision],
    ['trustSafetyPolicyRevision', input.policyPointers.trustSafetyPolicyRevision],
    ['retentionDsrPolicyRevision', input.policyPointers.retentionDsrPolicyRevision],
    ['supportPolicyRevision', input.policyPointers.supportPolicyRevision],
  ] as const;
  for (const [name, value] of policyEntries) {
    assertRevisionReference(value, `policy_${name}`);
  }
  return deepFreeze({
    schemaVersion: 1,
    revisionId: parseEntityId(input.revisionId),
    revisionNumber: input.revisionNumber,
    environmentId: parseReferenceEnvironmentId(input.environmentId),
    marketId,
    countryCode,
    status: 'disabled',
    primaryLocale,
    supportedLocales,
    fallbackLocaleOrder,
    languageFallbacks,
    currencyCodes,
    defaultIanaZone,
    allowedIanaZones,
    taxonomyRevisionRef: { ...input.taxonomyRevisionRef },
    mandatoryCopyManifestRevision: input.mandatoryCopyManifestRevision,
    sourceRecordIds: uniqueMapped(input.sourceRecordIds, parseEntityId, 'source_record', 0),
    policyPointers: { ...input.policyPointers },
    capabilityMatrix: createDisabledCapabilityMatrix(input.capabilityMatrix),
    compatibilityKey: referenceDataCompatibilityKey,
    contentHash: input.contentHash as `sha256:${string}`,
    supersedesRevisionId:
      input.supersedesRevisionId === null ? null : parseEntityId(input.supersedesRevisionId),
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
  });
}

export function isCompatibleMarketConfigRollback(
  current: MarketConfigRevision,
  target: MarketConfigRevision,
): boolean {
  return (
    current.environmentId === target.environmentId &&
    current.marketId === target.marketId &&
    current.schemaVersion === target.schemaVersion &&
    current.compatibilityKey === target.compatibilityKey &&
    target.revisionNumber < current.revisionNumber &&
    target.status === 'disabled'
  );
}

function assertRevisionReference(value: string | null, label: string): void {
  if (value !== null && (value.trim().length === 0 || value.length > 128)) {
    throw new TypeError(`reference_data_${label}_invalid`);
  }
}

function uniqueMapped<T>(
  values: readonly string[],
  parser: (value: unknown) => T,
  label: string,
  minimum = 1,
): T[] {
  if (values.length < minimum || values.length > 32)
    throw new TypeError(`reference_data_${label}_list_invalid`);
  const parsed = values.map(parser);
  if (new Set(parsed).size !== parsed.length)
    throw new TypeError(`reference_data_${label}_duplicate`);
  return parsed;
}

function assertAcyclicFallbacks(fallbacks: Readonly<Record<string, readonly LocaleId[]>>): void {
  const visit = (node: string, path: ReadonlySet<string>): void => {
    if (path.has(node)) throw new TypeError('reference_data_fallback_cycle');
    const nextPath = new Set(path).add(node);
    for (const next of fallbacks[node] ?? []) visit(next, nextPath);
  };
  for (const node of Object.keys(fallbacks)) visit(node, new Set());
}
