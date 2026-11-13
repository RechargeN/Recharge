import { boundedValidationIssues } from './schema_registry.js';
import {
  createReferenceDataSchemaRegistry,
  type ReferenceDataContractTarget,
} from './reference_data_schema_registry.js';

export type ReferenceDataContractValidationResult<T> =
  Readonly<{ ok: true; value: T }> | Readonly<{ ok: false; issues: readonly string[] }>;

let registryPromise: ReturnType<typeof createReferenceDataSchemaRegistry> | undefined;

export async function validateReferenceDataContract<T>(
  target: ReferenceDataContractTarget,
  value: unknown,
): Promise<ReferenceDataContractValidationResult<T>> {
  registryPromise ??= createReferenceDataSchemaRegistry();
  const validator = (await registryPromise).validator(target);
  if (!validator(value)) return { ok: false, issues: boundedValidationIssues(validator.errors) };
  return { ok: true, value: value as T };
}
