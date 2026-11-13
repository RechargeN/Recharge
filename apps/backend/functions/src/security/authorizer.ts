import type { ActorContext } from './actor_context.js';
import type { MarketId } from '../modules/reference_data/domain/identifiers.js';

export interface AuthorizationScope {
  readonly marketId: MarketId;
  readonly ownerId: string | null;
  readonly workspaceType: 'personal' | 'page';
  readonly workspaceId: string;
}

export interface AuthorizationRequest {
  readonly actor: ActorContext | null;
  readonly requiredCapability: string;
  readonly minimumAccessSnapshotRevision: number;
  readonly scope?: AuthorizationScope;
  readonly emergencyDisabled?: boolean;
}

export type AuthorizationDecision =
  | { readonly permitted: true; readonly reason: 'capability_granted' }
  | {
      readonly permitted: false;
      readonly reason:
        | 'actor_missing'
        | 'session_revoked'
        | 'session_expired'
        | 'session_compromised'
        | 'reauth_required'
        | 'account_inactive'
        | 'market_mismatch'
        | 'owner_mismatch'
        | 'workspace_mismatch'
        | 'page_membership_revoked'
        | 'access_snapshot_stale'
        | 'app_check_invalid'
        | 'capability_disabled'
        | 'emergency_disabled'
        | 'capability_unsupported';
    };

export interface Authorizer {
  authorize(request: AuthorizationRequest): AuthorizationDecision;
}
