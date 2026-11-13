import type { EntityId } from '../../../shared/ids.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';

export interface IdentityAuthorityChanged {
  readonly eventType: 'IdentityAuthorityChanged';
  readonly userId: EntityId;
  readonly pageId?: EntityId;
  readonly authorityRevision: number;
  readonly reason:
    | 'account_status_changed'
    | 'session_revoked'
    | 'creator_verification_changed'
    | 'membership_changed';
  readonly occurredAtUtc: UtcInstant;
}
