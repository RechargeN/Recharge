export type AppCheckPolicyDecision =
  | Readonly<{ allowed: true; mode: 'emulatorBypass' | 'verified' }>
  | Readonly<{ allowed: false; code: 'app_check_required' | 'policy_unavailable' }>;

export function decideAppCheck(input: {
  readonly environmentId: 'local' | 'dev' | 'stage' | 'prod';
  readonly projectId: string | undefined;
  readonly functionsEmulator: string | undefined;
  readonly firestoreEmulatorHost: string | undefined;
  readonly evidenceState: 'valid' | 'missing' | 'invalid' | 'expired';
}): AppCheckPolicyDecision {
  if (input.environmentId === 'local') {
    const exactBypass =
      input.projectId === 'demo-recharge' &&
      input.functionsEmulator === 'true' &&
      /^(127\.0\.0\.1|localhost):\d+$/u.test(input.firestoreEmulatorHost ?? '');
    return exactBypass
      ? { allowed: true, mode: 'emulatorBypass' }
      : { allowed: false, code: 'policy_unavailable' };
  }
  return input.evidenceState === 'valid'
    ? { allowed: true, mode: 'verified' }
    : { allowed: false, code: 'app_check_required' };
}
