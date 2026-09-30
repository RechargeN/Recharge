import type {
  ConfirmUploadCommandV1,
  CreateUploadSessionCommandV1,
  FinalizeAssetCommandV1,
  MediaAssetV1,
  MediaCommandV1,
  MediaFailureCode,
  MediaFamily,
  MediaQueryV1,
  ProcessingReceiptV1,
  RetryProcessingCommandV1,
  UploadSessionV1,
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
  acceptSource,
  advance,
  canonicalJson,
  createReservedAsset,
  markReady,
  markUploading,
  retryFromQuarantine,
  sha256Hex,
  startAttempt,
  toAssetView,
  verifyVariantManifest,
  type MediaAsset,
} from '../domain/media_asset.js';
import {
  resolveFamilyPolicy,
  type MediaFamilyPolicy,
  type MediaPolicy,
} from '../domain/media_policy.js';
import type {
  MediaRepository,
  MediaTransaction,
  StoredProcessingReceipt,
} from '../domain/repositories.js';
import {
  createUploadSession,
  isSessionExpired,
  toSessionView,
  withSessionState,
} from '../domain/upload_session.js';
import type { EntityScopePort } from './ports/entity_scope_port.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaAuthorityResult,
} from './ports/actor_authority_port.js';
import type { ObjectStorePort } from './ports/object_store_port.js';
import type { ProcessorPort, ProcessOutcome } from './ports/processor_port.js';
import type { ScanOutcome, ScannerPort } from './ports/scanner_port.js';

export interface MediaIdGenerator {
  newId(): EntityId;
}

export interface MediaServiceDeps {
  readonly repository: MediaRepository;
  readonly authority: MediaActorAuthorityPort;
  readonly entityScope: EntityScopePort;
  readonly objectStore: ObjectStorePort;
  readonly scanner: ScannerPort;
  readonly processor: ProcessorPort;
  readonly clock: ServerClock;
  readonly ids: MediaIdGenerator;
  /** Server-owned family flags. Every family is disabled unless listed here. */
  readonly enabledFamilies: ReadonlySet<MediaFamily>;
  /** Accepted policy from configuration; `undefined` fails closed. */
  readonly policy?: MediaPolicy;
}

export type MediaCommandData = DeepReadonly<MediaAssetV1> | DeepReadonly<UploadSessionV1>;
export type MediaQueryData = DeepReadonly<MediaAssetV1> | StoredProcessingReceipt;

/** A rejection that must still commit its state changes (e.g. a partial upload). */
class CommittedRejection {
  constructor(readonly code: MediaFailureCode) {}
}

interface CommandContext {
  readonly tx: MediaTransaction;
  readonly actor: MediaActor;
  readonly nowUtc: UtcInstant;
}

/**
 * Single writer of Media records (BCK-14). Storage, scanning, processing and the
 * owning domain's entity scope stay behind ports; authority is re-evaluated on
 * every command. Slice 2.5a: upload sessions, confirmation, finalize and retry.
 */
export class MediaService {
  constructor(private readonly deps: MediaServiceDeps) {}

  async execute(
    actor: MediaActor | undefined,
    rawCommand: unknown,
  ): Promise<MediaResult<MediaCommandData>> {
    if (actor === undefined) return rejected('unauthenticated');
    const early = preflight(rawCommand);
    if (early !== undefined) return early;
    const parsed = await validateMediaContract<MediaCommandV1>('command', rawCommand);
    if (!parsed.ok) return rejected('invalid_contract');
    const command = parsed.value;
    const semanticHash = sha256Hex(
      canonicalJson({
        algorithm: 'media_semantic_hash_v1',
        actorUserId: actor.userId,
        commandType: command.commandType,
        payload: command.payload,
      }),
    );
    try {
      switch (command.commandType) {
        case 'createUploadSession':
          return await this.single(actor, command, semanticHash, (context) =>
            this.createSession(context, command.payload),
          );
        case 'confirmUpload':
          return await this.single(actor, command, semanticHash, (context) =>
            this.confirmUpload(context, command.payload),
          );
        case 'finalizeAsset':
        case 'retryProcessing':
          return await this.processAsset(actor, command, semanticHash);
      }
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  async query(
    actor: MediaActor | undefined,
    rawQuery: unknown,
  ): Promise<MediaResult<MediaQueryData>> {
    if (actor === undefined) return rejected('unauthenticated');
    const early = preflight(rawQuery);
    if (early !== undefined) return early;
    const parsed = await validateMediaContract<MediaQueryV1>('query', rawQuery);
    if (!parsed.ok) return rejected('invalid_contract');
    const query = parsed.value;
    const nowUtc = this.now();
    try {
      return await this.deps.repository.transact(async (tx) => {
        const asset = await tx.asset(query.payload.assetId);
        // Another subject's asset does not exist for the caller.
        if (asset === null || asset.ownerSubjectId !== actor.userId)
          throw new MediaDomainRefusal('not_found');
        await this.authorize({ tx, actor, nowUtc }, asset, 'read');
        if (query.queryType === 'getAssetStatus')
          return succeeded<MediaQueryData>(toAssetView(asset));
        const attempts = await tx.receiptsForAsset(asset.assetId);
        const wanted = query.payload.attemptNumber;
        const receipt =
          wanted === undefined
            ? attempts[attempts.length - 1]
            : attempts.find((item) => item.attemptNumber === wanted);
        if (receipt === undefined) throw new MediaDomainRefusal('not_found');
        return succeeded<MediaQueryData>(receipt);
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  private now(): UtcInstant {
    return parseUtcInstant(this.deps.clock.now().toISOString());
  }

  private toRefusal<T>(error: unknown): MediaResult<T> {
    if (error instanceof MediaDomainRefusal) return rejected(error.code);
    if (error instanceof MediaRepositoryConflict) return rejected('revision_conflict');
    throw error;
  }

  /** Runs a one-transaction command with semantic idempotency. */
  private async single(
    actor: MediaActor,
    command: MediaCommandV1,
    semanticHash: string,
    handler: (context: CommandContext) => Promise<MediaCommandData | CommittedRejection>,
  ): Promise<MediaResult<MediaCommandData>> {
    const nowUtc = this.now();
    return this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        return succeeded(deepFreeze(structuredClone(prior.outcome)) as MediaCommandData);
      }
      const outcome = await handler({ tx, actor, nowUtc });
      if (outcome instanceof CommittedRejection) return rejected<MediaCommandData>(outcome.code);
      this.recordOutcome(tx, actor, command, semanticHash, outcome, nowUtc);
      return succeeded(outcome);
    });
  }

  private recordOutcome(
    tx: MediaTransaction,
    actor: MediaActor,
    command: MediaCommandV1,
    semanticHash: string,
    outcome: MediaCommandData,
    nowUtc: UtcInstant,
  ): void {
    tx.putIdempotency({
      actorUserId: actor.userId,
      commandType: command.commandType,
      idempotencyKey: command.idempotencyKey,
      semanticHash,
      outcome: structuredClone(outcome),
      createdAtUtc: nowUtc,
    });
    tx.appendAudit({
      auditId: this.deps.ids.newId(),
      occurredAtUtc: nowUtc,
      actorUserId: actor.userId,
      action: command.commandType,
      subjectId: outcome.assetId,
      outcome: 'succeeded',
    });
  }

  /** Backend-time authority for the exact Publisher, market and family. */
  private async authorize(
    context: CommandContext,
    subject: {
      readonly marketId: MediaAsset['marketId'];
      readonly publisherRef?: MediaAsset['publisherRef'];
      readonly family: MediaFamily;
    },
    action: 'upload' | 'read' | 'manage',
  ): Promise<void> {
    const result: MediaAuthorityResult = await this.deps.authority.evaluate({
      actor: context.actor,
      marketId: subject.marketId,
      ...(subject.publisherRef === undefined ? {} : { publisherRef: subject.publisherRef }),
      family: subject.family,
      action,
      nowUtc: context.nowUtc,
    });
    if (result.allowed) return;
    if (result.reason === 'session_invalid') throw new MediaDomainRefusal('unauthenticated');
    throw new MediaDomainRefusal(result.reason);
  }

  private familyPolicy(family: MediaFamily): MediaFamilyPolicy {
    const policy = resolveFamilyPolicy(this.deps.policy, family);
    if (!this.deps.enabledFamilies.has(family)) throw new MediaDomainRefusal('family_unavailable');
    return policy;
  }

  private async createSession(
    context: CommandContext,
    payload: CreateUploadSessionCommandV1['payload'],
  ): Promise<MediaCommandData> {
    const { tx, actor, nowUtc } = context;
    const policy = this.familyPolicy(payload.family);
    if (payload.publisherRef?.type === 'user' && payload.publisherRef.id !== actor.userId)
      throw new MediaDomainRefusal('capability_denied');
    await this.authorize(
      context,
      {
        marketId: payload.marketId,
        family: payload.family,
        ...(payload.publisherRef === undefined ? {} : { publisherRef: payload.publisherRef }),
      },
      'upload',
    );
    if (payload.entityIntent !== undefined) {
      // The binding is trusted only if the owning domain confirms the exact
      // entity, Publisher and market for this actor.
      if (payload.publisherRef === undefined) throw new MediaDomainRefusal('entity_scope_denied');
      const scope = await this.deps.entityScope.authorize({
        actor,
        entity: payload.entityIntent,
        publisherRef: payload.publisherRef,
        marketId: payload.marketId,
        nowUtc,
      });
      if (!scope.allowed) throw new MediaDomainRefusal('entity_scope_denied');
    }
    const assetId = this.deps.ids.newId();
    const objectKeyHandle = `objk:${this.deps.ids.newId()}`;
    const session = createUploadSession({
      uploadSessionId: this.deps.ids.newId(),
      assetId,
      ownerSubjectId: actor.userId,
      ...(payload.publisherRef === undefined ? {} : { publisherRef: payload.publisherRef }),
      ...(payload.entityIntent === undefined ? {} : { entityIntent: payload.entityIntent }),
      marketId: payload.marketId,
      family: payload.family,
      allowedMediaTypes: policy.allowedMediaTypes,
      maxBytes: policy.maxBytes,
      ttlSeconds: policy.sessionTtlSeconds,
      objectKeyHandle,
      declaredMediaType: payload.declaredMediaType,
      declaredByteLength: payload.declaredByteLength,
      nowUtc,
    });
    const asset = createReservedAsset({
      assetId,
      ownerSubjectId: actor.userId,
      ...(payload.publisherRef === undefined ? {} : { publisherRef: payload.publisherRef }),
      ...(payload.entityIntent === undefined ? {} : { entityBinding: payload.entityIntent }),
      marketId: payload.marketId,
      family: payload.family,
      visibilityClass: payload.visibilityClass,
      policyRevision: this.deps.policy?.revision ?? '',
      objectKeyHandle,
      nowUtc,
    });
    tx.putAsset(asset, 0);
    tx.putSession(session, 0);
    return toSessionView(session);
  }

  private async confirmUpload(
    context: CommandContext,
    payload: ConfirmUploadCommandV1['payload'],
  ): Promise<MediaCommandData | CommittedRejection> {
    const { tx, actor, nowUtc } = context;
    const session = await tx.session(payload.uploadSessionId);
    if (session === null || session.ownerSubjectId !== actor.userId)
      throw new MediaDomainRefusal('not_found');
    const asset = await tx.asset(session.assetId);
    if (asset === null) throw new MediaDomainRefusal('not_found');
    await this.authorize(context, asset, 'upload');
    const policy = this.familyPolicy(asset.family);
    if (session.state === 'completed') throw new MediaDomainRefusal('invalid_state');
    if (session.state !== 'open' || isSessionExpired(session, nowUtc))
      throw new MediaDomainRefusal('session_expired');
    if (asset.lifecycle !== 'reserved' && asset.lifecycle !== 'uploading')
      throw new MediaDomainRefusal('invalid_state');
    const stat = await this.deps.objectStore.stat(asset.objectKeyHandle);
    if (stat.kind === 'absent') throw new MediaDomainRefusal('object_missing');
    if (stat.kind === 'partial') {
      if (asset.lifecycle === 'reserved') tx.putAsset(markUploading(asset, nowUtc), asset.revision);
      return new CommittedRejection('upload_incomplete');
    }
    if (stat.byteLength > session.maxBytes) throw new MediaDomainRefusal('limit_exceeded');
    if (
      !session.allowedMediaTypes.includes(stat.detectedMediaType) ||
      stat.detectedMediaType !== session.declaredMediaType
    )
      throw new MediaDomainRefusal('signature_mismatch');
    if (
      stat.sha256 !== payload.expectedSha256 ||
      stat.byteLength !== payload.expectedByteLength ||
      stat.byteLength !== session.declaredByteLength
    )
      throw new MediaDomainRefusal('generation_mismatch');
    const accepted = acceptSource(
      asset,
      {
        providerGeneration: stat.providerGeneration,
        byteLength: stat.byteLength,
        verifiedMediaType: stat.detectedMediaType,
        sha256: stat.sha256,
        validationProfileRevision: policy.validationProfileRevision,
      },
      nowUtc,
    );
    tx.putAsset(accepted, asset.revision);
    tx.putSession(withSessionState(session, 'completed', nowUtc), session.revision);
    return toAssetView(accepted);
  }

  /**
   * Finalize/retry run in two transactions with the scanner and processor in
   * between. The result is applied only if the asset is still exactly the one
   * the attempt started from, so a late result after a delete or restriction can
   * never bring an asset back to `ready`.
   */
  private async processAsset(
    actor: MediaActor,
    command: FinalizeAssetCommandV1 | RetryProcessingCommandV1,
    semanticHash: string,
  ): Promise<MediaResult<MediaCommandData>> {
    const startedAtUtc = this.now();
    const started = await this.deps.repository.transact(async (tx) => {
      const prior = await tx.idempotency(actor.userId, command.commandType, command.idempotencyKey);
      if (prior !== null) {
        if (prior.semanticHash !== semanticHash)
          throw new MediaDomainRefusal('idempotency_conflict');
        return { replay: deepFreeze(structuredClone(prior.outcome)) as MediaCommandData };
      }
      const asset = await tx.asset(command.payload.assetId);
      if (asset === null || asset.ownerSubjectId !== actor.userId)
        throw new MediaDomainRefusal('not_found');
      const context: CommandContext = { tx, actor, nowUtc: startedAtUtc };
      await this.authorize(context, asset, 'upload');
      if (asset.revision !== command.payload.expectedAssetRevision)
        throw new MediaDomainRefusal('stale_revision');
      const policy = this.familyPolicy(asset.family);
      if (asset.entityBinding !== undefined) {
        if (asset.publisherRef === undefined) throw new MediaDomainRefusal('entity_scope_denied');
        const scope = await this.deps.entityScope.authorize({
          actor,
          entity: asset.entityBinding,
          publisherRef: asset.publisherRef,
          marketId: asset.marketId,
          nowUtc: startedAtUtc,
        });
        if (!scope.allowed) throw new MediaDomainRefusal('entity_scope_denied');
      }
      const source = asset.sourceGenerationRef;
      if (source?.providerGeneration !== command.payload.sourceProviderGeneration)
        throw new MediaDomainRefusal('generation_mismatch');
      let next: MediaAsset;
      if (command.commandType === 'finalizeAsset') {
        if (
          source.sha256 !== command.payload.expectedSha256 ||
          source.byteLength !== command.payload.expectedByteLength
        )
          throw new MediaDomainRefusal('generation_mismatch');
        if (asset.lifecycle !== 'validating' || asset.deliveryDisabled)
          throw new MediaDomainRefusal('invalid_state');
        if (asset.attemptCount >= policy.maxProcessingAttempts)
          throw new MediaDomainRefusal('retry_not_allowed');
        next = startAttempt(asset, startedAtUtc);
      } else {
        next = retryFromQuarantine(
          asset,
          command.payload.sourceProviderGeneration,
          policy.maxProcessingAttempts,
          startedAtUtc,
        );
      }
      tx.putAsset(next, asset.revision);
      return { asset: next, source, policy };
    });
    if ('replay' in started) return succeeded(started.replay);
    const { asset: attempt, source, policy } = started;

    const scan = await this.runScan(attempt, source.providerGeneration, source.sha256);
    let processing: ProcessOutcome | undefined;
    if (scan.result === 'clean')
      processing = await this.runProcess(attempt, source.providerGeneration, source.sha256, policy);

    return this.deps.repository.transact(async (tx) => {
      const completedAtUtc = this.now();
      const current = await tx.asset(attempt.assetId);
      if (current === null) throw new MediaDomainRefusal('not_found');
      if (current.revision !== attempt.revision) throw new MediaDomainRefusal('stale_revision');
      let manifest: ReturnType<typeof verifyVariantManifest> | undefined;
      if (processing?.result === 'succeeded')
        manifest = verifyVariantManifest(
          current,
          processing.variants,
          policy.mandatoryVariantProfiles,
        );
      let outcome: ProcessingReceiptV1['outcome'];
      let updated: MediaAsset;
      if (manifest?.ok === true) {
        outcome = 'ready';
        updated = markReady(
          advance(current, ['processing'], completedAtUtc),
          manifest,
          completedAtUtc,
        );
      } else if (scan.result === 'rejected' || processing?.result === 'rejected') {
        outcome = 'blocked';
        updated = advance(
          current,
          processing === undefined ? ['blocked'] : ['processing', 'blocked'],
          completedAtUtc,
        );
      } else {
        // inconclusive scan, failed processing or unverifiable variants
        outcome = 'quarantined';
        updated = advance(
          current,
          processing === undefined ? ['quarantined'] : ['processing', 'quarantined'],
          completedAtUtc,
        );
      }
      const receipt: ProcessingReceiptV1 = {
        schemaVersion: 1,
        assetId: attempt.assetId,
        attemptNumber: attempt.attemptCount,
        sourceProviderGeneration: source.providerGeneration,
        sourceSha256: source.sha256,
        policyRevision: this.deps.policy?.revision ?? '',
        scan: { toolRevision: scan.toolRevision, result: scan.result },
        ...(processing === undefined
          ? {}
          : {
              processing: {
                toolRevision: processing.toolRevision,
                result: processing.result,
                ...(manifest?.ok === true ? { variantManifestRevision: manifest.revision } : {}),
              },
            }),
        outcome,
        startedAtUtc,
        completedAtUtc,
      };
      tx.putReceipt(deepFreeze(receipt));
      tx.putAsset(updated, current.revision);
      const view = toAssetView(updated);
      this.recordOutcome(tx, actor, command, semanticHash, view, completedAtUtc);
      return succeeded<MediaCommandData>(view);
    });
  }

  private async runScan(
    asset: MediaAsset,
    providerGeneration: string,
    sha256: string,
  ): Promise<ScanOutcome> {
    try {
      return await this.deps.scanner.scan({
        assetId: asset.assetId,
        objectKeyHandle: asset.objectKeyHandle,
        providerGeneration,
        sha256,
        policyRevision: this.deps.policy?.revision ?? '',
      });
    } catch {
      // A failed or timed-out scan is never a pass: the asset stays quarantined.
      return { toolRevision: 'scanner-error', result: 'inconclusive' };
    }
  }

  private async runProcess(
    asset: MediaAsset,
    sourceProviderGeneration: string,
    sourceSha256: string,
    policy: MediaFamilyPolicy,
  ): Promise<ProcessOutcome> {
    try {
      return await this.deps.processor.process({
        assetId: asset.assetId,
        objectKeyHandle: asset.objectKeyHandle,
        family: asset.family,
        sourceProviderGeneration,
        sourceSha256,
        policyRevision: this.deps.policy?.revision ?? '',
        mandatoryVariantProfiles: policy.mandatoryVariantProfiles,
      });
    } catch {
      return { toolRevision: 'processor-error', result: 'failed' };
    }
  }
}

/** Early, contract-independent rejection of newer schemas. */
function preflight(raw: unknown) {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw))
    return rejected('invalid_contract');
  const record = raw as Record<string, unknown>;
  if (typeof record.schemaVersion === 'number' && record.schemaVersion !== 1) return unsupported();
  return undefined;
}
