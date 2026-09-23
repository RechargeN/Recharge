import type { ActorContext } from './actor_context.js';
import type { UtcInstant } from '../shared/utc_instant.js';

export type AuthenticationDecision =
  | { readonly authenticated: true; readonly actor: ActorContext }
  | {
      readonly authenticated: false;
      readonly reason:
        | 'authentication_missing'
        | 'session_revoked'
        | 'session_expired'
        | 'account_inactive'
        | 'authentication_stale';
    };

export interface AuthenticationGuardPort {
  resolve(bearerToken: string | undefined): Promise<AuthenticationDecision>;
}

export class LocalDenyAuthenticationGuard implements AuthenticationGuardPort {
  resolve(bearerToken: string | undefined): Promise<AuthenticationDecision> {
    void bearerToken;
    return Promise.resolve({ authenticated: false, reason: 'authentication_missing' });
  }
}

export function evaluateAuthentication(
  actor: ActorContext | null,
  nowUtc: UtcInstant,
  maximumAuthenticationAgeSeconds: number,
): AuthenticationDecision {
  if (actor === null) return { authenticated: false, reason: 'authentication_missing' };
  if (actor.sessionState === 'revoked') return { authenticated: false, reason: 'session_revoked' };
  if (actor.sessionState === 'expired') return { authenticated: false, reason: 'session_expired' };
  if (actor.activeAccountState !== 'active')
    return { authenticated: false, reason: 'account_inactive' };
  if (
    !Number.isSafeInteger(maximumAuthenticationAgeSeconds) ||
    maximumAuthenticationAgeSeconds < 0
  ) {
    throw new TypeError('authentication_maximum_age_invalid');
  }
  const ageSeconds = (Date.parse(nowUtc) - Date.parse(actor.authenticatedAtUtc)) / 1000;
  if (ageSeconds < 0 || ageSeconds > maximumAuthenticationAgeSeconds) {
    return { authenticated: false, reason: 'authentication_stale' };
  }
  return { authenticated: true, actor };
}
