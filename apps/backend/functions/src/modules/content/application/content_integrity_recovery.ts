import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import { canonicalJson, sha256Hex } from '../domain/published_revision.js';
import type { ContentRepository } from '../domain/repositories.js';

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
      const effects = await tx.effectsForContent(contentId);
      if (pointer === null && revisions.length > 0)
        findings.push({ code: 'pointer_missing', subjectId: contentId });
      revisions.forEach((revision, index) => {
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
        const published = effects.some(
          (effect) =>
            effect.publishedRevisionId === revision.publishedRevisionId &&
            (effect.kind === 'ContentPublished' || effect.kind === 'ContentRevisionActivated'),
        );
        if (!published)
          findings.push({
            code: 'effect_missing_for_revision',
            subjectId: revision.publishedRevisionId,
          });
      });
      if (pointer !== null) {
        const currentId = pointer.currentPublishedRevisionId;
        if (currentId !== null && !revisions.some((item) => item.publishedRevisionId === currentId))
          findings.push({ code: 'current_revision_missing', subjectId: currentId });
        if (!effects.some((effect) => effect.pointerRevision === pointer.revision))
          findings.push({ code: 'effect_missing_for_pointer_revision', subjectId: contentId });
      }
      return { contentId, ok: findings.length === 0, findings };
    });
  }

  /**
   * Hands stored effects to a consumer in `pointerRevision` order, starting after
   * `afterPointerRevision`. The consumer must be idempotent by `effectId`; nothing
   * is written and nothing is invented.
   */
  async replayEffects(
    contentId: string,
    consumer: (effect: ContentEffectV1) => Promise<void>,
    afterPointerRevision = 0,
  ): Promise<number> {
    const effects = await this.repository.transact((tx) => tx.effectsForContent(contentId));
    let delivered = 0;
    for (const effect of effects) {
      if (effect.pointerRevision <= afterPointerRevision) continue;
      await consumer(effect);
      delivered += 1;
    }
    return delivered;
  }
}
