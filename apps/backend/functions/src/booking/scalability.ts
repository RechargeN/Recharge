export const bookingPeakProfiles = Object.freeze({
  normal: Object.freeze({ sustainedRps: 5, burstRequests: 20 }),
  popular: Object.freeze({ sustainedRps: 25, burstRequests: 100 }),
  mass: Object.freeze({ sustainedRps: 100, burstRequests: 500 }),
});

export const bookingSingleLedgerTransitionThreshold = Object.freeze({
  sustainedRps: 25,
  burstRequests: 100,
  maximumP95LatencyMs: 1_500,
  minimumSuccessRatio: 0.999,
});

export type BookingLoadEvidenceSource = 'local_emulator' | 'dev_cloud' | 'stage_cloud';

export interface BookingLoadEvidence {
  readonly source: BookingLoadEvidenceSource;
  readonly sustainedRps: number;
  readonly burstRequests: number;
  readonly observedP95LatencyMs: number;
  readonly successRatio: number;
  readonly oversellCount: number;
}

export type BookingScalabilityDecision =
  | 'single_ledger_eligible_for_small_dev'
  | 'sharded_escrow_required'
  | 'production_evidence_required';

export function assessBookingScalability(
  evidence: BookingLoadEvidence,
): BookingScalabilityDecision {
  validateEvidence(evidence);
  if (
    evidence.oversellCount > 0 ||
    evidence.sustainedRps >= bookingSingleLedgerTransitionThreshold.sustainedRps ||
    evidence.burstRequests >= bookingSingleLedgerTransitionThreshold.burstRequests ||
    evidence.observedP95LatencyMs > bookingSingleLedgerTransitionThreshold.maximumP95LatencyMs ||
    evidence.successRatio < bookingSingleLedgerTransitionThreshold.minimumSuccessRatio
  ) {
    return 'sharded_escrow_required';
  }
  return evidence.source === 'local_emulator'
    ? 'single_ledger_eligible_for_small_dev'
    : 'production_evidence_required';
}

function validateEvidence(evidence: BookingLoadEvidence): void {
  if (
    !Number.isFinite(evidence.sustainedRps) ||
    evidence.sustainedRps < 0 ||
    !Number.isSafeInteger(evidence.burstRequests) ||
    evidence.burstRequests < 0 ||
    !Number.isFinite(evidence.observedP95LatencyMs) ||
    evidence.observedP95LatencyMs < 0 ||
    !Number.isFinite(evidence.successRatio) ||
    evidence.successRatio < 0 ||
    evidence.successRatio > 1 ||
    !Number.isSafeInteger(evidence.oversellCount) ||
    evidence.oversellCount < 0
  ) {
    throw new TypeError('booking_load_evidence_invalid');
  }
}
