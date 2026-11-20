import type { DocumentReference, Transaction } from 'firebase-admin/firestore';

import type {
  PrivacyApplier,
  PrivacyPlannedEffect,
} from '../../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import { contentCollections } from './firestore_content_repository.js';

/**
 * PB-18 (round 1, owner decisions 2026-11-20): the Content owner erases a
 * subject's private, never-published personal draft inside the DSR sweep. It
 * is an internal owner applier, not a user command. A draft that is published
 * (a publication pointer exists), is waiting for review, or publishes as a
 * Page is not personal private data and stays (PB-02 / PB-03).
 */
export const contentPrivacyAppliers: Readonly<Record<string, PrivacyApplier>> = Object.freeze({
  [contentCollections.drafts]: {
    async inTransaction(
      tx: Transaction,
      ref: DocumentReference,
      data: Record<string, unknown>,
    ): Promise<PrivacyPlannedEffect> {
      const publisher = data.publisherRef as { readonly type?: unknown } | undefined;
      if (publisher !== undefined && publisher !== null && publisher.type !== 'user')
        return { outcome: { blocked: 'PB-03' } };
      if (data.status === 'submitted') return { outcome: { blocked: 'PB-02' } };
      const contentId = data.contentId;
      if (typeof contentId === 'string' && contentId.length > 0) {
        const pointer = await tx.get(
          ref.firestore.collection(contentCollections.pointers).doc(contentId),
        );
        if (pointer.exists) return { outcome: { blocked: 'PB-02' } };
      }
      return {
        outcome: 'erased',
        write: () => {
          tx.delete(ref);
        },
      };
    },
  },
});
