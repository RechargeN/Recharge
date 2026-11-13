// D4.1 (LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md §4): the shared rollback and
// cleanup scenarios over the Firestore adapter, then the races only real
// Firestore transactions can decide: rollback against submit, rollback against
// a cleanup reservation, two installations reserving at once, and a D4 binding
// stored before generations existed.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { after, before, test } from 'node:test';

import {
  createContentDraft,
  directProvenance,
  localImportBindingRef,
} from '../../src/modules/content/domain/content_draft.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import {
  bodyFor,
  fencingTokenA,
  fencingTokenB,
  importHarness,
  localImportRollbackScenarios,
  newId,
} from '../support/content_repository_scenarios.js';

const firestore = emulatorFirestore();
const repository = () => new FirestoreContentRepository(firestore);

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

for (const scenario of localImportRollbackScenarios)
  void test(`firestore: ${scenario.name}`, () => scenario.run(repository));

interface Outcome {
  readonly kind: string;
  readonly data?: unknown;
  readonly code?: string;
}
interface Draft {
  readonly draftId: EntityId;
  readonly revision: number;
  readonly status: string;
}

function succeeded<T>(outcome: Outcome): T {
  assert.equal(outcome.kind, 'succeeded', JSON.stringify(outcome));
  return outcome.data as T;
}

const rounds = 4;

void test('rollback against submit of one draft: exactly one wins, the other gets a typed refusal', async () => {
  const winners = { rollback: 0, submit: 0 };
  for (let round = 0; round < rounds; round += 1) {
    const h = importHarness(repository());
    const imported = succeeded<Draft>(await h.run(h.importCommand()));
    const [rollback, submit] = await Promise.all([
      h.run(h.rollback(imported.draftId, 1, 1)),
      h.run(h.commands.submit(imported.draftId, 1)),
    ]);
    assert.equal(
      [rollback, submit].filter((item) => item.kind === 'succeeded').length,
      1,
      JSON.stringify({ rollback, submit }),
    );
    const draft = await h.draft(imported.draftId);
    if (rollback.kind === 'succeeded') {
      winners.rollback += 1;
      assert.ok(
        ['import_rolled_back', 'revision_conflict', 'source_revision_stale'].includes(
          submit.code ?? '',
        ),
        JSON.stringify(submit),
      );
      assert.equal(draft.status, 'rolledBack');
    } else {
      winners.submit += 1;
      assert.equal(rollback.code, 'import_rollback_not_allowed', JSON.stringify(rollback));
      assert.equal(draft.status, 'submitted');
      assert.equal(succeeded<{ state: string }>(await h.binding()).state, 'active');
    }
  }
  assert.equal(winners.rollback + winners.submit, rounds);
});

void test('cleanup reservation against rollback, from two installations: exactly one wins', async () => {
  for (let round = 0; round < rounds; round += 1) {
    const h = importHarness(repository());
    const imported = succeeded<Draft>(await h.run(h.importCommand()));
    // The second installation is another Session of the same author.
    const otherInstall = { userId: h.owner, sessionId: newId() };
    const [reserve, rollback] = await Promise.all([
      h.run(h.reserve(imported.draftId, 1, `install-a-${String(round)}`, fencingTokenA)),
      h.run(h.rollback(imported.draftId, 1, 1), otherInstall),
    ]);
    assert.equal(
      [reserve, rollback].filter((item) => item.kind === 'succeeded').length,
      1,
      JSON.stringify({ reserve, rollback }),
    );
    const binding = succeeded<{ state: string; cleanup: { state: string } | null }>(
      await h.binding(),
    );
    const draft = await h.draft(imported.draftId);
    if (reserve.kind === 'succeeded') {
      assert.equal(rollback.code, 'cleanup_reserved');
      assert.equal(binding.state, 'active');
      assert.equal(binding.cleanup?.state, 'reserved');
      assert.equal(draft.status, 'editing');
    } else {
      assert.equal(reserve.code, 'import_rolled_back');
      assert.equal(binding.state, 'rolledBack');
      assert.equal(binding.cleanup, null);
      assert.equal(draft.status, 'rolledBack');
    }
  }
});

void test('two installations reserving the same cleanup at once: one token holds it', async () => {
  for (let round = 0; round < rounds; round += 1) {
    const h = importHarness(repository());
    const imported = succeeded<Draft>(await h.run(h.importCommand()));
    const [a, b] = await Promise.all([
      h.run(h.reserve(imported.draftId, 1, 'install-a', fencingTokenA)),
      h.run(h.reserve(imported.draftId, 1, 'install-b', fencingTokenB), {
        userId: h.owner,
        sessionId: newId(),
      }),
    ]);
    const won = [a, b].filter((item) => item.kind === 'succeeded');
    assert.equal(won.length, 1, JSON.stringify({ a, b }));
    assert.equal([a, b].find((item) => item.kind !== 'succeeded')?.code, 'cleanup_reserved');
    const holder = a.kind === 'succeeded' ? fencingTokenA : fencingTokenB;
    const loser = holder === fencingTokenA ? fencingTokenB : fencingTokenA;
    assert.deepEqual(await h.run(h.complete(1, loser)), {
      kind: 'rejected',
      code: 'cleanup_token_mismatch',
    });
    assert.equal(
      succeeded<{ cleanup: { state: string } }>(await h.run(h.complete(1, holder))).cleanup.state,
      'done',
    );
  }
});

void test('a D4 binding stored without generation fields is generation 1 and rolls back', async () => {
  const h = importHarness(repository());
  const draft = createContentDraft({
    draftId: newId(),
    contentId: newId(),
    typeId: 'place',
    publisherRef: { type: 'user', id: h.owner },
    marketId: 'LV',
    body: bodyFor(h.owner),
    referenceRevisions: {
      marketConfigRevisionId: 'mc-lv-1',
      taxonomyRevisionId: 'tx-1',
      localizationRevisionId: 'loc-1',
    },
    createdByUserId: h.owner,
    provenance: directProvenance(h.owner),
    importSourceKey: h.source,
    nowUtc: parseUtcInstant('2026-10-12T10:00:00.000Z'),
  });
  await repository().transact((tx) => {
    tx.putDraft(draft);
  });
  // Exactly the document D4 wrote: the draft id and the binding reference.
  const ref = localImportBindingRef(h.owner, h.source);
  await firestore
    .collection(contentCollections.externalBindings)
    .doc(createHash('sha256').update(ref, 'utf8').digest('hex'))
    .set({ draftId: draft.draftId, externalBindingRef: ref });
  const legacy = succeeded<{ generation: number; state: string; bindingRevision: number }>(
    await h.binding(),
  );
  assert.deepEqual([legacy.generation, legacy.state, legacy.bindingRevision], [1, 'active', 0]);
  // D4 deduplication still finds it.
  assert.equal(succeeded<Draft>(await h.run(h.importCommand())).draftId, draft.draftId);
  assert.equal(succeeded<Draft>(await h.run(h.rollback(draft.draftId, 1, 1))).status, 'rolledBack');
  const next = succeeded<{ draftId: string; importGeneration: number }>(
    await h.run(h.importCommand()),
  );
  assert.notEqual(next.draftId, draft.draftId);
  assert.equal(next.importGeneration, 2);
});
