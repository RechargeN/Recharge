import type {
  CreatorVerificationStatus,
  CreatorVerificationV1,
} from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { IdentityFailure } from './failures.js';

export type CreatorVerification = CreatorVerificationV1;

export function submitCreatorVerification(input: {
  readonly verificationId: string;
  readonly userId: string;
  readonly evidenceRefIds: readonly string[];
  readonly submittedAtUtc: string;
}): CreatorVerification {
  if (input.evidenceRefIds.length < 1 || input.evidenceRefIds.length > 16)
    throw new IdentityFailure('invalid_transition');
  return deepFreeze({
    schemaVersion: 1,
    verificationId: parseEntityId(input.verificationId),
    userId: parseEntityId(input.userId),
    status: 'pendingReview',
    revision: 1,
    submittedAtUtc: parseUtcInstant(input.submittedAtUtc),
    evidenceRefIds: [...new Set(input.evidenceRefIds.map(parseEntityId))],
  });
}

export function decideCreatorVerification(
  verification: CreatorVerification,
  status: Exclude<CreatorVerificationStatus, 'pendingReview'>,
  decidedAtUtc: string,
): CreatorVerification {
  const allowed =
    verification.status === 'pendingReview'
      ? new Set<CreatorVerificationStatus>(['verified', 'rejected', 'revoked'])
      : verification.status === 'verified'
        ? new Set<CreatorVerificationStatus>(['suspended', 'revoked'])
        : verification.status === 'suspended'
          ? new Set<CreatorVerificationStatus>(['verified', 'revoked'])
          : new Set<CreatorVerificationStatus>();
  if (!allowed.has(status)) throw new IdentityFailure('invalid_transition');
  return deepFreeze({
    ...verification,
    status,
    revision: verification.revision + 1,
    decidedAtUtc: parseUtcInstant(decidedAtUtc),
  });
}
