import type { MarketId } from '../modules/reference_data/domain/identifiers.js';

export interface AgePolicyRequest {
  readonly marketId: MarketId;
  readonly surfaceId: string;
  readonly purposeId: string;
}

export type AgePolicyDecision =
  | { readonly eligible: true; readonly policyRevision: string }
  | {
      readonly eligible: false;
      readonly reason: 'policy_unavailable' | 'ineligible' | 'evidence_missing';
    };

export interface AgePolicyPort {
  evaluate(request: AgePolicyRequest): Promise<AgePolicyDecision>;
}

export class LocalUnavailableAgePolicyPort implements AgePolicyPort {
  evaluate(request: AgePolicyRequest): Promise<AgePolicyDecision> {
    void request;
    return Promise.resolve({ eligible: false, reason: 'policy_unavailable' });
  }
}

export function rejectClientDeclaredAge(value: unknown): void {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return;
  const forbidden = /^(?:age|birthdate|dateofbirth|ageverified|guardianconsent)$/iu;
  for (const [key, child] of Object.entries(value)) {
    if (forbidden.test(key)) throw new TypeError('client_declared_age_authority_forbidden');
    rejectClientDeclaredAge(child);
  }
}
