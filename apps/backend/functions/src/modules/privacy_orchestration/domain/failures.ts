export type PrivacyFailureCode =
  | 'request_not_found'
  | 'revision_conflict'
  | 'invalid_transition'
  | 'idempotency_conflict'
  | 'verification_required'
  | 'task_evidence_missing'
  | 'retention_policy_unavailable'
  | 'legal_hold'
  | 'scope_widening_forbidden'
  | 'task_retry_exhausted';

export interface PrivacyFailure {
  readonly ok: false;
  readonly code: PrivacyFailureCode;
}
