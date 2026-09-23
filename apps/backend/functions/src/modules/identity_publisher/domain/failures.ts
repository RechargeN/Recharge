export type IdentityFailureCode =
  | 'unauthenticated'
  | 'provider_assertion_invalid'
  | 'provider_subject_conflict'
  | 'account_creation_disabled'
  | 'account_restricted'
  | 'account_blocked'
  | 'session_revoked'
  | 'session_expired'
  | 'snapshot_stale'
  | 'creator_verification_required'
  | 'creator_verification_unavailable'
  | 'membership_inactive'
  | 'capability_denied'
  | 'publisher_not_accessible'
  | 'not_found_or_not_accessible'
  | 'revision_conflict'
  | 'invalid_transition'
  | 'policy_unavailable';

export class IdentityFailure extends Error {
  constructor(readonly code: IdentityFailureCode) {
    super(code);
    this.name = 'IdentityFailure';
  }
}
