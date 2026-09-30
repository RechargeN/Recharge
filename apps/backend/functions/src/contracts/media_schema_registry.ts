import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const mediaContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'media',
  'v1',
);
export const mediaSchemaFiles = [
  'media_common.schema.json',
  'media_asset.schema.json',
  'upload_session.schema.json',
  'media_command.schema.json',
  'media_query.schema.json',
  'media_result.schema.json',
] as const;
export const mediaTargetRefs = {
  asset: 'https://recharge.app/schemas/media/v1/media_asset.schema.json',
  uploadSession: 'https://recharge.app/schemas/media/v1/upload_session.schema.json',
  processingReceipt:
    'https://recharge.app/schemas/media/v1/media_asset.schema.json#/$defs/processingReceipt',
  deletionStatus:
    'https://recharge.app/schemas/media/v1/media_asset.schema.json#/$defs/deletionStatus',
  orphanReconciliation:
    'https://recharge.app/schemas/media/v1/media_asset.schema.json#/$defs/orphanReconciliation',
  command: 'https://recharge.app/schemas/media/v1/media_command.schema.json',
  query: 'https://recharge.app/schemas/media/v1/media_query.schema.json',
  result: 'https://recharge.app/schemas/media/v1/media_result.schema.json',
} as const;
export type MediaContractTarget = keyof typeof mediaTargetRefs;

export async function readMediaJson(relativePath: string): Promise<unknown> {
  return JSON.parse(await readFile(path.join(mediaContractRoot, relativePath), 'utf8')) as unknown;
}

export async function createMediaSchemaRegistry(): Promise<{
  readonly schemas: readonly {
    readonly fileName: string;
    readonly id: string;
    readonly sha256: string;
  }[];
  validator(target: MediaContractTarget): ValidateFunction;
}> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const schemas: { fileName: string; id: string; sha256: string }[] = [];
  for (const fileName of mediaSchemaFiles) {
    const raw = await readFile(path.join(mediaContractRoot, fileName), 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((item) => item.id === id))
      throw new TypeError(`Missing or duplicate media schema id in ${fileName}`);
    ajv.addSchema(schema, id);
    schemas.push({ fileName, id, sha256: createHash('sha256').update(raw).digest('hex') });
  }
  const cache = new Map<MediaContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target) {
      const cached = cache.get(target);
      if (cached !== undefined) return cached;
      const reference = mediaTargetRefs[target];
      const validator = ajv.getSchema(reference) ?? ajv.compile({ $ref: reference });
      cache.set(target, validator);
      return validator;
    },
  };
}
