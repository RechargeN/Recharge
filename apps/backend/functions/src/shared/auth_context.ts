export interface CallableAuthLike {
  readonly uid: string;
  readonly token: Readonly<Record<string, unknown>>;
}

export interface BookingActor {
  readonly actorId: string;
  readonly sessionId: string;
  readonly sessionHandle: string;
  readonly installationId: string;
}

export type ActorResolution =
  | Readonly<{ ok: true; actor: BookingActor }>
  | Readonly<{ ok: false; code: 'unauthenticated' | 'permission_denied' }>;

export function resolveBookingActor(
  auth: CallableAuthLike | undefined,
  sessionContext: unknown,
): ActorResolution {
  if (auth === undefined || auth.uid.length < 1) return { ok: false, code: 'unauthenticated' };
  if (
    typeof sessionContext !== 'object' ||
    sessionContext === null ||
    Array.isArray(sessionContext)
  ) {
    return { ok: false, code: 'permission_denied' };
  }
  const record = sessionContext as Record<string, unknown>;
  const sessionId = record.sessionId;
  const sessionHandle = record.sessionHandle;
  const installationId = record.installationId;
  if (
    typeof sessionId !== 'string' ||
    !/^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(sessionId) ||
    typeof sessionHandle !== 'string' ||
    !/^[A-Za-z0-9_-]{43}$/u.test(sessionHandle) ||
    typeof installationId !== 'string' ||
    !/^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u.test(installationId) ||
    Object.keys(record).some(
      (key) => !['sessionId', 'sessionHandle', 'installationId'].includes(key),
    )
  ) {
    return { ok: false, code: 'permission_denied' };
  }
  return {
    ok: true,
    actor: {
      actorId: auth.uid,
      sessionId,
      sessionHandle,
      installationId,
    },
  };
}

export function isEmulatorAppCheckAllowed(
  app: unknown,
  functionsEmulator = process.env.FUNCTIONS_EMULATOR,
): boolean {
  // RAW-C is deliberately non-runnable outside the local Functions Emulator.
  return functionsEmulator === 'true' && (app === undefined || typeof app === 'object');
}
