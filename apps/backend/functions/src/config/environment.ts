import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export const environmentIds = ['local', 'dev', 'stage', 'prod'] as const;
export type EnvironmentId = (typeof environmentIds)[number];

export interface EnvironmentIdentity {
  readonly logicalName: `recharge-${EnvironmentId}`;
  readonly bindingState: 'unbound';
}

export interface EnvironmentConfig {
  readonly schemaVersion: 1;
  readonly environmentId: EnvironmentId;
  readonly identity: EnvironmentIdentity;
  readonly cloudAllowed: false;
}

export function isEnvironmentId(value: unknown): value is EnvironmentId {
  return typeof value === 'string' && environmentIds.includes(value as EnvironmentId);
}

export function createEnvironmentConfig(
  environmentId: EnvironmentId,
): DeepReadonly<EnvironmentConfig> {
  return deepFreeze({
    schemaVersion: 1,
    environmentId,
    identity: {
      logicalName: `recharge-${environmentId}`,
      bindingState: 'unbound',
    },
    cloudAllowed: false,
  });
}

export function parseEnvironmentConfig(value: unknown): DeepReadonly<EnvironmentConfig> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('environment_config_invalid');
  }
  const record = value as Record<string, unknown>;
  if (!isEnvironmentId(record.environmentId)) throw new TypeError('environment_unknown');
  const expected = createEnvironmentConfig(record.environmentId);
  if (
    record.schemaVersion !== 1 ||
    record.cloudAllowed !== false ||
    typeof record.identity !== 'object' ||
    record.identity === null ||
    Array.isArray(record.identity)
  ) {
    throw new TypeError('environment_config_invalid');
  }
  const identity = record.identity as Record<string, unknown>;
  if (
    identity.logicalName !== expected.identity.logicalName ||
    identity.bindingState !== 'unbound' ||
    Object.keys(record).some(
      (key) => !['schemaVersion', 'environmentId', 'identity', 'cloudAllowed'].includes(key),
    ) ||
    Object.keys(identity).some((key) => !['logicalName', 'bindingState'].includes(key))
  ) {
    throw new TypeError('environment_config_invalid');
  }
  return expected;
}
