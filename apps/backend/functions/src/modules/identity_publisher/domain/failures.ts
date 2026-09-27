export type IdentityFailureCode =
  | 'unauthenticated'
  | 'provider_assertion_invalid'
  | 'provider_subject_conflict'
  | 'account_creation_disabled'
  | 'account_restricted'
  | 'account_blocked'
  | 'session_revoked'
  | 'session_expired'
  | 'session_limit_reached'
  | 'rate_limited'
  | 'snapshot_stale'
  | 'creator_verification_required'
  | 'creator_verification_unavailable'
  | 'membership_inactive'
  | 'capability_denied'
  | 'publisher_not_accessible'
  | 'not_found_or_not_accessible'
  | 'revision_conflict'
  | 'invalid_transition'
  | 'policy_unavailable'
  | 'temporarily_unavailable';

export class IdentityFailure extends Error {
  constructor(
    readonly code: IdentityFailureCode,
    readonly retryAfterSeconds?: number,
  ) {
    super(code);
    this.name = 'IdentityFailure';
  }
}
