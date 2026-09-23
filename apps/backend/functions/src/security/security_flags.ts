import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import type { MarketId } from '../modules/reference_data/domain/identifiers.js';

export interface SecurityFlagRevision {
  readonly flagId: string;
  readonly revision: number;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly emergencyDisabled: true;
  readonly createdAtUtc: UtcInstant;
}

export function createEmergencyDisabledSecurityFlag(
  input: Omit<SecurityFlagRevision, 'emergencyDisabled' | 'createdAtUtc'> & {
    readonly createdAtUtc: string;
  },
): DeepReadonly<SecurityFlagRevision> {
  if (
    !/^[a-z][a-z0-9._-]{0,95}$/.test(input.flagId) ||
    !/^[a-z][a-z0-9._-]{0,95}$/.test(input.capabilityId) ||
    !Number.isSafeInteger(input.revision) ||
    input.revision < 1
  )
    throw new TypeError('security_flag_invalid');
  return deepFreeze({
    ...input,
    emergencyDisabled: true,
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
  });
}
