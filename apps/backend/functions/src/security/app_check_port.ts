export type AppCheckEvidence =
  | { readonly state: 'valid'; readonly tokenAgeSeconds: number }
  | { readonly state: 'missing' | 'invalid' | 'expired' };

export interface AppCheckPort {
  verify(token: string | undefined): Promise<AppCheckEvidence>;
}

export class LocalDenyAppCheckPort implements AppCheckPort {
  verify(token: string | undefined): Promise<AppCheckEvidence> {
    void token;
    return Promise.resolve({ state: 'missing' });
  }
}

export function appCheckGrantsAuthority(evidence: AppCheckEvidence): false {
  void evidence;
  return false;
}
