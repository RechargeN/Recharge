import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { activateRevision } from '../../src/modules/content/domain/publication_pointer.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { newId, registerContentScenarios } from '../support/content_repository_scenarios.js';

const pointerFor = (contentId: ReturnType<typeof newId>) =>
  activateRevision(null, 0, contentId, newId(), parseUtcInstant('2026-09-30T10:05:00.000Z'));

const firestore = emulatorFirestore();

async function cleanup(): Promise<void> {
  for (const collection of Object.values(contentCollections))
    for (;;) {
      const snapshot = await firestore.collection(collection).limit(200).get();
      if (snapshot.empty) break;
      const batch = firestore.batch();
      for (const document of snapshot.docs) batch.delete(document.ref);
      await batch.commit();
    }
}

before(cleanup);
after(cleanup);

// The very same scenario suite that runs against the in-memory adapter.
registerContentScenarios(
  (name, run) => void test(name, run),
  'firestore',
  (limits) => new FirestoreContentRepository(firestore, limits === undefined ? {} : { limits }),
);

/**
 * Minimal Firestore double whose `runTransaction` aborts the first attempt (its
 * writes are discarded, as after a contention abort) and runs the callback again.
 */
function retryingFirestore(applied: { path: string; data: unknown }[]) {
  const query = {
    where: () => query,
    orderBy: () => query,
    select: () => query,
    limit: () => query,
  };
  const reference = (collection: string, id: string) => ({ path: `${collection}/${id}` });
  return {
    projectId: 'demo-recharge',
    collection: (name: string) => ({
      doc: (id: string) => reference(name, id),
      where: () => query,
    }),
    async runTransaction<T>(callback: (transaction: unknown) => Promise<T>): Promise<T> {
      for (let attempt = 1; attempt <= 2; attempt += 1) {
        const writes: { path: string; data: unknown }[] = [];
        const transaction = {
          get: (target: { path?: string }) =>
            Promise.resolve(
              target.path === undefined
                ? { docs: [], empty: true }
                : { exists: false, data: () => undefined },
            ),
          set: (ref: { path: string }, data: unknown) => {
            writes.push({ path: ref.path, data });
          },
        };
        const result = await callback(transaction);
        if (attempt === 2) {
          applied.push(...writes);
          return result;
        }
        // attempt 1 is aborted before commit: its writes never happen.
      }
      throw new Error('unreachable');
    },
  };
}

void test('a retried transaction runs the callback again with a new, empty buffer', async () => {
  const applied: { path: string; data: unknown }[] = [];
  const repository = new FirestoreContentRepository(
    retryingFirestore(applied) as unknown as typeof firestore,
    { environment: { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', GCLOUD_PROJECT: 'demo-recharge' } },
  );
  const auditId = newId();
  let attempts = 0;
  await repository.transact((tx) => {
    attempts += 1;
    // A create-only record staged in every attempt: a buffer leaked from the
    // aborted attempt would collide with itself and the commit would refuse.
    tx.appendAudit({
      auditId,
      occurredAtUtc: '2026-09-30T10:00:00.000Z',
      actorUserId: newId(),
      action: 'retry.probe',
      subjectId: newId(),
      outcome: 'succeeded',
    });
  });
  assert.equal(attempts, 2);
  assert.deepEqual(
    applied.map((item) => item.path),
    [`${contentCollections.audit}/${auditId}`],
  );
});

void test('firestore: contending transactions leave one winner and roll the losers back completely', async () => {
  const repository = new FirestoreContentRepository(firestore);
  const contentId = newId();
  const auditIds = Array.from({ length: 6 }, () => newId());
  let attempts = 0;
  const results = await Promise.allSettled(
    auditIds.map((auditId) =>
      repository.transact(async (tx) => {
        attempts += 1;
        await tx.pointer(contentId);
        tx.appendAudit({
          auditId,
          occurredAtUtc: '2026-09-30T10:00:00.000Z',
          actorUserId: newId(),
          action: 'contention.probe',
          subjectId: contentId,
          outcome: 'succeeded',
        });
        tx.putPointer(pointerFor(contentId), 0);
      }),
    ),
  );
  assert.equal(results.filter((item) => item.status === 'fulfilled').length, 1);
  assert.ok(attempts >= auditIds.length);
  // Only the winner's audit record exists: every loser rolled back completely.
  const stored = await Promise.all(
    auditIds.map((auditId) => firestore.collection(contentCollections.audit).doc(auditId).get()),
  );
  assert.equal(stored.filter((item) => item.exists).length, 1);
});

void test('firestore: bodies are stored as text, never as indexed nested fields', async () => {
  const snapshot = await firestore.collection(contentCollections.drafts).limit(20).get();
  assert.ok(snapshot.size > 0, 'the scenario suite must have stored drafts');
  for (const document of snapshot.docs) {
    const data = document.data();
    assert.equal(typeof data.bodyJson, 'string');
    assert.equal('body' in data, false);
    assert.ok(Array.isArray(data.mediaAssetIds));
  }
});
