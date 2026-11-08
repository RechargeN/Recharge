/**
 * ADR 0023, owner decision 2026-11-08: before the first payout the payment
 * provider's KYC/KYB must be complete and the payout account confirmed.
 * Recharge makes no payouts yet; every payout path must ask this port first.
 */
export type PayoutReadiness =
  | { readonly ready: true; readonly providerAccountRef: string }
  | {
      readonly ready: false;
      readonly reason: 'payment_provider_not_connected' | 'kyc_incomplete' | 'account_unconfirmed';
    };

export interface PayoutReadinessPort {
  readinessFor(userId: string): Promise<PayoutReadiness>;
}
