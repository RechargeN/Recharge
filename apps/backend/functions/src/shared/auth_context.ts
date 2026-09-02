export interface CallableAuthLike {
  readonly uid: string;
  readonly token: Readonly<Record<string, unknown>>;
}

export interface BookingActor {
  readonly actorId: string;
}

export type ActorResolution =
  | Readonly<{ ok: true; actor: BookingActor }>
  | Readonly<{ ok: false; code: 'unauthenticated' | 'permission_denied' }>;

const requiredCapability = 'booking.self_service';

export function resolveBookingActor(auth: CallableAuthLike | undefined): ActorResolution {
  if (auth === undefined || auth.uid.length < 1) return { ok: false, code: 'unauthenticated' };
  if (auth.token.accountState !== 'active') return { ok: false, code: 'permission_denied' };
  const capabilities = auth.token.capabilities;
  if (!Array.isArray(capabilities) || !capabilities.includes(requiredCapability)) {
    return { ok: false, code: 'permission_denied' };
  }
  return { ok: true, actor: { actorId: auth.uid } };
}

export function isEmulatorAppCheckAllowed(
  app: unknown,
  functionsEmulator = process.env.FUNCTIONS_EMULATOR,
): boolean {
  // RAW-C is deliberately non-runnable outside the local Functions Emulator.
  return functionsEmulator === 'true' && (app === undefined || typeof app === 'object');
}
