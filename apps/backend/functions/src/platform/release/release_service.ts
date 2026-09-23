import type { ReleaseManifest } from '../../config/release_manifest.js';
import {
  releaseScopeKey,
  type ReleaseManifestRepository,
  type ReleasePointerSwapResult,
} from './release_manifest_repository.js';

export class ReleaseService {
  constructor(private readonly repository: ReleaseManifestRepository) {}

  async publish(manifest: ReleaseManifest): Promise<void> {
    if (manifest.status !== 'disabled') throw new TypeError('r1_release_must_be_disabled');
    await this.repository.publish(manifest);
  }

  async activate(
    manifest: ReleaseManifest,
    expectedPointerRevision: number,
  ): Promise<ReleasePointerSwapResult> {
    if (manifest.status !== 'disabled') throw new TypeError('r1_release_must_be_disabled');
    return this.repository.swapActivePointer(
      releaseScopeKey(manifest.environmentId, manifest.marketId, manifest.capabilityId),
      manifest.manifestId,
      expectedPointerRevision,
    );
  }
}
