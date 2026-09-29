import type { PublicationPointerV1 } from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import { ContentDomainRefusal } from './failures.js';

export type PublicationPointer = DeepReadonly<PublicationPointerV1>;

/** Pointer revision that a not-yet-published content id is treated as having. */
export const absentPointerRevision = 0;

/**
 * Advance the pointer to a new immutable revision. The caller supplies the
 * pointer revision it observed; any other value is a stale write.
 */
export function activateRevision(
  current: PublicationPointer | null,
  expectedPointerRevision: number,
  contentId: EntityId,
  publishedRevisionId: EntityId,
  nowUtc: UtcInstant,
): PublicationPointer {
  const currentRevision = current?.revision ?? absentPointerRevision;
  if (currentRevision !== expectedPointerRevision)
    throw new ContentDomainRefusal('revision_conflict');
  return deepFreeze({
    schemaVersion: 1,
    contentId,
    currentPublishedRevisionId: publishedRevisionId,
    previousPublishedRevisionId: current?.currentPublishedRevisionId ?? null,
    visibility: 'visible',
    revision: currentRevision + 1,
    updatedAtUtc: nowUtc,
  } satisfies PublicationPointerV1);
}
