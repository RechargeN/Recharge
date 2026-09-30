import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import type { ContentDraft } from './content_draft.js';
import type { PublicationPointer } from './publication_pointer.js';
import type { PublicationSubmission } from './publication_submission.js';
import type { PublishedRevision } from './published_revision.js';

export interface ContentIdempotencyRecord {
  readonly actorUserId: string;
  readonly commandType: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly outcome: unknown;
  readonly createdAtUtc: string;
}

export interface ContentAuditEntry {
  readonly auditId: string;
  readonly occurredAtUtc: string;
  readonly actorUserId: string;
  readonly action: string;
  readonly subjectId: string;
  readonly outcome: 'succeeded';
}

/** Effects become visible only if the surrounding transaction commits. */
export interface PublicationEffectSink {
  append(effect: ContentEffectV1): void;
}

export interface ContentTransaction {
  draft(draftId: string): Promise<ContentDraft | null>;
  draftByContentId(contentId: string): Promise<ContentDraft | null>;
  /** Draft bound to an external source record by `originBinding.externalBindingRef`. */
  draftByExternalBinding(externalBindingRef: string): Promise<ContentDraft | null>;
  putDraft(draft: ContentDraft): void;
  submission(submissionId: string): Promise<PublicationSubmission | null>;
  submissionsForContent(contentId: string): Promise<readonly PublicationSubmission[]>;
  putSubmission(submission: PublicationSubmission): void;
  publishedRevision(publishedRevisionId: string): Promise<PublishedRevision | null>;
  publishedRevisionsForContent(contentId: string): Promise<readonly PublishedRevision[]>;
  /** Fails with a repository conflict if the id already exists (immutability). */
  putPublishedRevision(revision: PublishedRevision): void;
  /** Whether any draft body or immutable revision still references the Media asset. */
  isMediaReferenced(assetId: string): Promise<boolean>;
  pointer(contentId: string): Promise<PublicationPointer | null>;
  /** Stored effects of one Content in `pointerRevision` order (replay read; never rebuilt). */
  effectsForContent(contentId: string): Promise<readonly ContentEffectV1[]>;
  /** Compare-and-set on the stored pointer revision (0 = absent). */
  putPointer(pointer: PublicationPointer, expectedStoredRevision: number): void;
  idempotency(
    actorUserId: string,
    commandType: string,
    idempotencyKey: string,
  ): Promise<ContentIdempotencyRecord | null>;
  putIdempotency(record: ContentIdempotencyRecord): void;
  appendAudit(entry: ContentAuditEntry): void;
  readonly effects: PublicationEffectSink;
}

/** The Content application service is the only caller allowed to write. */
export interface ContentRepository {
  transact<T>(operation: (transaction: ContentTransaction) => T | Promise<T>): Promise<T>;
}
