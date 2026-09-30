import type {
  ApplyRestrictionCommandV1,
  DeleteAssetCommandV1,
  DeletionReason,
  DetachAssetCommandV1,
  GetDeletionStatusQueryV1,
  MediaAssetV1,
  MediaCommandV1,
  MediaDeletionStatusV1,
  MediaEffectV1,
} from '../../../contracts/media_v1.js';
import { validateMediaContract } from '../../../contracts/validate_media_contract.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import {
  MediaDomainRefusal,
  MediaRepositoryConflict,
  rejected,
  succeeded,
  unsupported,
  type MediaResult,
} from '../domain/failures.js';
import {
  abortUpload,
  beginDeletion,
  canonicalJson,
  finishDeletion,
  sha256Hex,
  toAssetView,
  withOrphanSince,
  withRestriction,
  type MediaAsset,
} from '../domain/media_asset.js';
import type {
  MediaRepository,
  MediaTransaction,
  StoredDeletionStatus,
} from '../domain/repositories.js';
import { withSessionState } from '../domain/upload_session.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaRestrictionAuthority,
} from './ports/actor_authority_port.js';
import type { AttachmentReferencePort } from './ports/attachment_reference_port.js';
import type { ObjectStorePort } from './ports/object_store_port.js';

export interface MediaDeletionDeps {
  readonly repository: MediaRepository;
  readonly authority: MediaActorAuthorityPort;
  readonly restrictionAuthority: MediaRestrictionAuthority;
  readonly references: AttachmentReferencePort;
  readonly objectStore: ObjectStorePort;
  readonly clock: ServerClock;
  readonly ids: { newId(): EntityId };
}

export type MediaDeletionData = DeepReadonly<MediaDeletionStatusV1> | DeepReadonly<MediaAssetV1>;

const systemActor = 'system:media-restriction';

/**
 * Deletion, detach and restriction of Media assets (BCK-14 §33.3). Delivery is
 * tombstoned first; bytes and variants are removed afterwards and the asset is
 * `deleted` only once cleanup is confirmed. It shares Media's repository and is
 * driven only by `MediaService` and the orphan reconciler.
 */
export class MediaDeletionService {
  constructor(private readonly deps: MediaDeletionDeps) {}

  private now(): UtcInstant {
    return parseUtcInstant(this.deps.clock.now().toISOString());
  }

  /** Owner deletion: references are consulted and the asset must be settled. */
  async deleteAsset(
    actor: MediaActor,
    command: DeleteAssetCommandV1,
    semanticHash: string,
  ): Promise<MediaResult<MediaDeletionData>> {
    const nowUtc = this.now();
    const begun = await this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        return { replay: deepFreeze(structuredClone(prior.outcome)) as MediaDeletionData };
      }
      const asset = await tx.asset(command.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      await this.authorize(actor, asset, nowUtc);
      if (asset.revision !== command.payload.expectedAssetRevision)
        throw new MediaDomainRefusal('stale_revision');
      return { status: await this.begin(tx, asset, 'owner_request', nowUtc) };
    });
    if ('replay' in begun) return succeeded(begun.replay);
    const final = await this.completeDeletion(command.payload.assetId);
    await this.deps.repository.transact((tx) => {
      this.remember(tx, actor.userId, command, semanticHash, final, nowUtc);
    });
    return succeeded(final);
  }

  /**
   * Owner-domain-confirmed detach: the owning domain no longer references the
   * asset, so Media starts its orphan clock. A referenced asset is never detached.
   */
  async detachAsset(
    actor: MediaActor,
    command: DetachAssetCommandV1,
    semanticHash: string,
  ): Promise<MediaResult<MediaDeletionData>> {
    const nowUtc = this.now();
    return this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        return succeeded(deepFreeze(structuredClone(prior.outcome)) as MediaDeletionData);
      }
      const asset = await tx.asset(command.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      await this.authorize(actor, asset, nowUtc);
      if (asset.revision !== command.payload.expectedAssetRevision)
        throw new MediaDomainRefusal('stale_revision');
      if (asset.lifecycle === 'deleting' || asset.lifecycle === 'deleted')
        throw new MediaDomainRefusal('invalid_state');
      if (await this.referenced(asset.assetId)) throw new MediaDomainRefusal('asset_referenced');
      const next = withOrphanSince(asset, nowUtc, nowUtc);
      if (next !== asset) tx.putAsset(next, asset.revision);
      const view = toAssetView(next);
      this.remember(tx, actor.userId, command, semanticHash, view, nowUtc);
      return succeeded<MediaDeletionData>(view);
    });
  }

  async getDeletionStatus(
    actor: MediaActor,
    query: GetDeletionStatusQueryV1,
  ): Promise<MediaResult<StoredDeletionStatus>> {
    const nowUtc = this.now();
    return this.deps.repository.transact(async (tx) => {
      const asset = await tx.asset(query.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      await this.authorize(actor, asset, nowUtc, 'read');
      const status = await tx.deletion(asset.assetId);
      if (status === null) throw new MediaDomainRefusal('not_found');
      return succeeded(status);
    });
  }

  /**
   * System path for authoritative privacy/moderation/security input. The
   * instruction is verified first; unknown or foreign ones mutate nothing.
   * Restricting disables delivery, lifting clears only the flag and never makes
   * anything public by itself.
   */
  async applyRestriction(rawCommand: unknown): Promise<MediaResult<MediaDeletionData>> {
    if (typeof rawCommand !== 'object' || rawCommand === null || Array.isArray(rawCommand))
      return rejected('invalid_contract');
    const record = rawCommand as Record<string, unknown>;
    if (typeof record.schemaVersion === 'number' && record.schemaVersion !== 1)
      return unsupported();
    const parsed = await validateMediaContract<MediaCommandV1>('command', rawCommand);
    if (!parsed.ok || parsed.value.commandType !== 'applyRestriction')
      return rejected('invalid_contract');
    const command: ApplyRestrictionCommandV1 = parsed.value;
    const trusted = await this.deps.restrictionAuthority
      .verifyRestriction({
        assetId: command.payload.assetId,
        decisionRef: command.payload.decisionRef,
        restricted: command.payload.restricted,
      })
      .catch(() => false);
    if (!trusted) return rejected('capability_denied');
    const semanticHash = sha256Hex(
      canonicalJson({ algorithm: 'media_semantic_hash_v1', command: command.payload }),
    );
    const nowUtc = this.now();
    try {
      return await this.deps.repository.transact(async (tx) => {
        const prior = await tx.idempotency(
          systemActor,
          command.commandType,
          command.idempotencyKey,
        );
        if (prior !== null) {
          if (prior.semanticHash !== semanticHash)
            throw new MediaDomainRefusal('idempotency_conflict');
          return succeeded(deepFreeze(structuredClone(prior.outcome)) as MediaDeletionData);
        }
        const asset = await tx.asset(command.payload.assetId);
        if (asset === null) throw new MediaDomainRefusal('not_found');
        const next = withRestriction(asset, command.payload.restricted, nowUtc);
        if (next !== asset) {
          tx.putAsset(next, asset.revision);
          if (command.payload.restricted) this.effect(tx, next, 'MediaDeliveryDisabled', nowUtc);
          else if (next.lifecycle === 'ready')
            this.effect(tx, next, 'MediaDeliveryRestored', nowUtc);
        }
        const view = toAssetView(next);
        this.remember(tx, systemActor, command, semanticHash, view, nowUtc);
        return succeeded<MediaDeletionData>(view);
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  /**
   * Cleanup worker entry: starts deletion of an asset the reconciler decided to
   * remove. References are re-checked and the asset must still be in the state the
   * decision was made for, so a late reference wins over cleanup.
   */
  async deleteForCleanup(
    assetId: string,
    reason: DeletionReason,
  ): Promise<StoredDeletionStatus | null> {
    const nowUtc = this.now();
    const begun = await this.deps.repository
      .transact(async (tx) => {
        const asset = await tx.asset(assetId);
        if (asset === null) return null;
        if (await this.referenced(assetId)) return null;
        return await this.begin(tx, asset, reason, nowUtc);
      })
      .catch((error: unknown) => {
        if (error instanceof MediaDomainRefusal || error instanceof MediaRepositoryConflict)
          return null;
        throw error;
      });
    if (begun === null) return null;
    return this.completeDeletion(assetId);
  }

  /**
   * Removes bytes and variants with the object store and marks the asset
   * `deleted` only if every removal is confirmed. An unconfirmed cleanup leaves
   * the asset `deleting` and the deletion status `pending`; it can be resumed.
   */
  async completeDeletion(assetId: string): Promise<StoredDeletionStatus> {
    const nowUtc = this.now();
    const target = await this.deps.repository.transact(async (tx) => {
      const asset = await tx.asset(assetId);
      const status = await tx.deletion(assetId);
      if (asset === null || status === null) throw new MediaDomainRefusal('not_found');
      return { asset, status };
    });
    if (target.asset.lifecycle !== 'deleting') return target.status;
    const removals = await Promise.all([
      this.deps.objectStore.remove(target.asset.objectKeyHandle),
      ...target.asset.variantRefs.map((variant) =>
        this.deps.objectStore.removeVariant(variant.variantId),
      ),
    ]);
    if (removals.includes('failed')) return target.status;
    return this.deps.repository.transact(async (tx) => {
      const asset = await tx.asset(assetId);
      const status = await tx.deletion(assetId);
      if (asset === null || status === null) throw new MediaDomainRefusal('not_found');
      if (asset.lifecycle !== 'deleting') return status;
      const finished = finishDeletion(asset, nowUtc);
      tx.putAsset(finished, asset.revision);
      const completed: StoredDeletionStatus = deepFreeze<MediaDeletionStatusV1>({
        ...status,
        state: 'completed',
        deletionRevision: status.deletionRevision + 1,
        completedAtUtc: nowUtc,
      });
      tx.putDeletion(completed, status.deletionRevision);
      this.effect(tx, finished, 'MediaAssetDeleted', nowUtc);
      return completed;
    });
  }

  private async begin(
    tx: MediaTransaction,
    asset: MediaAsset,
    reason: DeletionReason,
    nowUtc: UtcInstant,
  ): Promise<StoredDeletionStatus> {
    let next: MediaAsset;
    if (asset.lifecycle === 'reserved' || asset.lifecycle === 'uploading') {
      // Confirmed absence deletes at once; any partial data goes through `deleting`.
      const stat = await this.deps.objectStore.stat(asset.objectKeyHandle);
      next = abortUpload(asset, stat.kind === 'absent', nowUtc);
      const session = await tx.sessionForAsset(asset.assetId);
      if (session?.state === 'open')
        tx.putSession(
          withSessionState(session, reason === 'expired_upload' ? 'expired' : 'aborted', nowUtc),
          session.revision,
        );
    } else if (
      asset.lifecycle === 'ready' ||
      asset.lifecycle === 'quarantined' ||
      asset.lifecycle === 'blocked'
    ) {
      if (await this.referenced(asset.assetId)) throw new MediaDomainRefusal('asset_referenced');
      next = beginDeletion(asset, nowUtc);
    } else {
      throw new MediaDomainRefusal('invalid_state');
    }
    tx.putAsset(next, asset.revision);
    this.effect(tx, next, 'MediaDeliveryDisabled', nowUtc);
    const done = next.lifecycle === 'deleted';
    const state: MediaDeletionStatusV1['state'] = done ? 'completed' : 'pending';
    const status: StoredDeletionStatus = deepFreeze<MediaDeletionStatusV1>({
      schemaVersion: 1,
      assetId: asset.assetId,
      state,
      reason,
      deletionRevision: 1,
      requestedAtUtc: nowUtc,
      ...(done ? { completedAtUtc: nowUtc } : {}),
    });
    tx.putDeletion(status, 0);
    if (done) this.effect(tx, next, 'MediaAssetDeleted', nowUtc);
    return status;
  }

  private effect(
    tx: MediaTransaction,
    asset: MediaAsset,
    type: MediaEffectV1['type'],
    nowUtc: UtcInstant,
  ): void {
    tx.effects.append({
      schemaVersion: 1,
      effectId: `${asset.assetId}:${type}:${asset.revision}`,
      type,
      assetId: asset.assetId,
      assetRevision: asset.revision,
      occurredAtUtc: nowUtc,
    });
  }

  /** Doubt counts as referenced: an unreachable owning domain never lets deletion proceed. */
  private async referenced(assetId: string): Promise<boolean> {
    return this.deps.references.isReferenced(assetId).catch(() => true);
  }

  private async authorize(
    actor: MediaActor,
    asset: MediaAsset,
    nowUtc: UtcInstant,
    action: 'manage' | 'read' = 'manage',
  ): Promise<void> {
    const result = await this.deps.authority.evaluate({
      actor,
      marketId: asset.marketId,
      ...(asset.publisherRef === undefined ? {} : { publisherRef: asset.publisherRef }),
      family: asset.family,
      action,
      nowUtc,
    });
    if (result.allowed) return;
    throw new MediaDomainRefusal(
      result.reason === 'session_invalid' ? 'unauthenticated' : result.reason,
    );
  }

  private remember(
    tx: MediaTransaction,
    actorId: string,
    command: MediaCommandV1,
    semanticHash: string,
    outcome: MediaDeletionData,
    nowUtc: UtcInstant,
  ): void {
    tx.putIdempotency({
      actorUserId: actorId,
      commandType: command.commandType,
      idempotencyKey: command.idempotencyKey,
      semanticHash,
      outcome: structuredClone(outcome),
      createdAtUtc: nowUtc,
    });
    tx.appendAudit({
      auditId: this.deps.ids.newId(),
      occurredAtUtc: nowUtc,
      actorUserId: actorId,
      action: command.commandType,
      subjectId: outcome.assetId,
      outcome: 'succeeded',
    });
  }

  private toRefusal<T>(error: unknown): MediaResult<T> {
    if (error instanceof MediaDomainRefusal) return rejected(error.code);
    if (error instanceof MediaRepositoryConflict) return rejected('revision_conflict');
    throw error;
  }
}
