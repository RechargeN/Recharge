import { createHash } from 'node:crypto';

import type { DocumentReference, Firestore, Query, Transaction } from 'firebase-admin/firestore';

import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import { deepFreeze } from '../../../shared/immutable.js';
import type { ContentDraft } from '../domain/content_draft.js';
import { resolveContentType } from '../domain/content_type_registry.js';
import { ContentDomainRefusal, ContentRepositoryConflict } from '../domain/failures.js';
import type { PublicationPointer } from '../domain/publication_pointer.js';
import type { PublicationSubmission } from '../domain/publication_submission.js';
import type { PublishedRevision } from '../domain/published_revision.js';
import type {
  ContentAuditEntry,
  ContentIdempotencyRecord,
  ContentRepository,
  ContentTransaction,
} from '../domain/repositories.js';
import {
  assertDocumentWithinLimit,
  assertMediaIdsWithinLimit,
  resolveStorageLimits,
  type ContentStorageLimits,
} from '../domain/storage_limits.js';

/** Server-owned collections (BCK-07 v0.12 §38.2). Clients get no access. */
export const contentCollections = Object.freeze({
  drafts: 'contentDrafts',
  externalBindings: 'contentExternalBindings',
  submissions: 'contentSubmissions',
  publishedRevisions: 'contentPublishedRevisions',
  pointers: 'contentPublicationPointers',
  idempotency: 'contentIdempotency',
  audit: 'contentAudit',
  effects: 'contentEffects',
});

const emulatorProjectId = 'demo-recharge';
const loopbackEmulatorHost = /^(?:127\.0\.0\.1|localhost|\[::1\]):\d{2,5}$/u;

export type ContentPersistenceRefusal =
  | 'emulator_host_missing'
  | 'emulator_host_not_loopback'
  | 'project_not_demo'
  | 'cloud_credentials_present'
  | 'cloud_endpoint_override';

export class ContentPersistenceEnvironmentError extends Error {
  constructor(readonly reason: ContentPersistenceRefusal) {
    super(`Content persistence refused: ${reason}`);
    this.name = 'ContentPersistenceEnvironmentError';
  }
}

/**
 * The Firestore Content repository is Emulator-only. This gate runs in the
 * repository constructor itself, so a direct construction is exactly as safe as
 * the composition factory (BCK-07 v0.12 §38.5): exact `demo-recharge`, a
 * mandatory loopback Emulator endpoint and no path to a cloud project.
 */
export function assertContentEmulatorContext(
  firestore: Firestore,
  environment: NodeJS.ProcessEnv = process.env,
): void {
  const host = environment.FIRESTORE_EMULATOR_HOST;
  if (host === undefined || host === '')
    throw new ContentPersistenceEnvironmentError('emulator_host_missing');
  if (!loopbackEmulatorHost.test(host))
    throw new ContentPersistenceEnvironmentError('emulator_host_not_loopback');
  for (const name of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT'] as const) {
    const value = environment[name];
    if (value !== undefined && value !== emulatorProjectId)
      throw new ContentPersistenceEnvironmentError('project_not_demo');
  }
  if (
    (environment.GOOGLE_APPLICATION_CREDENTIALS ?? '') !== '' ||
    (environment.FIREBASE_SERVICE_ACCOUNT ?? '') !== ''
  )
    throw new ContentPersistenceEnvironmentError('cloud_credentials_present');
  if ((environment.FIRESTORE_HOST ?? '') !== '')
    throw new ContentPersistenceEnvironmentError('cloud_endpoint_override');
  let projectId: string | undefined;
  try {
    // The client exposes the resolved project at runtime but not in its public typings.
    projectId = (firestore as unknown as { readonly projectId: string }).projectId;
  } catch {
    projectId = undefined;
  }
  if (projectId !== emulatorProjectId)
    throw new ContentPersistenceEnvironmentError('project_not_demo');
}

export interface FirestoreContentRepositoryOptions {
  readonly limits?: Partial<ContentStorageLimits>;
  readonly environment?: NodeJS.ProcessEnv;
}

export class FirestoreContentRepository implements ContentRepository {
  readonly #limits: ContentStorageLimits;

  constructor(
    private readonly firestore: Firestore,
    options: FirestoreContentRepositoryOptions = {},
  ) {
    assertContentEmulatorContext(firestore, options.environment ?? process.env);
    this.#limits = resolveStorageLimits(options.limits);
  }

  transact<T>(operation: (transaction: ContentTransaction) => T | Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (transaction) => {
      // A retried Firestore transaction re-runs this callback with a new, empty buffer.
      const buffered = new BufferedContentTransaction(this.firestore, transaction, this.#limits);
      const result = await operation(buffered);
      await buffered.flush();
      return result;
    });
  }
}

type Fields = Record<string, unknown>;

type WriteCheck =
  | { readonly kind: 'none' }
  | { readonly kind: 'create'; readonly conflict: 'immutable_revision' | 'duplicate_id' }
  | { readonly kind: 'cas'; readonly expected: number }
  | { readonly kind: 'binding'; readonly draftId: string }
  | {
      readonly kind: 'history';
      readonly field: 'contentId';
      readonly value: string;
      readonly max: number;
    };

interface StagedWrite {
  readonly collection: string;
  readonly id: string;
  readonly data: Fields;
  readonly check: WriteCheck;
}

function sha256(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/** Undefined-free plain data (Firestore rejects undefined). */
function plain<T>(value: T): Fields {
  return JSON.parse(JSON.stringify(value)) as Fields;
}

function mediaIdsOf(draft: ContentDraft): string[] {
  return [
    ...new Set(
      (resolveContentType(draft.typeId)?.mediaIds?.(draft.body) ?? []).filter(
        (item): item is string => typeof item === 'string',
      ),
    ),
  ];
}

/**
 * Writes are buffered until commit because Firestore needs every read before any
 * write while the Content service reads after staging. Reads see the staged
 * writes (single documents and lists); checks and uniqueness run against freshly
 * read documents before the first write is issued.
 */
class BufferedContentTransaction implements ContentTransaction {
  readonly #staged: StagedWrite[] = [];

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
    private readonly limits: ContentStorageLimits,
  ) {}

  // ------------------------------------------------------------------ helpers
  private ref(collection: string, id: string): DocumentReference {
    return this.firestore.collection(collection).doc(id);
  }

  private stage(write: StagedWrite): void {
    this.#staged.push(write);
  }

  private stagedFor(collection: string, id: string): StagedWrite | undefined {
    for (let index = this.#staged.length - 1; index >= 0; index -= 1) {
      const item = this.#staged[index];
      if (item?.collection === collection && item.id === id) return item;
    }
    return undefined;
  }

  private async read(collection: string, id: string): Promise<Fields | null> {
    const staged = this.stagedFor(collection, id);
    if (staged !== undefined) return staged.data;
    const snapshot = await this.transaction.get(this.ref(collection, id));
    return snapshot.exists ? (snapshot.data() as Fields) : null;
  }

  /** Equality query with the staged writes of the same collection laid over it. */
  private async list(
    collection: string,
    field: string,
    value: string,
    options: { readonly limit: number; readonly orderBy?: string },
  ): Promise<Fields[]> {
    let query: Query = this.firestore.collection(collection).where(field, '==', value);
    if (options.orderBy !== undefined) query = query.orderBy(options.orderBy, 'asc');
    const snapshot = await this.transaction.get(query.limit(options.limit));
    const found = new Map<string, Fields>();
    for (const document of snapshot.docs) found.set(document.id, document.data());
    for (const item of this.#staged) {
      if (item.collection !== collection) continue;
      if (item.data[field] === value) found.set(item.id, item.data);
      else found.delete(item.id);
    }
    return [...found.values()];
  }

  // ------------------------------------------------------------------ drafts
  async draft(draftId: string): Promise<ContentDraft | null> {
    const data = await this.read(contentCollections.drafts, draftId);
    return data === null ? null : draftFromStored(data);
  }

  async draftByContentId(contentId: string): Promise<ContentDraft | null> {
    const found = await this.list(contentCollections.drafts, 'contentId', contentId, { limit: 2 });
    const [first] = found;
    return first === undefined ? null : draftFromStored(first);
  }

  async draftByExternalBinding(externalBindingRef: string): Promise<ContentDraft | null> {
    const binding = await this.read(
      contentCollections.externalBindings,
      sha256(externalBindingRef),
    );
    if (binding === null || typeof binding.draftId !== 'string') return null;
    return this.draft(binding.draftId);
  }

  putDraft(draft: ContentDraft): void {
    const mediaAssetIds = mediaIdsOf(draft);
    assertMediaIdsWithinLimit(mediaAssetIds.length, this.limits);
    const { body, ...rest } = draft;
    this.stage({
      collection: contentCollections.drafts,
      id: draft.draftId,
      data: { ...plain(rest), bodyJson: JSON.stringify(body), mediaAssetIds },
      check: { kind: 'none' },
    });
    const binding = draft.provenance.originBinding;
    if (binding.kind === 'delegatedImport')
      this.stage({
        collection: contentCollections.externalBindings,
        id: sha256(binding.externalBindingRef),
        data: { draftId: draft.draftId, externalBindingRef: binding.externalBindingRef },
        check: { kind: 'binding', draftId: draft.draftId },
      });
  }

  // ------------------------------------------------------------- submissions
  async submission(submissionId: string): Promise<PublicationSubmission | null> {
    const data = await this.read(contentCollections.submissions, submissionId);
    return data === null ? null : (deepFreeze(data) as PublicationSubmission);
  }

  async submissionsForContent(contentId: string): Promise<readonly PublicationSubmission[]> {
    const found = await this.list(contentCollections.submissions, 'contentId', contentId, {
      limit: this.limits.maxSubmissionsPerContent + 1,
    });
    if (found.length > this.limits.maxSubmissionsPerContent)
      throw new ContentDomainRefusal('storage_limit_exceeded');
    return found.map((item) => deepFreeze(item) as PublicationSubmission);
  }

  putSubmission(submission: PublicationSubmission): void {
    this.stage({
      collection: contentCollections.submissions,
      id: submission.submissionId,
      data: plain(submission),
      check: {
        kind: 'history',
        field: 'contentId',
        value: submission.contentId,
        max: this.limits.maxSubmissionsPerContent,
      },
    });
  }

  // -------------------------------------------------------------- revisions
  async publishedRevision(publishedRevisionId: string): Promise<PublishedRevision | null> {
    const data = await this.read(contentCollections.publishedRevisions, publishedRevisionId);
    return data === null ? null : revisionFromStored(data);
  }

  async publishedRevisionsForContent(contentId: string): Promise<readonly PublishedRevision[]> {
    const found = await this.list(contentCollections.publishedRevisions, 'contentId', contentId, {
      limit: this.limits.maxRevisionsPerContent + 1,
      orderBy: 'revisionNumber',
    });
    if (found.length > this.limits.maxRevisionsPerContent)
      throw new ContentDomainRefusal('storage_limit_exceeded');
    return found
      .map(revisionFromStored)
      .sort((left, right) => left.revisionNumber - right.revisionNumber);
  }

  putPublishedRevision(revision: PublishedRevision): void {
    const mediaAssetIds = [...new Set(revision.mediaAttachments.map((item) => item.assetId))];
    assertMediaIdsWithinLimit(mediaAssetIds.length, this.limits);
    const { body, ...rest } = revision;
    this.stage({
      collection: contentCollections.publishedRevisions,
      id: revision.publishedRevisionId,
      data: { ...plain(rest), bodyJson: JSON.stringify(body), mediaAssetIds },
      check: { kind: 'create', conflict: 'immutable_revision' },
    });
    // The history bound is checked separately so the create check keeps its own conflict.
    this.stage({
      collection: contentCollections.publishedRevisions,
      id: revision.publishedRevisionId,
      data: this.#staged[this.#staged.length - 1]?.data ?? {},
      check: {
        kind: 'history',
        field: 'contentId',
        value: revision.contentId,
        max: this.limits.maxRevisionsPerContent,
      },
    });
  }

  // ----------------------------------------------------------------- pointer
  async pointer(contentId: string): Promise<PublicationPointer | null> {
    const data = await this.read(contentCollections.pointers, contentId);
    return data === null ? null : (deepFreeze(data) as PublicationPointer);
  }

  putPointer(pointer: PublicationPointer, expectedStoredRevision: number): void {
    this.stage({
      collection: contentCollections.pointers,
      id: pointer.contentId,
      data: plain(pointer),
      check: { kind: 'cas', expected: expectedStoredRevision },
    });
  }

  async isMediaReferenced(assetId: string): Promise<boolean> {
    for (const collection of [contentCollections.drafts, contentCollections.publishedRevisions]) {
      const snapshot = await this.transaction.get(
        this.firestore
          .collection(collection)
          .where('mediaAssetIds', 'array-contains', assetId)
          .limit(100),
      );
      const found = new Map<string, Fields>();
      for (const document of snapshot.docs) found.set(document.id, document.data());
      for (const item of this.#staged) {
        if (item.collection !== collection) continue;
        const ids = item.data.mediaAssetIds;
        if (Array.isArray(ids) && ids.includes(assetId)) found.set(item.id, item.data);
        else found.delete(item.id);
      }
      if (found.size > 0) return true;
    }
    return false;
  }

  // ------------------------------------------------------ idempotency, audit
  async idempotency(
    actorUserId: string,
    commandType: string,
    idempotencyKey: string,
  ): Promise<ContentIdempotencyRecord | null> {
    const data = await this.read(
      contentCollections.idempotency,
      idempotencyDocumentId(actorUserId, commandType, idempotencyKey),
    );
    if (data === null) return null;
    const { outcomeJson, ...rest } = data;
    return {
      ...(rest as unknown as Omit<ContentIdempotencyRecord, 'outcome'>),
      outcome: JSON.parse(outcomeJson as string) as unknown,
    };
  }

  putIdempotency(record: ContentIdempotencyRecord): void {
    const { outcome, ...rest } = record;
    this.stage({
      collection: contentCollections.idempotency,
      id: idempotencyDocumentId(record.actorUserId, record.commandType, record.idempotencyKey),
      data: { ...plain(rest), outcomeJson: JSON.stringify(outcome) },
      check: { kind: 'none' },
    });
  }

  appendAudit(entry: ContentAuditEntry): void {
    this.stage({
      collection: contentCollections.audit,
      id: entry.auditId,
      data: plain(entry),
      check: { kind: 'create', conflict: 'duplicate_id' },
    });
  }

  async effectsForContent(contentId: string): Promise<readonly ContentEffectV1[]> {
    const found = await this.list(contentCollections.effects, 'contentId', contentId, {
      limit: 1000,
      orderBy: 'pointerRevision',
    });
    return found
      .map((item) => deepFreeze(item) as unknown as ContentEffectV1)
      .sort(
        (left, right) =>
          left.pointerRevision - right.pointerRevision ||
          left.effectId.localeCompare(right.effectId),
      );
  }

  readonly effects = {
    append: (effect: ContentEffectV1): void => {
      this.stage({
        collection: contentCollections.effects,
        id: effect.effectId,
        data: plain(effect),
        check: { kind: 'create', conflict: 'duplicate_id' },
      });
    },
  };

  // ------------------------------------------------------------------ commit
  /**
   * Phase 1 reads everything the checks need; phase 2 simulates the staged
   * writes in order against those reads (compare-and-set, create-only,
   * uniqueness, history bound); phase 3 issues all writes. A refusal in phase 2
   * happens before any write, so the transaction rolls back completely.
   */
  async flush(): Promise<void> {
    if (this.#staged.length === 0) return;
    for (const item of this.#staged) assertDocumentWithinLimit(item.data, this.limits);

    const keys = new Map<string, DocumentReference>();
    const histories = new Map<string, { collection: string; value: string; max: number }>();
    for (const item of this.#staged) {
      const key = `${item.collection}/${item.id}`;
      if (item.check.kind !== 'none' && item.check.kind !== 'history')
        keys.set(key, this.ref(item.collection, item.id));
      if (item.check.kind === 'history')
        histories.set(`${item.collection}|${item.check.value}`, {
          collection: item.collection,
          value: item.check.value,
          max: item.check.max,
        });
    }
    const documents = new Map<string, Fields | null>();
    await Promise.all(
      [...keys.entries()].map(async ([key, reference]) => {
        const snapshot = await this.transaction.get(reference);
        documents.set(key, snapshot.exists ? (snapshot.data() as Fields) : null);
      }),
    );
    const existingIds = new Map<string, Set<string>>();
    await Promise.all(
      [...histories.entries()].map(async ([key, info]) => {
        const snapshot = await this.transaction.get(
          this.firestore
            .collection(info.collection)
            .where('contentId', '==', info.value)
            .select()
            .limit(info.max + 1),
        );
        existingIds.set(key, new Set(snapshot.docs.map((document) => document.id)));
      }),
    );

    for (const item of this.#staged) {
      const key = `${item.collection}/${item.id}`;
      const check = item.check;
      switch (check.kind) {
        case 'none':
          break;
        case 'create':
          if ((documents.get(key) ?? null) !== null)
            throw new ContentRepositoryConflict(check.conflict);
          documents.set(key, item.data);
          break;
        case 'cas': {
          const stored = documents.get(key);
          const storedRevision = typeof stored?.revision === 'number' ? stored.revision : 0;
          if (storedRevision !== check.expected)
            throw new ContentRepositoryConflict('pointer_revision');
          documents.set(key, item.data);
          break;
        }
        case 'binding': {
          const stored = documents.get(key);
          if (stored !== null && stored !== undefined && stored.draftId !== check.draftId)
            throw new ContentRepositoryConflict('duplicate_id');
          documents.set(key, item.data);
          break;
        }
        case 'history': {
          const ids = existingIds.get(`${item.collection}|${check.value}`) ?? new Set<string>();
          if (!ids.has(item.id) && ids.size >= check.max)
            throw new ContentDomainRefusal('storage_limit_exceeded');
          ids.add(item.id);
          break;
        }
      }
    }

    for (const item of this.#staged)
      this.transaction.set(this.ref(item.collection, item.id), item.data);
  }
}

function idempotencyDocumentId(actorUserId: string, commandType: string, key: string): string {
  return sha256(`${actorUserId.length}:${actorUserId}|${commandType}|${key}`);
}

function draftFromStored(data: Fields): ContentDraft {
  const { bodyJson, mediaAssetIds, ...rest } = data;
  void mediaAssetIds;
  return deepFreeze({
    ...rest,
    body: JSON.parse(bodyJson as string) as unknown,
  }) as unknown as ContentDraft;
}

function revisionFromStored(data: Fields): PublishedRevision {
  const { bodyJson, mediaAssetIds, ...rest } = data;
  void mediaAssetIds;
  return deepFreeze({
    ...rest,
    body: JSON.parse(bodyJson as string) as unknown,
  }) as unknown as PublishedRevision;
}
