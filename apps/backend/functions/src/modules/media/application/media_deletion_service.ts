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
  holdOwnedBy,
  placeDeletionHold,
  releaseDeletionHold,
  withRestriction,
  type MediaAsset,
} from '../domain/media_asset.js';
import { requireRetentionPolicy, type MediaRetentionPolicy } from '../domain/media_retention.js';
import type {
  MediaAuthorization,
  MediaRepository,
  MediaTransaction,
  StoredDeletionStatus,
} from '../domain/repositories.js';
import { withSessionState } from '../domain/upload_session.js';
import {
  repeatAuthorizations,
  type MediaActor,
  type MediaActorAuthorityPort,
  type MediaRestrictionAuthority,
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
  /** Accepted retention policy (hold lease); `undefined` fails closed for settled assets. */
  readonly retention?: MediaRetentionPolicy;
}

export type MediaDeletionData = DeepReadonly<MediaDeletionStatusV1> | DeepReadonly<MediaAssetV1>;

const systemActor = 'system:media-restriction';

/** What the first step of a deletion left behind: a hold this call may have placed itself. */
interface HeldAsset {
  readonly holdId: string;
}

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

  /**
   * Owner deletion. The owning domain is asked about references only while no
   * Media transaction is held (no cross-module call under a lock), and delivery is
   * held first so nothing new can attach while it answers: hold, ask, then either
   * lift the hold (still referenced) or tombstone and clean up.
   */
  async deleteAsset(
    actor: MediaActor,
    command: DeleteAssetCommandV1,
    semanticHash: string,
  ): Promise<MediaResult<MediaDeletionData>> {
    const nowUtc = this.now();
    const authorizations: MediaAuthorization[] = [];
    // First look, before any transaction: an asset that is plainly referenced is
    // refused without touching it (no hold, no revision churn).
    const knownReferenced = await this.referenced(command.payload.assetId);
    const first = await this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        await this.repeat(actor, prior.authorizations, nowUtc);
        return { replay: deepFreeze(structuredClone(prior.outcome)) as MediaDeletionData };
      }
      const asset = await tx.asset(command.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      await this.authorize(actor, asset, nowUtc, 'manage', authorizations);
      if (asset.revision !== command.payload.expectedAssetRevision)
        throw new MediaDomainRefusal('stale_revision');
      return this.startDeletion(tx, asset, 'owner_request', nowUtc, knownReferenced);
    });
    if ('replay' in first) return succeeded(first.replay);
    if ('held' in first) {
      const referenced = await this.referenced(command.payload.assetId);
      const decided = await this.decide(
        command.payload.assetId,
        first.held,
        referenced,
        'owner_request',
      );
      if (decided === 'referenced') return rejected('asset_referenced');
      // The hold ran out while the owning domain was being asked: nothing was
      // changed, and a retry starts the check over.
      if (decided === 'expired') return rejected('revision_conflict');
    }
    const final = await this.completeDeletion(command.payload.assetId);
    await this.deps.repository.transact((tx) => {
      this.remember(tx, actor.userId, command, semanticHash, final, nowUtc, authorizations);
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
    // Asked before any Media transaction is held; the orphan clock is re-checked
    // against the owning domain by the reconciler before anything is deleted.
    const referenced = await this.referenced(command.payload.assetId);
    return this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        await this.repeat(actor, prior.authorizations, nowUtc);
        return succeeded(deepFreeze(structuredClone(prior.outcome)) as MediaDeletionData);
      }
      const authorizations: MediaAuthorization[] = [];
      const asset = await tx.asset(command.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      await this.authorize(actor, asset, nowUtc, 'manage', authorizations);
      if (asset.revision !== command.payload.expectedAssetRevision)
        throw new MediaDomainRefusal('stale_revision');
      if (asset.lifecycle === 'deleting' || asset.lifecycle === 'deleted')
        throw new MediaDomainRefusal('invalid_state');
      if (referenced) throw new MediaDomainRefusal('asset_referenced');
      const next = withOrphanSince(asset, nowUtc, nowUtc);
      if (next !== asset) tx.putAsset(next, asset.revision);
      const view = toAssetView(next);
      this.remember(tx, actor.userId, command, semanticHash, view, nowUtc, authorizations);
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
          // Announce only what clients can actually reach: a deletion hold may keep
          // delivery disabled although the restriction itself was lifted.
          if (!asset.deliveryDisabled && next.deliveryDisabled)
            this.effect(tx, next, 'MediaDeliveryDisabled', nowUtc);
          else if (asset.deliveryDisabled && !next.deliveryDisabled && next.lifecycle === 'ready')
            this.effect(tx, next, 'MediaDeliveryRestored', nowUtc);
        }
        const view = toAssetView(next);
        this.remember(tx, systemActor, command, semanticHash, view, nowUtc, []);
        return succeeded<MediaDeletionData>(view);
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  /**
   * Cleanup worker entry: starts deletion of an asset the reconciler decided to
   * remove. Same order as an owner deletion (hold, ask the owning domain outside
   * any transaction, then tombstone or lift), so a late reference wins over cleanup.
   */
  async deleteForCleanup(
    assetId: string,
    reason: DeletionReason,
  ): Promise<StoredDeletionStatus | null> {
    const nowUtc = this.now();
    const knownReferenced = await this.referenced(assetId);
    try {
      const first = await this.deps.repository.transact(async (tx) => {
        const asset = await tx.asset(assetId);
        if (asset === null) return null;
        return this.startDeletion(tx, asset, reason, nowUtc, knownReferenced);
      });
      if (first === null) return null;
      if ('held' in first) {
        const referenced = await this.referenced(assetId);
        if ((await this.decide(assetId, first.held, referenced, reason)) !== 'started') return null;
      }
    } catch (error) {
      if (error instanceof MediaDomainRefusal || error instanceof MediaRepositoryConflict)
        return null;
      throw error;
    }
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

  /**
   * First step of a deletion, with no cross-module call: an unfinished upload is
   * aborted at once; a settled asset only has its delivery held so nothing new can
   * attach; anything in flight is not deletable.
   */
  private async startDeletion(
    tx: MediaTransaction,
    asset: MediaAsset,
    reason: DeletionReason,
    nowUtc: UtcInstant,
    knownReferenced: boolean,
  ): Promise<{ readonly status: StoredDeletionStatus } | { readonly held: HeldAsset }> {
    if (asset.lifecycle === 'reserved' || asset.lifecycle === 'uploading')
      return { status: await this.abortInFlight(tx, asset, reason, nowUtc) };
    if (
      asset.lifecycle !== 'ready' &&
      asset.lifecycle !== 'quarantined' &&
      asset.lifecycle !== 'blocked'
    )
      throw new MediaDomainRefusal('invalid_state');
    if (knownReferenced) throw new MediaDomainRefusal('asset_referenced');
    // The hold has its own owner id and lease; the holder may act only on that.
    const policy = requireRetentionPolicy(this.deps.retention);
    const holdId = this.deps.ids.newId();
    const expiresAtUtc = parseUtcInstant(
      new Date(Date.parse(nowUtc) + policy.deletionHoldLeaseSeconds * 1000).toISOString(),
    );
    const held = placeDeletionHold(asset, { holdId, expiresAtUtc }, nowUtc);
    tx.putAsset(held, asset.revision);
    // Only a real change of what clients can reach is a fact worth announcing.
    if (!asset.deliveryDisabled) this.effect(tx, held, 'MediaDeliveryDisabled', nowUtc);
    return { held: { holdId } };
  }

  /**
   * Second step, after the owning domain answered outside any transaction: a
   * referenced asset gets its own hold lifted again (a hold that someone else
   * placed is left alone); an unreferenced one is tombstoned.
   */
  private async decide(
    assetId: string,
    held: HeldAsset,
    referenced: boolean,
    reason: DeletionReason,
  ): Promise<'started' | 'referenced' | 'expired'> {
    const nowUtc = this.now();
    return this.deps.repository.transact(async (tx) => {
      const asset = await tx.asset(assetId);
      if (asset === null) throw new MediaDomainRefusal('not_found');
      // Fencing: a holder whose lease ran out, or whose hold was released or taken
      // over, changes nothing; the answer it carries is about a moment that is over.
      if (!holdOwnedBy(asset, held.holdId, nowUtc)) return 'expired' as const;
      if (referenced) {
        // Only the deletion's own hold is released, whatever else happened to the
        // asset meanwhile: an authoritative restriction placed in between stays.
        this.releaseHold(tx, asset, held.holdId, nowUtc);
        return 'referenced' as const;
      }
      const next = beginDeletion(asset, nowUtc);
      tx.putAsset(next, asset.revision);
      tx.putDeletion(this.pendingStatus(asset.assetId, reason, nowUtc), 0);
      return 'started' as const;
    });
  }

  /** Releases the deletion hold and announces restored delivery only if it really is restored. */
  releaseHold(tx: MediaTransaction, asset: MediaAsset, holdId: string, nowUtc: UtcInstant): void {
    const released = releaseDeletionHold(asset, holdId, nowUtc);
    if (released === asset) return;
    tx.putAsset(released, asset.revision);
    if (asset.deliveryDisabled && !released.deliveryDisabled && released.lifecycle === 'ready')
      this.effect(tx, released, 'MediaDeliveryRestored', nowUtc);
  }

  private pendingStatus(
    assetId: string,
    reason: DeletionReason,
    nowUtc: UtcInstant,
  ): StoredDeletionStatus {
    return deepFreeze<MediaDeletionStatusV1>({
      schemaVersion: 1,
      assetId: assetId as MediaAsset['assetId'],
      state: 'pending',
      reason,
      deletionRevision: 1,
      requestedAtUtc: nowUtc,
    });
  }

  /** Aborts or expires an unfinished upload; confirmed absence deletes at once. */
  private async abortInFlight(
    tx: MediaTransaction,
    asset: MediaAsset,
    reason: DeletionReason,
    nowUtc: UtcInstant,
  ): Promise<StoredDeletionStatus> {
    const stat = await this.deps.objectStore.stat(asset.objectKeyHandle);
    const next = abortUpload(asset, stat.kind === 'absent', nowUtc);
    const session = await tx.sessionForAsset(asset.assetId);
    if (session?.state === 'open')
      tx.putSession(
        withSessionState(session, reason === 'expired_upload' ? 'expired' : 'aborted', nowUtc),
        session.revision,
      );
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
    record?: MediaAuthorization[],
  ): Promise<void> {
    const result = await this.deps.authority.evaluate({
      actor,
      marketId: asset.marketId,
      ...(asset.publisherRef === undefined ? {} : { publisherRef: asset.publisherRef }),
      family: asset.family,
      action,
      nowUtc,
    });
    if (!result.allowed)
      throw new MediaDomainRefusal(
        result.reason === 'session_invalid' ? 'unauthenticated' : result.reason,
      );
    record?.push({
      marketId: asset.marketId,
      ...(asset.publisherRef === undefined ? {} : { publisherRef: asset.publisherRef }),
      family: asset.family,
      action,
    });
  }

  /** A stored result is idempotency, not a standing permission: repeat its checks. */
  private async repeat(
    actor: MediaActor,
    recorded: readonly MediaAuthorization[],
    nowUtc: UtcInstant,
  ): Promise<void> {
    const refusal = await repeatAuthorizations(this.deps.authority, actor, recorded, nowUtc);
    if (refusal !== undefined) throw new MediaDomainRefusal(refusal);
  }

  private remember(
    tx: MediaTransaction,
    actorId: string,
    command: MediaCommandV1,
    semanticHash: string,
    outcome: MediaDeletionData,
    nowUtc: UtcInstant,
    authorizations: readonly MediaAuthorization[],
  ): void {
    tx.putIdempotency({
      actorUserId: actorId,
      commandType: command.commandType,
      idempotencyKey: command.idempotencyKey,
      semanticHash,
      outcome: structuredClone(outcome),
      authorizations: structuredClone([...authorizations]),
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
