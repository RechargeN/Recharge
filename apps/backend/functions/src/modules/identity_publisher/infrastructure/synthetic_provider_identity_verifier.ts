import type {
  ProviderIdentityProof,
  ProviderIdentityVerifier,
} from '../application/ports/provider_identity_verifier.js';
import type { TrustedProviderAssertion } from '../domain/auth_identity.js';

export class SyntheticProviderIdentityVerifier implements ProviderIdentityVerifier {
  verify(proof: ProviderIdentityProof, nowUtc: string): Promise<TrustedProviderAssertion | null> {
    if (proof.provider !== 'google' && proof.provider !== 'apple') return Promise.resolve(null);
    const prefix = `local-test:${proof.provider}:`;
    if (!proof.proof.startsWith(prefix)) return Promise.resolve(null);
    const providerSubject = proof.proof.slice(prefix.length);
    if (providerSubject.length < 1 || providerSubject.length > 128) return Promise.resolve(null);
    return Promise.resolve({
      provider: proof.provider,
      providerTenant: proof.providerTenant,
      providerSubject,
      verifiedAtUtc: nowUtc,
    });
  }
}
