import { createHash } from 'node:crypto';

import type {
  ContentReferenceRevisionsV1,
  MediaAttachmentV1,
  PublishedRevisionV1,
} from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import type { ContentDraft } from './content_draft.js';
import type { PublicationSubmission } from './publication_submission.js';

export type PublishedRevision = DeepReadonly<PublishedRevisionV1>;

/** Deterministic JSON with sorted object keys (used for hashes only). */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .filter((key) => record[key] !== undefined)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`)
    .join(',')}}`;
}

export function sha256Hex(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

export function createPublishedRevision(input: {
  readonly publishedRevisionId: EntityId;
  readonly revisionNumber: number;
  readonly draft: ContentDraft;
  readonly submission: PublicationSubmission;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly mediaRevision: string;
  readonly mediaAttachments: readonly MediaAttachmentV1[];
  readonly nowUtc: UtcInstant;
}): PublishedRevision {
  return deepFreeze({
    schemaVersion: 1,
    contentId: input.draft.contentId,
    publishedRevisionId: input.publishedRevisionId,
    revisionNumber: input.revisionNumber,
    draftId: input.draft.draftId,
    submissionId: input.submission.submissionId,
    typeId: input.draft.typeId,
    // Authorship is copied from the draft binding; never reassigned later.
    publisherRef: { ...input.draft.publisherRef },
    marketId: input.draft.marketId,
    body: structuredClone(input.draft.body) as PublishedRevisionV1['body'],
    bodyHash: sha256Hex(canonicalJson(input.draft.body)),
    referenceRevisions: { ...input.referenceRevisions },
    mediaRevision: input.mediaRevision,
    mediaAttachments: structuredClone([...input.mediaAttachments]),
    // Provenance is frozen into the revision: later refreshes never rewrite it.
    provenance: structuredClone(input.draft.provenance),
    publishedAtUtc: input.nowUtc,
  } satisfies PublishedRevisionV1);
}
