import type { MediaEffectV1 } from '../../../../contracts/media_v1.js';

/**
 * Effects become visible only if the surrounding transaction commits. They carry
 * ids and monotonic asset revisions, never bytes, URLs or object keys.
 */
export interface MediaEffectSink {
  append(effect: MediaEffectV1): void;
}
