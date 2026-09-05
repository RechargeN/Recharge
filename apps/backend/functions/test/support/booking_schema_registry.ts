import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const bookingContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'booking',
  'v1',
);

export const bookingSchemaFiles = [
  'common.schema.json',
  'booking.schema.json',
  'booking_hold.schema.json',
  'booking_policy.schema.json',
  'booking_command.schema.json',
  'booking_result.schema.json',
  'booking_error.schema.json',
  'booking_query.schema.json',
  'booking_read.schema.json',
  'booking_page.schema.json',
  'booking_availability.schema.json',
] as const;

export async function readBookingJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(bookingContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('Expected JSON object');
  }
  return value as Record<string, unknown>;
}

export function validateBoundedOpaquePayload(value: unknown): readonly string[] {
  const failures: string[] = [];
  validateOpaqueValue(value, '$', failures, 0);
  if (Buffer.byteLength(JSON.stringify(value), 'utf8') > 4096) {
    failures.push('$ exceeds 4096 canonical UTF-8 bytes');
  }
  return failures;
}

function validateOpaqueValue(
  value: unknown,
  path: string,
  failures: string[],
  depth: number,
): void {
  if (depth > 8) {
    failures.push(`${path} exceeds opaque depth 8`);
    return;
  }
  if (value === null || typeof value === 'boolean') return;
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) failures.push(`${path} must be a safe integer`);
    return;
  }
  if (typeof value === 'string') {
    if ([...value].length > 512) failures.push(`${path} exceeds 512 Unicode scalars`);
    return;
  }
  if (Array.isArray(value)) {
    if (value.length > 32) failures.push(`${path} exceeds 32 items`);
    value.forEach((item, index) =>
      validateOpaqueValue(item, `${path}[${index}]`, failures, depth + 1),
    );
    return;
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value);
    if (entries.length > 16) failures.push(`${path} exceeds 16 properties`);
    for (const [key, item] of entries)
      validateOpaqueValue(item, `${path}.${key}`, failures, depth + 1);
    return;
  }
  failures.push(`${path} has an unsupported value type`);
}

export async function createBookingSchemaRegistry(): Promise<{
  ids: readonly string[];
  validator(fileName: string): ValidateFunction;
}> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const ids: string[] = [];
  const byFile = new Map<string, string>();

  for (const fileName of bookingSchemaFiles) {
    const schema = asRecord(await readBookingJson(fileName));
    const id = schema.$id;
    if (typeof id !== 'string' || ids.includes(id)) {
      throw new TypeError(`Missing or duplicate schema id in ${fileName}`);
    }
    ids.push(id);
    byFile.set(fileName, id);
    ajv.addSchema(schema, id);
  }

  return {
    ids,
    validator(fileName: string): ValidateFunction {
      const id = byFile.get(fileName);
      if (id === undefined) throw new TypeError(`Unknown Booking schema ${fileName}`);
      const validator = ajv.getSchema(id);
      if (validator === undefined) throw new TypeError(`Uncompiled Booking schema ${fileName}`);
      return validator;
    },
  };
}
