import type { MediaFamily } from '../../../contracts/media_v1.js';
import { MediaDomainRefusal } from './failures.js';

/**
 * Accepted Media policy for one family. No value here is invented by the
 * platform: an accepted policy is supplied by configuration, tests supply a
 * synthetic one explicitly labelled test-only (BCK-14 v0.4 §34.5).
 */
export interface MediaFamilyPolicy {
  readonly allowedMediaTypes: readonly string[];
  readonly maxBytes: number;
  readonly sessionTtlSeconds: number;
  readonly maxProcessingAttempts: number;
  /** Variant profiles that must all be verified before an asset is `ready`. */
  readonly mandatoryVariantProfiles: readonly string[];
  readonly validationProfileRevision: string;
}

export interface MediaPolicy {
  readonly revision: string;
  readonly families: Readonly<Partial<Record<MediaFamily, MediaFamilyPolicy>>>;
}

/**
 * Resolves the accepted policy of a family. A missing policy is
 * `policy_unavailable`; a family the policy does not list is
 * `family_unavailable`. Both fail closed.
 */
export function resolveFamilyPolicy(
  policy: MediaPolicy | undefined,
  family: MediaFamily,
): MediaFamilyPolicy {
  if (policy === undefined) throw new MediaDomainRefusal('policy_unavailable');
  const familyPolicy = policy.families[family];
  if (familyPolicy === undefined) throw new MediaDomainRefusal('family_unavailable');
  return familyPolicy;
}
