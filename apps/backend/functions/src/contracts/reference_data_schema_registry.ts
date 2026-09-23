import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

import { isIanaTimezone } from '../shared/utc_instant.js';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const referenceDataContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'reference_data',
  'v1',
);
export const referenceDataSchemaFiles = [
  'localized_text.schema.json',
  'market_config_revision.schema.json',
  'mandatory_copy_reference.schema.json',
  'source_record.schema.json',
  'activation_pointer.schema.json',
] as const;
export const referenceDataTargetRefs = {
  localizedText: 'https://recharge.app/schemas/reference-data/v1/localized_text.schema.json',
  marketConfigRevision:
    'https://recharge.app/schemas/reference-data/v1/market_config_revision.schema.json',
  mandatoryCopyReference:
    'https://recharge.app/schemas/reference-data/v1/mandatory_copy_reference.schema.json',
  sourceRecord: 'https://recharge.app/schemas/reference-data/v1/source_record.schema.json',
  activationPointer:
    'https://recharge.app/schemas/reference-data/v1/activation_pointer.schema.json',
} as const;
export type ReferenceDataContractTarget = keyof typeof referenceDataTargetRefs;

export interface ReferenceDataSchemaDescriptor {
  readonly fileName: (typeof referenceDataSchemaFiles)[number];
  readonly id: string;
  readonly sha256: string;
}

export interface ReferenceDataSchemaRegistry {
  readonly schemas: readonly ReferenceDataSchemaDescriptor[];
  validator(target: ReferenceDataContractTarget): ValidateFunction;
}

export async function readReferenceDataJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(referenceDataContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export async function createReferenceDataSchemaRegistry(): Promise<ReferenceDataSchemaRegistry> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  ajv.addFormat('iana-time-zone', {
    type: 'string',
    validate: (value: string) => isIanaTimezone(value),
  });
  const currencies = new Set(Intl.supportedValuesOf('currency'));
  ajv.addFormat('iso-4217-currency', {
    type: 'string',
    validate: (value: string) => currencies.has(value),
  });
  const schemas: ReferenceDataSchemaDescriptor[] = [];
  for (const fileName of referenceDataSchemaFiles) {
    const raw = await readFile(path.join(referenceDataContractRoot, fileName), 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((entry) => entry.id === id))
      throw new TypeError(`Missing or duplicate reference-data schema id in ${fileName}`);
    ajv.addSchema(schema, id);
    schemas.push({ fileName, id, sha256: createHash('sha256').update(raw, 'utf8').digest('hex') });
  }
  const cache = new Map<ReferenceDataContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target) {
      const cached = cache.get(target);
      if (cached !== undefined) return cached;
      const reference = referenceDataTargetRefs[target];
      const validator = ajv.getSchema(reference) ?? ajv.compile({ $ref: reference });
      cache.set(target, validator);
      return validator;
    },
  };
}
