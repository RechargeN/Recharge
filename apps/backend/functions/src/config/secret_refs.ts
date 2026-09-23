import type { EnvironmentId } from './environment.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export interface SecretReference {
  readonly schemaVersion: 1;
  readonly environmentId: EnvironmentId;
  readonly logicalName: string;
  readonly provider: 'gcpSecretManager';
  readonly referenceName: string;
  readonly bindingState: 'unbound';
}

export function createUnboundSecretReference(input: {
  readonly environmentId: EnvironmentId;
  readonly logicalName: string;
  readonly referenceName: string;
}): DeepReadonly<SecretReference> {
  if (!/^[A-Z][A-Z0-9_]{0,95}$/.test(input.logicalName)) {
    throw new TypeError('secret_logical_name_invalid');
  }
  if (!/^[a-z][a-z0-9_-]{0,127}$/.test(input.referenceName)) {
    throw new TypeError('secret_reference_name_invalid');
  }
  return deepFreeze({
    schemaVersion: 1,
    environmentId: input.environmentId,
    logicalName: input.logicalName,
    provider: 'gcpSecretManager',
    referenceName: input.referenceName,
    bindingState: 'unbound',
  });
}

export function rejectSecretMaterial(value: unknown): void {
  visit(value, new WeakSet<object>());
}

function visit(value: unknown, seen: WeakSet<object>): void {
  if (typeof value !== 'object' || value === null || seen.has(value)) return;
  seen.add(value);
  const forbidden = ['value', 'secret', 'token', 'password', 'privateKey', 'credentials'];
  for (const [key, child] of Object.entries(value)) {
    if (forbidden.some((candidate) => key.toLowerCase().includes(candidate.toLowerCase()))) {
      throw new TypeError('secret_material_forbidden');
    }
    visit(child, seen);
  }
}
