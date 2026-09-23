import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import type { ProviderIdentityVerifier } from './ports/provider_identity_verifier.js';
import type { VerificationDecisionPort } from './ports/verification_decision_port.js';
import type { PageCreationPolicyPort } from './ports/page_creation_policy_port.js';
import { AccountLinkingService } from './account_linking_service.js';
import { AccountSecurityService } from './account_security_service.js';
import { AccessSnapshotService } from './access_snapshot_service.js';
import { CreatorVerificationService } from './creator_verification_service.js';
import { ManagedPageService } from './managed_page_service.js';
import { PublisherEligibilityService } from './publisher_eligibility_service.js';
import { SessionAuthorityService } from './session_authority_service.js';
import { InMemoryIdentityAuthorityRepository } from '../infrastructure/in_memory_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../infrastructure/synthetic_provider_identity_verifier.js';

export class IdentityPublisherAuthority {
  readonly accounts: AccountLinkingService;
  readonly sessions: SessionAuthorityService;
  readonly accountSecurity: AccountSecurityService;
  readonly creatorVerification: CreatorVerificationService;
  readonly pages: ManagedPageService;
  readonly access: AccessSnapshotService;
  readonly publishers: PublisherEligibilityService;

  constructor(input: {
    readonly repository: IdentityAuthorityRepository;
    readonly providerVerifier: ProviderIdentityVerifier;
    readonly verificationDecisions: VerificationDecisionPort;
    readonly pagePolicy: PageCreationPolicyPort;
  }) {
    this.accounts = new AccountLinkingService(input.repository, input.providerVerifier);
    this.sessions = new SessionAuthorityService(input.repository);
    this.accountSecurity = new AccountSecurityService(input.repository);
    this.creatorVerification = new CreatorVerificationService(
      input.repository,
      input.verificationDecisions,
    );
    this.pages = new ManagedPageService(
      input.repository,
      input.pagePolicy,
      input.verificationDecisions,
    );
    this.access = new AccessSnapshotService(input.repository);
    this.publishers = new PublisherEligibilityService(input.repository);
    Object.freeze(this);
  }
}

export function createLocalIdentityPublisherAuthority(options?: {
  readonly reviewerIds?: ReadonlySet<string>;
  readonly pageCreationEnabled?: boolean;
  readonly maximumOwnedPages?: number;
}): {
  readonly authority: IdentityPublisherAuthority;
  readonly repository: InMemoryIdentityAuthorityRepository;
} {
  const repository = new InMemoryIdentityAuthorityRepository();
  return Object.freeze({
    repository,
    authority: new IdentityPublisherAuthority({
      repository,
      providerVerifier: new SyntheticProviderIdentityVerifier(),
      verificationDecisions: new LocalVerificationDecisionAdapter(
        options?.reviewerIds ?? new Set(),
      ),
      pagePolicy: new LocalPageCreationPolicy(
        options?.pageCreationEnabled ?? false,
        options?.maximumOwnedPages ?? 0,
      ),
    }),
  });
}
