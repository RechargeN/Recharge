import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import { deepFreeze } from '../../../shared/immutable.js';
import type { ContentDraft } from '../domain/content_draft.js';
import { resolveContentType } from '../domain/content_type_registry.js';
import { ContentRepositoryConflict } from '../domain/failures.js';
import type { PublicationPointer } from '../domain/publication_pointer.js';
import type { PublicationSubmission } from '../domain/publication_submission.js';
import type { PublishedRevision } from '../domain/published_revision.js';
import type {
  ContentAuditEntry,
  ContentIdempotencyRecord,
  ContentRepository,
  ContentTransaction,
} from '../domain/repositories.js';

interface Store {
  readonly drafts: Map<string, ContentDraft>;
  readonly submissions: Map<string, PublicationSubmission>;
  readonly revisions: Map<string, PublishedRevision>;
  readonly pointers: Map<string, PublicationPointer>;
  readonly idempotency: Map<string, ContentIdempotencyRecord>;
  readonly audit: ContentAuditEntry[];
  readonly effects: ContentEffectV1[];
}

/**
 * Deterministic local adapter with serialized transactions. Writes are staged
 * and become visible only if the whole operation succeeds (all-or-nothing).
 * It is test infrastructure and carries no production authority.
 */
export class InMemoryContentRepository implements ContentRepository {
  #store: Store = emptyStore();
  #tail: Promise<void> = Promise.resolve();

  async transact<T>(operation: (transaction: ContentTransaction) => T | Promise<T>): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.#tail;
    this.#tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    const working = cloneStore(this.#store);
    try {
      const result = await operation(transactionFor(working));
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
  };
}

function copy<T>(value: T): T {
  return deepFreeze(structuredClone(value)) as T;
}

function idempotencyKey(actorUserId: string, commandType: string, key: string): string {
  return `${actorUserId.length}:${actorUserId}|${commandType}|${key}`;
}

function transactionFor(store: Store): ContentTransaction {
  return {
    draft: (draftId) => Promise.resolve(store.drafts.get(draftId) ?? null),
    draftByContentId: (contentId) =>
      Promise.resolve(
        [...store.drafts.values()].find((item) => item.contentId === contentId) ?? null,
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
      store.drafts.set(draft.draftId, copy(draft));
    },
    submission: (submissionId) => Promise.resolve(store.submissions.get(submissionId) ?? null),
    submissionsForContent: (contentId) =>
      Promise.resolve(
        [...store.submissions.values()].filter((item) => item.contentId === contentId),
      ),
    putSubmission(submission) {
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
    pointer: (contentId) => Promise.resolve(store.pointers.get(contentId) ?? null),
    putPointer(pointer, expectedStoredRevision) {
      const stored = store.pointers.get(pointer.contentId)?.revision ?? 0;
      if (stored !== expectedStoredRevision)
        throw new ContentRepositoryConflict('pointer_revision');
      store.pointers.set(pointer.contentId, copy(pointer));
    },
    idempotency: (actorUserId, commandType, key) =>
      Promise.resolve(store.idempotency.get(idempotencyKey(actorUserId, commandType, key)) ?? null),
    putIdempotency(record) {
      store.idempotency.set(
        idempotencyKey(record.actorUserId, record.commandType, record.idempotencyKey),
        copy(record),
      );
    },
    appendAudit(entry) {
      store.audit.push(copy(entry));
    },
    effects: {
      append(effect) {
        store.effects.push(copy(effect));
      },
    },
  };
}
