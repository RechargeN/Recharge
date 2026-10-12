import type { ContentTypeId } from '../../../contracts/content_v1.js';

/**
 * D3.3 §2 Q4: activation the Emulator authoring composition does not offer.
 * A Rental revision verified at publication is not proof that it may be shown
 * again today: the accepted validator depends on the current policy, its
 * version and the freshness of the confirmed availability, and activation does
 * not re-run it. Until the owner accepts a semantics (re-validation, or
 * `unknown` availability), re-activating a Rental revision is refused.
 */
export const emulatorActivationClosedTypes: ReadonlySet<ContentTypeId> = new Set<ContentTypeId>([
  'rental',
]);
