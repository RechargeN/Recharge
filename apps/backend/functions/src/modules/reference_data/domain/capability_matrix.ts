import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';

export type CapabilityStatus = 'disabled';

export interface MarketCapabilityEntry {
  readonly capabilityId: string;
  readonly status: CapabilityStatus;
  readonly requiresMandatoryCopy: boolean;
  readonly mandatoryCopyPurposeId: string | null;
  readonly requiresEligibleSources: boolean;
}

export function createDisabledCapabilityMatrix(
  entries: readonly MarketCapabilityEntry[],
): readonly DeepReadonly<MarketCapabilityEntry>[] {
  if (entries.length < 1 || entries.length > 64) {
    throw new TypeError('reference_data_capability_matrix_invalid');
  }
  const seen = new Set<string>();
  const validated = entries.map((entry) => {
    if (
      !/^[a-z][a-z0-9._-]{0,95}$/.test(entry.capabilityId) ||
      entry.status !== 'disabled' ||
      seen.has(entry.capabilityId) ||
      (entry.requiresMandatoryCopy && !entry.mandatoryCopyPurposeId) ||
      (!entry.requiresMandatoryCopy && entry.mandatoryCopyPurposeId !== null)
    ) {
      throw new TypeError('reference_data_capability_entry_invalid');
    }
    seen.add(entry.capabilityId);
    return deepFreeze({ ...entry });
  });
  return Object.freeze(validated);
}
