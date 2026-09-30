import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  MediaAssetV1,
  MediaDeletionStatusV1,
  OrphanReconciliationV1,
} from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
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
  inFlightAttemptLeaseSeconds: 120,
  deletionHoldLeaseSeconds: 60,
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
  /** Runs while the owning domain is being asked, i.e. outside any Media transaction. */
  onAsk: (() => Promise<void>) | undefined;
  async isReferenced(assetId: string): Promise<boolean> {
    await this.onAsk?.();
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
  const retentionForDeletion =
    options.retention === null ? undefined : (options.retention ?? testRetention);
  const deletion = new MediaDeletionService({
    ...(retentionForDeletion === undefined ? {} : { retention: retentionForDeletion }),
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

void test('an attempt whose result never arrived is recovered after its lease and a late result is refused', async () => {
  const h = harness();
  const asset = await validating(h);
  const finalize = command('finalizeAsset', {
    assetId: asset.assetId,
    expectedAssetRevision: asset.revision,
    sourceProviderGeneration: 'g-1001',
    expectedSha256: sha,
    expectedByteLength: 2048,
  });
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  // Waiting for its owner to finalize is not an attempt: nothing to recover.
  h.advanceSeconds(10_000);
  assert.equal((await run()).action, 'keep');
  assert.equal(stored(h, asset.assetId).lifecycle, 'validating');
  // The attempt starts, and while the scanner is "running" its worker is lost: the
  // lease passes and the reconciler recovers the attempt.
  let recovered: OrphanReconciliationV1 | undefined;
  h.scanner.onScan = async () => {
    h.advanceSeconds(119);
    assert.equal((await run()).action, 'keep');
    h.advanceSeconds(1);
    recovered = await run();
  };
  // The late result of the abandoned attempt is refused as stale.
  assert.deepEqual(await h.service.execute(actorA, finalize), denial('stale_revision'));
  assert.equal(recovered?.action, 'recovered');
  const after = stored(h, asset.assetId);
  assert.equal(after.lifecycle, 'quarantined');
  assert.equal(after.attemptCount, 1);
  const receipt = h.repository.snapshot().receipts[0];
  assert.equal(receipt?.attemptNumber, 1);
  assert.equal(receipt?.outcome, 'quarantined');
  assert.equal(receipt?.scan.toolRevision, 'attempt-abandoned');
  assert.equal(receipt?.sourceProviderGeneration, 'g-1001');
  // The owner continues with an explicit retry on the same generation.
  h.scanner.onScan = undefined;
  const ready = await ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('retryProcessing', {
        assetId: asset.assetId,
        expectedAssetRevision: after.revision,
        sourceProviderGeneration: 'g-1001',
      }),
    ),
  );
  assert.equal(ready.lifecycle, 'ready');
  assert.equal(ready.attemptCount, 2);
  assert.deepEqual(
    h.repository.snapshot().receipts.map((item) => item.outcome),
    ['quarantined', 'ready'],
  );
  // A recovered attempt counts against the attempt budget, so recovery cannot loop forever.
  assert.equal(stored(h, asset.assetId).attemptCount, 2);
});

void test('a stored result is not a standing permission: replays repeat the current authority check', async () => {
  const h = harness();
  const create = createCommand();
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, create),
  );
  upload(h, session.assetId);
  const confirm = command('confirmUpload', {
    uploadSessionId: session.uploadSessionId,
    expectedSha256: sha,
    expectedByteLength: 2048,
  });
  const confirmed = await ok<MediaAssetV1>(h.service.execute(actorA, confirm));
  const finalize = command('finalizeAsset', {
    assetId: session.assetId,
    expectedAssetRevision: confirmed.revision,
    sourceProviderGeneration: 'g-1001',
    expectedSha256: sha,
    expectedByteLength: 2048,
  });
  const ready = await ok<MediaAssetV1>(h.service.execute(actorA, finalize));
  const detach = command('detachAsset', {
    assetId: session.assetId,
    expectedAssetRevision: ready.revision,
  });
  const detached = await ok<MediaAssetV1>(h.service.execute(actorA, detach));
  const remove = deleteCommand(detached, 'delete-replay-key');
  await ok(h.service.execute(actorA, remove));
  // While authorized, every replay returns the stored result.
  for (const replayed of [create, confirm, finalize, detach, remove])
    assert.equal((await h.service.execute(actorA, replayed)).kind, 'succeeded');
  // Once the Session is revoked the very same commands are refused, and nothing is written.
  const before = JSON.stringify(h.repository.snapshot().audit.length);
  h.authority.revokedSessions.add(actorA.sessionId);
  for (const replayed of [create, confirm, finalize, detach, remove])
    assert.deepEqual(await h.service.execute(actorA, replayed), denial('unauthenticated'));
  assert.equal(JSON.stringify(h.repository.snapshot().audit.length), before);
  // Restoring the authority makes the replay available again: idempotency is intact.
  h.authority.revokedSessions.clear();
  assert.equal((await h.service.execute(actorA, create)).kind, 'succeeded');
  // A changed payload under the same key is still a conflict, never a leak of the old result.
  assert.deepEqual(
    await h.service.execute(actorA, {
      ...create,
      payload: { ...create.payload, declaredByteLength: 1 },
    }),
    denial('idempotency_conflict'),
  );
});

void test('a deletion hold never lifts an authoritative restriction placed while it was open', async () => {
  const h = harness();
  const asset = await ready(h);
  h.restriction.trusted.add('decision-sec-1');
  // First look: not referenced. While the hold is open Security restricts the asset,
  // then the owning domain reports a reference: the deletion is refused.
  let asks = 0;
  h.references.script.push(false, true);
  h.references.onAsk = async () => {
    asks += 1;
    if (asks === 2)
      await ok(h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-sec-1', true)));
  };
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(asset)),
    denial('asset_referenced'),
  );
  h.references.onAsk = undefined;
  const after = stored(h, asset.assetId);
  assert.equal(after.lifecycle, 'ready');
  // The deletion released only its own hold: the restriction and the disabled delivery stay.
  assert.equal(after.deletionHold, undefined);
  assert.equal(after.restricted, true);
  assert.equal(after.deliveryDisabled, true);
  // Only a verified Security instruction lifts it.
  h.restriction.trusted.add('decision-sec-2');
  const lifted = await ok<MediaAssetV1>(
    h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-sec-2', false)),
  );
  assert.equal(lifted.deliveryDisabled, false);
  assert.equal(lifted.restricted, undefined);
});

void test('lifting a restriction keeps delivery disabled while a deletion hold is open, and announces nothing false', async () => {
  const h = harness();
  const asset = await ready(h);
  h.restriction.trusted.add('decision-sec-3');
  await ok(h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-sec-3', true)));
  const before = h.repository.snapshot().effects.length;
  h.references.script.push(false, true);
  let asks = 0;
  h.references.onAsk = async () => {
    asks += 1;
    if (asks === 2) {
      h.restriction.trusted.add('decision-sec-4');
      const lifted = await ok<MediaAssetV1>(
        h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-sec-4', false)),
      );
      // The hold still disables delivery: the restriction flag is gone, delivery is not back.
      assert.equal(lifted.deliveryDisabled, true);
      assert.equal(lifted.restricted, undefined);
    }
  };
  // The restricted asset is deletable (first look unreferenced), then referenced at the second look.
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(stored(h, asset.assetId))),
    denial('asset_referenced'),
  );
  h.references.onAsk = undefined;
  const after = stored(h, asset.assetId);
  assert.equal(after.deliveryDisabled, false);
  assert.equal(after.deletionHold, undefined);
  // Only the real changes were announced: restored exactly once, at the end.
  const types = h.repository
    .snapshot()
    .effects.slice(before)
    .map((item) => item.type);
  assert.deepEqual(types, ['MediaDeliveryRestored']);
});

void test('a deletion hold nobody came back for is released after the lease, leaving a restriction alone', async () => {
  const h = harness();
  const asset = await ready(h);
  h.restriction.trusted.add('decision-sec-5');
  await ok(h.deletion.applyRestriction(restrictCommand(asset.assetId, 'decision-sec-5', true)));
  // A worker died right after placing its hold.
  await h.repository.transact(async (tx) => {
    const current = await tx.asset(asset.assetId);
    assert.ok(current);
    tx.putAsset(
      {
        ...current,
        deletionHold: {
          holdId: 'lost-worker',
          expiresAtUtc: parseUtcInstant('2026-09-30T09:01:00.000Z'),
        },
        revision: current.revision + 1,
      },
      current.revision,
    );
  });
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  h.advanceSeconds(59);
  assert.notEqual((await run()).action, 'recovered');
  h.advanceSeconds(1);
  assert.equal((await run()).action, 'recovered');
  const after = stored(h, asset.assetId);
  assert.equal(after.deletionHold, undefined);
  assert.equal(after.restricted, true);
  assert.equal(after.deliveryDisabled, true);
});

void test('an expired holder cannot delete: its stale answer changes nothing and a retry starts over', async () => {
  const h = harness();
  const asset = await ready(h);
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  // First look and the reconciler's own look: no references. Worker A then asks the
  // owning domain; while it waits the lease runs out, the reconciler releases the
  // hold, and a reference appears. A still receives its old answer "no references".
  h.references.script.push(false, false, false);
  let asks = 0;
  let inside = false;
  h.references.onAsk = async () => {
    if (inside) return;
    asks += 1;
    if (asks !== 2) return;
    inside = true;
    h.advanceSeconds(61);
    assert.equal((await run()).action, 'recovered');
    h.references.referenced.add(asset.assetId);
    inside = false;
  };
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(asset)),
    denial('revision_conflict'),
  );
  h.references.onAsk = undefined;
  const after = stored(h, asset.assetId);
  // The late worker changed nothing: not deleted, not deleting, delivery back, nothing removed.
  assert.equal(after.lifecycle, 'ready');
  assert.equal(after.deletionHold, undefined);
  assert.equal(after.deliveryDisabled, false);
  assert.equal(h.objectStore.removedHandles.length, 0);
  assert.equal(h.repository.snapshot().deletions.length, 0);
  // A retry starts the check over and now sees the reference.
  assert.deepEqual(
    await h.service.execute(actorA, deleteCommand(after)),
    denial('asset_referenced'),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
});

void test('a valid hold of another worker refuses, and a taken-over hold fences the old holder', async () => {
  const h = harness();
  const asset = await ready(h);
  const run = () =>
    ok<OrphanReconciliationV1>(h.reconciler.reconcile(reconcileCommand(asset.assetId)));
  h.references.script.push(false, false, false, false, false);
  let asks = 0;
  let inside = false;
  let concurrent: unknown;
  let second: unknown;
  h.references.onAsk = async () => {
    if (inside) return;
    asks += 1;
    // Only worker A's own post-hold question gets here with the hold placed.
    if (asks !== 2) return;
    inside = true;
    // Another delete while A's hold is valid: refused, A is not disturbed.
    concurrent = await h.service.execute(actorA, deleteCommand(stored(h, asset.assetId)));
    // A's lease runs out, the hold is released, and worker B completes the deletion.
    h.advanceSeconds(61);
    assert.equal((await run()).action, 'recovered');
    second = await h.service.execute(actorA, deleteCommand(stored(h, asset.assetId)));
    inside = false;
  };
  const late = await h.service.execute(actorA, deleteCommand(asset));
  h.references.onAsk = undefined;
  assert.deepEqual(concurrent, denial('revision_conflict'));
  assert.equal((second as { kind: string }).kind, 'succeeded');
  // A comes back with its old answer: fenced out, nothing changes, nothing is removed twice.
  assert.deepEqual(late, denial('revision_conflict'));
  assert.equal(stored(h, asset.assetId).lifecycle, 'deleted');
  assert.equal(h.objectStore.removedHandles.length, 1);
  assert.equal(h.repository.snapshot().deletions.length, 1);
});
