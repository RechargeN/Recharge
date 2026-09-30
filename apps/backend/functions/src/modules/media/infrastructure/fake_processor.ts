import type { MediaVariantRefV1 } from '../../../contracts/media_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import type {
  ProcessOutcome,
  ProcessorPort,
  ProcessRequest,
} from '../application/ports/processor_port.js';

/**
 * FAKE processor. By default it emits one deterministic variant per mandatory
 * profile; tests script failures or malformed output. It proves orchestration
 * only: no real transformation, EXIF handling or limit is exercised.
 */
export class FakeProcessor implements ProcessorPort {
  readonly requests: ProcessRequest[] = [];
  readonly script: (
    'succeeded' | 'failed' | 'rejected' | 'throw' | ((request: ProcessRequest) => ProcessOutcome)
  )[] = [];
  onProcess: (() => Promise<void>) | undefined;
  #counter = 0;

  async process(request: ProcessRequest): Promise<ProcessOutcome> {
    this.requests.push(request);
    await this.onProcess?.();
    const next = this.script.shift() ?? 'succeeded';
    if (next === 'throw') throw new Error('fake processor failure');
    if (typeof next === 'function') return next(request);
    if (next !== 'succeeded') return { toolRevision: 'fake-proc-1', result: next };
    return {
      toolRevision: 'fake-proc-1',
      result: 'succeeded',
      variants: request.mandatoryVariantProfiles.map((profile) => this.variant(request, profile)),
    };
  }

  private variant(request: ProcessRequest, profile: string): MediaVariantRefV1 {
    this.#counter += 1;
    const serial = String(this.#counter).padStart(24, '0');
    return {
      variantId: `01${serial}` as EntityId,
      profile,
      format: 'image/webp',
      providerGeneration: `variant-generation-${this.#counter}`,
      sha256: this.#counter.toString(16).padStart(64, '0'),
      byteLength: 100 + this.#counter,
      transformProfileRevision: 'fake-tp-1',
      sourceProviderGeneration: request.sourceProviderGeneration,
    };
  }
}
