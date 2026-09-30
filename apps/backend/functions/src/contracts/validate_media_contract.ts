import { boundedValidationIssues } from './schema_registry.js';
import { createMediaSchemaRegistry, type MediaContractTarget } from './media_schema_registry.js';

export type MediaContractValidationResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly issues: readonly string[] };

let registryPromise: ReturnType<typeof createMediaSchemaRegistry> | undefined;

export async function validateMediaContract<T>(
  target: MediaContractTarget,
  value: unknown,
): Promise<MediaContractValidationResult<T>> {
  registryPromise ??= createMediaSchemaRegistry();
  const validator = (await registryPromise).validator(target);
  if (!validator(value)) return { ok: false, issues: boundedValidationIssues(validator.errors) };
  return { ok: true, value: value as T };
}
