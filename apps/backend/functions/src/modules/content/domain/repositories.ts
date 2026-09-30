import type { ContentEffectV1, ContentTypeId } from '../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import type { ContentAction } from './content_type_registry.js';
import type { ContentDraft } from './content_draft.js';
import type { PublicationPointer } from './publication_pointer.js';
import type { PublicationSubmission } from './publication_submission.js';
import type { PublishedRevision } from './published_revision.js';

/** Stable cursor over stored effects: the last item of the previous page. */
export interface EffectCursor {
  readonly pointerRevision: number;
  readonly effectId: string;
}

/** Total order of stored effects; the same in every adapter. */
export function compareEffects(
  left: { readonly pointerRevision: number; readonly effectId: string },
  right: { readonly pointerRevision: number; readonly effectId: string },
): number {
  if (left.pointerRevision !== right.pointerRevision)
    return left.pointerRevision - right.pointerRevision;
  return left.effectId < right.effectId ? -1 : left.effectId > right.effectId ? 1 : 0;
}

export function isAfterCursor(
  effect: { readonly pointerRevision: number; readonly effectId: string },
  cursor: EffectCursor | null,
): boolean {
  return cursor === null || compareEffects(effect, cursor) > 0;
}

/** One authority check a stored command result relied on; repeated on every replay. */
export interface ContentAuthorization {
  readonly publisherRef: PublisherRefV1;
  readonly typeId: ContentTypeId;
  readonly action: ContentAction;
  readonly marketId: MarketId;
}

export interface ContentIdempotencyRecord {
  readonly actorUserId: string;
  readonly commandType: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly outcome: unknown;
  readonly authorizations: readonly ContentAuthorization[];
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
  /**
   * One page of stored effects of a Content in `(pointerRevision, effectId)` order
   * strictly after `after` (`null` = from the start). Stored effects are replayed
   * and verified page by page: there is no whole-history read and no silent cap.
   */
  effectsPage(
    contentId: string,
    after: EffectCursor | null,
    limit: number,
  ): Promise<readonly ContentEffectV1[]>;
  /** Whether a publish or activation effect of this revision is stored. */
  hasPublicationEffect(publishedRevisionId: string): Promise<boolean>;
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
