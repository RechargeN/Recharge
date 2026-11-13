import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaAssetV1, MediaDeletionStatusV1 } from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { MediaService } from '../../src/modules/media/application/media_service.js';
import type { MediaActor } from '../../src/modules/media/application/ports/actor_authority_port.js';
import type { MediaPolicy } from '../../src/modules/media/domain/media_policy.js';
import { toVariantMetadata } from '../../src/modules/media/domain/media_variant.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { FakeProcessor } from '../../src/modules/media/infrastructure/fake_processor.js';
import { FakeScanner } from '../../src/modules/media/infrastructure/fake_scanner.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';

const ulid = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const actorA: MediaActor = { userId: ulid(1), sessionId: ulid(101) };
const actorB: MediaActor = { userId: ulid(2), sessionId: ulid(102) };
const sha = 'a'.repeat(64);

/** Synthetic, explicitly TEST-ONLY policy: not an accepted product policy. */
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

function harness() {
  const repository = new InMemoryMediaRepository();
  const objectStore = new FakeObjectStore();
  const authority = {
    evaluate: () => Promise.resolve({ allowed: true as const, authorityRevision: 1 }),
  };
  const clock: ServerClock = { now: () => new Date('2026-09-30T09:00:00.000Z') };
  let counter = 1000;
  const ids = { newId: () => ulid(++counter) };
  const deletion = new MediaDeletionService({
    retention: {
      revision: 'retention-test-1',
      orphanGraceSeconds: 600,
      quarantinedRetentionSeconds: 300,
      blockedRetentionSeconds: 200,
      inFlightAttemptLeaseSeconds: 120,
      deletionHoldLeaseSeconds: 60,
      deletionReceiptRetentionSeconds: 1000,
    },
    repository,
    authority,
    restrictionAuthority: { verifyRestriction: () => Promise.resolve({ verified: true }) },
    references: { isReferenced: () => Promise.resolve(false) },
    objectStore,
    clock,
    ids,
  });
  const service = new MediaService({
    repository,
    authority,
    entityScope: { authorize: () => Promise.resolve({ allowed: true, entityRevision: 1 }) },
    objectStore,
    scanner: new FakeScanner(),
    processor: new FakeProcessor(),
    clock,
    ids,
    enabledFamilies: new Set(['image'] as const),
    policy: testPolicy,
    deletion,
  });
  return { service, deletion, repository, objectStore };
}
type Harness = ReturnType<typeof harness>;

let keySerial = 0;
const key = (label: string): string => `${label}-${String(++keySerial).padStart(6, '0')}`;
const command = (commandType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  commandType,
  idempotencyKey: key(commandType),
  payload,
});

async function ok<T>(promise: Promise<{ kind: string }>): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return (result as unknown as { data: T }).data;
}

/** Runs the full happy path and returns every outward-facing value it produced. */
async function lifecycle(h: Harness, visibilityClass = 'publicDerived') {
  const outputs: unknown[] = [];
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(
      actorA,
      command('createUploadSession', {
        family: 'image',
        marketId: 'LV',
        visibilityClass,
        declaredMediaType: 'image/jpeg',
        declaredByteLength: 2048,
      }),
    ),
  );
  outputs.push(session);
  const stored = h.repository.snapshot().assets[0];
  assert.ok(stored);
  h.objectStore.put(stored.objectKeyHandle, {
    providerGeneration: 'g-1001',
    byteLength: 2048,
    sha256: sha,
    detectedMediaType: 'image/jpeg',
  });
  const validating = await ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('confirmUpload', {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  outputs.push(validating);
  const ready = await ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('finalizeAsset', {
        assetId: session.assetId,
        expectedAssetRevision: validating.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  outputs.push(ready);
  outputs.push(
    await ok(
      h.service.query(actorA, {
        schemaVersion: 1,
        queryType: 'getAssetStatus',
        payload: { assetId: session.assetId },
      }),
    ),
    await ok(
      h.service.query(actorA, {
        schemaVersion: 1,
        queryType: 'getProcessingReceipt',
        payload: { assetId: session.assetId },
      }),
    ),
  );
  return { session, ready, outputs, handle: stored.objectKeyHandle };
}

const leaks = /objk:|https?:\/\/|signedUrl|publicUrl|bucket|gs:\/\//iu;

void test('no outward value carries object keys, URLs or bucket detail', async () => {
  const h = harness();
  const { ready, outputs, handle } = await lifecycle(h);
  const status = await ok<MediaDeletionStatusV1>(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: ready.assetId, expectedAssetRevision: ready.revision }),
    ),
  );
  outputs.push(
    status,
    await ok(
      h.service.query(actorA, {
        schemaVersion: 1,
        queryType: 'getDeletionStatus',
        payload: { assetId: ready.assetId },
      }),
    ),
    await ok(
      h.service.query(actorA, {
        schemaVersion: 1,
        queryType: 'getAssetStatus',
        payload: { assetId: ready.assetId },
      }),
    ),
  );
  for (const value of outputs) {
    const text = JSON.stringify(value);
    assert.equal(leaks.test(text), false, text);
    assert.equal(text.includes(handle), false);
  }
  // Effects, audit and receipts (the records other domains and operators see) stay clean too.
  const snapshot = h.repository.snapshot();
  for (const value of [snapshot.effects, snapshot.audit, snapshot.receipts, snapshot.deletions])
    assert.equal(leaks.test(JSON.stringify(value)), false);
});

void test('effects and audit carry only ids, revisions, times and outcomes', async () => {
  const h = harness();
  const { ready } = await lifecycle(h);
  await ok(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: ready.assetId, expectedAssetRevision: ready.revision }),
    ),
  );
  const snapshot = h.repository.snapshot();
  assert.ok(snapshot.effects.length >= 3);
  for (const effect of snapshot.effects)
    assert.deepEqual(Object.keys(effect).sort(), [
      'assetId',
      'assetRevision',
      'effectId',
      'occurredAtUtc',
      'schemaVersion',
      'type',
    ]);
  for (const entry of snapshot.audit)
    assert.deepEqual(Object.keys(entry).sort(), [
      'action',
      'actorUserId',
      'auditId',
      'occurredAtUtc',
      'outcome',
      'subjectId',
    ]);
  for (const deletion of snapshot.deletions)
    assert.deepEqual(Object.keys(deletion).sort(), [
      'assetId',
      'completedAtUtc',
      'deletionRevision',
      'reason',
      'requestedAtUtc',
      'schemaVersion',
      'state',
    ]);
});

void test('the deletion tombstone keeps identity only and nothing can resurrect it', async () => {
  const h = harness();
  const { ready } = await lifecycle(h);
  await ok(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: ready.assetId, expectedAssetRevision: ready.revision }),
    ),
  );
  const tomb = h.repository.snapshot().assets[0];
  assert.ok(tomb);
  assert.equal(tomb.lifecycle, 'deleted');
  assert.equal(tomb.sourceGenerationRef, undefined);
  assert.equal(tomb.variantManifestRevision, undefined);
  assert.equal(tomb.variantRefs.length, 0);
  assert.equal(toVariantMetadata(tomb).length, 0);
  // A stale finalize or retry, or a lifted restriction, never returns it to `ready`.
  const finalize = command('finalizeAsset', {
    assetId: ready.assetId,
    expectedAssetRevision: ready.revision,
    sourceProviderGeneration: 'g-1001',
    expectedSha256: sha,
    expectedByteLength: 2048,
  });
  assert.deepEqual(await h.service.execute(actorA, finalize), {
    kind: 'rejected',
    code: 'stale_revision',
  });
  const now = h.repository.snapshot().assets[0];
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('retryProcessing', {
        assetId: ready.assetId,
        expectedAssetRevision: now?.revision ?? 0,
        sourceProviderGeneration: 'g-1001',
      }),
    ),
    { kind: 'rejected', code: 'generation_mismatch' },
  );
  assert.deepEqual(
    await h.deletion.applyRestriction(
      command('applyRestriction', {
        assetId: ready.assetId,
        decisionRef: 'decision-1',
        restricted: false,
      }),
    ),
    { kind: 'rejected', code: 'invalid_state' },
  );
  assert.equal(h.repository.snapshot().assets[0]?.lifecycle, 'deleted');
});

void test('private and protected assets never expose public variant metadata', async () => {
  for (const visibility of ['private', 'protected'] as const) {
    const h = harness();
    const { ready } = await lifecycle(h, visibility);
    assert.equal(ready.lifecycle, 'ready');
    assert.equal(ready.visibilityClass, visibility);
    const stored = h.repository.snapshot().assets[0];
    assert.ok(stored);
    assert.equal(toVariantMetadata(stored).length, 0, visibility);
  }
  const h = harness();
  const { ready } = await lifecycle(h, 'publicDerived');
  const stored = h.repository.snapshot().assets[0];
  assert.ok(stored);
  assert.equal(toVariantMetadata(stored).length, ready.variantRefs.length);
});

void test('a foreign asset is indistinguishable from an unknown one', async () => {
  const h = harness();
  const { ready } = await lifecycle(h);
  const probe = (assetId: string) =>
    Promise.all([
      h.service.query(actorB, {
        schemaVersion: 1,
        queryType: 'getAssetStatus',
        payload: { assetId },
      }),
      h.service.query(actorB, {
        schemaVersion: 1,
        queryType: 'getProcessingReceipt',
        payload: { assetId },
      }),
      h.service.query(actorB, {
        schemaVersion: 1,
        queryType: 'getDeletionStatus',
        payload: { assetId },
      }),
      h.service.execute(actorB, command('deleteAsset', { assetId, expectedAssetRevision: 1 })),
      h.service.execute(actorB, command('detachAsset', { assetId, expectedAssetRevision: 1 })),
    ]);
  assert.deepEqual(await probe(ready.assetId), await probe(ulid(9999)));
  assert.equal((await probe(ready.assetId))[0]?.kind, 'rejected');
});

void test('there is no delivery surface in this slice: handles and URLs cannot be requested', async () => {
  const h = harness();
  const { ready } = await lifecycle(h);
  for (const queryType of ['getDeliveryHandle', 'requestDelivery'])
    assert.deepEqual(
      await h.service.query(actorA, {
        schemaVersion: 1,
        queryType,
        payload: { assetId: ready.assetId },
      }),
      { kind: 'rejected', code: 'invalid_contract' },
      queryType,
    );
  for (const commandType of ['requestDelivery', 'replaceAsset'])
    assert.deepEqual(
      await h.service.execute(actorA, command(commandType, { assetId: ready.assetId })),
      { kind: 'rejected', code: 'invalid_contract' },
      commandType,
    );
});
