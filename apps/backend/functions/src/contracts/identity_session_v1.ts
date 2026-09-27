export interface EstablishIdentitySessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'establishIdentitySession';
  readonly requestId: string;
  readonly installationId: string;
}

export interface RefreshIdentitySessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'refreshIdentitySession';
  readonly requestId: string;
  readonly sessionContext: Readonly<{
    sessionId: string;
    sessionHandle: string;
    installationId: string;
  }>;
}

export interface RecoverIdentitySessionsCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'recoverIdentitySessions';
  readonly requestId: string;
  readonly installationId: string;
}

export type IdentitySessionCommandV1 =
  | EstablishIdentitySessionCommandV1
  | RefreshIdentitySessionCommandV1
  | RecoverIdentitySessionsCommandV1;

export type IdentitySessionCommandInspection =
  | Readonly<{ ok: true; value: IdentitySessionCommandV1 }>
  | Readonly<{ ok: false; reason: 'invalid_contract' | 'unsupported_schema' }>;

const boundedId = /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u;
const installationId = /^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u;

export function inspectIdentitySessionCommand(value: unknown): IdentitySessionCommandInspection {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return { ok: false, reason: 'invalid_contract' };
  }
  const record = value as Record<string, unknown>;
  if (record.schemaVersion !== 1) return { ok: false, reason: 'unsupported_schema' };
  if (typeof record.requestId !== 'string' || !boundedId.test(record.requestId)) {
    return { ok: false, reason: 'invalid_contract' };
  }
  if (
    (record.commandType === 'establishIdentitySession' ||
      record.commandType === 'recoverIdentitySessions') &&
    typeof record.installationId === 'string' &&
    installationId.test(record.installationId) &&
    Object.keys(record).every((key) =>
      ['schemaVersion', 'commandType', 'requestId', 'installationId'].includes(key),
    )
  ) {
    return { ok: true, value: record as unknown as IdentitySessionCommandV1 };
  }
  if (
    record.commandType === 'refreshIdentitySession' &&
    validSessionContext(record.sessionContext) &&
    Object.keys(record).every((key) =>
      ['schemaVersion', 'commandType', 'requestId', 'sessionContext'].includes(key),
    )
  ) {
    return { ok: true, value: record as unknown as RefreshIdentitySessionCommandV1 };
  }
  return { ok: false, reason: 'invalid_contract' };
}

function validSessionContext(value: unknown): boolean {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const context = value as Record<string, unknown>;
  return (
    Object.keys(context).every((key) =>
      ['sessionId', 'sessionHandle', 'installationId'].includes(key),
    ) &&
    typeof context.sessionId === 'string' &&
    boundedId.test(context.sessionId) &&
    typeof context.sessionHandle === 'string' &&
    /^[A-Za-z0-9_-]{43}$/u.test(context.sessionHandle) &&
    typeof context.installationId === 'string' &&
    installationId.test(context.installationId)
  );
}
