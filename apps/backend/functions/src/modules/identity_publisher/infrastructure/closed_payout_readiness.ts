import type {
  PayoutReadiness,
  PayoutReadinessPort,
} from '../application/ports/payout_readiness_port.js';

/** No payment provider is connected: nobody is ever ready for a payout. */
export class ClosedPayoutReadiness implements PayoutReadinessPort {
  readinessFor(): Promise<PayoutReadiness> {
    return Promise.resolve({ ready: false, reason: 'payment_provider_not_connected' });
  }
}
