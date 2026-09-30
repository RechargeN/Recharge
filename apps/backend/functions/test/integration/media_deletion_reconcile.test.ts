import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  MediaAssetV1,
  MediaDeletionStatusV1,
  OrphanReconciliationV1,
} from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { MediaService } from '../../src/modules/media/application/media_service.js';
import { OrphanReconciler } from '../../src/modules/media/application/orphan_reconciler.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaAuthorityResult,
  MediaRestrictionAuthority,
} from '../../src/modules/media/application/ports/actor_authority_port.js';
import type { AttachmentReferencePort } from '../../src/modules/media/application/ports/attachment_reference_port.js';
import type { EntityScopePort } from '../../src/modules/media/application/ports/entity_scope_port.js';
import type { MediaPolicy } from '../../src/modules/media/domain/media_policy.js';
import type { MediaRetentionPolicy } from '../../src/modules/media/domain/media_retention.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { FakeProcessor } from '../../src/modules/media/infrastructure/fake_processor.js';
import { FakeScanner } from '../../src/modules/media/infrastructure/fake_scanner.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';

const ulid = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const userA = ulid(1);
const userB = ulid(2);
const actorA: MediaActor = { userId: userA, sessionId: ulid(101) };
const actorB: MediaActor = { userId: userB, sessionId: ulid(102) };
const sha = 'a'.repeat(64);

/** Synthetic, explicitly TEST-ONLY policies: not accepted product policies. */
const testPolicy: MediaPolicy = {
  revision: 'policy-test-1',
  families: {
    image: {
      allowedMediaTypes: ['image/jpeg'],
      maxBytes: 4096,
      sessionTtlSeconds: 900,
      maxProcessingAttempts: 3,
      mandatoryVariantProfiles: ['display', 'thumb'],
      validationProfileRevision: 'vp-test-1',
    },
  },
};
const testRetention: MediaRetentionPolicy = {
  revision: 'retention-test-1',
  orphanGraceSeconds: 600,
  quarantinedRetentionSeconds: 300,
  blockedRetentionSeconds: 200,
  deletionReceiptRetentionSeconds: 1000,
};

class FakeAuthority implements MediaActorAuthorityPort {
  readonly revokedSessions = new Set<string>();
  evaluate(request: { actor: MediaActor }): Promise<MediaAuthorityResult> {
    return Promise.resolve(
      this.revokedSessions.has(request.actor.sessionId)
        ? { allowed: false, reason: 'session_invalid' }
        : { allowed: true, authorityRevision: 1 },
    );
  }
}

class FakeReferences implements AttachmentReferencePort {
  readonly referenced = new Set<string>();
  /** Scripted answers consumed first; `throw` simulates an unreachable owning domain. */
  readonly script: (boolean | 'throw')[] = [];
  isReferenced(assetId: string): Promise<boolean> {
    const next = this.script.shift();
    if (next === 'throw') return Promise.reject(new Error('owning domain unreachable'));
    if (next !== undefined) return Promise.resolve(next);
    return Promise.resolve(this.referenced.has(assetId));
  }
}

class FakeRestriction implements MediaRestrictionAuthority {
  readonly trusted = new Set<string>();
  verifyRestriction(input: { decisionRef: string }): Promise<boolean> {
    return Promise.resolve(this.trusted.has(input.decisionRef));
  }
}

function harness(options: { retention?: MediaRetentionPolicy | null } = {}) {
  const repository = new InMemoryMediaRepository();
  const authority = new FakeAuthority();
  const references = new FakeReferences();
  const restriction = new FakeRestriction();
  const objectStore = new FakeObjectStore();
  const scanner = new FakeScanner();
  const processor = new FakeProcessor();
  let clockMs = Date.parse('2026-09-30T09:00:00.000Z');
  const clock: ServerClock = { now: () => new Date(clockMs) };
  let counter = 1000;
  const ids = { newId: () => ulid(++counter) };
  const deletion = new MediaDeletionService({
    repository,
    authority,
    restrictionAuthority: restriction,
    references,
    objectStore,
    clock,
    ids,
  });
  const retention = options.retention === null ? undefined : (options.retention ?? testRetention);
  const reconciler = new OrphanReconciler({
    repository,
    references,
    deletion,
    clock,
    ...(retention === undefined ? {} : { retention }),
  });
  const entityScope: EntityScopePort = {
    authorize: () => Promise.resolve({ allowed: true, entityRevision: 1 }),
  };
  const service = new MediaService({
    repository,
    authority,
    entityScope,
    objectStore,
    scanner,
    processor,
    clock,
    ids,
    enabledFamilies: new Set(['image'] as const),
    policy: testPolicy,
    deletion,
  });
  return {
    service,
    deletion,
    reconciler,
    repository,
    authority,
    references,
    restriction,
    objectStore,
    scanner,
    processor,
    advanceSeconds: (seconds: number) => {
      clockMs += seconds * 1000;
    },
  };
}
type Harness = ReturnType<typeof harness>;

let keySerial = 0;
const key = (label: string): string => `${label}-${String(++keySerial).padStart(6, '0')}`;

const createCommand = () => ({
  schemaVersion: 1,
  commandType: 'createUploadSession',
  idempotencyKey: key('create'),
  payload: {
    family: 'image',
    marketId: 'LV',
    visibilityClass: 'publicDerived',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 2048,
  },
});
const command = (commandType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  commandType,
  idempotencyKey: key(commandType),
  payload,
});
const deleteCommand = (asset: { assetId: string; revision: number }, idempotencyKey?: string) => ({
  ...command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
  ...(idempotencyKey === undefined ? {} : { idempotencyKey }),
});
const reconcileCommand = (assetId: string) => command('reconcileOrphan', { assetId });
const restrictCommand = (assetId: string, decisionRef: string, restricted: boolean) =>
  command('applyRestriction', { assetId, decisionRef, restricted });

async function ok<T>(promise: Promise<{ kind: string }>): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return (result as unknown as { data: T }).data;
}
const denial = (code: string) => ({ kind: 'rejected', code });

function stored(h: Harness, assetId: string) {
  const asset = h.repository.snapshot().assets.find((item) => item.assetId === assetId);
  assert.ok(asset);
  return asset;
}

/** Test stand-in for the client upload. */
function upload(h: Harness, assetId: string): void {
  h.objectStore.put(stored(h, assetId).objectKeyHandle, {
    providerGeneration: 'g-1001',
    byteLength: 2048,
    sha256: sha,
    detectedMediaType: 'image/jpeg',
  });
}

async function reserved(h: Harness) {
  return ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, createCommand()),
  );
}

async function validating(h: Harness) {
  const session = await reserved(h);
  upload(h, session.assetId);
  return ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('confirmUpload', {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
}

async function ready(h: Harness) {
  const asset = await validating(h);
  const result = await ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('finalizeAsset', {
        assetId: asset.assetId,
        expectedAssetRevision: asset.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  assert.equal(result.lifecycle, 'ready');
  for (const variant of result.variantRefs) h.objectStore.variants.add(variant.variantId);
  return result;
}

const effectTypes = (h: Harness) => h.repository.snapshot().effects.map((item) => item.type);

void test('deleting a ready asset tombstones delivery first and then removes bytes and variants', async () => {
  const h = harness();
  const asset = await ready(h);
  const handle = stored(h, asset.assetId).objectKeyHandle;
  const status = await ok<MediaDeletionStatusV1>(h.service.execute(actorA, deleteCommand(asset)));
  assert.equal(status.state, 'completed');
  assert.equal(status.reason, 'owner_request');
  const after = stored(h, asset.assetId);
  assert.equal(after.lifecycle, 'deleted');
  assert.equal(after.deliveryDisabled, true);
  assert.equal(after.variantRefs.length, 0);
  assert.equal(after.variantManifestRevision, undefined);
  assert.ok(after.deletedAtUtc);
  assert.deepEqual(h.objectStore.removedHandles, [handle]);
  assert.equal(h.objectStore.removedVariants.length, 2);
  // Effects carry a monotonic revision so a tombstone beats a stale cache.
  assert.deepEqual(effectTypes(h), [
    'MediaAssetReady',
    'MediaDeliveryDisabled',
    'MediaAssetDeleted',
  ]);
  const revisions = h.repository.snapshot().effects.map((item) => item.assetRevision);
  assert.deepEqual(
    [...revisions].sort((a, b) => a - b),
    revisions,
  );
  assert.equal(new Set(revisions).size, revisions.length);
  const read = await ok<MediaDeletionStatusV1>(
    h.service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDeletionStatus',
      payload: { assetId: asset.assetId },
    }),
  );
  assert.equal(read.state, 'completed');
});

void test('deletion is idempotent, revision-checked and owner-only', async () => {
  const h = harness();
  const asset = await ready(h);
  const cmd = deleteCommand(asset, 'delete-fixed-key');
  assert.deepEqual(await h.service.execute(actorB, cmd), denial('not_found'));
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand({ ...asset, revision: asset.revision - 1 })),
    denial('stale_revision'),
  );
  const first = await ok<MediaDeletionStatusV1>(h.service.execute(actorA, cmd));
  const replay = await ok<MediaDeletionStatusV1>(h.service.execute(actorA, cmd));
  assert.deepEqual(replay, first);
  assert.equal(h.objectStore.removedHandles.length, 1);
  assert.deepEqual(
    await h.service.execute(actorA, {
      ...cmd,
      payload: { ...cmd.payload, expectedAssetRevision: 99 },
    }),
    denial('idempotency_conflict'),
  );
  assert.deepEqual(
    await h.service.query(actorB, {
      schemaVersion: 1,
      queryType: 'getDeletionStatus',
      payload: { assetId: asset.assetId },
    }),
    denial('not_found'),
  );
});

void test('a revoked Session cannot delete, and in-flight assets are not deletable', async () => {
  const h = harness();
  const inflight = await validating(h);
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(inflight)),
    denial('invalid_state'),
  );
  const asset = await ready(h);
  h.authority.revokedSessions.add(actorA.sessionId);
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(asset)),
    denial('unauthenticated'),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
});

void test('a referenced asset is never deleted, and doubt counts as referenced', async () => {
  const h = harness();
  const asset = await ready(h);
  h.references.referenced.add(asset.assetId);
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(asset)),
    denial('asset_referenced'),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
  h.references.referenced.clear();
  h.references.script.push('throw');
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(asset)),
    denial('asset_referenced'),
  );
  assert.equal(stored(h, asset.assetId).deliveryDisabled, false);
  assert.equal(h.objectStore.removedHandles.length, 0);
});

void test('unconfirmed cleanup leaves the asset deleting and a later run finishes it', async () => {
  const h = harness();
  const asset = await ready(h);
  h.objectStore.failRemovals = true;
  const pending = await ok<MediaDeletionStatusV1>(h.service.execute(actorA, deleteCommand(asset)));
  assert.equal(pending.state, 'pending');
  const midway = stored(h, asset.assetId);
  assert.equal(midway.lifecycle, 'deleting');
  assert.equal(midway.deliveryDisabled, true);
  // The tombstone already holds: nothing can bring it back while cleanup is pending.
  assert.deepEqual(effectTypes(h), ['MediaAssetReady', 'MediaDeliveryDisabled']);
  h.objectStore.failRemovals = false;
  const resumed = await ok<OrphanReconciliationV1>(
    h.reconciler.reconcile(reconcileCommand(asset.assetId)),
  );
  assert.equal(resumed.action, 'deleted');
  assert.equal(stored(h, asset.assetId).lifecycle, 'deleted');
  assert.deepEqual(effectTypes(h).slice(-1), ['MediaAssetDeleted']);
});

void test('aborting an upload deletes at once when no object exists and cleans up otherwise', async () => {
  const empty = harness();
  const first = await reserved(empty);
  const before = stored(empty, first.assetId);
  const status = await ok<MediaDeletionStatusV1>(
    empty.service.execute(actorA, deleteCommand(before)),
  );
  assert.equal(status.state, 'completed');
  assert.equal(stored(empty, first.assetId).lifecycle, 'deleted');
  assert.equal(empty.repository.snapshot().sessions[0]?.state, 'aborted');

  const partial = harness();
  const second = await reserved(partial);
  const target = stored(partial, second.assetId);
  partial.objectStore.putPartial(target.objectKeyHandle);
  partial.objectStore.failRemovals = true;
  const pending = await ok<MediaDeletionStatusV1>(
    partial.service.execute(actorA, deleteCommand(target)),
  );
  assert.equal(pending.state, 'pending');
  assert.equal(stored(partial, second.assetId).lifecycle, 'deleting');
  partial.objectStore.failRemovals = false;
  const done = await partial.deletion.completeDeletion(second.assetId);
  assert.equal(done.state, 'completed');
  assert.equal(stored(partial, second.assetId).lifecycle, 'deleted');
});

void test('a restriction is a verified system instruction and never a user command', async () => {
  const h = harness();
  const asset = await ready(h);
  // A user, even the owner, cannot send system commands.
  assert.deepEqual(
    await h.service.execute(actorA, restrictCommand(asset.assetId, 'decision-1', true)),
    denial('capability_denied'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, reconcileCommand(asset.assetId)),
    denial('capability_denied'),
  );
  // An unverified instruction mutates nothing.
  assert.deepEqual(
    await h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-1', true)),
    denial('capability_denied'),
  );
  assert.equal(stored(h, asset.assetId).deliveryDisabled, false);
  h.restriction.trusted.add('decision-1');
  const cmd = restrictCommand(asset.assetId, 'decision-1', true);
  const restricted = await ok<MediaAssetV1>(h.deletion.applyRestriction(cmd));
  assert.equal(restricted.deliveryDisabled, true);
  assert.equal(restricted.lifecycle, 'ready');
  const replay = await ok<MediaAssetV1>(h.deletion.applyRestriction(cmd));
  assert.deepEqual(replay, restricted);
  assert.equal(effectTypes(h).filter((item) => item === 'MediaDeliveryDisabled').length, 1);
  assert.deepEqual(
    await h.deletion.applyRestriction({ ...cmd, payload: { ...cmd.payload, restricted: false } }),
    denial('idempotency_conflict'),
  );
  h.restriction.trusted.add('decision-2');
  const lifted = await ok<MediaAssetV1>(
    h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-2', false)),
  );
  assert.equal(lifted.deliveryDisabled, false);
  assert.equal(lifted.lifecycle, 'ready');
  assert.deepEqual(effectTypes(h).slice(-1), ['MediaDeliveryRestored']);
  assert.deepEqual(await h.deletion.applyRestriction('nope'), denial('invalid_contract'));
  assert.deepEqual(await h.deletion.applyRestriction({ ...cmd, schemaVersion: 2 }), {
    kind: 'unsupportedContract',
    code: 'unsupported_version',
  });
});

void test('a restriction cannot lift a deletion and a deleted asset stays deleted', async () => {
  const h = harness();
  const asset = await ready(h);
  await ok(h.service.execute(actorA, deleteCommand(asset)));
  h.restriction.trusted.add('decision-9');
  assert.deepEqual(
    await h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-9', false)),
    denial('invalid_state'),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'deleted');
  assert.equal(stored(h, asset.assetId).deliveryDisabled, true);
  h.restriction.trusted.add('decision-8');
  assert.deepEqual(
    await h.deletion.applyRestriction(restrictCommand(ulid(9999), 'decision-8', true)),
    denial('not_found'),
  );
});

void test('detach starts the orphan clock only when the owning domain no longer references the asset', async () => {
  const h = harness();
  const asset = await ready(h);
  h.references.referenced.add(asset.assetId);
  const detach = command('detachAsset', {
    assetId: asset.assetId,
    expectedAssetRevision: asset.revision,
  });
  assert.deepEqual(await h.service.execute(actorA, detach), denial('asset_referenced'));
  h.references.referenced.clear();
  const done = await ok<MediaAssetV1>(h.service.execute(actorA, detach));
  assert.ok(done.orphanSinceUtc);
  const replay = await ok<MediaAssetV1>(h.service.execute(actorA, detach));
  assert.deepEqual(replay, done);
  assert.deepEqual(
    await h.service.execute(
      actorB,
      command('detachAsset', { assetId: asset.assetId, expectedAssetRevision: done.revision }),
    ),
    denial('not_found'),
  );
  await ok(h.service.execute(actorA, deleteCommand(done)));
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('detachAsset', {
        assetId: asset.assetId,
        expectedAssetRevision: stored(h, asset.assetId).revision,
      }),
    ),
    denial('invalid_state'),
  );
});

void test('orphan reconcile marks, waits out the grace and only then deletes', async () => {
  const h = harness();
  const asset = await ready(h);
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  assert.equal((await run()).action, 'marked');
  assert.ok(stored(h, asset.assetId).orphanSinceUtc);
  h.advanceSeconds(599);
  assert.equal((await run()).action, 'keep');
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
  h.advanceSeconds(1);
  assert.equal((await run()).action, 'deleted');
  assert.equal(stored(h, asset.assetId).lifecycle, 'deleted');
  assert.equal(h.repository.snapshot().deletions[0]?.reason, 'orphan_cleanup');
  // A repeat is stable.
  assert.equal((await run()).action, 'keep');
});

void test('a reference that appears again cancels cleanup', async () => {
  const h = harness();
  const asset = await ready(h);
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  await run();
  h.references.referenced.add(asset.assetId);
  h.advanceSeconds(10_000);
  assert.equal((await run()).action, 'unmarked');
  assert.equal(stored(h, asset.assetId).orphanSinceUtc, undefined);
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
});

void test('a late reference between decision and cleanup wins over deletion', async () => {
  const h = harness();
  const asset = await ready(h);
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  await run();
  h.advanceSeconds(601);
  // The decision sees "unreferenced"; the re-check before deletion sees a reference.
  h.references.script.push(false, true);
  assert.equal((await run()).action, 'keep');
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
  assert.equal(h.objectStore.removedHandles.length, 0);
  // An unreachable owning domain never lets cleanup proceed.
  h.references.script.push('throw');
  assert.equal((await run()).action, 'keep');
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
});

void test('quarantined, blocked and expired uploads follow their own retention and never touch in-flight assets', async () => {
  const h = harness();
  const inflight = await validating(h);
  h.advanceSeconds(100_000);
  const inflightRun = await ok<OrphanReconciliationV1>(
    h.reconciler.reconcile(reconcileCommand(inflight.assetId)),
  );
  assert.equal(inflightRun.action, 'keep');
  assert.equal(stored(h, inflight.assetId).lifecycle, 'validating');

  const q = harness();
  q.scanner.script.push('inconclusive');
  const asset = await validating(q);
  const quarantined = await ok<MediaAssetV1>(
    q.service.execute(
      actorA,
      command('finalizeAsset', {
        assetId: asset.assetId,
        expectedAssetRevision: asset.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  assert.equal(quarantined.lifecycle, 'quarantined');
  const runQ = () =>
    ok<OrphanReconciliationV1>(q.reconciler.reconcile(reconcileCommand(asset.assetId)));
  assert.equal((await runQ()).action, 'marked');
  q.advanceSeconds(299);
  assert.equal((await runQ()).action, 'keep');
  q.advanceSeconds(1);
  assert.equal((await runQ()).action, 'deleted');

  const b = harness();
  b.scanner.script.push('rejected');
  const blockedAsset = await validating(b);
  await ok(
    b.service.execute(
      actorA,
      command('finalizeAsset', {
        assetId: blockedAsset.assetId,
        expectedAssetRevision: blockedAsset.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  const runB = () =>
    ok<OrphanReconciliationV1>(b.reconciler.reconcile(reconcileCommand(blockedAsset.assetId)));
  assert.equal((await runB()).action, 'marked');
  b.advanceSeconds(200);
  assert.equal((await runB()).action, 'deleted');

  const u = harness();
  const abandoned = await reserved(u);
  const runU = () =>
    ok<OrphanReconciliationV1>(u.reconciler.reconcile(reconcileCommand(abandoned.assetId)));
  assert.equal((await runU()).action, 'keep');
  u.advanceSeconds(901);
  assert.equal((await runU()).action, 'deleted');
  assert.equal(u.repository.snapshot().deletions[0]?.reason, 'expired_upload');
  assert.equal(u.repository.snapshot().sessions[0]?.state, 'expired');
});

void test('reconcile needs an accepted retention policy and a well-formed system command', async () => {
  const h = harness({ retention: null });
  const asset = await ready(h);
  assert.deepEqual(
    await h.reconciler.reconcile(reconcileCommand(asset.assetId)),
    denial('policy_unavailable'),
  );
  assert.equal(stored(h, asset.assetId).orphanSinceUtc, undefined);
  const withPolicy = harness();
  const other = await ready(withPolicy);
  assert.deepEqual(await withPolicy.reconciler.reconcile('x'), denial('invalid_contract'));
  assert.deepEqual(
    await withPolicy.reconciler.reconcile(deleteCommand(other)),
    denial('invalid_contract'),
  );
  assert.deepEqual(
    await withPolicy.reconciler.reconcile({ ...reconcileCommand(other.assetId), schemaVersion: 2 }),
    {
      kind: 'unsupportedContract',
      code: 'unsupported_version',
    },
  );
  assert.deepEqual(
    await withPolicy.reconciler.reconcile(reconcileCommand(ulid(9999))),
    denial('not_found'),
  );
});
