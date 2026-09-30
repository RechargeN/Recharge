import type { MediaCommandV1, OrphanReconciliationV1 } from '../../../contracts/media_v1.js';
import { validateMediaContract } from '../../../contracts/validate_media_contract.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import {
  MediaDomainRefusal,
  MediaRepositoryConflict,
  rejected,
  succeeded,
  unsupported,
  type MediaResult,
} from '../domain/failures.js';
import { withOrphanSince } from '../domain/media_asset.js';
import {
  decideOrphan,
  requireRetentionPolicy,
  type MediaRetentionPolicy,
} from '../domain/media_retention.js';
import type { MediaRepository } from '../domain/repositories.js';
import type { MediaDeletionService } from './media_deletion_service.js';
import type { AttachmentReferencePort } from './ports/attachment_reference_port.js';

export interface OrphanReconcilerDeps {
  readonly repository: MediaRepository;
  readonly references: AttachmentReferencePort;
  readonly deletion: MediaDeletionService;
  readonly clock: ServerClock;
  /** Accepted retention policy from configuration; `undefined` fails closed. */
  readonly retention?: MediaRetentionPolicy;
}

/**
 * Cleanup worker logic (BCK-14 `media.reconcileOrphan`): keep, mark, unmark or
 * delete an asset by retention policy and the owning domain's reference answer.
 * It is a system path, never reachable from a client command, and the decision
 * is stable on repeat so it needs no idempotency record of its own.
 */
export class OrphanReconciler {
  constructor(private readonly deps: OrphanReconcilerDeps) {}

  async reconcile(rawCommand: unknown): Promise<MediaResult<DeepReadonly<OrphanReconciliationV1>>> {
    if (typeof rawCommand !== 'object' || rawCommand === null || Array.isArray(rawCommand))
      return rejected('invalid_contract');
    const record = rawCommand as Record<string, unknown>;
    if (typeof record.schemaVersion === 'number' && record.schemaVersion !== 1)
      return unsupported();
    const parsed = await validateMediaContract<MediaCommandV1>('command', rawCommand);
    if (!parsed.ok || parsed.value.commandType !== 'reconcileOrphan')
      return rejected('invalid_contract');
    const { assetId } = parsed.value.payload;
    try {
      const policy = requireRetentionPolicy(this.deps.retention);
      const answer = await this.deps.references
        .isReferenced(assetId)
        .then((value) => ({ known: true as const, value }))
        .catch(() => ({ known: false as const }));
      if (!answer.known) {
        // The owning domain is unreachable: nothing changes, not even the grace clock.
        const current = await this.deps.repository.transact((tx) => tx.asset(assetId));
        if (current === null) throw new MediaDomainRefusal('not_found');
        return succeeded(
          deepFreeze({
            schemaVersion: 1,
            assetId,
            action: 'keep',
            assetRevision: current.revision,
          }),
        );
      }
      const referenced = answer.value;
      const nowUtc = parseUtcInstant(this.deps.clock.now().toISOString());
      const decision = await this.deps.repository.transact(async (tx) => {
        const asset = await tx.asset(assetId);
        if (asset === null) throw new MediaDomainRefusal('not_found');
        const session = await tx.sessionForAsset(assetId);
        const choice = decideOrphan({ asset, session, referenced, policy, nowUtc });
        if (choice.action === 'mark' || choice.action === 'unmark') {
          const next = withOrphanSince(asset, choice.action === 'mark' ? nowUtc : null, nowUtc);
          if (next !== asset) tx.putAsset(next, asset.revision);
          return { choice, revision: next.revision };
        }
        return { choice, revision: asset.revision };
      });
      const { choice } = decision;
      let action: OrphanReconciliationV1['action'];
      switch (choice.action) {
        case 'keep':
          action = 'keep';
          break;
        case 'mark':
          action = 'marked';
          break;
        case 'unmark':
          action = 'unmarked';
          break;
        case 'delete': {
          const status = await this.deps.deletion.deleteForCleanup(assetId, choice.reason);
          action =
            status?.state === 'completed' ? 'deleted' : status === null ? 'keep' : 'deleting';
          break;
        }
        case 'resume_delete': {
          const status = await this.deps.deletion.completeDeletion(assetId);
          action = status.state === 'completed' ? 'deleted' : 'deleting';
          break;
        }
      }
      const revision = await this.deps.repository.transact(
        async (tx) => (await tx.asset(assetId))?.revision ?? decision.revision,
      );
      return succeeded(
        deepFreeze({
          schemaVersion: 1,
          assetId,
          action,
          assetRevision: revision,
        }),
      );
    } catch (error) {
      if (error instanceof MediaDomainRefusal) return rejected(error.code);
      if (error instanceof MediaRepositoryConflict) return rejected('revision_conflict');
      throw error;
    }
  }
}
