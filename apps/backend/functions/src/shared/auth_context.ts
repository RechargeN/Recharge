export interface CallableAuthLike {
  readonly uid: string;
  readonly token: Readonly<Record<string, unknown>>;
}

export interface BookingActor {
  readonly actorId: string;
  readonly sessionId: string;
  readonly accessSnapshotRevision: number;
}

export type ActorResolution =
  | Readonly<{ ok: true; actor: BookingActor }>
  | Readonly<{ ok: false; code: 'unauthenticated' | 'permission_denied' }>;

export function resolveBookingActor(auth: CallableAuthLike | undefined): ActorResolution {
  if (auth === undefined || auth.uid.length < 1) return { ok: false, code: 'unauthenticated' };
  const sessionId = auth.token.sessionId;
  const accessSnapshotRevision = auth.token.accessSnapshotRevision;
  if (
    typeof sessionId !== 'string' ||
    !/^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(sessionId) ||
    !Number.isSafeInteger(accessSnapshotRevision) ||
    Number(accessSnapshotRevision) < 1
  ) {
    return { ok: false, code: 'permission_denied' };
  }
  return {
    ok: true,
    actor: {
      actorId: auth.uid,
      sessionId,
      accessSnapshotRevision: Number(accessSnapshotRevision),
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
