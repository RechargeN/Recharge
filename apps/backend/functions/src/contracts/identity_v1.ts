import type { EntityId } from '../shared/ids.js';
import type { UtcInstant } from '../shared/utc_instant.js';
import type { MarketId } from '../modules/reference_data/domain/identifiers.js';

export type IdentityProvider = 'google' | 'apple';
export type AccountStatus = 'active' | 'restricted' | 'blocked' | 'deleted';
export type IdentitySessionStatus =
  'active' | 'stepUpRequired' | 'revoked' | 'expired' | 'compromised';
export type CreatorVerificationStatus =
  'pendingReview' | 'verified' | 'rejected' | 'suspended' | 'revoked';

export interface AccountV1 {
  readonly schemaVersion: 1;
  readonly userId: EntityId;
  readonly status: AccountStatus;
  readonly systemRoles: readonly ('User' | 'Creator' | 'Admin')[];
  readonly revision: number;
  readonly securityRevision: number;
  readonly revokeBeforeSecurityRevision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

export interface AuthIdentityV1 {
  readonly schemaVersion: 1;
  readonly identityId: EntityId;
  readonly userId: EntityId;
  readonly provider: IdentityProvider;
  readonly providerTenant: string;
  readonly subjectHash: string;
  readonly status: 'active' | 'disabled';
  readonly revision: number;
  readonly linkedAtUtc: UtcInstant;
}

export interface IdentitySessionV1 {
  readonly schemaVersion: 1;
  readonly sessionId: EntityId;
  readonly userId: EntityId;
  readonly status: IdentitySessionStatus;
  readonly revision: number;
  readonly authzRevision: number;
  readonly firebaseUid: string;
  readonly installationId: string;
  readonly handleHash: string;
  readonly issuedAtUtc: UtcInstant;
  readonly lastActiveAtUtc: UtcInstant;
  readonly revokedAtUtc?: UtcInstant;
}

export interface PublisherRefV1 {
  readonly type: 'user' | 'page';
  readonly id: EntityId;
}

export interface AccessSnapshotV1 {
  readonly schemaVersion: 1;
  readonly userId: EntityId;
  readonly sessionId: EntityId;
  readonly pageId?: EntityId;
  readonly accountRevision: number;
  readonly sessionRevision: number;
  readonly authzRevision: number;
  readonly membershipRevision?: number;
  readonly capabilityPolicyRevision: number;
  readonly capabilityIds: readonly string[];
  readonly evaluatedAtUtc: UtcInstant;
  readonly expiresAtUtc: UtcInstant;
}

export interface CreatorVerificationV1 {
  readonly schemaVersion: 1;
  readonly verificationId: EntityId;
  readonly userId: EntityId;
  readonly status: CreatorVerificationStatus;
  readonly revision: number;
  readonly submittedAtUtc: UtcInstant;
  readonly decidedAtUtc?: UtcInstant;
  readonly evidenceRefIds: readonly EntityId[];
}

export interface ManagedPageV1 {
  readonly schemaVersion: 1;
  readonly pageId: EntityId;
  readonly ownerUserId: EntityId;
  readonly marketId: MarketId;
  readonly status: 'pendingReview' | 'active' | 'restricted' | 'archived';
  readonly verificationStatus:
    'unverified' | 'pendingReview' | 'verified' | 'rejected' | 'suspended' | 'revoked';
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

export interface PageMembershipV1 {
  readonly schemaVersion: 1;
  readonly membershipId: EntityId;
  readonly pageId: EntityId;
  readonly userId: EntityId;
  readonly role: 'owner' | 'manager' | 'analyst' | 'bookingManager';
  readonly status: 'active' | 'revoked';
  readonly capabilityIds: readonly string[];
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

export interface PublisherEligibilityV1 {
  readonly schemaVersion: 1;
  readonly publisherRef: PublisherRefV1;
  readonly eligible: boolean;
  readonly reason:
    | 'eligible'
    | 'account_inactive'
    | 'creator_verification_required'
    | 'creator_verification_unavailable'
    | 'membership_inactive'
    | 'capability_denied'
    | 'publisher_not_accessible'
    | 'snapshot_stale';
  readonly authorityRevision: number;
  readonly evaluatedAtUtc: UtcInstant;
}
