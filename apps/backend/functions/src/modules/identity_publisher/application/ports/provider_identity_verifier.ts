import type { IdentityProvider } from '../../../../contracts/identity_v1.js';
import type { TrustedProviderAssertion } from '../../domain/auth_identity.js';

export interface ProviderIdentityProof {
  readonly provider: IdentityProvider;
  readonly providerTenant: string;
  readonly proof: string;
}

export interface ProviderIdentityVerifier {
  verify(proof: ProviderIdentityProof, nowUtc: string): Promise<TrustedProviderAssertion | null>;
}
