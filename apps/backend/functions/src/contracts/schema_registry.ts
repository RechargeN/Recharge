import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ErrorObject, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

import { isIanaTimezone } from '../shared/utc_instant.js';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const platformContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'platform',
  'v1',
);

export const platformSchemaFiles = [
  'request_context.schema.json',
  'error.schema.json',
  'result_envelope.schema.json',
  'cursor_page.schema.json',
  'event_envelope.schema.json',
  'async_operation.schema.json',
] as const;

export const platformTargetRefs = {
  requestContext: 'https://recharge.app/schemas/platform/v1/request_context.schema.json',
  entityReference:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/entityReference',
  money: 'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/money',
  utcInstant:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/utcInstant',
  ianaTimezone:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/ianaTimezone',
  commandEnvelope:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/commandEnvelope',
  queryEnvelope:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/queryEnvelope',
  minimumClientPolicy:
    'https://recharge.app/schemas/platform/v1/request_context.schema.json#/$defs/minimumClientPolicy',
  error: 'https://recharge.app/schemas/platform/v1/error.schema.json',
  resultEnvelope: 'https://recharge.app/schemas/platform/v1/result_envelope.schema.json',
  cursorPage: 'https://recharge.app/schemas/platform/v1/cursor_page.schema.json',
  eventEnvelope: 'https://recharge.app/schemas/platform/v1/event_envelope.schema.json',
  asyncOperation: 'https://recharge.app/schemas/platform/v1/async_operation.schema.json',
} as const;

export type PlatformContractTarget = keyof typeof platformTargetRefs;

export interface PlatformSchemaDescriptor {
  readonly fileName: (typeof platformSchemaFiles)[number];
  readonly id: string;
  readonly sha256: string;
}

export interface PlatformSchemaRegistry {
  readonly schemas: readonly PlatformSchemaDescriptor[];
  validator(target: PlatformContractTarget): ValidateFunction;
}

export async function readPlatformJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(platformContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export async function createPlatformSchemaRegistry(): Promise<PlatformSchemaRegistry> {
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

  const schemas: PlatformSchemaDescriptor[] = [];
  for (const fileName of platformSchemaFiles) {
    const raw = await readFile(path.join(platformContractRoot, fileName), 'utf8');
    const schema = asRecord(JSON.parse(raw) as unknown);
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((descriptor) => descriptor.id === id)) {
      throw new TypeError(`Missing or duplicate platform schema id in ${fileName}`);
    }
    ajv.addSchema(schema, id);
    schemas.push({
      fileName,
      id,
      sha256: createHash('sha256').update(raw, 'utf8').digest('hex'),
    });
  }

  const validatorCache = new Map<PlatformContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target: PlatformContractTarget): ValidateFunction {
      const cached = validatorCache.get(target);
      if (cached !== undefined) return cached;
      const ref = platformTargetRefs[target];
      const validator = ajv.getSchema(ref) ?? ajv.compile({ $ref: ref });
      validatorCache.set(target, validator);
      return validator;
    },
  };
}

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('Expected JSON object');
  }
  return value as Record<string, unknown>;
}

export function boundedValidationIssues(
  errors: readonly ErrorObject[] | null | undefined,
): readonly string[] {
  if (errors === null || errors === undefined) return [];
  return errors.slice(0, 20).map((error) => `${error.instancePath || '$'} ${error.keyword}`);
}
