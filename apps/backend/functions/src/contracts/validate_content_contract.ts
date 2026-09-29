import { boundedValidationIssues } from './schema_registry.js';
import {
  createContentSchemaRegistry,
  type ContentContractTarget,
} from './content_schema_registry.js';

export type ContentContractValidationResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly issues: readonly string[] };

let registryPromise: ReturnType<typeof createContentSchemaRegistry> | undefined;

export async function validateContentContract<T>(
  target: ContentContractTarget,
  value: unknown,
): Promise<ContentContractValidationResult<T>> {
  registryPromise ??= createContentSchemaRegistry();
  const validator = (await registryPromise).validator(target);
  if (!validator(value)) return { ok: false, issues: boundedValidationIssues(validator.errors) };
  return { ok: true, value: value as T };
}
