import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const contentContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'content',
  'v1',
);
export const contentSchemaFiles = [
  'content_common.schema.json',
  'content_draft.schema.json',
  'publication_submission.schema.json',
  'published_revision.schema.json',
  'publication_pointer.schema.json',
  'content_command.schema.json',
  'content_query.schema.json',
  'content_result.schema.json',
] as const;
export const contentTargetRefs = {
  draft: 'https://recharge.app/schemas/content/v1/content_draft.schema.json',
  submission: 'https://recharge.app/schemas/content/v1/publication_submission.schema.json',
  publishedRevision: 'https://recharge.app/schemas/content/v1/published_revision.schema.json',
  publicationPointer: 'https://recharge.app/schemas/content/v1/publication_pointer.schema.json',
  command: 'https://recharge.app/schemas/content/v1/content_command.schema.json',
  query: 'https://recharge.app/schemas/content/v1/content_query.schema.json',
  result: 'https://recharge.app/schemas/content/v1/content_result.schema.json',
} as const;
export type ContentContractTarget = keyof typeof contentTargetRefs;

export async function readContentJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(contentContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export async function createContentSchemaRegistry(): Promise<{
  readonly schemas: readonly {
    readonly fileName: string;
    readonly id: string;
    readonly sha256: string;
  }[];
  validator(target: ContentContractTarget): ValidateFunction;
}> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const schemas: { fileName: string; id: string; sha256: string }[] = [];
  for (const fileName of contentSchemaFiles) {
    const raw = await readFile(path.join(contentContractRoot, fileName), 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((item) => item.id === id))
      throw new TypeError(`Missing or duplicate content schema id in ${fileName}`);
    ajv.addSchema(schema, id);
    schemas.push({ fileName, id, sha256: createHash('sha256').update(raw).digest('hex') });
  }
  const cache = new Map<ContentContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target) {
      const cached = cache.get(target);
      if (cached !== undefined) return cached;
      const reference = contentTargetRefs[target];
      const validator = ajv.getSchema(reference) ?? ajv.compile({ $ref: reference });
      cache.set(target, validator);
      return validator;
    },
  };
}
