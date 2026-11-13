import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const privacyContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'privacy',
  'v1',
);
export const privacySchemaFiles = [
  'privacy_request.schema.json',
  'privacy_request_status.schema.json',
  'privacy_domain_task.schema.json',
] as const;
export const privacyTargetRefs = {
  privacyRequest: 'https://recharge.app/schemas/privacy/v1/privacy_request.schema.json',
  privacyRequestStatus:
    'https://recharge.app/schemas/privacy/v1/privacy_request_status.schema.json',
  privacyDomainTask: 'https://recharge.app/schemas/privacy/v1/privacy_domain_task.schema.json',
} as const;
export type PrivacyContractTarget = keyof typeof privacyTargetRefs;

export async function readPrivacyJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(privacyContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export async function createPrivacySchemaRegistry(): Promise<{
  readonly schemas: readonly {
    readonly fileName: string;
    readonly id: string;
    readonly sha256: string;
  }[];
  validator(target: PrivacyContractTarget): ValidateFunction;
}> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const schemas: { fileName: string; id: string; sha256: string }[] = [];
  for (const fileName of privacySchemaFiles) {
    const raw = await readFile(path.join(privacyContractRoot, fileName), 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((item) => item.id === id))
      throw new TypeError(`Missing or duplicate privacy schema id in ${fileName}`);
    ajv.addSchema(schema, id);
    schemas.push({ fileName, id, sha256: createHash('sha256').update(raw, 'utf8').digest('hex') });
  }
  const cache = new Map<PrivacyContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target) {
      const cached = cache.get(target);
      if (cached !== undefined) return cached;
      const reference = privacyTargetRefs[target];
      const validator = ajv.getSchema(reference) ?? ajv.compile({ $ref: reference });
      cache.set(target, validator);
      return validator;
    },
  };
}
