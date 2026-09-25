import type { PageMembership } from '../../domain/page_membership.js';

export interface PageCapabilityGrantPolicyPort {
  mayGrant(input: {
    readonly actor: PageMembership;
    readonly target: PageMembership;
    readonly requestedCapabilityIds: readonly string[];
  }): Promise<boolean>;
}
