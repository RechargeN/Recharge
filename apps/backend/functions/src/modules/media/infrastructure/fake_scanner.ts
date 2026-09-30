import type { ScanOutcome, ScannerPort, ScanRequest } from '../application/ports/scanner_port.js';

/**
 * FAKE scanner with scripted outcomes. It proves how the service reacts to a
 * result, not that any real malware, decompression bomb or unsafe content is
 * detected; real scanner evidence is verified separately before dev acceptance.
 */
export class FakeScanner implements ScannerPort {
  readonly requests: ScanRequest[] = [];
  /** Scripted results consumed in order; `clean` when empty. */
  readonly script: (ScanOutcome['result'] | 'throw')[] = [];
  /** Runs while the scan is "in flight", e.g. to mutate state concurrently. */
  onScan: (() => Promise<void>) | undefined;

  async scan(request: ScanRequest): Promise<ScanOutcome> {
    this.requests.push(request);
    await this.onScan?.();
    const next = this.script.shift() ?? 'clean';
    if (next === 'throw') throw new Error('fake scanner failure');
    return { toolRevision: 'fake-scan-1', result: next };
  }
}
