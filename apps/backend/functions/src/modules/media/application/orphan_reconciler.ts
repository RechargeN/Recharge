import type {
  MediaCommandV1,
  OrphanReconciliationV1,
  ProcessingReceiptV1,
} from '../../../contracts/media_v1.js';
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
import { advance, releaseDeletionHold, withOrphanSince } from '../domain/media_asset.js';
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
      // Asked before any transaction is held. An unreachable owning domain leaves
      // every settled asset untouched; attempt and upload recovery never need it.
      const answer = await this.deps.references
        .isReferenced(assetId)
        .then((value): boolean | 'unknown' => value)
        .catch((): 'unknown' => 'unknown');
      const nowUtc = parseUtcInstant(this.deps.clock.now().toISOString());
      const decision = await this.deps.repository.transact(async (tx) => {
        const asset = await tx.asset(assetId);
        if (asset === null) throw new MediaDomainRefusal('not_found');
        const session = await tx.sessionForAsset(assetId);
        const receipts = await tx.receiptsForAsset(assetId);
        const lastAttempt = receipts[receipts.length - 1]?.attemptNumber ?? 0;
        const choice = decideOrphan({
          asset,
          session,
          referenced: answer,
          attemptInFlight: asset.attemptCount > lastAttempt,
          policy,
          nowUtc,
        });
        if (choice.action === 'mark' || choice.action === 'unmark') {
          const next = withOrphanSince(asset, choice.action === 'mark' ? nowUtc : null, nowUtc);
          if (next !== asset) tx.putAsset(next, asset.revision);
          return { choice, revision: next.revision };
        }
        if (choice.action === 'release_hold') {
          // A deletion hold nobody came back for: only that hold is released.
          const released = releaseDeletionHold(asset, nowUtc);
          if (released !== asset) {
            tx.putAsset(released, asset.revision);
            if (
              asset.deliveryDisabled &&
              !released.deliveryDisabled &&
              released.lifecycle === 'ready'
            )
              tx.effects.append({
                schemaVersion: 1,
                effectId: `${released.assetId}:MediaDeliveryRestored:${String(released.revision)}`,
                type: 'MediaDeliveryRestored',
                assetId: released.assetId,
                assetRevision: released.revision,
                occurredAtUtc: nowUtc,
              });
          }
          return { choice, revision: released.revision };
        }
        if (choice.action === 'abandon_attempt') {
          const source = asset.sourceGenerationRef;
          if (source === undefined)
            return { choice: { action: 'keep' as const }, revision: asset.revision };
          // The attempt is closed as quarantined with an honest receipt. The asset
          // revision moves, so a result that arrives late is refused as stale; the
          // owner continues with `retryProcessing` on the same source generation.
          const recovered = advance(asset, ['quarantined'], nowUtc);
          tx.putReceipt(
            deepFreeze<ProcessingReceiptV1>({
              schemaVersion: 1,
              assetId: asset.assetId,
              attemptNumber: asset.attemptCount,
              sourceProviderGeneration: source.providerGeneration,
              sourceSha256: source.sha256,
              policyRevision: asset.policyRevision,
              scan: { toolRevision: 'attempt-abandoned', result: 'inconclusive' },
              outcome: 'quarantined',
              startedAtUtc: asset.updatedAtUtc,
              completedAtUtc: nowUtc,
            }),
          );
          tx.putAsset(recovered, asset.revision);
          return { choice, revision: recovered.revision };
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
        case 'abandon_attempt':
        case 'release_hold':
          action = 'recovered';
          break;
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
