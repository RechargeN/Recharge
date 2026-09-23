export type ReferenceDataFailureCode =
  | 'unsupported_schema'
  | 'invalid_contract'
  | 'market_disabled'
  | 'capability_disabled'
  | 'unsupported_locale'
  | 'translation_missing'
  | 'fallback_forbidden'
  | 'mandatory_copy_missing'
  | 'mandatory_copy_not_approved'
  | 'source_not_eligible'
  | 'revision_not_found'
  | 'revision_conflict'
  | 'incompatible_rollback';

export interface ReferenceDataFailure {
  readonly ok: false;
  readonly code: ReferenceDataFailureCode;
  readonly detail?: string;
}

export function referenceDataFailure(
  code: ReferenceDataFailureCode,
  detail?: string,
): ReferenceDataFailure {
  return detail === undefined ? { ok: false, code } : { ok: false, code, detail };
}
