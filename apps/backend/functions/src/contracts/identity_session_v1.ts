export interface EstablishIdentitySessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'establishIdentitySession';
  readonly requestId: string;
  readonly installationId: string;
}

export type IdentitySessionCommandInspection =
  | Readonly<{ ok: true; value: EstablishIdentitySessionCommandV1 }>
  | Readonly<{ ok: false; reason: 'invalid_contract' | 'unsupported_schema' }>;

const boundedId = /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u;
const installationId = /^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u;

export function inspectIdentitySessionCommand(value: unknown): IdentitySessionCommandInspection {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return { ok: false, reason: 'invalid_contract' };
  }
  const record = value as Record<string, unknown>;
  if (record.schemaVersion !== 1) return { ok: false, reason: 'unsupported_schema' };
  if (
    record.commandType !== 'establishIdentitySession' ||
    typeof record.requestId !== 'string' ||
    !boundedId.test(record.requestId) ||
    typeof record.installationId !== 'string' ||
    !installationId.test(record.installationId) ||
    Object.keys(record).some(
      (key) => !['schemaVersion', 'commandType', 'requestId', 'installationId'].includes(key),
    )
  ) {
    return { ok: false, reason: 'invalid_contract' };
  }
  return { ok: true, value: record as unknown as EstablishIdentitySessionCommandV1 };
}
