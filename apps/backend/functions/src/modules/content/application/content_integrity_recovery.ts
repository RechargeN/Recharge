import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import { canonicalJson, sha256Hex } from '../domain/published_revision.js';
import type { ContentRepository, EffectCursor } from '../domain/repositories.js';

export type IntegrityFindingCode =
  | 'pointer_missing'
  | 'current_revision_missing'
  | 'revision_content_mismatch'
  | 'revision_body_hash_mismatch'
  | 'revision_number_gap'
  | 'effect_missing_for_pointer_revision'
  | 'effect_missing_for_revision';

export interface IntegrityFinding {
  readonly code: IntegrityFindingCode;
  readonly subjectId: string;
}

export interface IntegrityReport {
  readonly contentId: string;
  readonly ok: boolean;
  /** A missing historical fact is reported as corruption, never invented. */
  readonly findings: readonly IntegrityFinding[];
}

/**
 * Narrow recovery (BCK-07 v0.12 §38.6). The pointer holds only the current state,
 * not the history of activations and visibility changes, so lost effects cannot
 * be rebuilt from it. This service verifies stored records and replays stored
 * effects; anything missing is a finding.
 */
export class ContentIntegrityRecovery {
  constructor(private readonly repository: ContentRepository) {}

  verify(contentId: string): Promise<IntegrityReport> {
    return this.repository.transact(async (tx) => {
      const findings: IntegrityFinding[] = [];
      const revisions = await tx.publishedRevisionsForContent(contentId);
      const pointer = await tx.pointer(contentId);
      if (pointer === null && revisions.length > 0)
        findings.push({ code: 'pointer_missing', subjectId: contentId });
      for (const [index, revision] of revisions.entries()) {
        if (revision.contentId !== contentId)
          findings.push({
            code: 'revision_content_mismatch',
            subjectId: revision.publishedRevisionId,
          });
        if (revision.bodyHash !== sha256Hex(canonicalJson(revision.body)))
          findings.push({
            code: 'revision_body_hash_mismatch',
            subjectId: revision.publishedRevisionId,
          });
        if (revision.revisionNumber !== index + 1)
          findings.push({ code: 'revision_number_gap', subjectId: revision.publishedRevisionId });
        // A targeted read: independent of how many effects the Content has accumulated.
        if (!(await tx.hasPublicationEffect(revision.publishedRevisionId)))
          findings.push({
            code: 'effect_missing_for_revision',
            subjectId: revision.publishedRevisionId,
          });
      }
      if (pointer !== null) {
        const currentId = pointer.currentPublishedRevisionId;
        if (currentId !== null && !revisions.some((item) => item.publishedRevisionId === currentId))
          findings.push({ code: 'current_revision_missing', subjectId: currentId });
        // The first stored effect at or after the pointer revision, however long the history is.
        const [atPointer] = await tx.effectsPage(contentId, before(pointer.revision), 1);
        if (atPointer?.pointerRevision !== pointer.revision)
          findings.push({ code: 'effect_missing_for_pointer_revision', subjectId: contentId });
      }
      return { contentId, ok: findings.length === 0, findings };
    });
  }

  /**
   * Hands stored effects to a consumer in `(pointerRevision, effectId)` order,
   * page by page from a stable cursor, starting after `afterPointerRevision`. The
   * consumer must be idempotent by `effectId`; nothing is written and nothing is
   * invented, and no history length can silently cut the replay short.
   */
  async replayEffects(
    contentId: string,
    consumer: (effect: ContentEffectV1) => Promise<void>,
    afterPointerRevision = 0,
    pageSize = replayPageSize,
  ): Promise<number> {
    let cursor: EffectCursor | null = before(afterPointerRevision + 1);
    let delivered = 0;
    for (;;) {
      const at: EffectCursor | null = cursor;
      const page: readonly ContentEffectV1[] = await this.repository.transact((tx) =>
        tx.effectsPage(contentId, at, pageSize),
      );
      for (const effect of page) {
        await consumer(effect);
        delivered += 1;
      }
      const last = page[page.length - 1];
      if (last === undefined || page.length < pageSize) return delivered;
      cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
    }
  }
}

/** Cursor placed after every effect of the previous pointer revision. */
function before(pointerRevision: number): EffectCursor {
  return { pointerRevision: pointerRevision - 1, effectId: '￿' };
}

export const replayPageSize = 100;
