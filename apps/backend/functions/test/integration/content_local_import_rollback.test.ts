// D4.1 (LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md): rollback of a local import,
// binding generations and the fenced cleanup reservation. The shared scenarios
// run here over the in-memory adapter and in `test/emulator/
// content_local_import_rollback.test.ts` over Firestore; what follows them is
// specific to this suite: the audit trail, revoked authority, the Media orphan
// reconcile of a rolled-back body and the Media binding of a tombstone.
import assert from 'node:assert/strict';
import test from 'node:test';

import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import { ContentMediaScope } from '../../src/modules/content/application/content_media_scope.js';
import { ContentPublicationService } from '../../src/modules/content/application/content_publication_service.js';
import type {
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { OrphanReconciler } from '../../src/modules/media/application/orphan_reconciler.js';
import { OrphanSweep } from '../../src/modules/media/application/orphan_sweep.js';
import { createReservedAsset } from '../../src/modules/media/domain/media_asset.js';
import type { MediaRetentionPolicy } from '../../src/modules/media/domain/media_retention.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import {
  bodyFor,
  importHarness,
  localImportRollbackScenarios,
  newId,
  servicePorts,
} from '../support/content_repository_scenarios.js';

for (const scenario of localImportRollbackScenarios)
  void test(`in-memory: ${scenario.name}`, () =>
    scenario.run(() => new InMemoryContentRepository()));

interface Draft {
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly revision: number;
  readonly status: string;
}

async function data<T>(promise: Promise<unknown>): Promise<T> {
  const result = (await promise) as { kind: string; data?: unknown; code?: string };
  assert.equal(result.kind, 'succeeded', `unexpected ${result.kind}:${String(result.code)}`);
  return result.data as T;
}

void test('rollback is audited once as content.draft.import_rolled_back', async () => {
  const repository = new InMemoryContentRepository();
  const h = importHarness(repository);
  const imported = await data<Draft>(h.run(h.importCommand()));
  const command = h.rollback(imported.draftId, 1, 1);
  await data(h.run(command));
  await data(h.run(command));
  const audit = repository
    .snapshot()
    .audit.filter((entry) => entry.action === 'content.draft.import_rolled_back');
  assert.equal(audit.length, 1, 'a replay is not a second rollback');
  assert.equal(audit[0]?.subjectId, imported.draftId);
  assert.equal(audit[0]?.actorUserId, h.owner);
});

class Revocable implements PublisherEligibilityPort {
  revoked = false;
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    return Promise.resolve({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: !this.revoked,
      reason: this.revoked ? 'capability_denied' : 'eligible',
      authorityRevision: 1,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
  }
  evaluateDelegated(): Promise<PublisherEligibilityV1> {
    return Promise.reject(new Error('not used'));
  }
}

void test('rollback needs the current Publisher authority; the draft stays as it was', async () => {
  const repository = new InMemoryContentRepository();
  const eligibility = new Revocable();
  const owner = newId();
  const h = importHarness(repository, { owner });
  const service = new ContentPublicationService({ repository, ...servicePorts(), eligibility });
  const imported = await data<Draft>(service.execute(h.actor, h.importCommand()));
  eligibility.revoked = true;
  assert.deepEqual(await service.execute(h.actor, h.rollback(imported.draftId, 1, 1)), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  assert.equal((await h.draft(imported.draftId)).status, 'editing');
  eligibility.revoked = false;
  assert.equal(
    (await data<Draft>(service.execute(h.actor, h.rollback(imported.draftId, 1, 1)))).status,
    'rolledBack',
  );
});

/** Synthetic, explicitly TEST-ONLY retention: not an accepted product policy. */
const testOnlyRetention: MediaRetentionPolicy = {
  revision: 'd4-1-test-only-retention-1',
  orphanGraceSeconds: 60,
  quarantinedRetentionSeconds: 60,
  blockedRetentionSeconds: 60,
  inFlightAttemptLeaseSeconds: 60,
  deletionHoldLeaseSeconds: 30,
  deletionReceiptRetentionSeconds: 600,
};

void test('the media of a rolled-back body is an orphan after grace; an asset used elsewhere stays', async () => {
  const content = new InMemoryContentRepository();
  const h = importHarness(content);
  const only = newId();
  const shared = newId();
  const body = (cover: string, gallery: readonly string[]) => ({
    ...bodyFor(h.owner),
    media: { coverImage: { mediaId: cover }, gallery: gallery.map((mediaId) => ({ mediaId })) },
  });
  const imported = await data<Draft>(h.run(h.importCommand(undefined, body(only, [shared]))));
  // Another draft of the same author keeps referencing the shared asset.
  await data(h.run(h.commands.create(body(shared, []))));

  let ms = Date.parse('2026-10-13T11:00:00.000Z');
  const clock = { now: () => new Date(ms) };
  const media = new InMemoryMediaRepository();
  const objects = new FakeObjectStore();
  for (const [index, assetId] of [only, shared].entries())
    await media.transact((tx) =>
      tx.putAsset(
        {
          ...createReservedAsset({
            assetId,
            ownerSubjectId: h.owner,
            entityBinding: {
              domain: 'content',
              entityId: imported.contentId,
              purpose: 'contentMedia',
            },
            marketId: 'LV',
            family: 'image',
            visibilityClass: 'publicDerived',
            policyRevision: 'policy-test-1',
            objectKeyHandle: `objk:d41-${String(index)}-aaaaaaaaaaaaaaaaaa`,
            nowUtc: parseUtcInstant('2026-10-13T10:00:00.000Z'),
          }),
          lifecycle: 'ready',
        },
        0,
      ),
    );
  const references = new ContentMediaScope({
    repository: content,
    eligibility: servicePorts().eligibility,
  });
  const deletion = new MediaDeletionService({
    repository: media,
    authority: { evaluate: () => Promise.resolve({ allowed: true, authorityRevision: 1 }) },
    restrictionAuthority: { verifyRestriction: () => Promise.resolve({ verified: false }) },
    references,
    objectStore: objects,
    clock,
    ids: { newId },
    retention: testOnlyRetention,
  });
  const sweep = new OrphanSweep({
    repository: media,
    reconciler: new OrphanReconciler({
      repository: media,
      references,
      deletion,
      clock,
      retention: testOnlyRetention,
    }),
    batchSize: 10,
  });
  const asset = async (assetId: EntityId) => {
    const stored = await media.transact((tx) => tx.asset(assetId));
    assert.ok(stored);
    return stored;
  };

  // While the import is live both assets are referenced.
  assert.equal((await sweep.sweep()).actions.marked, 0);
  await data(h.run(h.rollback(imported.draftId, 1, 1)));
  // Content only stopped referencing it; Media marks it and waits for grace.
  assert.equal((await sweep.sweep()).actions.marked, 1);
  assert.ok((await asset(only)).orphanSinceUtc !== undefined);
  assert.equal((await asset(only)).lifecycle, 'ready');
  assert.equal((await asset(shared)).orphanSinceUtc, undefined);
  ms += 61_000;
  assert.equal((await sweep.sweep()).actions.deleted, 1);
  assert.equal((await asset(only)).lifecycle, 'deleted');
  assert.equal((await asset(shared)).lifecycle, 'ready');
  // The tombstone accepts no new Media binding.
  assert.deepEqual(
    await references.authorize({
      actor: h.actor,
      entity: { domain: 'content', entityId: imported.contentId, purpose: 'contentMedia' },
      publisherRef: { type: 'user', id: h.owner },
      marketId: 'LV',
      nowUtc: new Date(ms).toISOString(),
    }),
    { allowed: false },
  );
});
