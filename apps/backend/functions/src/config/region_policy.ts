import type { EnvironmentId } from './environment.js';
import { parseEntityId, type EntityId } from '../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export interface RegionPolicy {
  readonly schemaVersion: 1;
  readonly policyId: EntityId;
  readonly revision: number;
  readonly environmentId: EnvironmentId;
  readonly firestoreLocation: 'eur3';
  readonly functionsRegion: 'europe-west1';
  readonly storageRegion: 'europe-west1';
  readonly exportLocation: 'EU';
  readonly activationState: 'disabled';
}

export function createDisabledRegionPolicy(
  policyId: string,
  revision: number,
  environmentId: EnvironmentId,
): DeepReadonly<RegionPolicy> {
  if (!Number.isSafeInteger(revision) || revision < 0) {
    throw new TypeError('region_policy_revision_invalid');
  }
  return deepFreeze({
    schemaVersion: 1,
    policyId: parseEntityId(policyId),
    revision,
    environmentId,
    firestoreLocation: 'eur3',
    functionsRegion: 'europe-west1',
    storageRegion: 'europe-west1',
    exportLocation: 'EU',
    activationState: 'disabled',
  });
}
