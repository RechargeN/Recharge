import { boundedValidationIssues } from './schema_registry.js';
import {
  createIdentitySchemaRegistry,
  type IdentityContractTarget,
} from './identity_schema_registry.js';

export type IdentityContractValidationResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly issues: readonly string[] };

let registryPromise: ReturnType<typeof createIdentitySchemaRegistry> | undefined;

export async function validateIdentityContract<T>(
  target: IdentityContractTarget,
  value: unknown,
): Promise<IdentityContractValidationResult<T>> {
  registryPromise ??= createIdentitySchemaRegistry();
  const validator = (await registryPromise).validator(target);
  if (!validator(value)) return { ok: false, issues: boundedValidationIssues(validator.errors) };
  return { ok: true, value: value as T };
}
