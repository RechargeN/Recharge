export type PrivacyRequestTypeV1 =
  'access' | 'erasure' | 'restriction' | 'rectification' | 'objection';
export type PrivacyRequestStatusV1 =
  | 'submitted'
  | 'verified'
  | 'dispatched'
  | 'partially_completed'
  | 'completed'
  | 'failed'
  | 'cancelled';

export interface PrivacyRequestV1Contract {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly subjectId: string;
  readonly requestType: PrivacyRequestTypeV1;
  readonly status: PrivacyRequestStatusV1;
  readonly revision: number;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly requiredDomainIds: readonly string[];
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly terminalEvidenceIds: readonly string[];
}

export interface PrivacyRequestStatusV1Contract {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly status: PrivacyRequestStatusV1;
  readonly revision: number;
  readonly requiredTaskCount: number;
  readonly completedTaskCount: number;
  readonly failedTaskCount: number;
  readonly updatedAtUtc: string;
}

export interface PrivacyDomainTaskV1Contract {
  readonly schemaVersion: 1;
  readonly taskId: string;
  readonly requestId: string;
  readonly subjectId: string;
  readonly domainId: string;
  readonly marketId: 'LV' | 'EE' | 'LT' | null;
  readonly targetRevision: number;
  readonly status: 'pending' | 'dispatched' | 'succeeded' | 'failed' | 'cancelled';
  readonly revision: number;
  readonly attempts: number;
  readonly evidenceId: string | null;
  readonly updatedAtUtc: string;
}
