import type { MediaDeletionService } from '../../media/application/media_deletion_service.js';
import type { MediaRepository } from '../../media/domain/repositories.js';
import type {
  EnforcementOutcome,
  MediaAssetView,
  MediaModerationPort,
} from '../application/ports.js';

/**
 * Moderation's window onto Media (D2 §7). The read gives ids and revision only;
 * the only write is Media's own `applyRestriction`, which verifies the recorded
 * decision again through `MediaRestrictionVerifier` before it changes anything.
 */
export class MediaModerationAdapter implements MediaModerationPort {
  constructor(
    private readonly repository: MediaRepository,
    private readonly deletion: MediaDeletionService,
  ) {}

  async asset(assetId: string): Promise<MediaAssetView | null> {
    const asset = await this.repository.transact((tx) => tx.asset(assetId));
    if (asset === null) return null;
    const binding = asset.entityBinding;
    return {
      assetId: asset.assetId,
      contentId: binding?.domain === 'content' ? binding.entityId : null,
      assetRevision: asset.revision,
    };
  }

  async enforce(instruction: {
    readonly decisionId: string;
    readonly assetId: string;
    readonly restricted: boolean;
  }): Promise<EnforcementOutcome> {
    const result = await this.deletion.applyRestriction({
      schemaVersion: 1,
      commandType: 'applyRestriction',
      idempotencyKey:
        `${instruction.decisionId}:${instruction.restricted ? 'restrict' : 'restore'}`.slice(
          0,
          128,
        ),
      payload: {
        assetId: instruction.assetId,
        decisionRef: instruction.decisionId,
        restricted: instruction.restricted,
      },
    });
    if (result.kind === 'succeeded')
      return { kind: 'applied', outcome: 'applied', pointerRevision: null };
    return { kind: 'refused', code: result.code };
  }
}
