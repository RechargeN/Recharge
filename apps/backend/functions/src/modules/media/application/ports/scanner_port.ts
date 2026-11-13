export interface ScanRequest {
  readonly assetId: string;
  readonly objectKeyHandle: string;
  readonly providerGeneration: string;
  readonly sha256: string;
  readonly policyRevision: string;
}

export interface ScanOutcome {
  readonly toolRevision: string;
  readonly result: 'clean' | 'rejected' | 'inconclusive';
}

/**
 * Malware/type/safety scanning. A failure or timeout is reported by throwing or
 * `inconclusive`; both keep the asset quarantined. The adapter in this slice is
 * `fake_scanner`, which proves orchestration only, not detection.
 */
export interface ScannerPort {
  scan(request: ScanRequest): Promise<ScanOutcome>;
}
