import type {
  ContentBody,
  ContentDraftV1,
  ContentReferenceRevisionsV1,
  ContentTypeId,
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

export function createContentDraft(input: {
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly body: ContentBody;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly createdByUserId: EntityId;
  readonly importSourceKey?: string;
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
    ...(input.importSourceKey === undefined ? {} : { importSourceKey: input.importSourceKey }),
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
): ContentDraft {
  if (draft.revision !== expectedRevision) throw new ContentDomainRefusal('revision_conflict');
  if (draft.status === 'submitted') throw new ContentDomainRefusal('revision_conflict');
  assertBoundedBody(body);
  return deepFreeze({
    ...structuredClone(draft),
    status: draft.status === 'revision_requested' ? 'editing' : draft.status,
    revision: draft.revision + 1,
    body: structuredClone(body),
    referenceRevisions: { ...referenceRevisions },
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
  if (draft.revision !== expectedRevision) throw new ContentDomainRefusal('revision_conflict');
  if (draft.status === 'submitted') throw new ContentDomainRefusal('revision_conflict');
}
