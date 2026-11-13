import { boundedValidationIssues } from './schema_registry.js';
import {
  createPrivacySchemaRegistry,
  type PrivacyContractTarget,
} from './privacy_schema_registry.js';

export type PrivacyContractValidationResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly issues: readonly string[] };
let registryPromise: ReturnType<typeof createPrivacySchemaRegistry> | undefined;

export async function validatePrivacyContract<T>(
  target: PrivacyContractTarget,
  value: unknown,
): Promise<PrivacyContractValidationResult<T>> {
  registryPromise ??= createPrivacySchemaRegistry();
  const validator = (await registryPromise).validator(target);
  if (!validator(value)) return { ok: false, issues: boundedValidationIssues(validator.errors) };
  return { ok: true, value: value as T };
}
