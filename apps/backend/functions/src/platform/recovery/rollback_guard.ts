import { isReleaseCompatible, type ReleaseManifest } from '../../config/release_manifest.js';
import type { ReleaseManifestRepository } from '../release/release_manifest_repository.js';
import { releaseScopeKey } from '../release/release_manifest_repository.js';

export type RollbackResult =
  | {
      readonly rolledBack: true;
      readonly targetManifestId: string;
      readonly pointerRevision: number;
    }
  | {
      readonly rolledBack: false;
      readonly action: 'remain_disabled';
      readonly reason:
        | 'target_missing'
        | 'scope_or_contract_incompatible'
        | 'revision_conflict'
        | 'target_not_declared';
    };

export class RollbackGuard {
  constructor(private readonly repository: ReleaseManifestRepository) {}

  async rollback(
    current: ReleaseManifest,
    expectedPointerRevision: number,
  ): Promise<RollbackResult> {
    if (current.rollbackTargetManifestId === null) {
      return { rolledBack: false, action: 'remain_disabled', reason: 'target_not_declared' };
    }
    const target = await this.repository.getById(current.rollbackTargetManifestId);
    if (target === null) {
      return { rolledBack: false, action: 'remain_disabled', reason: 'target_missing' };
    }
    if (!isReleaseCompatible(current, target)) {
      return {
        rolledBack: false,
        action: 'remain_disabled',
        reason: 'scope_or_contract_incompatible',
      };
    }
    const result = await this.repository.swapActivePointer(
      releaseScopeKey(current.environmentId, current.marketId, current.capabilityId),
      target.manifestId,
      expectedPointerRevision,
    );
    if (!result.swapped) {
      return {
        rolledBack: false,
        action: 'remain_disabled',
        reason: result.reason === 'revision_conflict' ? 'revision_conflict' : 'target_missing',
      };
    }
    return {
      rolledBack: true,
      targetManifestId: result.pointer.activeManifestId,
      pointerRevision: result.pointer.pointerRevision,
    };
  }
}
