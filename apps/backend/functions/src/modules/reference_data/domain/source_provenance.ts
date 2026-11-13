import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import { marketIds, parseMarketId, type MarketId } from './identifiers.js';

export type SourceEligibility = 'candidate' | 'eligible' | 'rejected';
export type LicenseDecision = 'pending' | 'accepted' | 'rejected';

export interface SourceRecord {
  readonly schemaVersion: 1;
  readonly sourceRecordId: EntityId;
  readonly sourceKind: 'internal' | 'external';
  readonly sourceRevision: string;
  readonly originUri: string | null;
  readonly evidenceSha256: string | null;
  readonly licenseDecision: LicenseDecision;
  readonly licenseEvidenceRevision: string | null;
  readonly eligibility: SourceEligibility;
  readonly marketScope: readonly MarketId[];
  readonly capturedAtUtc: UtcInstant;
  readonly expiresAtUtc: UtcInstant | null;
}

export function createSourceRecord(
  input: Omit<
    SourceRecord,
    'schemaVersion' | 'sourceRecordId' | 'capturedAtUtc' | 'expiresAtUtc' | 'marketScope'
  > & {
    readonly sourceRecordId: string;
    readonly capturedAtUtc: string;
    readonly expiresAtUtc: string | null;
    readonly marketScope: readonly string[];
  },
): DeepReadonly<SourceRecord> {
  if (input.sourceRevision.trim().length === 0 || input.sourceRevision.length > 128) {
    throw new TypeError('source_revision_invalid');
  }
  if (
    (input.originUri !== null && !isHttpsUri(input.originUri)) ||
    (input.evidenceSha256 !== null && !/^[0-9a-f]{64}$/.test(input.evidenceSha256)) ||
    (input.licenseEvidenceRevision !== null &&
      (input.licenseEvidenceRevision.trim().length === 0 ||
        input.licenseEvidenceRevision.length > 128))
  ) {
    throw new TypeError('source_evidence_invalid');
  }
  const marketScope = input.marketScope.map(parseMarketId);
  if (
    marketScope.length < 1 ||
    marketScope.length > marketIds.length ||
    new Set(marketScope).size !== marketScope.length
  ) {
    throw new TypeError('source_market_scope_invalid');
  }
  if (
    input.eligibility === 'eligible' &&
    (input.licenseDecision !== 'accepted' ||
      input.licenseEvidenceRevision === null ||
      input.evidenceSha256 === null)
  ) {
    throw new TypeError('source_eligible_without_accepted_evidence');
  }
  return deepFreeze({
    ...input,
    schemaVersion: 1,
    sourceRecordId: parseEntityId(input.sourceRecordId),
    marketScope,
    capturedAtUtc: parseUtcInstant(input.capturedAtUtc),
    expiresAtUtc: input.expiresAtUtc === null ? null : parseUtcInstant(input.expiresAtUtc),
  });
}

function isHttpsUri(value: string): boolean {
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

export function isSourceEligible(
  source: SourceRecord,
  marketId: MarketId,
  nowUtc: UtcInstant,
): boolean {
  return (
    source.eligibility === 'eligible' &&
    source.licenseDecision === 'accepted' &&
    source.licenseEvidenceRevision !== null &&
    source.evidenceSha256 !== null &&
    source.marketScope.includes(marketId) &&
    (source.expiresAtUtc === null || Date.parse(source.expiresAtUtc) > Date.parse(nowUtc))
  );
}
