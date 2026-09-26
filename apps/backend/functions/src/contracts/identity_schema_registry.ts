import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type { FormatsPlugin } from 'ajv-formats';

const require = createRequire(import.meta.url);
const loadedFormats = require('ajv-formats') as FormatsPlugin | { readonly default: FormatsPlugin };
const addFormats = typeof loadedFormats === 'function' ? loadedFormats : loadedFormats.default;

export const identityContractRoot = path.resolve(
  process.cwd(),
  '..',
  '..',
  '..',
  'packages',
  'api_contracts',
  'schema',
  'identity',
  'v1',
);
export const identitySchemaFiles = [
  'identity_common.schema.json',
  'account.schema.json',
  'auth_identity.schema.json',
  'session.schema.json',
  'access_snapshot.schema.json',
  'creator_verification.schema.json',
  'managed_page.schema.json',
  'page_membership.schema.json',
  'publisher_eligibility.schema.json',
  'identity_session_command.schema.json',
  'identity_session_result.schema.json',
] as const;
export const identityTargetRefs = {
  account: 'https://recharge.app/schemas/identity/v1/account.schema.json',
  authIdentity: 'https://recharge.app/schemas/identity/v1/auth_identity.schema.json',
  session: 'https://recharge.app/schemas/identity/v1/session.schema.json',
  accessSnapshot: 'https://recharge.app/schemas/identity/v1/access_snapshot.schema.json',
  creatorVerification: 'https://recharge.app/schemas/identity/v1/creator_verification.schema.json',
  managedPage: 'https://recharge.app/schemas/identity/v1/managed_page.schema.json',
  pageMembership: 'https://recharge.app/schemas/identity/v1/page_membership.schema.json',
  publisherEligibility:
    'https://recharge.app/schemas/identity/v1/publisher_eligibility.schema.json',
  identitySessionCommand:
    'https://recharge.app/schemas/identity/v1/identity_session_command.schema.json',
  identitySessionResult:
    'https://recharge.app/schemas/identity/v1/identity_session_result.schema.json',
} as const;
export type IdentityContractTarget = keyof typeof identityTargetRefs;

export async function readIdentityJson(relativePath: string): Promise<unknown> {
  return JSON.parse(
    await readFile(path.join(identityContractRoot, relativePath), 'utf8'),
  ) as unknown;
}

export async function createIdentitySchemaRegistry(): Promise<{
  readonly schemas: readonly {
    readonly fileName: string;
    readonly id: string;
    readonly sha256: string;
  }[];
  validator(target: IdentityContractTarget): ValidateFunction;
}> {
  const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
  addFormats(ajv);
  const schemas: { fileName: string; id: string; sha256: string }[] = [];
  for (const fileName of identitySchemaFiles) {
    const raw = await readFile(path.join(identityContractRoot, fileName), 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;
    const id = schema.$id;
    if (typeof id !== 'string' || schemas.some((item) => item.id === id))
      throw new TypeError(`Missing or duplicate identity schema id in ${fileName}`);
    ajv.addSchema(schema, id);
    schemas.push({ fileName, id, sha256: createHash('sha256').update(raw).digest('hex') });
  }
  const cache = new Map<IdentityContractTarget, ValidateFunction>();
  return {
    schemas: Object.freeze(schemas),
    validator(target) {
      const cached = cache.get(target);
      if (cached !== undefined) return cached;
      const reference = identityTargetRefs[target];
      const validator = ajv.getSchema(reference) ?? ajv.compile({ $ref: reference });
      cache.set(target, validator);
      return validator;
    },
  };
}
