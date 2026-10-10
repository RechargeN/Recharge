// D2 §8 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): R2 walks every asset through
// the existing `media.reconcileOrphan` logic. Without an accepted retention
// policy nothing is deleted; with the explicitly test-only policy a real orphan
// is deleted and anything the owning domain still references — or cannot
// answer about — is kept. T10 (in-process half).
import assert from 'node:assert/strict';
import test from 'node:test';

import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { OrphanReconciler } from '../../src/modules/media/application/orphan_reconciler.js';
import { OrphanSweep } from '../../src/modules/media/application/orphan_sweep.js';
import {
  createReservedAsset,
  withRestriction,
  type MediaAsset,
} from '../../src/modules/media/domain/media_asset.js';
import type { MediaRetentionPolicy } from '../../src/modules/media/domain/media_retention.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;

/** Synthetic, explicitly TEST-ONLY retention: not an accepted product policy. */
const testOnlyRetention: MediaRetentionPolicy = {
  revision: 'd2-test-only-retention-1',
  orphanGraceSeconds: 60,
  quarantinedRetentionSeconds: 60,
  blockedRetentionSeconds: 60,
  inFlightAttemptLeaseSeconds: 60,
  deletionHoldLeaseSeconds: 30,
  deletionReceiptRetentionSeconds: 600,
};

function readyAsset(n: number): MediaAsset {
  return {
    ...createReservedAsset({
      assetId: id(n),
      ownerSubjectId: id(2),
      entityBinding: { domain: 'content', entityId: id(10), purpose: 'contentMedia' },
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'policy-test-1',
      objectKeyHandle: `objk:test-${String(n)}-aaaaaaaaaaaaaaaaaa`,
      nowUtc: parseUtcInstant('2026-10-09T08:00:00.000Z'),
    }),
    lifecycle: 'ready',
  };
}

async function harness(retention: MediaRetentionPolicy | undefined) {
  let ms = Date.parse('2026-10-09T09:00:00.000Z');
  const clock = { now: () => new Date(ms) };
  const repository = new InMemoryMediaRepository();
  const objects = new FakeObjectStore();
  // 31: orphan; 32: referenced by a draft or any revision; 33: owning domain
  // cannot answer; 34: restricted orphan; 35..: paging.
  const referenced = new Set<string>([id(32)]);
  const unknown = new Set<string>([id(33)]);
  const references = {
    isReferenced: (assetId: string) =>
      unknown.has(assetId)
        ? Promise.reject(new Error('Content unreachable'))
        : Promise.resolve(referenced.has(assetId)),
  };
  for (const n of [31, 32, 33, 34, ...Array.from({ length: 7 }, (_, index) => 40 + index)]) {
    const asset =
      n === 34
        ? withRestriction(
            readyAsset(n),
            { restricted: true, decisionRef: 'd-1' },
            parseUtcInstant('2026-10-09T08:30:00.000Z'),
          )
        : readyAsset(n);
    await repository.transact((tx) => tx.putAsset(asset, 0));
    if (n >= 40) referenced.add(id(n));
  }
  const deletion = new MediaDeletionService({
    repository,
    authority: { evaluate: () => Promise.resolve({ allowed: true, authorityRevision: 1 }) },
    restrictionAuthority: { verifyRestriction: () => Promise.resolve({ verified: false }) },
    references,
    objectStore: objects,
    clock,
    ids: { newId: () => id(900 + Math.floor(Math.random() * 99)) },
    ...(retention === undefined ? {} : { retention }),
  });
  const sweep = new OrphanSweep({
    repository,
    reconciler: new OrphanReconciler({
      repository,
      references,
      deletion,
      clock,
      ...(retention === undefined ? {} : { retention }),
    }),
    batchSize: 4,
  });
  const asset = async (n: number) => {
    const stored = await repository.transact((tx) => tx.asset(id(n)));
    assert.ok(stored);
    return stored;
  };
  return {
    sweep,
    asset,
    objects,
    advance: (seconds: number) => {
      ms += seconds * 1000;
    },
  };
}

void test('without an accepted retention policy R2 refuses and deletes nothing', async () => {
  const h = await harness(undefined);
  const report = await h.sweep.sweep();
  assert.equal(report.checked, 11, 'every asset, across pages of four');
  assert.deepEqual(report.refused, { policy_unavailable: 11 });
  assert.equal((await h.asset(31)).lifecycle, 'ready');
  assert.equal((await h.asset(31)).orphanSinceUtc, undefined);
});

void test('with the test-only policy: an orphan is marked, then deleted; references are kept', async () => {
  const h = await harness(testOnlyRetention);
  const first = await h.sweep.sweep();
  assert.equal(first.checked, 11);
  assert.equal(first.actions.marked, 2, 'the orphan and the restricted orphan');
  assert.ok((await h.asset(31)).orphanSinceUtc !== undefined);
  assert.equal((await h.asset(32)).orphanSinceUtc, undefined, 'referenced: never marked');
  assert.equal((await h.asset(33)).orphanSinceUtc, undefined, 'doubt counts as a reference');
  h.advance(61);
  const second = await h.sweep.sweep();
  assert.equal(second.actions.deleted, 2);
  assert.equal((await h.asset(31)).lifecycle, 'deleted');
  assert.ok(h.objects.removedHandles.includes((await h.asset(31)).objectKeyHandle));
  for (const kept of [32, 33, 40, 46]) assert.equal((await h.asset(kept)).lifecycle, 'ready');
  // A restriction is never lifted by R2: the tombstone keeps delivery disabled.
  const restricted = await h.asset(34);
  assert.equal(restricted.lifecycle, 'deleted');
  assert.equal(restricted.deliveryDisabled, true);
});
