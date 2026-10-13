import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import { deepFreeze } from '../../../shared/immutable.js';
import type { ContentDraft } from '../domain/content_draft.js';
import { resolveContentType } from '../domain/content_type_registry.js';
import { ContentRepositoryConflict } from '../domain/failures.js';
import {
  assertDocumentWithinLimit,
  assertMediaIdsWithinLimit,
  assertRoomForHistory,
  defaultContentStorageLimits,
  resolveStorageLimits,
  type ContentStorageLimits,
} from '../domain/storage_limits.js';
import type { PublicationPointer } from '../domain/publication_pointer.js';
import type { PublicationSubmission } from '../domain/publication_submission.js';
import type { PublishedRevision } from '../domain/published_revision.js';
import {
  compareEffects,
  isAfterCursor,
  type ContentAuditEntry,
  type ContentIdempotencyRecord,
  type ContentRepository,
  type ContentTransaction,
  type MediaAvailabilityFeed,
  type MediaAvailabilityReceipt,
  type MediaAvailabilityStatusRecord,
} from '../domain/repositories.js';

interface Store {
  readonly drafts: Map<string, ContentDraft>;
  readonly submissions: Map<string, PublicationSubmission>;
  readonly revisions: Map<string, PublishedRevision>;
  readonly pointers: Map<string, PublicationPointer>;
  readonly idempotency: Map<string, ContentIdempotencyRecord>;
  readonly audit: ContentAuditEntry[];
  readonly effects: ContentEffectV1[];
  readonly availabilityStatus: Map<MediaAvailabilityFeed, MediaAvailabilityStatusRecord>;
  readonly availabilityReceipts: Map<string, MediaAvailabilityReceipt>;
}

/**
 * Deterministic local adapter with serialized transactions. Writes are staged
 * and become visible only if the whole operation succeeds (all-or-nothing).
 * It is test infrastructure and carries no production authority.
 */
export class InMemoryContentRepository implements ContentRepository {
  readonly #limits: ContentStorageLimits;
  #store: Store = emptyStore();
  #tail: Promise<void> = Promise.resolve();

  constructor(limits: Partial<ContentStorageLimits> = defaultContentStorageLimits) {
    this.#limits = resolveStorageLimits(limits);
  }

  async transact<T>(operation: (transaction: ContentTransaction) => T | Promise<T>): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.#tail;
    this.#tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    const working = cloneStore(this.#store);
    try {
      const result = await operation(transactionFor(working, this.#limits));
      this.#store = working;
      return result;
    } finally {
      release?.();
    }
  }

  /** Test-only inspection of committed state. */
  snapshot(): Readonly<{
    drafts: readonly ContentDraft[];
    submissions: readonly PublicationSubmission[];
    revisions: readonly PublishedRevision[];
    pointers: readonly PublicationPointer[];
    audit: readonly ContentAuditEntry[];
    effects: readonly ContentEffectV1[];
  }> {
    return deepFreeze({
      drafts: [...this.#store.drafts.values()],
      submissions: [...this.#store.submissions.values()],
      revisions: [...this.#store.revisions.values()],
      pointers: [...this.#store.pointers.values()],
      audit: [...this.#store.audit],
      effects: [...this.#store.effects],
    });
  }
}

function emptyStore(): Store {
  return {
    drafts: new Map(),
    submissions: new Map(),
    revisions: new Map(),
    pointers: new Map(),
    idempotency: new Map(),
    audit: [],
    effects: [],
    availabilityStatus: new Map(),
    availabilityReceipts: new Map(),
  };
}

function cloneStore(store: Store): Store {
  // Stored values are deep-frozen and never mutated; copying containers suffices.
  return {
    drafts: new Map(store.drafts),
    submissions: new Map(store.submissions),
    revisions: new Map(store.revisions),
    pointers: new Map(store.pointers),
    idempotency: new Map(store.idempotency),
    audit: [...store.audit],
    effects: [...store.effects],
    availabilityStatus: new Map(store.availabilityStatus),
    availabilityReceipts: new Map(store.availabilityReceipts),
  };
}

function copy<T>(value: T): T {
  return deepFreeze(structuredClone(value)) as T;
}

function idempotencyKey(actorUserId: string, commandType: string, key: string): string {
  return `${actorUserId.length}:${actorUserId}|${commandType}|${key}`;
}

function transactionFor(store: Store, limits: ContentStorageLimits): ContentTransaction {
  return {
    draft: (draftId) => Promise.resolve(store.drafts.get(draftId) ?? null),
    draftByContentId: (contentId) =>
      Promise.resolve(
        [...store.drafts.values()].find((item) => item.contentId === contentId) ?? null,
      ),
    draftByImportSource: (createdByUserId, importSourceKey) =>
      Promise.resolve(
        [...store.drafts.values()].find(
          (item) =>
            item.createdByUserId === createdByUserId && item.importSourceKey === importSourceKey,
        ) ?? null,
      ),
    draftByExternalBinding: (externalBindingRef) =>
      Promise.resolve(
        [...store.drafts.values()].find(
          (item) =>
            item.provenance.originBinding.kind === 'delegatedImport' &&
            item.provenance.originBinding.externalBindingRef === externalBindingRef,
        ) ?? null,
      ),
    putDraft(draft) {
      assertDocumentWithinLimit(draft, limits);
      assertMediaIdsWithinLimit(
        (resolveContentType(draft.typeId)?.mediaIds?.(draft.body) ?? []).length,
        limits,
      );
      const binding = draft.provenance.originBinding;
      // One external source record binds to at most one draft (same rule as the Firestore adapter).
      if (
        binding.kind === 'delegatedImport' &&
        [...store.drafts.values()].some(
          (other) =>
            other.draftId !== draft.draftId &&
            other.provenance.originBinding.kind === 'delegatedImport' &&
            other.provenance.originBinding.externalBindingRef === binding.externalBindingRef,
        )
      )
        throw new ContentRepositoryConflict('duplicate_id');
      // D4: one author's local import source binds to at most one draft.
      if (
        draft.createdByUserId !== null &&
        draft.importSourceKey !== undefined &&
        [...store.drafts.values()].some(
          (other) =>
            other.draftId !== draft.draftId &&
            other.createdByUserId === draft.createdByUserId &&
            other.importSourceKey === draft.importSourceKey,
        )
      )
        throw new ContentRepositoryConflict('duplicate_id');
      store.drafts.set(draft.draftId, copy(draft));
    },
    submission: (submissionId) => Promise.resolve(store.submissions.get(submissionId) ?? null),
    submissionsForContent: (contentId) =>
      Promise.resolve(
        [...store.submissions.values()].filter((item) => item.contentId === contentId),
      ),
    putSubmission(submission) {
      assertDocumentWithinLimit(submission, limits);
      if (!store.submissions.has(submission.submissionId))
        assertRoomForHistory(
          [...store.submissions.values()].filter((item) => item.contentId === submission.contentId)
            .length,
          limits.maxSubmissionsPerContent,
        );
      store.submissions.set(submission.submissionId, copy(submission));
    },
    publishedRevision: (id) => Promise.resolve(store.revisions.get(id) ?? null),
    publishedRevisionsForContent: (contentId) =>
      Promise.resolve(
        [...store.revisions.values()]
          .filter((item) => item.contentId === contentId)
          .sort((left, right) => left.revisionNumber - right.revisionNumber),
      ),
    putPublishedRevision(revision) {
      if (store.revisions.has(revision.publishedRevisionId))
        throw new ContentRepositoryConflict('immutable_revision');
      assertDocumentWithinLimit(revision, limits);
      assertMediaIdsWithinLimit(revision.mediaAttachments.length, limits);
      assertRoomForHistory(
        [...store.revisions.values()].filter((item) => item.contentId === revision.contentId)
          .length,
        limits.maxRevisionsPerContent,
      );
      store.revisions.set(revision.publishedRevisionId, copy(revision));
    },
    isMediaReferenced: (assetId) =>
      Promise.resolve(
        [...store.revisions.values()].some((revision) =>
          revision.mediaAttachments.some((item) => item.assetId === assetId),
        ) ||
          [...store.drafts.values()].some((draft) =>
            (resolveContentType(draft.typeId)?.mediaIds?.(draft.body) ?? []).includes(assetId),
          ),
      ),
    contentIdsAttachingMedia: (assetId, limit) =>
      Promise.resolve(
        [
          ...new Set(
            [...store.revisions.values()]
              .filter((revision) =>
                revision.mediaAttachments.some((item) => item.assetId === assetId),
              )
              .map((revision) => revision.contentId),
          ),
        ]
          .sort()
          .slice(0, limit),
      ),
    pointer: (contentId) => Promise.resolve(store.pointers.get(contentId) ?? null),
    pointersPage: (afterContentId, limit) =>
      Promise.resolve(
        [...store.pointers.values()]
          .filter((item) => afterContentId === null || item.contentId > afterContentId)
          .sort((left, right) => (left.contentId < right.contentId ? -1 : 1))
          .slice(0, limit),
      ),
    mediaAvailabilityStatus: (feed) => Promise.resolve(store.availabilityStatus.get(feed) ?? null),
    putMediaAvailabilityStatus(record) {
      store.availabilityStatus.set(record.feed, copy(record));
    },
    mediaAvailabilityReceipt: (feed, effectId) =>
      Promise.resolve(store.availabilityReceipts.get(`${feed}:${effectId}`) ?? null),
    putMediaAvailabilityReceipt(receipt) {
      const key = `${receipt.feed}:${receipt.effectId}`;
      if (store.availabilityReceipts.has(key)) throw new ContentRepositoryConflict('duplicate_id');
      store.availabilityReceipts.set(key, copy(receipt));
    },
    putPointer(pointer, expectedStoredRevision) {
      const stored = store.pointers.get(pointer.contentId)?.revision ?? 0;
      if (stored !== expectedStoredRevision)
        throw new ContentRepositoryConflict('pointer_revision');
      store.pointers.set(pointer.contentId, copy(pointer));
    },
    idempotency: (actorUserId, commandType, key) =>
      Promise.resolve(store.idempotency.get(idempotencyKey(actorUserId, commandType, key)) ?? null),
    putIdempotency(record) {
      assertDocumentWithinLimit(record, limits);
      store.idempotency.set(
        idempotencyKey(record.actorUserId, record.commandType, record.idempotencyKey),
        copy(record),
      );
    },
    appendAudit(entry) {
      if (store.audit.some((item) => item.auditId === entry.auditId))
        throw new ContentRepositoryConflict('duplicate_id');
      store.audit.push(copy(entry));
    },
    effectsPage: (contentId, after, limit) =>
      Promise.resolve(
        store.effects
          .filter((item) => item.contentId === contentId && isAfterCursor(item, after))
          .sort(compareEffects)
          .slice(0, limit),
      ),
    hasPublicationEffect: (publishedRevisionId) =>
      Promise.resolve(
        store.effects.some(
          (item) =>
            item.publishedRevisionId === publishedRevisionId &&
            (item.kind === 'ContentPublished' || item.kind === 'ContentRevisionActivated'),
        ),
      ),
    effects: {
      append(effect) {
        if (store.effects.some((item) => item.effectId === effect.effectId))
          throw new ContentRepositoryConflict('duplicate_id');
        store.effects.push(copy(effect));
      },
    },
  };
}
