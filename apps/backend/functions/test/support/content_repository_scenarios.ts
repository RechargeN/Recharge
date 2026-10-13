import assert from 'node:assert/strict';

import type { ContentEffectV1, MediaAttachmentV1 } from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import { ContentIntegrityRecovery } from '../../src/modules/content/application/content_integrity_recovery.js';
import {
  ContentPublicationService,
  type ContentPublicationServiceDeps,
} from '../../src/modules/content/application/content_publication_service.js';
import type { MediaReadinessPort } from '../../src/modules/content/application/ports/media_readiness_port.js';
import type { ModerationDispositionPort } from '../../src/modules/content/application/ports/moderation_disposition_port.js';
import type {
  ContentActor,
  DelegatedEligibilityRequest,
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import type { ReferenceDataPort } from '../../src/modules/content/application/ports/reference_data_port.js';
import {
  createContentDraft,
  directProvenance,
  importProvenance,
  rollBackImportedDraft,
  withDraftStatus,
  type ContentDraft,
} from '../../src/modules/content/domain/content_draft.js';
import {
  openImportGeneration,
  rollBackBinding,
} from '../../src/modules/content/domain/local_import_binding.js';
import {
  ContentDomainRefusal,
  ContentRepositoryConflict,
} from '../../src/modules/content/domain/failures.js';
import {
  activateRevision,
  type PublicationPointer,
} from '../../src/modules/content/domain/publication_pointer.js';
import { createPublicationSubmission } from '../../src/modules/content/domain/publication_submission.js';
import {
  canonicalJson,
  createPublishedRevision,
} from '../../src/modules/content/domain/published_revision.js';
import type { ContentRepository } from '../../src/modules/content/domain/repositories.js';
import type { ContentStorageLimits } from '../../src/modules/content/domain/storage_limits.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

/**
 * One scenario suite executed against every Content repository adapter
 * (BCK-07 v0.12 §38.8). The in-memory adapter runs it in the integration suite,
 * the Firestore adapter in the Emulator suite; both must behave identically.
 */
export type RepositoryFactory = (limits?: Partial<ContentStorageLimits>) => ContentRepository;

export interface ContentScenario {
  readonly name: string;
  readonly run: (make: RepositoryFactory) => Promise<void>;
}

const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
export function newId(): EntityId {
  let value = '01';
  for (let index = 0; index < 24; index += 1)
    value += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  return value as EntityId;
}
const uniqueToken = (): string => newId().slice(2);

const now = parseUtcInstant('2026-09-30T10:00:00.000Z');
const later = parseUtcInstant('2026-09-30T10:05:00.000Z');
const references = {
  marketConfigRevisionId: 'mc-lv-1',
  taxonomyRevisionId: 'tx-1',
  localizationRevisionId: 'loc-1',
};

const placeBody = {
  title: 'Vermanes garden greenhouse',
  placeKind: 'managedVenue',
  relationshipToPlace: 'owner',
  shortDescription: 'Historic glass greenhouse in the city centre',
  contentLocale: 'en',
  categoryId: 'art_culture_museums',
  subcategoryId: 'museum',
  location: {
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    formattedAddress: 'Elizabetes iela 1, Riga',
    point: { latitude: 56.9496, longitude: 24.1052 },
    timezoneId: 'Europe/Riga',
    accuracy: 'rooftop',
    pinConfirmed: true,
  },
  hours: {
    mode: 'regular',
    weeklyPeriods: [
      { id: 'period-1', dayOfWeek: 1, openMinute: 600, closeMinute: 1140, closesNextDay: false },
    ],
    seasons: [],
    exceptions: [],
  },
  operationalStatus: { status: 'operating' },
  pricing: { entryType: 'paid', entryPriceFrom: 700, currencyCode: 'EUR' },
  media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
  provenance: {
    sourceType: 'ownerSubmission',
    submittedByUserId: '01000000000000000000000001',
    relationshipClaim: 'owner',
    createdAtUtc: '2026-09-30T09:00:00.000Z',
    lastConfirmedAtUtc: '2026-09-30T09:00:00.000Z',
  },
};

export function bodyFor(owner: string): Record<string, unknown> {
  return { ...placeBody, provenance: { ...placeBody.provenance, submittedByUserId: owner } };
}

function bodyWithMedia(...mediaIds: string[]) {
  return {
    ...placeBody,
    media: {
      ...(mediaIds[0] === undefined ? {} : { coverImage: { mediaId: mediaIds[0] } }),
      gallery: mediaIds.slice(1).map((mediaId) => ({ mediaId })),
    },
  };
}

function draftOf(input: {
  contentId?: EntityId;
  draftId?: EntityId;
  mediaIds?: string[];
  binding?: string;
  body?: Record<string, unknown>;
  owner?: EntityId;
  importSourceKey?: string;
  importGeneration?: number;
}): ContentDraft {
  const owner = input.owner ?? newId();
  return createContentDraft({
    draftId: input.draftId ?? newId(),
    contentId: input.contentId ?? newId(),
    typeId: 'place',
    publisherRef: { type: 'user', id: owner },
    marketId: 'LV',
    body: input.body ?? bodyWithMedia(...(input.mediaIds ?? [])),
    referenceRevisions: references,
    createdByUserId: input.binding === undefined ? owner : null,
    provenance:
      input.binding === undefined
        ? directProvenance(owner)
        : importProvenance({
            kind: 'delegatedImport',
            delegatedActorRef: 'module:event-ingestion/syncSource',
            externalBindingRef: input.binding,
            sourceId: 'src-1',
            sourceRevision: '1',
            acquiredAtUtc: now,
            correctionRemovalPolicyRef: 'removal-policy-1',
          }),
    ...(input.importSourceKey === undefined ? {} : { importSourceKey: input.importSourceKey }),
    ...(input.importGeneration === undefined ? {} : { importGeneration: input.importGeneration }),
    nowUtc: now,
  });
}

function submissionOf(draft: ContentDraft) {
  return createPublicationSubmission({
    submissionId: newId(),
    draft,
    moderation: {
      profileId: 'place.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'pol-1',
      policyDecisionId: 'pd-1',
    },
    eligibilityAuthorityRevision: 1,
    referenceRevisions: references,
    nowUtc: now,
  });
}

function revisionOf(
  draft: ContentDraft,
  number: number,
  attachments: readonly MediaAttachmentV1[] = [],
) {
  return createPublishedRevision({
    publishedRevisionId: newId(),
    revisionNumber: number,
    draft,
    submission: submissionOf(draft),
    referenceRevisions: references,
    mediaRevision: 'media-1',
    mediaAttachments: attachments,
    nowUtc: later,
  });
}

function pointerFor(revisionId: EntityId, contentId: EntityId, expected = 0): PublicationPointer {
  return activateRevision(null, expected, contentId, revisionId, later);
}

function effectOf(contentId: EntityId, revisionId: EntityId, pointerRevision: number) {
  return {
    schemaVersion: 1,
    effectId: `${revisionId}:ContentPublished:${String(pointerRevision)}`,
    kind: 'ContentPublished',
    contentId,
    publishedRevisionId: revisionId,
    pointerRevision,
    visibility: 'visible',
    typeId: 'place',
    publisherRef: { type: 'user', id: newId() },
    marketId: 'LV',
    referenceRevisions: references,
    occurredAtUtc: later,
  } as ContentEffectV1;
}

/** Every stored effect of a Content, read page by page (never a single unbounded read). */
async function allEffects(
  tx: Parameters<Parameters<ContentRepository['transact']>[0]>[0],
  contentId: string,
): Promise<ContentEffectV1[]> {
  const found: ContentEffectV1[] = [];
  let cursor: { pointerRevision: number; effectId: string } | null = null;
  for (;;) {
    const page: readonly ContentEffectV1[] = await tx.effectsPage(contentId, cursor, 2);
    found.push(...page);
    const last = page[page.length - 1];
    if (last === undefined || page.length < 2) return found;
    cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
  }
}

const refusalCode = (code: string) => (error: unknown) =>
  error instanceof ContentDomainRefusal && error.code === code;
const conflict = (reason: string) => (error: unknown) =>
  error instanceof ContentRepositoryConflict && error.reason === reason;

// ---------------------------------------------------------------------------
// Repository-level scenarios
// ---------------------------------------------------------------------------

export const repositoryScenarios: readonly ContentScenario[] = [
  {
    name: 'a draft round-trips exactly and is found by id, content and external binding',
    async run(make) {
      const repository = make();
      const binding = `src-1|${uniqueToken()}|`;
      const plainDraft = draftOf({});
      const imported = draftOf({ binding });
      await repository.transact((tx) => {
        tx.putDraft(plainDraft);
        tx.putDraft(imported);
      });
      await repository.transact(async (tx) => {
        assert.deepEqual(await tx.draft(plainDraft.draftId), plainDraft);
        assert.deepEqual(await tx.draftByContentId(plainDraft.contentId), plainDraft);
        assert.deepEqual(await tx.draftByExternalBinding(binding), imported);
        assert.equal(await tx.draft(newId()), null);
        assert.equal(await tx.draftByContentId(newId()), null);
        assert.equal(await tx.draftByExternalBinding(`src-1|${uniqueToken()}|`), null);
        assert.equal(Object.isFrozen(await tx.draft(plainDraft.draftId)), true);
      });
    },
  },
  {
    name: 'a body with nested arrays and unusual keys survives storage unchanged',
    async run(make) {
      const repository = make();
      const draft = draftOf({
        body: {
          ...placeBody,
          geometry: [
            [1, 2],
            [3, 4],
          ],
          'odd key': { nested: [[], [[5]]], empty: {}, zero: 0, no: false, nothing: null },
        },
      });
      await repository.transact((tx) => {
        tx.putDraft(draft);
      });
      const stored = await repository.transact((tx) => tx.draft(draft.draftId));
      assert.equal(canonicalJson(stored?.body), canonicalJson(draft.body));
    },
  },
  {
    name: 'a read after a staged write sees it, for single documents and lists',
    async run(make) {
      const repository = make();
      const draft = draftOf({});
      const submission = submissionOf(draft);
      await repository.transact(async (tx) => {
        tx.putDraft(draft);
        tx.putSubmission(submission);
        assert.deepEqual(await tx.draft(draft.draftId), draft);
        assert.deepEqual(await tx.draftByContentId(draft.contentId), draft);
        assert.deepEqual(await tx.submission(submission.submissionId), submission);
        assert.deepEqual(await tx.submissionsForContent(draft.contentId), [submission]);
      });
      await repository.transact(async (tx) => {
        assert.deepEqual(await tx.submissionsForContent(draft.contentId), [submission]);
      });
    },
  },
  {
    name: 'two staged changes to one document leave the last one and one stored document',
    async run(make) {
      const repository = make();
      const first = draftOf({});
      const second = withDraftStatus(first, 'ready', later);
      await repository.transact(async (tx) => {
        tx.putDraft(first);
        tx.putDraft(second);
        assert.equal((await tx.draft(first.draftId))?.status, 'ready');
        assert.equal(((await tx.draftByContentId(first.contentId)) ?? first).status, 'ready');
      });
      await repository.transact(async (tx) => {
        assert.equal((await tx.draft(first.draftId))?.status, 'ready');
      });
    },
  },
  {
    name: 'a published revision is immutable within and across transactions',
    async run(make) {
      const repository = make();
      const draft = draftOf({});
      const revision = revisionOf(draft, 1);
      await repository.transact((tx) => {
        tx.putPublishedRevision(revision);
      });
      await assert.rejects(
        repository.transact((tx) => {
          tx.putPublishedRevision(revision);
        }),
        conflict('immutable_revision'),
      );
      const other = revisionOf(draft, 2);
      await assert.rejects(
        repository.transact((tx) => {
          tx.putPublishedRevision(other);
          tx.putPublishedRevision(other);
        }),
        conflict('immutable_revision'),
      );
      await repository.transact(async (tx) => {
        assert.deepEqual(await tx.publishedRevision(revision.publishedRevisionId), revision);
        assert.equal(await tx.publishedRevision(other.publishedRevisionId), null);
        assert.deepEqual(
          (await tx.publishedRevisionsForContent(draft.contentId)).map(
            (item) => item.publishedRevisionId,
          ),
          [revision.publishedRevisionId],
        );
      });
    },
  },
  {
    name: 'the pointer swap is compare-and-set on its stored revision',
    async run(make) {
      const repository = make();
      const contentId = newId();
      const revisionId = newId();
      const first = pointerFor(revisionId, contentId);
      await repository.transact((tx) => {
        tx.putPointer(first, 0);
      });
      await assert.rejects(
        repository.transact((tx) => {
          tx.putPointer(first, 0);
        }),
        conflict('pointer_revision'),
      );
      const next = activateRevision(first, first.revision, contentId, newId(), later);
      await repository.transact((tx) => {
        tx.putPointer(next, first.revision);
      });
      await repository.transact(async (tx) => {
        assert.deepEqual(await tx.pointer(contentId), next);
      });
    },
  },
  {
    name: 'only one of several concurrent pointer swaps wins the same expected revision',
    async run(make) {
      const repository = make();
      const contentId = newId();
      const results = await Promise.allSettled(
        Array.from({ length: 4 }, () =>
          repository.transact(async (tx) => {
            await tx.pointer(contentId);
            tx.putPointer(pointerFor(newId(), contentId), 0);
          }),
        ),
      );
      assert.equal(results.filter((item) => item.status === 'fulfilled').length, 1);
      for (const item of results)
        if (item.status === 'rejected') assert.ok(conflict('pointer_revision')(item.reason));
      await repository.transact(async (tx) => {
        assert.equal((await tx.pointer(contentId))?.revision, 1);
      });
    },
  },
  {
    name: 'a refused or failed transaction stores nothing at all',
    async run(make) {
      const repository = make();
      const draft = draftOf({});
      const revision = revisionOf(draft, 1);
      const contentId = draft.contentId;
      // A stale pointer expectation is checked at commit, after other writes were staged.
      await assert.rejects(
        repository.transact(async (tx) => {
          tx.putDraft(draft);
          tx.putPublishedRevision(revision);
          tx.appendAudit({
            auditId: newId(),
            occurredAtUtc: later,
            actorUserId: newId(),
            action: 'x',
            subjectId: contentId,
            outcome: 'succeeded',
          });
          tx.effects.append(effectOf(contentId, revision.publishedRevisionId, 1));
          tx.putPointer(pointerFor(revision.publishedRevisionId, contentId), 5);
          await Promise.resolve();
        }),
        conflict('pointer_revision'),
      );
      await assert.rejects(
        repository.transact(async (tx) => {
          tx.putDraft(draft);
          await Promise.resolve();
          throw new Error('operation failed after staging');
        }),
        /operation failed/u,
      );
      await repository.transact(async (tx) => {
        assert.equal(await tx.draft(draft.draftId), null);
        assert.equal(await tx.publishedRevision(revision.publishedRevisionId), null);
        assert.equal(await tx.pointer(contentId), null);
        assert.deepEqual(await allEffects(tx, contentId), []);
      });
    },
  },
  {
    name: 'idempotency records are keyed by actor, command and key and keep the full outcome',
    async run(make) {
      const repository = make();
      const actor = newId();
      const key = `key-${uniqueToken()}`;
      const outcome = { nested: [[1, 2], [3]], list: [{ a: 1 }], text: 'ok', nothing: null };
      const record = {
        actorUserId: actor,
        commandType: 'createDraft',
        idempotencyKey: key,
        semanticHash: 'a'.repeat(64),
        outcome,
        authorizations: [],
        createdAtUtc: later,
      };
      await repository.transact((tx) => {
        tx.putIdempotency(record);
      });
      await repository.transact(async (tx) => {
        assert.deepEqual(await tx.idempotency(actor, 'createDraft', key), record);
        assert.equal(await tx.idempotency(actor, 'updateDraft', key), null);
        assert.equal(await tx.idempotency(newId(), 'createDraft', key), null);
        // Key material never bleeds across the actor boundary.
        assert.equal(await tx.idempotency(`${actor}|createDraft`, '', key), null);
      });
    },
  },
  {
    name: 'audit and effects are create-only and effects replay in pointer revision order',
    async run(make) {
      const repository = make();
      const contentId = newId();
      const revisionId = newId();
      const third = effectOf(contentId, revisionId, 3);
      const first = effectOf(contentId, revisionId, 1);
      const second = {
        ...effectOf(contentId, revisionId, 2),
        kind: 'ContentVisibilityChanged' as const,
      };
      const auditId = newId();
      await repository.transact((tx) => {
        tx.effects.append(third);
        tx.effects.append(first);
        tx.effects.append(second);
        tx.appendAudit({
          auditId,
          occurredAtUtc: later,
          actorUserId: newId(),
          action: 'x',
          subjectId: contentId,
          outcome: 'succeeded',
        });
      });
      await repository.transact(async (tx) => {
        assert.deepEqual(
          (await allEffects(tx, contentId)).map((item) => item.pointerRevision),
          [1, 2, 3],
        );
        assert.deepEqual(await allEffects(tx, newId()), []);
      });
      await assert.rejects(
        repository.transact((tx) => {
          tx.effects.append(first);
        }),
        conflict('duplicate_id'),
      );
      await assert.rejects(
        repository.transact((tx) => {
          tx.appendAudit({
            auditId,
            occurredAtUtc: later,
            actorUserId: newId(),
            action: 'y',
            subjectId: contentId,
            outcome: 'succeeded',
          });
        }),
        conflict('duplicate_id'),
      );
    },
  },
  {
    name: 'stored effects are read in stable pages, ties included, with no cap on history length',
    async run(make) {
      const repository = make();
      const contentId = newId();
      const revisionId = newId();
      const total = 1100;
      for (let start = 1; start <= total; start += 300)
        await repository.transact((tx) => {
          for (let revision = start; revision < start + 300 && revision <= total; revision += 1)
            tx.effects.append(effectOf(contentId, revisionId, revision));
        });
      // Two effects at one pointer revision keep a total order through the cursor.
      await repository.transact((tx) => {
        tx.effects.append({
          ...effectOf(contentId, revisionId, 5),
          effectId: `${revisionId}:ContentVisibilityChanged:5`,
          kind: 'ContentVisibilityChanged',
        });
      });
      const seen: string[] = [];
      let cursor: { pointerRevision: number; effectId: string } | null = null;
      let pages = 0;
      for (;;) {
        const at: typeof cursor = cursor;
        const page: readonly ContentEffectV1[] = await repository.transact((tx) =>
          tx.effectsPage(contentId, at, 250),
        );
        pages += 1;
        seen.push(...page.map((item) => item.effectId));
        const last = page[page.length - 1];
        if (last === undefined || page.length < 250) break;
        cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
      }
      assert.equal(seen.length, total + 1);
      assert.equal(new Set(seen).size, total + 1);
      assert.ok(pages >= 5);
      const ordered = await repository.transact(async (tx) => allEffects(tx, contentId));
      assert.equal(ordered.length, total + 1);
      assert.deepEqual(
        ordered.map((item) => item.effectId),
        seen,
      );
      // The very last effect is reachable however long the history is.
      const tail = await repository.transact((tx) =>
        tx.effectsPage(contentId, { pointerRevision: total - 1, effectId: '￿' }, 1),
      );
      assert.equal(tail[0]?.pointerRevision, total);
    },
  },
  {
    name: 'integrity verification finds the current effect however long the effect history is',
    async run(make) {
      const repository = make();
      const draft = draftOf({});
      const revision = revisionOf(draft, 1);
      const contentId = draft.contentId;
      await repository.transact((tx) => {
        tx.putPublishedRevision(revision);
        tx.effects.append(effectOf(contentId, revision.publishedRevisionId, 1));
        tx.putPointer(
          { ...pointerFor(revision.publishedRevisionId, contentId), revision: 1300 },
          0,
        );
      });
      for (let start = 2; start <= 1300; start += 300)
        await repository.transact((tx) => {
          for (let value = start; value < start + 300 && value <= 1300; value += 1)
            tx.effects.append({
              ...effectOf(contentId, revision.publishedRevisionId, value),
              kind: 'ContentVisibilityChanged',
              effectId: `${revision.publishedRevisionId}:ContentVisibilityChanged:${String(value)}`,
            });
        });
      const report = await new ContentIntegrityRecovery(repository).verify(contentId);
      assert.deepEqual(report.findings, []);
      const seen: number[] = [];
      const delivered = await new ContentIntegrityRecovery(repository).replayEffects(
        contentId,
        (effect) => {
          seen.push(effect.pointerRevision);
          return Promise.resolve();
        },
        1200,
        7,
      );
      assert.equal(delivered, 100);
      assert.deepEqual(
        seen,
        Array.from({ length: 100 }, (_, index) => 1201 + index),
      );
    },
  },
  {
    name: 'media references are found in drafts and in published revisions, staged writes included',
    async run(make) {
      const repository = make();
      const draftAsset = `media-${uniqueToken()}`;
      const revisionAsset = newId();
      const draft = draftOf({ mediaIds: [draftAsset] });
      const revision = revisionOf(draftOf({}), 1, [
        {
          assetId: revisionAsset,
          sourceGeneration: 'g-1',
          variantManifestRevision: 'b'.repeat(64),
          purpose: 'contentMedia',
        },
      ]);
      await repository.transact((tx) => {
        tx.putDraft(draft);
        tx.putPublishedRevision(revision);
      });
      await repository.transact(async (tx) => {
        assert.equal(await tx.isMediaReferenced(draftAsset), true);
        assert.equal(await tx.isMediaReferenced(revisionAsset), true);
        assert.equal(await tx.isMediaReferenced(`media-${uniqueToken()}`), false);
        // Dropping the reference in the same transaction is visible to the check.
        tx.putDraft(draftOf({ draftId: draft.draftId, contentId: draft.contentId }));
        assert.equal(await tx.isMediaReferenced(draftAsset), false);
        assert.equal(await tx.isMediaReferenced(revisionAsset), true);
      });
    },
  },
  {
    name: 'one external source record binds to at most one draft',
    async run(make) {
      const repository = make();
      const binding = `src-1|${uniqueToken()}|`;
      const first = draftOf({ binding });
      await repository.transact((tx) => {
        tx.putDraft(first);
      });
      await assert.rejects(
        repository.transact((tx) => {
          tx.putDraft(draftOf({ binding }));
        }),
        conflict('duplicate_id'),
      );
      // The same draft can be updated under its own binding.
      await repository.transact((tx) => {
        tx.putDraft(withDraftStatus(first, 'ready', later));
      });
      await repository.transact(async (tx) => {
        assert.equal((await tx.draftByExternalBinding(binding))?.status, 'ready');
      });
    },
  },
  {
    name: "D4: one author's local import source binds to at most one draft",
    async run(make) {
      const repository = make();
      const owner = newId();
      const source = `loc_${uniqueToken()}`;
      const first = draftOf({ owner, importSourceKey: source });
      await repository.transact((tx) => {
        tx.putImportBinding(openImportGeneration(owner, source, null, first.draftId), 0);
        tx.putDraft(first);
      });
      // D4.1: the binding is a compare-and-set; a second first generation is refused.
      await assert.rejects(
        repository.transact((tx) => {
          const second = draftOf({ owner, importSourceKey: source });
          tx.putImportBinding(openImportGeneration(owner, source, null, second.draftId), 0);
          tx.putDraft(second);
        }),
        conflict('binding_revision'),
      );
      // Another author may import a local draft with the same local key.
      const other = draftOf({ importSourceKey: source });
      await repository.transact((tx) => {
        tx.putImportBinding(
          openImportGeneration(other.createdByUserId!, source, null, other.draftId),
          0,
        );
        tx.putDraft(other);
        // The same draft is updated under its own binding.
        tx.putDraft(withDraftStatus(first, 'ready', later));
      });
      await repository.transact(async (tx) => {
        assert.equal((await tx.draftByImportSource(owner, source))?.draftId, first.draftId);
        assert.equal((await tx.draftByImportSource(owner, source))?.status, 'ready');
        assert.equal(
          (await tx.draftByImportSource(other.createdByUserId!, source))?.draftId,
          other.draftId,
        );
        assert.equal(await tx.draftByImportSource(owner, `loc_${uniqueToken()}`), null);
        assert.equal(await tx.draftByImportSource(newId(), source), null);
        assert.equal((await tx.importBinding(owner, source))?.generation, 1);
        assert.equal(await tx.importBinding(newId(), source), null);
      });
    },
  },
  {
    name: 'D4.1: a rolled-back generation is a tombstone and the next one binds one new draft',
    async run(make) {
      const repository = make();
      const owner = newId();
      const source = `loc_${uniqueToken()}`;
      const asset = `media-${uniqueToken()}`;
      const first = draftOf({
        owner,
        importSourceKey: source,
        importGeneration: 1,
        mediaIds: [asset],
      });
      const g1 = openImportGeneration(owner, source, null, first.draftId);
      await repository.transact((tx) => {
        tx.putImportBinding(g1, 0);
        tx.putDraft(first);
      });
      await repository.transact(async (tx) => {
        assert.equal(await tx.isMediaReferenced(asset), true);
      });
      const rolled = rollBackBinding(g1, later);
      await repository.transact((tx) => {
        tx.putImportBinding(rolled, g1.bindingRevision);
        tx.putDraft(rollBackImportedDraft(first, first.revision, later));
      });
      await repository.transact(async (tx) => {
        assert.equal(await tx.draftByImportSource(owner, source), null);
        assert.equal((await tx.importBinding(owner, source))?.state, 'rolledBack');
        assert.equal((await tx.draft(first.draftId))?.status, 'rolledBack');
        // The tombstone keeps its body, but it no longer holds the Media asset.
        assert.deepEqual((await tx.draft(first.draftId))?.body, first.body);
        assert.equal(await tx.isMediaReferenced(asset), false);
      });
      // A writer holding the old binding revision loses the compare-and-set.
      await assert.rejects(
        repository.transact((tx) => {
          tx.putImportBinding(rollBackBinding(g1, later), g1.bindingRevision);
        }),
        conflict('binding_revision'),
      );
      const second = draftOf({
        owner,
        importSourceKey: source,
        importGeneration: 2,
        mediaIds: [asset],
      });
      await repository.transact(async (tx) => {
        const stored = await tx.importBinding(owner, source);
        assert.ok(stored);
        tx.putImportBinding(
          openImportGeneration(owner, source, stored, second.draftId),
          stored.bindingRevision,
        );
        tx.putDraft(second);
      });
      await repository.transact(async (tx) => {
        assert.equal((await tx.draftByImportSource(owner, source))?.draftId, second.draftId);
        const binding = await tx.importBinding(owner, source);
        assert.equal(binding?.generation, 2);
        assert.equal(binding?.state, 'active');
        assert.equal(binding?.bindingRevision, 3);
        assert.equal(binding?.cleanup, null);
        assert.equal(await tx.isMediaReferenced(asset), true);
        assert.equal((await tx.draft(first.draftId))?.status, 'rolledBack');
      });
    },
  },
  {
    name: 'history and document size are bounded with a typed refusal and nothing is written',
    async run(make) {
      const repository = make({
        maxRevisionsPerContent: 2,
        maxSubmissionsPerContent: 2,
        maxDocumentBytes: 4000,
      });
      const draft = draftOf({});
      await repository.transact((tx) => {
        tx.putPublishedRevision(revisionOf(draft, 1));
        tx.putPublishedRevision(revisionOf(draft, 2));
        tx.putSubmission(submissionOf(draft));
        tx.putSubmission(submissionOf(draft));
      });
      await assert.rejects(
        repository.transact((tx) => {
          tx.putPublishedRevision(revisionOf(draft, 3));
        }),
        refusalCode('storage_limit_exceeded'),
      );
      await assert.rejects(
        repository.transact((tx) => {
          tx.putSubmission(submissionOf(draft));
        }),
        refusalCode('storage_limit_exceeded'),
      );
      // Another Content has its own room.
      await repository.transact((tx) => {
        tx.putPublishedRevision(revisionOf(draftOf({}), 1));
      });
      // The whole persisted document counts, an idempotency outcome included.
      await assert.rejects(
        repository.transact((tx) => {
          tx.putIdempotency({
            actorUserId: newId(),
            commandType: 'createDraft',
            idempotencyKey: `key-${uniqueToken()}`,
            semanticHash: 'a'.repeat(64),
            outcome: { blob: 'x'.repeat(5000) },
            authorizations: [],
            createdAtUtc: later,
          });
        }),
        refusalCode('storage_limit_exceeded'),
      );
      await repository.transact(async (tx) => {
        assert.equal((await tx.publishedRevisionsForContent(draft.contentId)).length, 2);
        assert.equal((await tx.submissionsForContent(draft.contentId)).length, 2);
      });
    },
  },
];

// ---------------------------------------------------------------------------
// Service-level scenarios: the real Content service over the adapter
// ---------------------------------------------------------------------------

class Eligibility implements PublisherEligibilityPort {
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    return Promise.resolve(this.result(request.publisherRef, request.nowUtc));
  }
  evaluateDelegated(request: DelegatedEligibilityRequest): Promise<PublisherEligibilityV1> {
    return Promise.resolve(this.result(request.publisherRef, request.nowUtc));
  }
  private result(
    publisherRef: PublisherEligibilityV1['publisherRef'],
    nowUtc: string,
  ): PublisherEligibilityV1 {
    return {
      schemaVersion: 1,
      publisherRef,
      eligible: true,
      reason: 'eligible',
      authorityRevision: 7,
      evaluatedAtUtc: nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    };
  }
}

const referenceData: ReferenceDataPort = {
  resolve: () =>
    Promise.resolve({
      ok: true,
      revisions: references,
      market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
      lookups: {
        supportsLocale: (locale: string) => ['en', 'ru', 'lv'].includes(locale),
        subcategoryApplies: () => true,
        requiredCriteria: () => [] as readonly string[],
        pointInServiceArea: (latitude: number, longitude: number) =>
          latitude > 56 && latitude < 58 && longitude > 23 && longitude < 25.5,
      },
    } as const),
};

const moderation: ModerationDispositionPort = {
  verifyDisposition: () => Promise.resolve({ verified: false } as const),
  profileFor: () =>
    Promise.resolve({
      available: true,
      profileId: 'place.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'pol-1',
      policyDecisionId: 'pd-1',
    } as const),
};

export function servicePorts(
  attachments: MediaAttachmentV1[] = [],
): Omit<ContentPublicationServiceDeps, 'repository'> {
  const media: MediaReadinessPort = {
    check: () =>
      Promise.resolve({
        ready: true,
        mediaRevision: 'media-1',
        attachments,
        confirmations: attachments.map((item) => ({ assetId: item.assetId, revocationEpoch: 0 })),
      } as const),
  };
  return {
    eligibility: new Eligibility(),
    referenceData,
    moderation,
    media,
    clock: { now: () => new Date('2026-09-30T10:00:00.000Z') },
    ids: { newId },
    enabledTypes: new Set(['place'] as const),
    delegatedModules: new Map([
      [
        'event-ingestion',
        { operations: new Set(['syncSource']), typeIds: new Set(['event'] as const) },
      ],
    ]),
  };
}

function serviceOver(repository: ContentRepository, attachments: MediaAttachmentV1[] = []) {
  return new ContentPublicationService({ repository, ...servicePorts(attachments) });
}

interface Wire {
  draftId: EntityId;
  contentId: EntityId;
  revision: number;
  submissionId: EntityId;
  publishedRevisionId: EntityId;
  currentPublishedRevisionId: EntityId | null;
  visibility: string;
}

async function data<T>(
  promise: Promise<{ kind: string; data?: unknown; code?: string }>,
): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `unexpected ${result.kind}:${String(result.code)}`);
  return result.data as T;
}

let keySerial = 0;
const key = (label: string): string => `${label}-${uniqueToken()}-${String(++keySerial)}`;

export function commands(owner: EntityId) {
  return {
    create: (body: Record<string, unknown> = bodyFor(owner), idempotencyKey = key('create')) => ({
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey,
      payload: {
        typeId: 'place',
        publisherRef: { type: 'user', id: owner },
        marketId: 'LV',
        body,
      },
    }),
    update: (draftId: string, expectedRevision: number, body: unknown) => ({
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('update'),
      payload: { draftId, expectedRevision, body },
    }),
    submit: (draftId: string, expectedDraftRevision: number) => ({
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('submit'),
      payload: { draftId, expectedDraftRevision },
    }),
    publish: (
      submissionId: string,
      expectedPointerRevision: number,
      idempotencyKey = key('publish'),
    ) => ({
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey,
      payload: { submissionId, expectedPointerRevision },
    }),
    activate: (
      contentId: string,
      publishedRevisionId: string,
      expectedPointerRevision: number,
    ) => ({
      schemaVersion: 1,
      commandType: 'activatePublishedRevision',
      idempotencyKey: key('activate'),
      payload: { contentId, publishedRevisionId, expectedPointerRevision },
    }),
    withdraw: (contentId: string, expectedPointerRevision: number) => ({
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw'),
      payload: { contentId, expectedPointerRevision, mode: 'withdraw' },
    }),
  };
}

export const serviceScenarios: readonly ContentScenario[] = [
  {
    name: 'the Content service runs a full lifecycle and the stored records verify as intact',
    async run(make) {
      const repository = make();
      const asset = newId();
      const service = serviceOver(repository, [
        {
          assetId: asset,
          sourceGeneration: 'g-1',
          variantManifestRevision: 'c'.repeat(64),
          purpose: 'contentMedia',
        },
      ]);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const draft = await data<Wire>(service.execute(actor, c.create()));
      const submission = await data<Wire>(service.execute(actor, c.submit(draft.draftId, 1)));
      const first = await data<Wire>(service.execute(actor, c.publish(submission.submissionId, 0)));
      const edited = await data<Wire>(
        service.execute(actor, c.update(draft.draftId, 1, { ...bodyFor(owner), title: 'Second' })),
      );
      const second = await data<Wire>(
        service.execute(actor, c.submit(draft.draftId, edited.revision)),
      );
      const published = await data<Wire>(service.execute(actor, c.publish(second.submissionId, 1)));
      const rolledBack = await data<Wire>(
        service.execute(actor, c.activate(draft.contentId, first.publishedRevisionId, 2)),
      );
      assert.equal(rolledBack.currentPublishedRevisionId, first.publishedRevisionId);
      const withdrawn = await data<Wire>(service.execute(actor, c.withdraw(draft.contentId, 3)));
      assert.equal(withdrawn.visibility, 'withdrawn');
      assert.notEqual(published.publishedRevisionId, first.publishedRevisionId);
      await repository.transact(async (tx) => {
        const revisions = await tx.publishedRevisionsForContent(draft.contentId);
        assert.deepEqual(
          revisions.map((item) => item.revisionNumber),
          [1, 2],
        );
        assert.equal(revisions[0]?.mediaAttachments[0]?.assetId, asset);
        assert.equal(await tx.isMediaReferenced(asset), true);
        const effects = await allEffects(tx, draft.contentId);
        assert.deepEqual(
          effects.map((item) => item.pointerRevision),
          [1, 2, 3, 4],
        );
      });
      const report = await new ContentIntegrityRecovery(repository).verify(draft.contentId);
      assert.deepEqual(report.findings, []);
      assert.equal(report.ok, true);
    },
  },
  {
    name: 'a repeated command replays its stored outcome and a changed payload conflicts',
    async run(make) {
      const repository = make();
      const service = serviceOver(repository);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const command = c.create(bodyFor(owner), key('create-fixed'));
      const first = await data<Wire>(service.execute(actor, command));
      const replay = await data<Wire>(service.execute(actor, command));
      assert.equal(replay.draftId, first.draftId);
      assert.deepEqual(
        await service.execute(
          actor,
          c.create({ ...bodyFor(owner), title: 'Other' }, command.idempotencyKey),
        ),
        { kind: 'rejected', code: 'idempotency_conflict' },
      );
    },
  },
  {
    name: 'concurrent duplicate publishes create exactly one revision',
    async run(make) {
      const repository = make();
      const service = serviceOver(repository);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const draft = await data<Wire>(service.execute(actor, c.create()));
      const submission = await data<Wire>(service.execute(actor, c.submit(draft.draftId, 1)));
      const command = c.publish(submission.submissionId, 0, key('publish-fixed'));
      const results = await Promise.all([
        service.execute(actor, command),
        service.execute(actor, command),
        service.execute(actor, command),
      ]);
      assert.equal(
        results.every((item) => item.kind === 'succeeded'),
        true,
      );
      await repository.transact(async (tx) => {
        assert.equal((await tx.publishedRevisionsForContent(draft.contentId)).length, 1);
        assert.equal((await allEffects(tx, draft.contentId)).length, 1);
      });
    },
  },
  {
    name: 'D4: importing the same local source again returns the same draft under any key',
    async run(make) {
      const repository = make();
      const service = serviceOver(repository);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const source = `loc_${uniqueToken()}`;
      const importCommand = (idempotencyKey: string, payload: Record<string, unknown> = {}) => {
        const command = c.create({}, idempotencyKey);
        return { ...command, payload: { ...command.payload, importSourceKey: source, ...payload } };
      };
      const first = await data<Wire>(service.execute(actor, importCommand(key('import-1'))));
      const edited = await data<Wire>(
        service.execute(actor, c.update(first.draftId, 1, bodyFor(owner))),
      );
      // A lost receipt: another key, same source -> the same, current draft.
      const again = await data<Wire>(service.execute(actor, importCommand(key('import-2'))));
      assert.equal(again.draftId, first.draftId);
      assert.equal(again.revision, edited.revision);
      // The same source for another publisher or market is a conflict, never a second draft.
      assert.deepEqual(
        await service.execute(
          actor,
          importCommand(key('import-3'), { publisherRef: { type: 'page', id: newId() } }),
        ),
        { kind: 'rejected', code: 'idempotency_conflict' },
      );
      assert.deepEqual(
        await service.execute(actor, importCommand(key('import-4'), { marketId: 'EE' })),
        { kind: 'rejected', code: 'idempotency_conflict' },
      );
      // Without an import source nothing is deduplicated.
      const plain = await data<Wire>(service.execute(actor, c.create({}, key('plain'))));
      assert.notEqual(plain.draftId, first.draftId);
      await repository.transact(async (tx) => {
        assert.equal((await tx.draftByImportSource(owner, source))?.draftId, first.draftId);
      });
    },
  },
  {
    name: 'D4: concurrent imports of one local source leave exactly one draft',
    async run(make) {
      const repository = make();
      const service = serviceOver(repository);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const source = `loc_${uniqueToken()}`;
      const importCommand = (idempotencyKey: string) => {
        const command = c.create({}, idempotencyKey);
        return { ...command, payload: { ...command.payload, importSourceKey: source } };
      };
      const results = await Promise.all(
        [1, 2, 3].map((index) => service.execute(actor, importCommand(key(`race-${index}`)))),
      );
      const ids = new Set<string>();
      for (const result of results) {
        if (result.kind === 'succeeded') ids.add((result.data as unknown as Wire).draftId);
        else assert.equal((result as { code?: string }).code, 'revision_conflict');
      }
      // A loser that retries gets the winner's draft.
      const retried = await data<Wire>(service.execute(actor, importCommand(key('race-retry'))));
      ids.add(retried.draftId);
      assert.equal(ids.size, 1);
      await repository.transact(async (tx) => {
        assert.equal((await tx.draftByImportSource(owner, source))?.draftId, retried.draftId);
      });
    },
  },
  {
    name: 'two different publishes racing for the same pointer revision leave one winner',
    async run(make) {
      const repository = make();
      const service = serviceOver(repository);
      const owner = newId();
      const actor: ContentActor = { userId: owner, sessionId: newId() };
      const c = commands(owner);
      const draft = await data<Wire>(service.execute(actor, c.create()));
      const first = await data<Wire>(service.execute(actor, c.submit(draft.draftId, 1)));
      await data<Wire>(service.execute(actor, c.publish(first.submissionId, 0)));
      const edited = await data<Wire>(
        service.execute(actor, c.update(draft.draftId, 1, { ...bodyFor(owner), title: 'Next' })),
      );
      const next = await data<Wire>(
        service.execute(actor, c.submit(draft.draftId, edited.revision)),
      );
      const results = await Promise.all([
        service.execute(actor, c.publish(next.submissionId, 1)),
        service.execute(actor, c.publish(next.submissionId, 1)),
      ]);
      assert.equal(results.filter((item) => item.kind === 'succeeded').length, 1);
      assert.equal(results.filter((item) => item.kind === 'rejected').length, 1);
      await repository.transact(async (tx) => {
        assert.equal((await tx.publishedRevisionsForContent(draft.contentId)).length, 2);
      });
    },
  },
];

/** Registers every scenario for one adapter with the given node:test `test`. */
export function registerContentScenarios(
  register: (name: string, run: () => Promise<void>) => void,
  adapter: string,
  make: RepositoryFactory,
): void {
  for (const scenario of [...repositoryScenarios, ...serviceScenarios])
    register(`${adapter}: ${scenario.name}`, () => scenario.run(make));
}

/** Real service over a repository plus one ready-made published Content, for other suites. */
export function serviceHarness(
  repository: ContentRepository,
  attachments: MediaAttachmentV1[] = [],
) {
  const ports = servicePorts(attachments);
  const service = new ContentPublicationService({ repository, ...ports });
  const owner = newId();
  const actor: ContentActor = { userId: owner, sessionId: newId() };
  const c = commands(owner);
  async function publishOne() {
    const draft = await data<Wire>(service.execute(actor, c.create()));
    const submission = await data<Wire>(service.execute(actor, c.submit(draft.draftId, 1)));
    const revision = await data<Wire>(
      service.execute(actor, c.publish(submission.submissionId, 0)),
    );
    return {
      contentId: draft.contentId,
      draftId: draft.draftId,
      publishedRevisionId: revision.publishedRevisionId,
    };
  }
  return { service, ports, actor, commands: c, publishOne };
}

// ---------------------------------------------------------------------------
// D4.1 local import rollback and cleanup reservation: the same scenarios run
// over the in-memory adapter (integration) and the Firestore adapter (Emulator)
// ---------------------------------------------------------------------------

type Outcome = { readonly kind: string; readonly data?: unknown; readonly code?: string };

interface ImportedDraft {
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly revision: number;
  readonly status: string;
  readonly importGeneration?: number;
  readonly body: unknown;
}

interface BindingView {
  readonly generation: number;
  readonly state: string;
  readonly draftId: string;
  readonly bindingRevision: number;
  readonly cleanup: {
    readonly state: string;
    readonly installationId: string;
    readonly leaseExpiresAtUtc: string;
  } | null;
}

/** A movable clock so a lease can be seen to expire. */
export class ScenarioClock {
  #ms = Date.parse('2026-10-13T10:00:00.000Z');
  now(): Date {
    return new Date(this.#ms);
  }
  advance(seconds: number): void {
    this.#ms += seconds * 1000;
  }
}

const refusal = (code: string) => ({ kind: 'rejected', code });

/** One author's commands for one local source, over the real service. */
export function importHarness(
  repository: ContentRepository,
  options: { readonly owner?: EntityId; readonly clock?: ScenarioClock } = {},
) {
  const clock = options.clock ?? new ScenarioClock();
  const service = new ContentPublicationService({ repository, ...servicePorts(), clock });
  const owner = options.owner ?? newId();
  const actor: ContentActor = { userId: owner, sessionId: newId() };
  const source = `loc_${uniqueToken()}`;
  const envelope = (commandType: string, payload: unknown, idempotencyKey = key(commandType)) => ({
    schemaVersion: 1,
    commandType,
    idempotencyKey,
    payload,
  });
  const run = (command: unknown, as: ContentActor = actor) =>
    service.execute(as, command) as Promise<Outcome>;
  return {
    service,
    clock,
    owner,
    actor,
    source,
    commands: commands(owner),
    run,
    importCommand: (idempotencyKey = key('import'), body = bodyFor(owner)) =>
      envelope(
        'createDraft',
        {
          typeId: 'place',
          publisherRef: { type: 'user', id: owner },
          marketId: 'LV',
          body,
          importSourceKey: source,
        },
        idempotencyKey,
      ),
    rollback: (
      draftId: string,
      generation: number,
      expectedRevision: number,
      idempotencyKey?: string,
    ) =>
      envelope(
        'rollbackImportedDraft',
        { draftId, importSourceKey: source, generation, expectedRevision },
        idempotencyKey,
      ),
    reserve: (
      draftId: string,
      generation: number,
      installationId: string,
      fencingToken: string,
      idempotencyKey?: string,
    ) =>
      envelope(
        'reserveImportCleanup',
        { importSourceKey: source, generation, draftId, installationId, fencingToken },
        idempotencyKey,
      ),
    complete: (generation: number, fencingToken: string, idempotencyKey?: string) =>
      envelope(
        'completeImportCleanup',
        { importSourceKey: source, generation, fencingToken },
        idempotencyKey,
      ),
    release: (generation: number, fencingToken: string, idempotencyKey?: string) =>
      envelope(
        'releaseImportCleanup',
        { importSourceKey: source, generation, fencingToken },
        idempotencyKey,
      ),
    binding: async (as: ContentActor = actor) =>
      (await service.query(as, {
        schemaVersion: 1,
        queryType: 'getImportBinding',
        payload: { importSourceKey: source },
      })) as Outcome,
    draft: async (draftId: string) =>
      data<ImportedDraft>(
        service.query(actor, { schemaVersion: 1, queryType: 'getDraft', payload: { draftId } }),
      ),
  };
}

export const fencingTokenA = 'token-a-0123456789abcdef';
export const fencingTokenB = 'token-b-0123456789abcdef';

export const localImportRollbackScenarios: readonly ContentScenario[] = [
  {
    name: 'D4.1: rollback tombstones the draft and its generation; cleanup is then refused',
    async run(make) {
      const h = importHarness(make());
      const imported = await data<ImportedDraft>(h.run(h.importCommand()));
      assert.equal(imported.importGeneration, 1);
      const edited = await data<ImportedDraft>(
        h.run(h.commands.update(imported.draftId, 1, { ...bodyFor(h.owner), title: 'Edited' })),
      );
      const command = h.rollback(imported.draftId, 1, edited.revision);
      const tombstone = await data<ImportedDraft>(h.run(command));
      assert.equal(tombstone.status, 'rolledBack');
      assert.equal(tombstone.revision, edited.revision + 1);
      assert.deepEqual(tombstone.body, edited.body);
      // A lost answer is recovered by the same key; another key finds it done.
      assert.deepEqual(await data<ImportedDraft>(h.run(command)), tombstone);
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, tombstone.revision)),
        refusal('import_rolled_back'),
      );
      const binding = await data<BindingView>(h.binding());
      assert.equal(binding.state, 'rolledBack');
      assert.equal(binding.generation, 1);
      assert.equal(binding.draftId, imported.draftId);
      assert.equal(binding.cleanup, null);
      // `rolledBack` withdraws the right to clean up this original for good.
      assert.deepEqual(
        await h.run(h.reserve(imported.draftId, 1, 'install-1', fencingTokenA)),
        refusal('import_rolled_back'),
      );
      assert.deepEqual(await h.run(h.complete(1, fencingTokenA)), refusal('cleanup_not_reserved'));
      assert.deepEqual(await h.run(h.release(1, fencingTokenA)), refusal('cleanup_not_reserved'));
      // The tombstone is never edited or submitted again.
      assert.deepEqual(
        await h.run(h.commands.update(imported.draftId, tombstone.revision, bodyFor(h.owner))),
        refusal('import_rolled_back'),
      );
      assert.deepEqual(
        await h.run(h.commands.submit(imported.draftId, tombstone.revision)),
        refusal('import_rolled_back'),
      );
      assert.equal((await h.draft(imported.draftId)).status, 'rolledBack');
    },
  },
  {
    name: 'D4.1: rollback is refused for another author, a stale revision or generation, and anything submitted or published',
    async run(make) {
      const repository = make();
      const h = importHarness(repository);
      const imported = await data<ImportedDraft>(h.run(h.importCommand()));
      const stranger: ContentActor = { userId: newId(), sessionId: newId() };
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 1), stranger),
        refusal('not_found'),
      );
      assert.deepEqual(await h.binding(stranger), refusal('not_found'));
      const plain = await data<ImportedDraft>(h.run(h.commands.create()));
      assert.deepEqual(await h.run(h.rollback(plain.draftId, 1, 1)), refusal('not_found'));
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 2, 1)),
        refusal('import_generation_mismatch'),
      );
      await data(h.run(h.commands.update(imported.draftId, 1, bodyFor(h.owner))));
      // The server copy changed since the receipt: no override.
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 1)),
        refusal('revision_conflict'),
      );
      assert.equal((await h.draft(imported.draftId)).status, 'editing');
      // A delegated module never reaches the lifecycle commands.
      assert.deepEqual(
        await h.service.executeDelegated(
          { moduleId: 'event-ingestion', operation: 'syncSource' },
          h.rollback(imported.draftId, 1, 2),
        ),
        refusal('capability_denied'),
      );
      const submission = await data<{ submissionId: string }>(
        h.run(h.commands.submit(imported.draftId, 2)),
      );
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 2)),
        refusal('import_rollback_not_allowed'),
      );
      await data(h.run(h.commands.publish(submission.submissionId, 0)));
      const published = await h.draft(imported.draftId);
      assert.equal(published.status, 'editing');
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, published.revision)),
        refusal('import_rollback_not_allowed'),
      );
      assert.equal((await data<BindingView>(h.binding())).state, 'active');
    },
  },
  {
    name: 'D4.1: a cleanup reservation is fenced by its token, also after its lease expired',
    async run(make) {
      const h = importHarness(make());
      const imported = await data<ImportedDraft>(h.run(h.importCommand()));
      const reserved = await data<BindingView>(
        h.run(h.reserve(imported.draftId, 1, 'install-1', fencingTokenA)),
      );
      assert.equal(reserved.cleanup?.state, 'reserved');
      assert.equal(reserved.cleanup?.installationId, 'install-1');
      assert.equal(reserved.cleanup?.leaseExpiresAtUtc, '2026-10-13T10:15:00.000Z');
      // The same reservation again is the same state, not a new one.
      assert.deepEqual(
        await data<BindingView>(h.run(h.reserve(imported.draftId, 1, 'install-1', fencingTokenA))),
        reserved,
      );
      assert.deepEqual(
        await h.run(h.reserve(imported.draftId, 1, 'install-2', fencingTokenB)),
        refusal('cleanup_reserved'),
      );
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 1)),
        refusal('cleanup_reserved'),
      );
      // An expired lease is not taken over and does not open rollback.
      h.clock.advance(3600);
      assert.deepEqual(
        await h.run(h.reserve(imported.draftId, 1, 'install-2', fencingTokenB)),
        refusal('cleanup_reserved'),
      );
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 1)),
        refusal('cleanup_reserved'),
      );
      assert.deepEqual(
        await h.run(h.complete(1, fencingTokenB)),
        refusal('cleanup_token_mismatch'),
      );
      assert.deepEqual(await h.run(h.release(1, fencingTokenB)), refusal('cleanup_token_mismatch'));
      assert.deepEqual(
        await h.run(h.complete(2, fencingTokenA)),
        refusal('import_generation_mismatch'),
      );
      // Only the reserving token releases; then another installation may reserve.
      assert.equal((await data<BindingView>(h.run(h.release(1, fencingTokenA)))).cleanup, null);
      await data(h.run(h.reserve(imported.draftId, 1, 'install-2', fencingTokenB)));
      const completeCommand = h.complete(1, fencingTokenB);
      const done = await data<BindingView>(h.run(completeCommand));
      assert.equal(done.cleanup?.state, 'done');
      // A lost answer is recovered by repeating complete, under any key.
      assert.deepEqual(await data<BindingView>(h.run(completeCommand)), done);
      assert.deepEqual(await data<BindingView>(h.run(h.complete(1, fencingTokenB))), done);
      // A stale token never completes nor lifts anything.
      assert.deepEqual(
        await h.run(h.complete(1, fencingTokenA)),
        refusal('cleanup_token_mismatch'),
      );
      assert.deepEqual(await h.run(h.release(1, fencingTokenB)), refusal('original_removed'));
      assert.deepEqual(
        await h.run(h.rollback(imported.draftId, 1, 1)),
        refusal('original_removed'),
      );
      assert.deepEqual(
        await h.run(h.reserve(imported.draftId, 1, 'install-1', fencingTokenA)),
        refusal('original_removed'),
      );
      assert.equal((await h.draft(imported.draftId)).status, 'editing');
    },
  },
  {
    name: 'D4.1: an old retry after rollback returns its own generation; the next import opens one new draft',
    async run(make) {
      const repository = make();
      const h = importHarness(repository);
      const firstCommand = h.importCommand();
      const first = await data<ImportedDraft>(h.run(firstCommand));
      await data(h.run(h.rollback(first.draftId, 1, 1)));
      // The old command replays its stored outcome and creates nothing.
      const replay = await data<ImportedDraft>(h.run(firstCommand));
      assert.equal(replay.draftId, first.draftId);
      assert.equal(replay.importGeneration, 1);
      const afterReplay = await data<BindingView>(h.binding());
      assert.equal(afterReplay.generation, 1);
      assert.equal(afterReplay.state, 'rolledBack');
      // A newly approved import opens generation 2.
      const second = await data<ImportedDraft>(h.run(h.importCommand()));
      assert.notEqual(second.draftId, first.draftId);
      assert.equal(second.importGeneration, 2);
      assert.equal(second.status, 'editing');
      assert.equal(
        (await data<ImportedDraft>(h.run(h.importCommand()))).draftId,
        second.draftId,
        'generation 2 deduplicates like D4',
      );
      assert.deepEqual(
        await h.run(h.rollback(first.draftId, 1, 2)),
        refusal('import_generation_mismatch'),
      );
      assert.deepEqual(
        await h.run(h.rollback(second.draftId, 1, 1)),
        refusal('import_generation_mismatch'),
      );
      await data(h.run(h.rollback(second.draftId, 2, 1)));
      // Concurrent new imports open generation 3 with exactly one draft.
      const results = await Promise.all([1, 2, 3].map(() => h.run(h.importCommand())));
      const ids = new Set<string>();
      for (const result of results)
        if (result.kind === 'succeeded') ids.add((result.data as ImportedDraft).draftId);
        else assert.equal(result.code, 'revision_conflict');
      const retried = await data<ImportedDraft>(h.run(h.importCommand()));
      ids.add(retried.draftId);
      assert.equal(ids.size, 1);
      assert.equal(retried.importGeneration, 3);
      const binding = await data<BindingView>(h.binding());
      assert.equal(binding.generation, 3);
      assert.equal(binding.state, 'active');
      assert.equal(binding.draftId, retried.draftId);
      assert.equal((await h.draft(first.draftId)).status, 'rolledBack');
      assert.equal((await h.draft(second.draftId)).status, 'rolledBack');
    },
  },
];
