import type { Firestore } from 'firebase-admin/firestore';

import type { ContentPublicationService } from '../../content/application/content_publication_service.js';
import {
  contentCollections,
  type FirestoreContentRepository,
} from '../../content/infrastructure/firestore_content_repository.js';
import type {
  ContentModerationPort,
  EnforcementInstruction,
  EnforcementOutcome,
  PublicationView,
  SubmissionView,
} from '../application/ports.js';

/**
 * Moderation's window onto Content. Reads go through the Content repository's
 * own decoders; the only write is Content's verified
 * `applyModerationDisposition`, so Content documents are never edited here.
 */
export class ContentModerationAdapter implements ContentModerationPort {
  constructor(
    private readonly firestore: Firestore,
    private readonly repository: FirestoreContentRepository,
    private readonly content: ContentPublicationService,
  ) {}

  async reviewQueue(limit: number): Promise<readonly SubmissionView[]> {
    const snapshot = await this.firestore
      .collection(contentCollections.submissions)
      .where('state', '==', 'under_review')
      .limit(limit)
      .get();
    const items: SubmissionView[] = [];
    for (const document of snapshot.docs) {
      const view = await this.submission(document.id);
      if (view !== null) items.push(view);
    }
    return items.sort((left, right) => (left.submissionId < right.submissionId ? -1 : 1));
  }

  async submission(submissionId: string): Promise<SubmissionView | null> {
    const submission = await this.repository.transact((tx) => tx.submission(submissionId));
    if (submission === null) return null;
    return {
      submissionId: submission.submissionId,
      contentId: submission.contentId,
      state: submission.state,
      revision: submission.revision,
      draftRevision: submission.draftRevision,
      typeId: submission.typeId,
      publisherRef: { type: submission.publisherRef.type, id: submission.publisherRef.id },
    };
  }

  async publication(contentId: string): Promise<PublicationView | null> {
    const pointer = await this.repository.transact((tx) => tx.pointer(contentId));
    if (pointer === null) return null;
    return {
      contentId: pointer.contentId,
      pointerRevision: pointer.revision,
      currentPublishedRevisionId: pointer.currentPublishedRevisionId,
      visibility: pointer.visibility,
      ownerHold: pointer.ownerHold,
      moderationHold:
        pointer.moderationHold === null
          ? null
          : { kind: pointer.moderationHold.kind, decisionId: pointer.moderationHold.decisionId },
    };
  }

  async enforce(instruction: EnforcementInstruction): Promise<EnforcementOutcome> {
    const result = await this.content.applyModerationDisposition({
      schemaVersion: 1,
      commandType: 'applyModerationDisposition',
      idempotencyKey: `${instruction.decisionId}:${instruction.disposition}`.slice(0, 128),
      payload: instruction,
    });
    if (result.kind === 'succeeded')
      return {
        kind: 'applied',
        outcome: result.data.outcome,
        pointerRevision: result.data.pointerRevision,
      };
    return { kind: 'refused', code: result.code };
  }
}
