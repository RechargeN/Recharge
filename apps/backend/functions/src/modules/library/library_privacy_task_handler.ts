import type { Firestore } from 'firebase-admin/firestore';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { libraryCollections as cols } from './library_contract.js';
import type { PrivacyApplier } from '../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import type { PrivacyDomainOutcome } from '../privacy_orchestration/infrastructure/registry_privacy_task_handler.js';

type LibraryPrivacyResult =
  | {
      readonly kind: 'succeeded';
      readonly evidence: {
        readonly recordCount: number;
        readonly erasedCount: number;
        readonly retainedCount: number;
        readonly outcome: 'completed';
      };
    }
  | { readonly kind: 'retryableFailure'; readonly code: 'temporarily_unavailable' };

/** L1: Library's own delete of entries and command receipts, inside the sweep page. */
export const libraryPrivacyAppliers: Readonly<Record<string, PrivacyApplier>> = {
  [cols.entries]: {
    inTransaction: (tx, ref) => Promise.resolve({ outcome: 'erased', write: () => tx.delete(ref) }),
  },
  [cols.receipts]: {
    inTransaction: (tx, ref) => Promise.resolve({ outcome: 'erased', write: () => tx.delete(ref) }),
  },
};

/** Same access/restriction/erasure lifecycle as the existing Privacy runner. */
export class LibraryPrivacyTaskHandler {
  constructor(private readonly db: Firestore) {
    assertContentEmulatorContext(db);
  }
  /**
   * `erase`, when given, deletes the entries and receipts through the L1
   * registry sweep (holds, checkpoints, verification); `erased` is recorded only
   * after it succeeded. Without it the original unpaged loop runs.
   */
  async handle(input: {
    taskType: 'access' | 'restriction' | 'erasure';
    subjectId: string;
    erase?: () => Promise<PrivacyDomainOutcome>;
  }): Promise<PrivacyDomainOutcome | LibraryPrivacyResult> {
    try {
      if (input.taskType === 'access') {
        const count = await this.db
          .collection(cols.entries)
          .where('ownerId', '==', input.subjectId)
          .count()
          .get();
        return {
          kind: 'succeeded',
          evidence: {
            recordCount: count.data().count,
            erasedCount: 0,
            retainedCount: 0,
            outcome: 'completed',
          },
        } as const;
      }
      const ref = this.db.collection(cols.owners).doc(input.subjectId);
      // Every writer reads this document. A concurrent command retries and observes the fence.
      await this.db.runTransaction(async (tx) => {
        const owner = (await tx.get(ref)).data();
        if (owner?.restricted === true) return;
        tx.set(ref, {
          schemaVersion: 1,
          revision: Number(owner?.revision ?? 0) + 1,
          restricted: true,
          erased: owner?.erased === true,
        });
      });
      if (input.taskType === 'erasure' && input.erase !== undefined) {
        const outcome = await input.erase();
        if (outcome.kind === 'succeeded') await ref.set({ erased: true }, { merge: true });
        return outcome;
      }
      let erasedCount = 0;
      if (input.taskType === 'erasure') {
        for (const collection of [cols.entries, cols.receipts]) {
          for (;;) {
            const page = await this.db
              .collection(collection)
              .where('ownerId', '==', input.subjectId)
              .limit(200)
              .get();
            if (page.empty) break;
            const batch = this.db.batch();
            for (const document of page.docs) batch.delete(document.ref);
            await batch.commit();
            erasedCount += page.size;
          }
        }
        await ref.set({ erased: true }, { merge: true });
      }
      return {
        kind: 'succeeded',
        evidence: { recordCount: erasedCount, erasedCount, retainedCount: 0, outcome: 'completed' },
      } as const;
    } catch {
      return { kind: 'retryableFailure', code: 'temporarily_unavailable' } as const;
    }
  }
}
