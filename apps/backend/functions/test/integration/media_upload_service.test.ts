import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaAssetV1, ProcessingReceiptV1 } from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import {
  MediaService,
  type MediaCommandData,
  type MediaQueryData,
} from '../../src/modules/media/application/media_service.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaAuthorityRequest,
  MediaAuthorityResult,
} from '../../src/modules/media/application/ports/actor_authority_port.js';
import type {
  EntityScopePort,
  EntityScopeRequest,
  EntityScopeResult,
} from '../../src/modules/media/application/ports/entity_scope_port.js';
import type { MediaResult } from '../../src/modules/media/domain/failures.js';
import type { MediaPolicy } from '../../src/modules/media/domain/media_policy.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { FakeProcessor } from '../../src/modules/media/infrastructure/fake_processor.js';
import { FakeScanner } from '../../src/modules/media/infrastructure/fake_scanner.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';

const ulid = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const userA = ulid(1);
const userB = ulid(2);
const page = ulid(50);
const contentId = ulid(60);
const actorA: MediaActor = { userId: userA, sessionId: ulid(101) };
const actorB: MediaActor = { userId: userB, sessionId: ulid(102) };
const sha = 'a'.repeat(64);

/** Synthetic, explicitly TEST-ONLY policy: not an accepted product policy. */
const testPolicy: MediaPolicy = {
  revision: 'policy-test-1',
  families: {
    image: {
      allowedMediaTypes: ['image/jpeg', 'image/png'],
      maxBytes: 4096,
      sessionTtlSeconds: 900,
      maxProcessingAttempts: 3,
      mandatoryVariantProfiles: ['display', 'thumb'],
      validationProfileRevision: 'vp-test-1',
    },
  },
};

class FakeAuthority implements MediaActorAuthorityPort {
  readonly requests: MediaAuthorityRequest[] = [];
  readonly revokedSessions = new Set<string>();
  readonly members = new Set<string>();
  readonly disabledMarkets = new Set<string>();
  denyCapability = false;

  evaluate(request: MediaAuthorityRequest): Promise<MediaAuthorityResult> {
    this.requests.push(request);
    const deny = (
      reason: 'session_invalid' | 'membership_inactive' | 'capability_denied' | 'market_disabled',
    ) => Promise.resolve({ allowed: false as const, reason });
    if (this.revokedSessions.has(request.actor.sessionId)) return deny('session_invalid');
    if (this.disabledMarkets.has(request.marketId)) return deny('market_disabled');
    if (this.denyCapability) return deny('capability_denied');
    if (
      request.publisherRef?.type === 'page' &&
      !this.members.has(`${request.actor.userId}:${request.publisherRef.id}`)
    )
      return deny('membership_inactive');
    return Promise.resolve({ allowed: true, authorityRevision: 1 });
  }
}

class FakeEntityScope implements EntityScopePort {
  readonly requests: EntityScopeRequest[] = [];
  readonly allowed = new Set<string>();

  static key(userId: string, publisherId: string, marketId: string, entityId: string): string {
    return `${userId}|${publisherId}|${marketId}|${entityId}`;
  }

  authorize(request: EntityScopeRequest): Promise<EntityScopeResult> {
    this.requests.push(request);
    const ok = this.allowed.has(
      FakeEntityScope.key(
        request.actor.userId,
        request.publisherRef.id,
        request.marketId,
        request.entity.entityId,
      ),
    );
    return Promise.resolve(ok ? { allowed: true, entityRevision: 1 } : { allowed: false });
  }
}

function harness(options: { policy?: MediaPolicy | null; families?: readonly string[] } = {}) {
  const repository = new InMemoryMediaRepository();
  const authority = new FakeAuthority();
  const entityScope = new FakeEntityScope();
  const objectStore = new FakeObjectStore();
  const scanner = new FakeScanner();
  const processor = new FakeProcessor();
  let clockMs = Date.parse('2026-09-30T09:00:00.000Z');
  const clock: ServerClock = { now: () => new Date(clockMs) };
  let counter = 1000;
  const policy = options.policy === null ? undefined : (options.policy ?? testPolicy);
  const service = new MediaService({
    repository,
    authority,
    entityScope,
    objectStore,
    scanner,
    processor,
    clock,
    ids: { newId: () => ulid(++counter) },
    enabledFamilies: new Set((options.families ?? ['image']) as ['image']),
    ...(policy === undefined ? {} : { policy }),
  });
  authority.members.add(`${userA}:${page}`);
  entityScope.allowed.add(FakeEntityScope.key(userA, page, 'LV', contentId));
  return {
    service,
    repository,
    authority,
    entityScope,
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

const createCommand = (payload: Record<string, unknown> = {}, idempotencyKey = key('create')) => ({
  schemaVersion: 1,
  commandType: 'createUploadSession',
  idempotencyKey,
  payload: {
    family: 'image',
    marketId: 'LV',
    visibilityClass: 'publicDerived',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 2048,
    ...payload,
  },
});
const pageIntent = {
  publisherRef: { type: 'page', id: page },
  entityIntent: { domain: 'content', entityId: contentId, purpose: 'contentMedia' },
};
const confirmCommand = (uploadSessionId: string, over: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  commandType: 'confirmUpload',
  idempotencyKey: key('confirm'),
  payload: { uploadSessionId, expectedSha256: sha, expectedByteLength: 2048, ...over },
});
const finalizeCommand = (asset: { assetId: string; revision: number }, over = {}) => ({
  schemaVersion: 1,
  commandType: 'finalizeAsset',
  idempotencyKey: key('finalize'),
  payload: {
    assetId: asset.assetId,
    expectedAssetRevision: asset.revision,
    sourceProviderGeneration: 'g-1001',
    expectedSha256: sha,
    expectedByteLength: 2048,
    ...over,
  },
});
const retryCommand = (asset: { assetId: string; revision: number }, over = {}) => ({
  schemaVersion: 1,
  commandType: 'retryProcessing',
  idempotencyKey: key('retry'),
  payload: {
    assetId: asset.assetId,
    expectedAssetRevision: asset.revision,
    sourceProviderGeneration: 'g-1001',
    ...over,
  },
});
const statusQuery = (assetId: string) => ({
  schemaVersion: 1,
  queryType: 'getAssetStatus',
  payload: { assetId },
});
const receiptQuery = (assetId: string, attemptNumber?: number) => ({
  schemaVersion: 1,
  queryType: 'getProcessingReceipt',
  payload: { assetId, ...(attemptNumber === undefined ? {} : { attemptNumber }) },
});

async function ok<T = MediaCommandData>(
  promise: Promise<MediaResult<MediaCommandData | MediaQueryData>>,
): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return (result as { data: T }).data;
}
const denial = (code: string) => ({ kind: 'rejected', code });

/** Test stand-in for the client upload: the object appears in the fake store. */
function upload(h: Harness, assetId: string, over: Record<string, unknown> = {}): void {
  const asset = h.repository.snapshot().assets.find((item) => item.assetId === assetId);
  assert.ok(asset);
  h.objectStore.put(asset.objectKeyHandle, {
    providerGeneration: 'g-1001',
    byteLength: 2048,
    sha256: sha,
    detectedMediaType: 'image/jpeg',
    ...over,
  });
}

async function validated(h: Harness, actor = actorA, intent: Record<string, unknown> = pageIntent) {
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actor, createCommand(intent)),
  );
  upload(h, session.assetId);
  const asset = await ok<MediaAssetV1>(
    h.service.execute(actor, confirmCommand(session.uploadSessionId)),
  );
  return { session, asset };
}

void test('a clean upload becomes ready only after scan, variants and manifest', async () => {
  const h = harness();
  const { asset } = await validated(h);
  assert.equal(asset.lifecycle, 'validating');
  assert.equal(asset.sourceGenerationRef?.providerGeneration, 'g-1001');
  const ready = await ok<MediaAssetV1>(h.service.execute(actorA, finalizeCommand(asset)));
  assert.equal(ready.lifecycle, 'ready');
  assert.equal(ready.variantRefs.length, 2);
  assert.match(ready.variantManifestRevision ?? '', /^[0-9a-f]{64}$/u);
  assert.equal(ready.attemptCount, 1);
  assert.equal(h.scanner.requests.length, 1);
  assert.equal(h.processor.requests.length, 1);
  const receipt = await ok<ProcessingReceiptV1>(
    h.service.query(actorA, receiptQuery(ready.assetId)),
  );
  assert.equal(receipt.outcome, 'ready');
  assert.equal(receipt.sourceProviderGeneration, 'g-1001');
  assert.equal(receipt.processing?.variantManifestRevision, ready.variantManifestRevision);
  assert.equal(JSON.stringify(ready).includes('objk:'), false);
  const audit = h.repository.snapshot().audit.map((item) => item.action);
  assert.deepEqual(audit, ['createUploadSession', 'confirmUpload', 'finalizeAsset']);
});

void test('policy is never invented and families are disabled unless listed', async () => {
  const noPolicy = harness({ policy: null });
  assert.deepEqual(
    await noPolicy.service.execute(actorA, createCommand()),
    denial('policy_unavailable'),
  );
  const disabled = harness({ families: [] });
  assert.deepEqual(
    await disabled.service.execute(actorA, createCommand()),
    denial('family_unavailable'),
  );
  const unlisted = harness();
  assert.deepEqual(
    await unlisted.service.execute(actorA, createCommand({ family: 'video' })),
    denial('family_unavailable'),
  );
  for (const h of [noPolicy, disabled, unlisted])
    assert.equal(h.repository.snapshot().assets.length, 0);
});

void test('unauthenticated, malformed, newer and key-choosing commands are refused', async () => {
  const h = harness();
  assert.deepEqual(await h.service.execute(undefined, createCommand()), denial('unauthenticated'));
  assert.deepEqual(await h.service.execute(actorA, 'x'), denial('invalid_contract'));
  assert.deepEqual(await h.service.execute(actorA, { ...createCommand(), schemaVersion: 2 }), {
    kind: 'unsupportedContract',
    code: 'unsupported_version',
  });
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ objectKey: 'public/other-user.jpg' })),
    denial('invalid_contract'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ declaredMediaType: 'not a type' })),
    denial('invalid_contract'),
  );
  assert.deepEqual(
    await h.service.query(undefined, statusQuery(ulid(9))),
    denial('unauthenticated'),
  );
  assert.equal(h.repository.snapshot().assets.length, 0);
});

void test('semantic idempotency replays equal commands and rejects a changed payload', async () => {
  const h = harness();
  const command = createCommand(pageIntent, 'create-fixed-key');
  const first = await ok<{ uploadSessionId: string }>(h.service.execute(actorA, command));
  const replay = await ok<{ uploadSessionId: string }>(h.service.execute(actorA, command));
  assert.equal(replay.uploadSessionId, first.uploadSessionId);
  assert.equal(h.repository.snapshot().assets.length, 1);
  assert.deepEqual(
    await h.service.execute(
      actorA,
      createCommand({ ...pageIntent, declaredByteLength: 1024 }, 'create-fixed-key'),
    ),
    denial('idempotency_conflict'),
  );
  // Another actor with the same key is a separate scope.
  const other = await ok<{ uploadSessionId: string }>(
    h.service.execute(actorB, createCommand({}, 'create-fixed-key')),
  );
  assert.notEqual(other.uploadSessionId, first.uploadSessionId);
});

void test('concurrent duplicate creates produce exactly one asset', async () => {
  const h = harness();
  const command = createCommand(pageIntent, 'create-concurrent');
  const results = await Promise.all([
    h.service.execute(actorA, command),
    h.service.execute(actorA, command),
    h.service.execute(actorA, command),
  ]);
  assert.equal(
    results.every((item) => item.kind === 'succeeded'),
    true,
  );
  assert.equal(h.repository.snapshot().assets.length, 1);
  assert.equal(h.repository.snapshot().sessions.length, 1);
});

void test('an entity intent is trusted only if the owning domain confirms the exact scope', async () => {
  const h = harness();
  const foreign = ulid(61);
  assert.deepEqual(
    await h.service.execute(
      actorA,
      createCommand({
        ...pageIntent,
        entityIntent: { ...pageIntent.entityIntent, entityId: foreign },
      }),
    ),
    denial('entity_scope_denied'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ entityIntent: pageIntent.entityIntent })),
    denial('entity_scope_denied'),
  );
  // The Publisher must match what the owning domain recorded.
  h.authority.members.add(`${userA}:${ulid(51)}`);
  assert.deepEqual(
    await h.service.execute(
      actorA,
      createCommand({ ...pageIntent, publisherRef: { type: 'page', id: ulid(51) } }),
    ),
    denial('entity_scope_denied'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ ...pageIntent, marketId: 'EE' })),
    denial('entity_scope_denied'),
  );
  // Another authenticated user cannot bind media to someone else's entity.
  h.authority.members.add(`${userB}:${page}`);
  assert.deepEqual(
    await h.service.execute(actorB, createCommand(pageIntent)),
    denial('entity_scope_denied'),
  );
  assert.equal(h.repository.snapshot().assets.length, 0);
});

void test('authority denials leave nothing behind', async () => {
  const h = harness();
  assert.deepEqual(
    await h.service.execute(actorB, createCommand({ publisherRef: { type: 'page', id: page } })),
    denial('membership_inactive'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ publisherRef: { type: 'user', id: userB } })),
    denial('capability_denied'),
  );
  h.authority.disabledMarkets.add('LV');
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('market_disabled'));
  h.authority.disabledMarkets.clear();
  h.authority.denyCapability = true;
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('capability_denied'));
  h.authority.denyCapability = false;
  h.authority.revokedSessions.add(actorA.sessionId);
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('unauthenticated'));
  assert.equal(h.repository.snapshot().assets.length, 0);
  assert.equal(h.repository.snapshot().audit.length, 0);
});

void test('limits are checked at session creation', async () => {
  const h = harness();
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ declaredByteLength: 4097 })),
    denial('limit_exceeded'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ declaredMediaType: 'image/gif' })),
    denial('limit_exceeded'),
  );
});

void test('confirm distinguishes missing, partial and complete objects', async () => {
  const h = harness();
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, createCommand(pageIntent)),
  );
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('object_missing'),
  );
  const handle = h.repository.snapshot().assets[0]?.objectKeyHandle ?? '';
  h.objectStore.putPartial(handle);
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('upload_incomplete'),
  );
  // A committed partial upload is visible as `uploading` and a retry can complete it.
  assert.equal(h.repository.snapshot().assets[0]?.lifecycle, 'uploading');
  upload(h, session.assetId);
  const asset = await ok<MediaAssetV1>(
    h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
  );
  assert.equal(asset.lifecycle, 'validating');
  assert.equal(h.repository.snapshot().sessions[0]?.state, 'completed');
});

void test('confirm rejects mismatching hash, length, signature and size', async () => {
  const h = harness();
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, createCommand(pageIntent)),
  );
  upload(h, session.assetId, { sha256: 'c'.repeat(64) });
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('generation_mismatch'),
  );
  upload(h, session.assetId, { byteLength: 1000 });
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('generation_mismatch'),
  );
  // The client declared a JPEG; the bytes are something else.
  upload(h, session.assetId, { detectedMediaType: 'image/png' });
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('signature_mismatch'),
  );
  upload(h, session.assetId, { detectedMediaType: 'application/x-msdownload' });
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('signature_mismatch'),
  );
  upload(h, session.assetId, { byteLength: 5000 });
  assert.deepEqual(
    await h.service.execute(
      actorA,
      confirmCommand(session.uploadSessionId, { expectedByteLength: 5000 }),
    ),
    denial('limit_exceeded'),
  );
  assert.equal(h.repository.snapshot().assets[0]?.lifecycle, 'reserved');
});

void test('an expired, foreign or already completed session cannot be confirmed', async () => {
  const h = harness();
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, createCommand(pageIntent)),
  );
  upload(h, session.assetId);
  assert.deepEqual(
    await h.service.execute(actorB, confirmCommand(session.uploadSessionId)),
    denial('not_found'),
  );
  h.advanceSeconds(901);
  assert.deepEqual(
    await h.service.execute(actorA, confirmCommand(session.uploadSessionId)),
    denial('session_expired'),
  );
  const fresh = harness();
  const { session: done } = await validated(fresh);
  assert.deepEqual(
    await fresh.service.execute(actorA, confirmCommand(done.uploadSessionId)),
    denial('invalid_state'),
  );
});

void test('finalize needs the exact revision, generation and hash', async () => {
  const h = harness();
  const { asset } = await validated(h);
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand({ ...asset, revision: asset.revision - 1 })),
    denial('stale_revision'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(asset, { sourceProviderGeneration: 'g-9' })),
    denial('generation_mismatch'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(asset, { expectedSha256: 'd'.repeat(64) })),
    denial('generation_mismatch'),
  );
  assert.deepEqual(await h.service.execute(actorB, finalizeCommand(asset)), denial('not_found'));
  assert.equal(h.scanner.requests.length, 0);
  assert.equal(h.repository.snapshot().receipts.length, 0);
  // An asset that was never confirmed has no pinned source at all.
  const session = await ok<{ assetId: string }>(
    h.service.execute(actorA, createCommand(pageIntent)),
  );
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand({ assetId: session.assetId, revision: 1 })),
    denial('generation_mismatch'),
  );
});

void test('an inconclusive or failed scan keeps the asset quarantined and skips processing', async () => {
  for (const scripted of ['inconclusive', 'throw'] as const) {
    const h = harness();
    h.scanner.script.push(scripted);
    const { asset } = await validated(h);
    const result = await ok<MediaAssetV1>(h.service.execute(actorA, finalizeCommand(asset)));
    assert.equal(result.lifecycle, 'quarantined', scripted);
    assert.equal(h.processor.requests.length, 0);
    const receipt = await ok<ProcessingReceiptV1>(
      h.service.query(actorA, receiptQuery(asset.assetId)),
    );
    assert.equal(receipt.scan.result, 'inconclusive');
    assert.equal(receipt.outcome, 'quarantined');
    assert.equal(receipt.processing, undefined);
  }
});

void test('a rejected scan or processor result blocks the asset', async () => {
  const scanRejected = harness();
  scanRejected.scanner.script.push('rejected');
  const first = await validated(scanRejected);
  assert.equal(
    (await ok<MediaAssetV1>(scanRejected.service.execute(actorA, finalizeCommand(first.asset))))
      .lifecycle,
    'blocked',
  );
  assert.equal(scanRejected.processor.requests.length, 0);
  const processRejected = harness();
  processRejected.processor.script.push('rejected');
  const second = await validated(processRejected);
  assert.equal(
    (await ok<MediaAssetV1>(processRejected.service.execute(actorA, finalizeCommand(second.asset))))
      .lifecycle,
    'blocked',
  );
});

void test('a failed processor or unverifiable variants never produce ready', async () => {
  const failed = harness();
  failed.processor.script.push('failed');
  const first = await validated(failed);
  assert.equal(
    (await ok<MediaAssetV1>(failed.service.execute(actorA, finalizeCommand(first.asset))))
      .lifecycle,
    'quarantined',
  );
  const thrown = harness();
  thrown.processor.script.push('throw');
  const second = await validated(thrown);
  assert.equal(
    (await ok<MediaAssetV1>(thrown.service.execute(actorA, finalizeCommand(second.asset))))
      .lifecycle,
    'quarantined',
  );
  // Variants missing a mandatory profile are not a manifest.
  const partial = harness();
  partial.processor.script.push((request) => ({
    toolRevision: 'fake-proc-1',
    result: 'succeeded',
    variants: [
      {
        variantId: ulid(900),
        profile: 'display',
        format: 'image/webp',
        providerGeneration: 'vg-1',
        sha256: 'f'.repeat(64),
        byteLength: 10,
        transformProfileRevision: 'tp-1',
        sourceProviderGeneration: request.sourceProviderGeneration,
      },
    ],
  }));
  const third = await validated(partial);
  const result = await ok<MediaAssetV1>(
    partial.service.execute(actorA, finalizeCommand(third.asset)),
  );
  assert.equal(result.lifecycle, 'quarantined');
  assert.equal(result.variantRefs.length, 0);
  assert.equal(result.variantManifestRevision, undefined);
});

void test('quarantine exits only through an explicit retry on the same generation', async () => {
  const h = harness();
  h.scanner.script.push('inconclusive');
  const { asset } = await validated(h);
  const quarantined = await ok<MediaAssetV1>(h.service.execute(actorA, finalizeCommand(asset)));
  assert.equal(quarantined.lifecycle, 'quarantined');
  // Finalize is not a way out of quarantine.
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(quarantined)),
    denial('invalid_state'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, retryCommand(quarantined, { sourceProviderGeneration: 'g-x' })),
    denial('generation_mismatch'),
  );
  assert.deepEqual(
    await h.service.execute(actorA, retryCommand({ ...quarantined, revision: 1 })),
    denial('stale_revision'),
  );
  const ready = await ok<MediaAssetV1>(h.service.execute(actorA, retryCommand(quarantined)));
  assert.equal(ready.lifecycle, 'ready');
  assert.equal(ready.attemptCount, 2);
  // Attempt 1 stays exactly as it was recorded; attempt 2 is new.
  const first = await ok<ProcessingReceiptV1>(
    h.service.query(actorA, receiptQuery(asset.assetId, 1)),
  );
  const second = await ok<ProcessingReceiptV1>(
    h.service.query(actorA, receiptQuery(asset.assetId, 2)),
  );
  assert.equal(first.outcome, 'quarantined');
  assert.equal(second.outcome, 'ready');
  assert.equal(second.sourceProviderGeneration, first.sourceProviderGeneration);
  assert.equal(second.sourceSha256, first.sourceSha256);
});

void test('retry is refused for ready, blocked and exhausted assets', async () => {
  const readyHarness = harness();
  const { asset } = await validated(readyHarness);
  const ready = await ok<MediaAssetV1>(
    readyHarness.service.execute(actorA, finalizeCommand(asset)),
  );
  assert.deepEqual(
    await readyHarness.service.execute(actorA, retryCommand(ready)),
    denial('retry_not_allowed'),
  );
  const blockedHarness = harness();
  blockedHarness.scanner.script.push('rejected');
  const second = await validated(blockedHarness);
  const blocked = await ok<MediaAssetV1>(
    blockedHarness.service.execute(actorA, finalizeCommand(second.asset)),
  );
  assert.deepEqual(
    await blockedHarness.service.execute(actorA, retryCommand(blocked)),
    denial('retry_not_allowed'),
  );
  const exhausted = harness();
  exhausted.scanner.script.push('inconclusive', 'inconclusive', 'inconclusive');
  const third = await validated(exhausted);
  let current = await ok<MediaAssetV1>(
    exhausted.service.execute(actorA, finalizeCommand(third.asset)),
  );
  for (let attempt = 2; attempt <= 3; attempt += 1)
    current = await ok<MediaAssetV1>(exhausted.service.execute(actorA, retryCommand(current)));
  assert.equal(current.lifecycle, 'quarantined');
  assert.equal(current.attemptCount, 3);
  assert.deepEqual(
    await exhausted.service.execute(actorA, retryCommand(current)),
    denial('retry_not_allowed'),
  );
});

void test('finalize and retry are idempotent and never double-process', async () => {
  const h = harness();
  const { asset } = await validated(h);
  const command = finalizeCommand(asset);
  const first = await ok<MediaAssetV1>(h.service.execute(actorA, command));
  const replay = await ok<MediaAssetV1>(h.service.execute(actorA, command));
  assert.deepEqual(replay, first);
  assert.equal(h.scanner.requests.length, 1);
  assert.equal(h.processor.requests.length, 1);
  assert.deepEqual(
    await h.service.execute(actorA, {
      ...command,
      payload: { ...command.payload, expectedByteLength: 1 },
    }),
    denial('idempotency_conflict'),
  );
});

void test('a late result after the asset was disabled never brings it back to ready', async () => {
  const h = harness();
  const { asset } = await validated(h);
  // While the scanner is "in flight", the asset is disabled (restriction or delete).
  h.scanner.onScan = async () => {
    await h.repository.transact(async (tx) => {
      const current = await tx.asset(asset.assetId);
      assert.ok(current);
      tx.putAsset(
        { ...current, deliveryDisabled: true, revision: current.revision + 1 },
        current.revision,
      );
    });
  };
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(asset)),
    denial('stale_revision'),
  );
  const stored = h.repository.snapshot().assets[0];
  assert.equal(stored?.lifecycle, 'validating');
  assert.equal(stored?.deliveryDisabled, true);
  assert.equal(h.repository.snapshot().receipts.length, 0);
  // The disabled asset cannot be processed again either.
  h.scanner.onScan = undefined;
  assert.deepEqual(
    await h.service.execute(
      actorA,
      finalizeCommand({ assetId: asset.assetId, revision: stored?.revision ?? 0 }),
    ),
    denial('invalid_state'),
  );
});

void test('the entity scope is re-checked at finalize and Session revocation stops processing', async () => {
  const h = harness();
  const { asset } = await validated(h);
  h.entityScope.allowed.clear();
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(asset)),
    denial('entity_scope_denied'),
  );
  h.entityScope.allowed.add(FakeEntityScope.key(userA, page, 'LV', contentId));
  h.authority.revokedSessions.add(actorA.sessionId);
  assert.deepEqual(
    await h.service.execute(actorA, finalizeCommand(asset)),
    denial('unauthenticated'),
  );
  assert.equal(h.scanner.requests.length, 0);
});

void test('only the owner reads status and receipts, and revoked Sessions read nothing', async () => {
  const h = harness();
  const { asset } = await validated(h);
  const ready = await ok<MediaAssetV1>(h.service.execute(actorA, finalizeCommand(asset)));
  assert.equal(
    (await ok<MediaAssetV1>(h.service.query(actorA, statusQuery(ready.assetId)))).lifecycle,
    'ready',
  );
  assert.deepEqual(await h.service.query(actorB, statusQuery(ready.assetId)), denial('not_found'));
  assert.deepEqual(await h.service.query(actorB, receiptQuery(ready.assetId)), denial('not_found'));
  assert.deepEqual(await h.service.query(actorA, statusQuery(ulid(999))), denial('not_found'));
  assert.deepEqual(
    await h.service.query(actorA, receiptQuery(ready.assetId, 9)),
    denial('not_found'),
  );
  assert.deepEqual(
    await h.service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDeliveryHandle',
      payload: {},
    }),
    denial('invalid_contract'),
  );
  h.authority.revokedSessions.add(actorA.sessionId);
  assert.deepEqual(
    await h.service.query(actorA, statusQuery(ready.assetId)),
    denial('unauthenticated'),
  );
});

void test('a failed command commits nothing (all-or-nothing)', async () => {
  const h = harness();
  const { asset } = await validated(h);
  const before = h.repository.snapshot().audit.length;
  h.scanner.onScan = async () => {
    await h.repository.transact(async (tx) => {
      const current = await tx.asset(asset.assetId);
      assert.ok(current);
      tx.putAsset({ ...current, revision: current.revision + 1 }, current.revision);
    });
  };
  const result = await h.service.execute(actorA, finalizeCommand(asset));
  assert.deepEqual(result, denial('stale_revision'));
  const after = h.repository.snapshot();
  assert.equal(after.receipts.length, 0);
  assert.equal(after.audit.length, before);
});
