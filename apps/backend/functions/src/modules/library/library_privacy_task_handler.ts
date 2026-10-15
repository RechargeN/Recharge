import type { Firestore } from 'firebase-admin/firestore';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { libraryCollections as cols } from './library_contract.js';

/** Same access/restriction/erasure lifecycle as the existing Privacy runner. */
export class LibraryPrivacyTaskHandler {
  constructor(private readonly db: Firestore) {
    assertContentEmulatorContext(db);
  }
  async handle(input: { taskType: 'access' | 'restriction' | 'erasure'; subjectId: string }) {
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
