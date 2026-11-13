import type {
  ContentBody,
  ContentDraftV1,
  ContentProvenanceV1,
  ContentReferenceRevisionsV1,
  ContentTypeId,
  DelegatedOriginV1,
  SourceRefreshV1,
} from '../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import { ContentDomainRefusal } from './failures.js';

export type ContentDraft = DeepReadonly<ContentDraftV1>;

const maxBodyBytes = 64 * 1024;
const maxBodyDepth = 8;

/** Provenance of content authored directly by a signed-in user. */
export function directProvenance(userId: string): ContentProvenanceV1 {
  return deepFreeze({
    kind: 'creatorSubmission',
    importerActorRef: `user:${userId}`,
    originBinding: { kind: 'directAuthoring' },
  } satisfies ContentProvenanceV1);
}

/**
 * Provenance of an owner import. Only what the source really supplied is
 * recorded; optional fields are omitted rather than invented.
 */
export function importProvenance(origin: DelegatedOriginV1): ContentProvenanceV1 {
  return deepFreeze({
    kind: 'ownerImport',
    sourceId: origin.sourceId,
    sourceRevision: origin.sourceRevision,
    ...(origin.snapshotHash === undefined ? {} : { snapshotHash: origin.snapshotHash }),
    ...(origin.sourceUrlRef === undefined ? {} : { sourceUrlRef: origin.sourceUrlRef }),
    acquiredAtUtc: origin.acquiredAtUtc,
    ...(origin.checkedAtUtc === undefined ? {} : { checkedAtUtc: origin.checkedAtUtc }),
    correctionRemovalPolicyRef: origin.correctionRemovalPolicyRef,
    importerActorRef: origin.delegatedActorRef,
    originBinding: {
      kind: 'delegatedImport',
      delegatedActorRef: origin.delegatedActorRef,
      externalBindingRef: origin.externalBindingRef,
    },
  } satisfies ContentProvenanceV1);
}

/**
 * Refresh the source snapshot of an imported draft. The binding, the importer
 * and the acquisition facts are immutable; only the source revision, its hash
 * and the last check move forward.
 */
export function refreshProvenance(
  provenance: ContentProvenanceV1,
  refresh: SourceRefreshV1,
): ContentProvenanceV1 {
  if (provenance.kind !== 'ownerImport') throw new ContentDomainRefusal('capability_denied');
  // Only the moving source facts are replaced; everything else is carried over.
  const stable: Record<string, unknown> = { ...provenance };
  delete stable.snapshotHash;
  delete stable.checkedAtUtc;
  return deepFreeze({
    ...stable,
    sourceRevision: refresh.sourceRevision,
    ...(refresh.snapshotHash === undefined ? {} : { snapshotHash: refresh.snapshotHash }),
    ...(refresh.checkedAtUtc === undefined ? {} : { checkedAtUtc: refresh.checkedAtUtc }),
  } as unknown as ContentProvenanceV1);
}

export function assertBoundedBody(body: unknown): asserts body is ContentBody {
  if (typeof body !== 'object' || body === null || Array.isArray(body))
    throw new ContentDomainRefusal('validation_failed');
  if (depthOf(body, 0) > maxBodyDepth) throw new ContentDomainRefusal('validation_failed');
  if (Buffer.byteLength(JSON.stringify(body), 'utf8') > maxBodyBytes)
    throw new ContentDomainRefusal('validation_failed');
}

function depthOf(value: unknown, level: number): number {
  if (typeof value !== 'object' || value === null) return level;
  if (level >= maxBodyDepth + 1) return level;
  let deepest = level + 1;
  for (const child of Object.values(value)) deepest = Math.max(deepest, depthOf(child, level + 1));
  return deepest;
}

/**
 * D4: the binding of a user's local import source to one Content draft. One
 * author's `loc_*` key binds to at most one draft; it lives with the delegated
 * import bindings and has the same uniqueness rule.
 */
export function localImportBindingRef(createdByUserId: string, importSourceKey: string): string {
  return `local-import:v1:${createdByUserId}:${importSourceKey}`;
}

export function createContentDraft(input: {
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly body: ContentBody;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly createdByUserId: EntityId | null;
  readonly provenance: ContentProvenanceV1;
  readonly importSourceKey?: string;
  readonly importGeneration?: number;
  readonly nowUtc: UtcInstant;
}): ContentDraft {
  assertBoundedBody(input.body);
  return deepFreeze({
    schemaVersion: 1,
    draftId: input.draftId,
    contentId: input.contentId,
    typeId: input.typeId,
    typeSchemaMajor: 1,
    publisherRef: { ...input.publisherRef },
    // Immutable origin: workspace switching never rewrites authorship.
    publisherBindingOrigin: { ...input.publisherRef },
    marketId: input.marketId,
    status: 'editing',
    revision: 1,
    body: structuredClone(input.body),
    referenceRevisions: { ...input.referenceRevisions },
    createdByUserId: input.createdByUserId,
    provenance: structuredClone(input.provenance),
    ...(input.importSourceKey === undefined ? {} : { importSourceKey: input.importSourceKey }),
    ...(input.importGeneration === undefined ? {} : { importGeneration: input.importGeneration }),
    createdAtUtc: input.nowUtc,
    updatedAtUtc: input.nowUtc,
  } satisfies ContentDraftV1);
}

export function updateContentDraftBody(
  draft: ContentDraft,
  expectedRevision: number,
  body: ContentBody,
  referenceRevisions: ContentReferenceRevisionsV1,
  nowUtc: UtcInstant,
  sourceRefresh?: SourceRefreshV1,
): ContentDraft {
  assertNotRolledBack(draft);
  if (draft.revision !== expectedRevision) throw new ContentDomainRefusal('revision_conflict');
  if (draft.status === 'submitted') throw new ContentDomainRefusal('revision_conflict');
  assertBoundedBody(body);
  return deepFreeze({
    ...structuredClone(draft),
    status: draft.status === 'revision_requested' ? 'editing' : draft.status,
    revision: draft.revision + 1,
    body: structuredClone(body),
    referenceRevisions: { ...referenceRevisions },
    provenance:
      sourceRefresh === undefined
        ? structuredClone(draft.provenance)
        : refreshProvenance(draft.provenance, sourceRefresh),
    updatedAtUtc: nowUtc,
  });
}

/** Status-only transition: the content revision is unchanged. */
export function withDraftStatus(
  draft: ContentDraft,
  status: ContentDraftV1['status'],
  nowUtc: UtcInstant,
): ContentDraft {
  return deepFreeze({
    ...structuredClone(draft),
    status,
    updatedAtUtc: nowUtc,
  });
}

export function assertSubmittable(draft: ContentDraft, expectedRevision: number): void {
  assertNotRolledBack(draft);
  if (draft.revision !== expectedRevision) throw new ContentDomainRefusal('revision_conflict');
  if (draft.status === 'submitted') throw new ContentDomainRefusal('revision_conflict');
}

/** D4.1: a rolled-back import is a terminal tombstone; it is never edited or revived. */
export function assertNotRolledBack(draft: ContentDraft): void {
  if (draft.status === 'rolledBack') throw new ContentDomainRefusal('import_rolled_back');
}

/**
 * D4.1: the tombstone of a rolled-back import. Only the exact revision the
 * author confirmed is rolled back; the body is kept for audit, never deleted.
 */
export function rollBackImportedDraft(
  draft: ContentDraft,
  expectedRevision: number,
  nowUtc: UtcInstant,
): ContentDraft {
  assertNotRolledBack(draft);
  if (draft.status === 'submitted') throw new ContentDomainRefusal('import_rollback_not_allowed');
  if (draft.revision !== expectedRevision) throw new ContentDomainRefusal('revision_conflict');
  return deepFreeze({
    ...structuredClone(draft),
    status: 'rolledBack',
    revision: draft.revision + 1,
    updatedAtUtc: nowUtc,
  });
}
