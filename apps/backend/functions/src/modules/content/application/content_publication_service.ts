import type {
  ApplyModerationDispositionCommandV1,
  ContentCommandV1,
  ContentEffectV1,
  ContentFailureCode,
  ContentQueryV1,
  ContentReferenceRevisionsV1,
  ContentTypeId,
  ModerationAcknowledgementV1,
  PublicationStatusV1,
} from '../../../contracts/content_v1.js';
import type { PublisherEligibilityV1, PublisherRefV1 } from '../../../contracts/identity_v1.js';
import { validateContentContract } from '../../../contracts/validate_content_contract.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import {
  assertSubmittable,
  createContentDraft,
  updateContentDraftBody,
  withDraftStatus,
  type ContentDraft,
} from '../domain/content_draft.js';
import {
  contentTypeRegistry,
  isContentTypeAvailable,
  resolveContentType,
  type ContentAction,
  type ContentTypeRegistryEntry,
} from '../domain/content_type_registry.js';
import {
  ContentDomainRefusal,
  ContentRepositoryConflict,
  rejected,
  succeeded,
  unsupported,
  type ContentResult,
} from '../domain/failures.js';
import {
  activateRevision,
  applyModerationHold,
  isPubliclyVisible,
  restoreModerationHold,
  withdrawByOwner,
  type PublicationPointer,
} from '../domain/publication_pointer.js';
import {
  applyReviewDisposition,
  assertPublishable,
  createPublicationSubmission,
  withSubmissionState,
  type PublicationSubmission,
} from '../domain/publication_submission.js';
import {
  canonicalJson,
  createPublishedRevision,
  sha256Hex,
  type PublishedRevision,
} from '../domain/published_revision.js';
import type { ContentRepository, ContentTransaction } from '../domain/repositories.js';
import type { MediaReadinessPort } from './ports/media_readiness_port.js';
import type { ModerationDispositionPort } from './ports/moderation_disposition_port.js';
import type { ContentActor, PublisherEligibilityPort } from './ports/publisher_eligibility_port.js';
import type { ReferenceDataPort, ReferenceResolution } from './ports/reference_data_port.js';
import type {
  ContentValidationContext,
  PublishedObjectLookup,
} from '../domain/type_rules/validation_context.js';

export interface ContentIdGenerator {
  newId(): EntityId;
}

export interface ContentPublicationServiceDeps {
  readonly repository: ContentRepository;
  readonly eligibility: PublisherEligibilityPort;
  readonly referenceData: ReferenceDataPort;
  readonly moderation: ModerationDispositionPort;
  readonly media: MediaReadinessPort;
  readonly clock: ServerClock;
  readonly ids: ContentIdGenerator;
  /** Server-owned type flags. Every type is disabled unless listed here. */
  readonly enabledTypes: ReadonlySet<ContentTypeId>;
  /** Live status of published objects a Collection references (Catalog/Content owners). */
  readonly publishedObjects?: PublishedObjectLookup;
}

export type ContentCommandData =
  ContentDraft | PublicationSubmission | PublishedRevision | PublicationPointer;
export type ContentQueryData = ContentDraft | PublicationStatusV1 | PublishedRevision;

type ResolvedReferences = Extract<ReferenceResolution, { ok: true }>;

interface CommandContext {
  readonly tx: ContentTransaction;
  readonly actor: ContentActor;
  readonly nowUtc: UtcInstant;
}

/**
 * Single writer of Content records (BCK-07). Moderation, Media, Catalog and
 * delivery stay behind ports; authority is re-evaluated on every command.
 */
export class ContentPublicationService {
  constructor(private readonly deps: ContentPublicationServiceDeps) {}

  async execute(
    actor: ContentActor | undefined,
    rawCommand: unknown,
  ): Promise<ContentResult<ContentCommandData>> {
    if (actor === undefined) return rejected('unauthenticated');
    const early = preflight(rawCommand, 'commandType');
    if (early !== undefined) return early;
    const parsed = await validateContentContract<ContentCommandV1>('command', rawCommand);
    if (!parsed.ok) return rejected('invalid_contract');
    const command = parsed.value;
    // A moderation disposition is a BCK-22 instruction, not a user command: it
    // is only accepted through `applyModerationDisposition` after verification.
    if ((command as { commandType: string }).commandType === 'applyModerationDisposition')
      return rejected('capability_denied');
    const semanticHash = sha256Hex(
      canonicalJson({
        algorithm: 'content_semantic_hash_v1',
        actorUserId: actor.userId,
        commandType: command.commandType,
        payload: command.payload,
      }),
    );
    const nowUtc = this.now();
    try {
      return await this.deps.repository.transact(async (tx) => {
        const prior = await tx.idempotency(
          actor.userId,
          command.commandType,
          command.idempotencyKey,
        );
        if (prior !== undefined && prior !== null) {
          if (prior.semanticHash !== semanticHash)
            throw new ContentDomainRefusal('idempotency_conflict');
          return succeeded(deepFreeze(structuredClone(prior.outcome)) as ContentCommandData);
        }
        const context: CommandContext = { tx, actor, nowUtc };
        const outcome = await this.dispatch(context, command);
        tx.putIdempotency({
          actorUserId: actor.userId,
          commandType: command.commandType,
          idempotencyKey: command.idempotencyKey,
          semanticHash,
          outcome: structuredClone(outcome),
          createdAtUtc: nowUtc,
        });
        return succeeded(outcome);
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  async query(
    actor: ContentActor | undefined,
    rawQuery: unknown,
  ): Promise<ContentResult<ContentQueryData>> {
    if (actor === undefined) return rejected('unauthenticated');
    const early = preflight(rawQuery, 'queryType');
    if (early !== undefined) return early;
    const parsed = await validateContentContract<ContentQueryV1>('query', rawQuery);
    if (!parsed.ok) return rejected('invalid_contract');
    const query = parsed.value;
    const nowUtc = this.now();
    try {
      return await this.deps.repository.transact(async (tx) => {
        const context: CommandContext = { tx, actor, nowUtc };
        switch (query.queryType) {
          case 'getDraft': {
            const draft = await tx.draft(query.payload.draftId);
            if (draft === null) throw new ContentDomainRefusal('not_found');
            await this.authorize(context, draft.publisherRef, draft.typeId, 'read', draft.marketId);
            return succeeded<ContentQueryData>(draft);
          }
          case 'getPublicationStatus': {
            const draft = await tx.draftByContentId(query.payload.contentId);
            if (draft === null) throw new ContentDomainRefusal('not_found');
            await this.authorize(context, draft.publisherRef, draft.typeId, 'read', draft.marketId);
            const status: PublicationStatusV1 = deepFreeze({
              contentId: draft.contentId,
              pointer: await tx.pointer(draft.contentId),
              submissions: await tx.submissionsForContent(draft.contentId),
            });
            return succeeded<ContentQueryData>(status);
          }
          case 'getPublishedRevision': {
            const pointer = await tx.pointer(query.payload.contentId);
            // Withdrawn, archived and restricted content is not served publicly.
            if (!isPubliclyVisible(pointer) || pointer?.currentPublishedRevisionId == null)
              throw new ContentDomainRefusal('not_found');
            const revision = await tx.publishedRevision(pointer.currentPublishedRevisionId);
            if (revision === null) throw new ContentDomainRefusal('not_found');
            return succeeded<ContentQueryData>(revision);
          }
        }
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  private now(): UtcInstant {
    return parseUtcInstant(this.deps.clock.now().toISOString());
  }

  private toRefusal<T>(error: unknown): ContentResult<T> {
    if (error instanceof ContentDomainRefusal) return rejected(error.code);
    if (error instanceof ContentRepositoryConflict) return rejected('revision_conflict');
    throw error;
  }

  private async dispatch(
    context: CommandContext,
    command: ContentCommandV1,
  ): Promise<ContentCommandData> {
    switch (command.commandType) {
      case 'createDraft':
        return this.createDraft(context, command.payload);
      case 'updateDraft':
        return this.updateDraft(context, command.payload);
      case 'submitForPublication':
        return this.submit(context, command.payload);
      case 'publishApprovedRevision':
        return this.publish(context, command.payload);
      case 'withdrawPublication':
        return this.withdraw(context, command.payload);
      case 'activatePublishedRevision':
        return this.activate(context, command.payload);
    }
  }

  private async createDraft(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'createDraft' }>['payload'],
  ): Promise<ContentDraft> {
    const entry = this.usableType(payload.typeId);
    if (!entry.allowedPublisherTypes.includes(payload.publisherRef.type))
      throw new ContentDomainRefusal('publisher_not_eligible');
    await this.authorize(context, payload.publisherRef, payload.typeId, 'create', payload.marketId);
    const references = await this.pin(payload.marketId, payload.typeId, context.nowUtc);
    const draft = createContentDraft({
      draftId: this.deps.ids.newId(),
      contentId: this.deps.ids.newId(),
      typeId: payload.typeId,
      publisherRef: payload.publisherRef,
      marketId: payload.marketId,
      body: payload.body,
      referenceRevisions: references,
      createdByUserId: context.actor.userId,
      ...(payload.importSourceKey === undefined
        ? {}
        : { importSourceKey: payload.importSourceKey }),
      nowUtc: context.nowUtc,
    });
    context.tx.putDraft(draft);
    this.audit(context, 'content.draft.created', draft.draftId);
    return draft;
  }

  private async updateDraft(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'updateDraft' }>['payload'],
  ): Promise<ContentDraft> {
    const draft = await context.tx.draft(payload.draftId);
    if (draft === null) throw new ContentDomainRefusal('not_found');
    this.usableType(draft.typeId, draft.typeSchemaMajor);
    await this.authorize(context, draft.publisherRef, draft.typeId, 'update', draft.marketId);
    const references = await this.pin(draft.marketId, draft.typeId, context.nowUtc);
    const updated = updateContentDraftBody(
      draft,
      payload.expectedRevision,
      payload.body,
      references,
      context.nowUtc,
    );
    context.tx.putDraft(updated);
    this.audit(context, 'content.draft.updated', updated.draftId);
    return updated;
  }

  private async submit(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'submitForPublication' }>['payload'],
  ): Promise<PublicationSubmission> {
    const draft = await context.tx.draft(payload.draftId);
    if (draft === null) throw new ContentDomainRefusal('not_found');
    const entry = this.usableType(draft.typeId, draft.typeSchemaMajor);
    const eligibility = await this.authorize(
      context,
      draft.publisherRef,
      draft.typeId,
      'submit',
      draft.marketId,
    );
    assertSubmittable(draft, payload.expectedDraftRevision);
    const resolved = await this.resolveReferences(draft.marketId, draft.typeId, context.nowUtc);
    this.assertValid(entry, draft, resolved, context.nowUtc, context.actor.userId);
    const references = resolved.revisions;
    const profile = await this.deps.moderation.profileFor({
      typeId: draft.typeId,
      marketId: draft.marketId,
      publisherRef: draft.publisherRef,
    });
    if (!profile.available) throw new ContentDomainRefusal('policy_unavailable');
    await this.assertMediaReady(entry, draft);
    const submission = createPublicationSubmission({
      submissionId: this.deps.ids.newId(),
      draft,
      moderation: {
        profileId: profile.profileId,
        requiresPrePublicationModeration: profile.requiresPrePublicationModeration,
        policyRevision: profile.policyRevision,
        ...(profile.policyDecisionId === undefined
          ? {}
          : { policyDecisionId: profile.policyDecisionId }),
      },
      eligibilityAuthorityRevision: eligibility.authorityRevision,
      referenceRevisions: references,
      nowUtc: context.nowUtc,
    });
    context.tx.putSubmission(submission);
    context.tx.putDraft(withDraftStatus(draft, 'submitted', context.nowUtc));
    this.audit(context, 'content.publication.submitted', submission.submissionId);
    return submission;
  }

  private async publish(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'publishApprovedRevision' }>['payload'],
  ): Promise<PublishedRevision> {
    const { tx, nowUtc } = context;
    const submission = await tx.submission(payload.submissionId);
    if (submission === null) throw new ContentDomainRefusal('not_found');
    assertPublishable(submission);
    const draft = await tx.draft(submission.draftId);
    if (draft === null) throw new ContentDomainRefusal('not_found');
    if (draft.revision !== submission.draftRevision)
      throw new ContentDomainRefusal('source_revision_stale');
    const entry = this.usableType(submission.typeId, draft.typeSchemaMajor);
    // Authority is re-read at publish time; the submit-time result is not reused.
    await this.authorize(
      context,
      submission.publisherRef,
      submission.typeId,
      'publish',
      submission.marketId,
    );
    const resolved = await this.resolveReferences(submission.marketId, submission.typeId, nowUtc);
    this.assertValid(entry, draft, resolved, nowUtc, context.actor.userId);
    const references = resolved.revisions;
    const media = await this.assertMediaReady(entry, draft);
    const pointer = await tx.pointer(submission.contentId);
    const existing = await tx.publishedRevisionsForContent(submission.contentId);
    const revision = createPublishedRevision({
      publishedRevisionId: this.deps.ids.newId(),
      revisionNumber: existing.length + 1,
      draft,
      submission,
      referenceRevisions: references,
      mediaRevision: media,
      nowUtc,
    });
    const nextPointer = activateRevision(
      pointer,
      payload.expectedPointerRevision,
      submission.contentId,
      revision.publishedRevisionId,
      nowUtc,
    );
    tx.putPublishedRevision(revision);
    tx.putPointer(nextPointer, pointer?.revision ?? 0);
    for (const prior of await tx.submissionsForContent(submission.contentId))
      if (prior.state === 'published')
        tx.putSubmission(withSubmissionState(prior, 'superseded', nowUtc));
    tx.putSubmission(withSubmissionState(submission, 'published', nowUtc));
    tx.putDraft(withDraftStatus(draft, 'editing', nowUtc));
    tx.effects.append(this.publishEffect(revision, nextPointer, existing.length === 0, nowUtc));
    this.audit(context, 'content.publication.published', revision.publishedRevisionId);
    return revision;
  }

  private publishEffect(
    revision: PublishedRevision,
    pointer: PublicationPointer,
    first: boolean,
    nowUtc: UtcInstant,
  ): ContentEffectV1 {
    const kind = first ? 'ContentPublished' : 'ContentRevisionActivated';
    return this.effectBase(
      revision,
      pointer,
      kind,
      `${revision.publishedRevisionId}:${kind}`,
      nowUtc,
    );
  }

  private effectBase(
    revision: PublishedRevision,
    pointer: PublicationPointer,
    kind: ContentEffectV1['kind'],
    effectId: string,
    nowUtc: UtcInstant,
  ): ContentEffectV1 {
    return deepFreeze({
      schemaVersion: 1,
      effectId,
      kind,
      contentId: revision.contentId,
      publishedRevisionId: revision.publishedRevisionId,
      pointerRevision: pointer.revision,
      visibility: pointer.visibility,
      typeId: revision.typeId,
      publisherRef: { ...revision.publisherRef },
      marketId: revision.marketId,
      referenceRevisions: { ...revision.referenceRevisions },
      occurredAtUtc: nowUtc,
    });
  }

  /**
   * Visibility changes are committed with the pointer and carry its revision, so
   * a consumer can drop stale replays and a tombstone always beats stale cache.
   */
  private async visibilityEffect(
    tx: ContentTransaction,
    pointer: PublicationPointer,
    nowUtc: UtcInstant,
  ): Promise<ContentEffectV1> {
    const current = pointer.currentPublishedRevisionId;
    const revision = current === null ? null : await tx.publishedRevision(current);
    if (revision === null) throw new ContentDomainRefusal('not_found');
    return this.effectBase(
      revision,
      pointer,
      'ContentVisibilityChanged',
      `${revision.contentId}:visibility:${pointer.revision}`,
      nowUtc,
    );
  }

  /** Owner withdrawal/archival: always allowed to reduce visibility, even if the type is later disabled. */
  private async withdraw(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'withdrawPublication' }>['payload'],
  ): Promise<PublicationPointer> {
    const { tx, nowUtc } = context;
    const draft = await tx.draftByContentId(payload.contentId);
    if (draft === null) throw new ContentDomainRefusal('not_found');
    // Taking content down is authorized by the publisher's current authority but
    // never by the type flag: a disabled type must still be withdrawable.
    await this.authorize(context, draft.publisherRef, draft.typeId, 'withdraw', draft.marketId);
    const pointer = await tx.pointer(payload.contentId);
    const next = withdrawByOwner(pointer, payload.expectedPointerRevision, payload.mode, nowUtc);
    tx.putPointer(next, pointer?.revision ?? 0);
    tx.effects.append(await this.visibilityEffect(tx, next, nowUtc));
    this.audit(context, `content.publication.${payload.mode}`, payload.contentId);
    return next;
  }

  /** Compatible rollback: select an earlier immutable revision, never edit history. */
  private async activate(
    context: CommandContext,
    payload: Extract<ContentCommandV1, { commandType: 'activatePublishedRevision' }>['payload'],
  ): Promise<PublicationPointer> {
    const { tx, nowUtc } = context;
    const draft = await tx.draftByContentId(payload.contentId);
    if (draft === null) throw new ContentDomainRefusal('not_found');
    const entry = this.usableType(draft.typeId, draft.typeSchemaMajor);
    await this.authorize(context, draft.publisherRef, draft.typeId, 'publish', draft.marketId);
    const target = await tx.publishedRevision(payload.publishedRevisionId);
    if (target === null || target.contentId !== payload.contentId)
      throw new ContentDomainRefusal('not_found');
    // Compatible = same type, still available, market and media still valid.
    if (target.typeId !== draft.typeId) throw new ContentDomainRefusal('content_type_unsupported');
    await this.resolveReferences(target.marketId, target.typeId, nowUtc);
    const media = await this.deps.media.check({
      contentId: target.contentId,
      typeId: target.typeId,
      mediaIds: entry.mediaIds?.(target.body) ?? [],
    });
    if (!media.ready) throw new ContentDomainRefusal('media_not_ready');
    const pointer = await tx.pointer(payload.contentId);
    if (pointer === null) throw new ContentDomainRefusal('not_found');
    // Re-selecting what is already public is a no-op conflict, not a new state.
    if (
      pointer.currentPublishedRevisionId === target.publishedRevisionId &&
      pointer.ownerHold === null &&
      pointer.moderationHold === null
    )
      throw new ContentDomainRefusal('revision_conflict');
    const next = activateRevision(
      pointer,
      payload.expectedPointerRevision,
      payload.contentId,
      target.publishedRevisionId,
      nowUtc,
    );
    tx.putPointer(next, pointer.revision);
    tx.effects.append(
      this.effectBase(
        target,
        next,
        'ContentRevisionActivated',
        `${target.publishedRevisionId}:ContentRevisionActivated:${next.revision}`,
        nowUtc,
      ),
    );
    this.audit(context, 'content.publication.rolled_back', target.publishedRevisionId);
    return next;
  }

  /**
   * System path for BCK-22 enforcement instructions. It verifies the instruction
   * through the moderation port first; unknown, unsigned, stale or foreign
   * instructions mutate nothing. Replays are idempotent by decision.
   */
  async applyModerationDisposition(
    rawCommand: unknown,
  ): Promise<ContentResult<ModerationAcknowledgementV1>> {
    const early = preflight(rawCommand, 'commandType');
    if (early !== undefined) return early;
    const parsed = await validateContentContract<
      ContentCommandV1 | { commandType: 'applyModerationDisposition'; payload: unknown }
    >('command', rawCommand);
    if (!parsed.ok) return rejected('invalid_contract');
    const command = parsed.value as ApplyModerationDispositionCommandV1;
    if (command.commandType !== 'applyModerationDisposition') return rejected('invalid_contract');
    const payload = command.payload;
    const nowUtc = this.now();
    const verification = await this.deps.moderation.verifyDisposition({ payload, nowUtc });
    if (!verification.verified) return rejected('capability_denied');
    // An instruction that is not yet in effect cannot be applied early.
    if (Date.parse(payload.effectiveAtUtc) > Date.parse(nowUtc))
      return rejected('moderation_decision_stale');
    const systemActor = `moderation:${verification.issuer}`;
    const semanticHash = sha256Hex(
      canonicalJson({
        algorithm: 'content_disposition_hash_v1',
        decisionId: payload.decisionId,
        disposition: payload.disposition,
        policyRevision: payload.policyRevision,
        reasonCategory: payload.reasonCategory,
        target: payload.target,
        restoresDecisionId: payload.restoresDecisionId ?? null,
      }),
    );
    const key = `${payload.decisionId}:${payload.disposition}`.slice(0, 128);
    try {
      return await this.deps.repository.transact(async (tx) => {
        const prior = await tx.idempotency(systemActor, 'applyModerationDisposition', key);
        if (prior !== null) {
          if (prior.semanticHash !== semanticHash)
            throw new ContentDomainRefusal('idempotency_conflict');
          const stored = deepFreeze(structuredClone(prior.outcome)) as ModerationAcknowledgementV1;
          return succeeded<ModerationAcknowledgementV1>({ ...stored, outcome: 'already_applied' });
        }
        const pointerRevision = await this.applyDisposition(tx, payload, systemActor, nowUtc);
        const ack: ModerationAcknowledgementV1 = {
          instructionId: payload.instructionId,
          decisionId: payload.decisionId,
          outcome: 'applied',
          disposition: payload.disposition,
          contentId: payload.target.contentId,
          pointerRevision,
        };
        tx.putIdempotency({
          actorUserId: systemActor,
          commandType: 'applyModerationDisposition',
          idempotencyKey: key,
          semanticHash,
          outcome: structuredClone(ack),
          createdAtUtc: nowUtc,
        });
        return succeeded(deepFreeze(ack));
      });
    } catch (error) {
      return this.toRefusal(error);
    }
  }

  private async applyDisposition(
    tx: ContentTransaction,
    payload: ApplyModerationDispositionCommandV1['payload'],
    systemActor: string,
    nowUtc: UtcInstant,
  ): Promise<number | null> {
    const { disposition, target, decisionId } = payload;
    if (
      disposition === 'approve' ||
      disposition === 'request_revision' ||
      disposition === 'reject'
    ) {
      // Exact submission only; a foreign or unknown target is a stale decision.
      const submission =
        target.submissionId === undefined ? null : await tx.submission(target.submissionId);
      if (submission === null || submission.contentId !== target.contentId)
        throw new ContentDomainRefusal('moderation_decision_stale');
      const updated = applyReviewDisposition(submission, disposition, decisionId, nowUtc);
      tx.putSubmission(updated);
      if (disposition !== 'approve') {
        const draft = await tx.draft(submission.draftId);
        // The draft returns to the author only if it is still the reviewed one.
        if (
          draft !== null &&
          draft.status === 'submitted' &&
          draft.revision === submission.draftRevision
        )
          tx.putDraft(
            withDraftStatus(
              draft,
              disposition === 'reject' ? 'editing' : 'revision_requested',
              nowUtc,
            ),
          );
      }
      this.auditAs(
        tx,
        systemActor,
        `content.moderation.${disposition}`,
        submission.submissionId,
        nowUtc,
      );
      return null;
    }
    const pointer = await tx.pointer(target.contentId);
    let next: PublicationPointer;
    if (disposition === 'restore') {
      if (payload.restoresDecisionId === undefined)
        throw new ContentDomainRefusal('moderation_decision_stale');
      next = restoreModerationHold(pointer, payload.restoresDecisionId, nowUtc);
    } else {
      next = applyModerationHold(
        pointer,
        target.publishedRevisionId,
        disposition === 'withdraw' ? 'withdrawn' : 'restricted',
        decisionId,
        nowUtc,
      );
    }
    tx.putPointer(next, pointer?.revision ?? 0);
    tx.effects.append(await this.visibilityEffect(tx, next, nowUtc));
    this.auditAs(tx, systemActor, `content.moderation.${disposition}`, target.contentId, nowUtc);
    return next.revision;
  }

  private usableType(typeId: ContentTypeId, storedSchemaMajor?: number): ContentTypeRegistryEntry {
    const entry = resolveContentType(typeId);
    if (entry === null || !isContentTypeAvailable(entry))
      throw new ContentDomainRefusal('content_type_unsupported');
    // A stored record from a newer/incompatible type schema is never coerced.
    if (storedSchemaMajor !== undefined && storedSchemaMajor !== entry.typeSchemaMajor)
      throw new ContentDomainRefusal('unsupported_version');
    if (!this.deps.enabledTypes.has(typeId)) throw new ContentDomainRefusal('type_disabled');
    return entry;
  }

  private assertValid(
    entry: ContentTypeRegistryEntry,
    draft: ContentDraft,
    resolved: ResolvedReferences,
    nowUtc: UtcInstant,
    actorUserId: string,
  ): void {
    const context: ContentValidationContext = {
      typeId: draft.typeId,
      marketId: draft.marketId,
      publisherRef: draft.publisherRef,
      createdByUserId: draft.createdByUserId,
      actorUserId,
      nowUtc,
      draftRevision: draft.revision,
      ...(this.deps.publishedObjects === undefined
        ? {}
        : { publishedObjects: this.deps.publishedObjects }),
      market: resolved.market,
      lookups: resolved.lookups,
    };
    const issues = entry.validate?.(draft.body, context) ?? ['no_source_contract'];
    if (issues.length > 0) throw new ContentDomainRefusal('validation_failed');
  }

  private async assertMediaReady(
    entry: ContentTypeRegistryEntry,
    draft: ContentDraft,
  ): Promise<string> {
    const readiness = await this.deps.media.check({
      contentId: draft.contentId,
      typeId: draft.typeId,
      mediaIds: entry.mediaIds?.(draft.body) ?? [],
    });
    if (!readiness.ready) throw new ContentDomainRefusal('media_not_ready');
    return readiness.mediaRevision;
  }

  private async resolveReferences(
    marketId: MarketId,
    typeId: ContentTypeId,
    nowUtc: UtcInstant,
  ): Promise<ResolvedReferences> {
    const resolution = await this.deps.referenceData.resolve({ marketId, typeId, nowUtc });
    if (!resolution.ok) throw new ContentDomainRefusal(resolution.code);
    return resolution;
  }

  private async pin(
    marketId: MarketId,
    typeId: ContentTypeId,
    nowUtc: UtcInstant,
  ): Promise<ContentReferenceRevisionsV1> {
    return (await this.resolveReferences(marketId, typeId, nowUtc)).revisions;
  }

  private async authorize(
    context: CommandContext,
    publisherRef: PublisherRefV1,
    typeId: ContentTypeId,
    action: ContentAction,
    marketId: MarketId,
  ): Promise<PublisherEligibilityV1> {
    const entry = resolveContentType(typeId);
    if (entry === null) throw new ContentDomainRefusal('content_type_unsupported');
    const result = await this.deps.eligibility.evaluate({
      actor: context.actor,
      publisherRef,
      typeId,
      action,
      marketId,
      requiredCapability: entry.requiredCapabilities[action],
      nowUtc: context.nowUtc,
    });
    // A response about another publisher is never accepted as authority.
    const sameRef =
      result.publisherRef.type === publisherRef.type && result.publisherRef.id === publisherRef.id;
    if (result.eligible && sameRef) return result;
    throw new ContentDomainRefusal(sameRef ? failureFor(result.reason) : 'publisher_not_eligible');
  }

  private audit(context: CommandContext, action: string, subjectId: string): void {
    this.auditAs(context.tx, context.actor.userId, action, subjectId, context.nowUtc);
  }

  private auditAs(
    tx: ContentTransaction,
    actorUserId: string,
    action: string,
    subjectId: string,
    nowUtc: UtcInstant,
  ): void {
    tx.appendAudit({
      auditId: this.deps.ids.newId(),
      occurredAtUtc: nowUtc,
      actorUserId,
      action,
      subjectId,
      outcome: 'succeeded',
    });
  }
}

function failureFor(reason: PublisherEligibilityV1['reason']): ContentFailureCode {
  switch (reason) {
    case 'creator_verification_required':
      return 'creator_verification_required';
    case 'membership_inactive':
      return 'membership_inactive';
    case 'capability_denied':
      return 'capability_denied';
    default:
      return 'publisher_not_eligible';
  }
}

/** Early, contract-independent rejection of newer schemas and unknown types. */
function preflight(raw: unknown, discriminator: 'commandType' | 'queryType') {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw))
    return rejected('invalid_contract');
  const record = raw as Record<string, unknown>;
  if (typeof record.schemaVersion === 'number' && record.schemaVersion !== 1)
    return unsupported('unsupported_version');
  const payload = record.payload;
  if (
    discriminator === 'commandType' &&
    record.commandType === 'createDraft' &&
    typeof payload === 'object' &&
    payload !== null &&
    'typeId' in payload &&
    resolveContentType((payload as Record<string, unknown>).typeId) === null
  )
    return unsupported('content_type_unsupported');
  return undefined;
}

export const registeredContentTypeIds = contentTypeRegistry.map((item) => item.typeId);
export type { PublicationPointer };
