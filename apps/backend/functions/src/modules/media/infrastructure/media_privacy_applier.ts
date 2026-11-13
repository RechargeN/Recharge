import type { MediaDeletionService } from '../application/media_deletion_service.js';
import type { AttachmentReferencePort } from '../application/ports/attachment_reference_port.js';
import type { PrivacyApplier } from '../../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';

/**
 * L1 erasure (PB-00) of the subject's free Media through Media's own deletion
 * protocol: delivery is held, the owning domain is asked again, then source and
 * variant bytes are removed and the asset is `deleted` only once every removal
 * is confirmed. An asset that Content still references stays (PB-02); a settled
 * asset without an accepted retention policy cannot be held and stays (PB-14).
 * An unconfirmed byte removal is retried and never counted as erased.
 */
export function mediaPrivacyApplier(input: {
  readonly deletion: MediaDeletionService;
  readonly references: AttachmentReferencePort;
  /** Whether the composition carries an accepted (here: test-only) retention policy. */
  readonly retentionPolicyAvailable: boolean;
}): Record<string, PrivacyApplier> {
  return {
    mediaAssets: {
      async external(assetId, data) {
        const lifecycle = String(data.lifecycle);
        if (lifecycle === 'deleted') return 'unchanged';
        if (lifecycle === 'deleting') {
          const resumed = await input.deletion.completeDeletion(assetId);
          return resumed.state === 'completed' ? 'erased' : 'retry';
        }
        // Doubt counts as a reference, as everywhere in Media.
        if (await input.references.isReferenced(assetId).catch(() => true))
          return { blocked: 'PB-02' };
        if (
          !input.retentionPolicyAvailable &&
          lifecycle !== 'reserved' &&
          lifecycle !== 'uploading'
        )
          return { blocked: 'PB-14' };
        const status = await input.deletion.deleteForCleanup(assetId, 'owner_request');
        if (status === null) return 'retry';
        return status.state === 'completed' ? 'erased' : 'retry';
      },
    },
  };
}
