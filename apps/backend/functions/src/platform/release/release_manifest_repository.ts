import type { EnvironmentId } from '../../config/environment.js';
import type { MarketId } from '../../config/market_capability.js';
import type { ReleaseManifest } from '../../config/release_manifest.js';
import { deepFreeze, type DeepReadonly } from '../../shared/immutable.js';

export const releaseManifestCollection = 'platformReleaseManifests';
export const activeReleasePointerCollection = 'platformActiveReleasePointers';

export interface ActiveReleasePointer {
  readonly key: string;
  readonly activeManifestId: string;
  readonly pointerRevision: number;
}

export type ReleasePointerSwapResult =
  | { readonly swapped: true; readonly pointer: DeepReadonly<ActiveReleasePointer> }
  | { readonly swapped: false; readonly reason: 'manifest_not_found' | 'revision_conflict' };

export interface ReleaseManifestRepository {
  publish(manifest: ReleaseManifest): Promise<void>;
  getById(manifestId: string): Promise<DeepReadonly<ReleaseManifest> | null>;
  getActivePointer(key: string): Promise<DeepReadonly<ActiveReleasePointer> | null>;
  swapActivePointer(
    key: string,
    manifestId: string,
    expectedPointerRevision: number,
  ): Promise<ReleasePointerSwapResult>;
}

export class InMemoryReleaseManifestRepository implements ReleaseManifestRepository {
  readonly #manifests = new Map<string, DeepReadonly<ReleaseManifest>>();
  readonly #pointers = new Map<string, DeepReadonly<ActiveReleasePointer>>();

  publish(manifest: ReleaseManifest): Promise<void> {
    if (manifest.status !== 'disabled') throw new TypeError('r1_release_must_be_disabled');
    const existing = this.#manifests.get(manifest.manifestId);
    const frozen = deepFreeze({ ...manifest, approvedBy: [...manifest.approvedBy] });
    if (existing !== undefined && JSON.stringify(existing) !== JSON.stringify(frozen)) {
      throw new TypeError('immutable_release_manifest_conflict');
    }
    this.#manifests.set(manifest.manifestId, existing ?? frozen);
    return Promise.resolve();
  }

  getById(manifestId: string): Promise<DeepReadonly<ReleaseManifest> | null> {
    return Promise.resolve(this.#manifests.get(manifestId) ?? null);
  }

  getActivePointer(key: string): Promise<DeepReadonly<ActiveReleasePointer> | null> {
    return Promise.resolve(this.#pointers.get(key) ?? null);
  }

  swapActivePointer(
    key: string,
    manifestId: string,
    expectedPointerRevision: number,
  ): Promise<ReleasePointerSwapResult> {
    assertPointerRevision(expectedPointerRevision);
    const manifest = this.#manifests.get(manifestId);
    if (
      manifest === undefined ||
      releaseScopeKey(manifest.environmentId, manifest.marketId, manifest.capabilityId) !== key
    ) {
      return Promise.resolve({ swapped: false, reason: 'manifest_not_found' });
    }
    const current = this.#pointers.get(key);
    if ((current?.pointerRevision ?? 0) !== expectedPointerRevision) {
      return Promise.resolve({ swapped: false, reason: 'revision_conflict' });
    }
    const pointer = deepFreeze({
      key,
      activeManifestId: manifestId,
      pointerRevision: expectedPointerRevision + 1,
    });
    this.#pointers.set(key, pointer);
    return Promise.resolve({ swapped: true, pointer });
  }
}

function assertPointerRevision(value: number): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new TypeError('pointer_revision_invalid');
}

export function releaseScopeKey(
  environmentId: EnvironmentId,
  marketId: MarketId,
  capabilityId: string,
): string {
  return `${environmentId}:${marketId}:${capabilityId}`;
}
