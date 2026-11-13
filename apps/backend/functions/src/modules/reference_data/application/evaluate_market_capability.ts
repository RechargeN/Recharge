import type { UtcInstant } from '../../../shared/utc_instant.js';
import type { MandatoryCopyReference } from '../domain/mandatory_copy.js';
import { isMandatoryCopyUsable } from '../domain/mandatory_copy.js';
import type { MarketConfigRevision } from '../domain/market_config.js';
import type { SourceRecord } from '../domain/source_provenance.js';
import { isSourceEligible } from '../domain/source_provenance.js';

export interface CapabilityEvaluation {
  readonly status: 'disabled';
  readonly eligibleForActivation: false;
  readonly blockers: readonly (
    | 'market_disabled'
    | 'capability_disabled'
    | 'mandatory_copy_missing'
    | 'mandatory_copy_not_approved'
    | 'source_not_eligible'
  )[];
}

export function evaluateMarketCapability(input: {
  readonly config: MarketConfigRevision;
  readonly capabilityId: string;
  readonly requestedLocale: string;
  readonly mandatoryCopies: readonly MandatoryCopyReference[];
  readonly sources: readonly SourceRecord[];
  readonly nowUtc: UtcInstant;
}): CapabilityEvaluation {
  const entry = input.config.capabilityMatrix.find(
    (item) => item.capabilityId === input.capabilityId,
  );
  const blockers: CapabilityEvaluation['blockers'][number][] = ['market_disabled'];
  if (entry === undefined || entry.status === 'disabled') blockers.push('capability_disabled');
  if (entry?.requiresMandatoryCopy === true && entry.mandatoryCopyPurposeId !== null) {
    const scoped = input.mandatoryCopies.filter(
      (copy) =>
        copy.marketId === input.config.marketId &&
        copy.capabilityId === entry.capabilityId &&
        copy.purposeId === entry.mandatoryCopyPurposeId &&
        copy.locale === input.requestedLocale,
    );
    if (scoped.length === 0) blockers.push('mandatory_copy_missing');
    else if (
      !scoped.some((copy) =>
        isMandatoryCopyUsable(
          copy,
          {
            marketId: input.config.marketId,
            capabilityId: entry.capabilityId,
            purposeId: entry.mandatoryCopyPurposeId!,
            locale: copy.locale,
          },
          input.nowUtc,
        ),
      )
    )
      blockers.push('mandatory_copy_not_approved');
  }
  if (entry?.requiresEligibleSources === true) {
    const expected = new Set(input.config.sourceRecordIds);
    const eligible = input.sources.filter(
      (source) =>
        expected.has(source.sourceRecordId) &&
        isSourceEligible(source, input.config.marketId, input.nowUtc),
    );
    if (eligible.length !== expected.size) blockers.push('source_not_eligible');
  }
  return Object.freeze({
    status: 'disabled',
    eligibleForActivation: false,
    blockers: Object.freeze([...new Set(blockers)]),
  });
}
