import { createHash } from 'node:crypto';

import type { AuthIdentityV1, IdentityProvider } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';

export type AuthIdentity = AuthIdentityV1;

export interface TrustedProviderAssertion {
  readonly provider: IdentityProvider;
  readonly providerTenant: string;
  readonly providerSubject: string;
  readonly verifiedAtUtc: string;
}

export function providerSubjectKey(assertion: TrustedProviderAssertion): string {
  if (!/^[A-Za-z0-9._-]{1,64}$/u.test(assertion.providerTenant))
    throw new TypeError('provider_tenant_invalid');
  if (assertion.providerSubject.length < 1 || assertion.providerSubject.length > 512)
    throw new TypeError('provider_subject_invalid');
  return createHash('sha256')
    .update(`${assertion.provider}\0${assertion.providerTenant}\0${assertion.providerSubject}`)
    .digest('hex');
}

export function createAuthIdentity(input: {
  readonly identityId: string;
  readonly userId: string;
  readonly assertion: TrustedProviderAssertion;
  readonly linkedAtUtc: string;
}): AuthIdentity {
  return deepFreeze({
    schemaVersion: 1,
    identityId: parseEntityId(input.identityId),
    userId: parseEntityId(input.userId),
    provider: input.assertion.provider,
    providerTenant: input.assertion.providerTenant,
    subjectHash: providerSubjectKey(input.assertion),
    status: 'active',
    revision: 1,
    linkedAtUtc: parseUtcInstant(input.linkedAtUtc),
  });
}
