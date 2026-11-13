import type { AuthorizationDecision, AuthorizationRequest, Authorizer } from './authorizer.js';

export class DefaultDenyAuthorizer implements Authorizer {
  authorize(request: AuthorizationRequest): AuthorizationDecision {
    if (request.actor === null) return { permitted: false, reason: 'actor_missing' };
    if (request.actor.sessionState === 'revoked') {
      return { permitted: false, reason: 'session_revoked' };
    }
    if (request.actor.sessionState === 'expired') {
      return { permitted: false, reason: 'session_expired' };
    }
    if (request.actor.sessionState === 'compromised') {
      return { permitted: false, reason: 'session_compromised' };
    }
    if (request.actor.sessionState === 'stepUpRequired') {
      return { permitted: false, reason: 'reauth_required' };
    }
    if (request.actor.activeAccountState !== 'active') {
      return { permitted: false, reason: 'account_inactive' };
    }
    if (request.actor.appCheckState !== 'valid') {
      return { permitted: false, reason: 'app_check_invalid' };
    }
    if (request.emergencyDisabled === true) {
      return { permitted: false, reason: 'emergency_disabled' };
    }
    if (request.scope !== undefined) {
      if (request.actor.marketId !== request.scope.marketId) {
        return { permitted: false, reason: 'market_mismatch' };
      }
      if (request.scope.ownerId !== null && request.actor.actorId !== request.scope.ownerId) {
        return { permitted: false, reason: 'owner_mismatch' };
      }
      if (
        request.actor.workspace.type !== request.scope.workspaceType ||
        request.actor.workspace.id !== request.scope.workspaceId
      ) {
        return { permitted: false, reason: 'workspace_mismatch' };
      }
      if (
        request.actor.workspace.type === 'page' &&
        request.actor.workspace.membershipState !== 'active'
      ) {
        return { permitted: false, reason: 'page_membership_revoked' };
      }
    }
    if (request.actor.accessSnapshotRevision < request.minimumAccessSnapshotRevision) {
      return { permitted: false, reason: 'access_snapshot_stale' };
    }
    if (!request.actor.capabilities.includes(request.requiredCapability)) {
      return { permitted: false, reason: 'capability_unsupported' };
    }
    return { permitted: false, reason: 'capability_disabled' };
  }
}
