import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaAttachmentV1 } from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import type { MediaAssetV1 } from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { ContentPublicationService } from '../../src/modules/content/application/content_publication_service.js';
import { ContentMediaScope } from '../../src/modules/content/application/content_media_scope.js';
import type { MediaReadinessPort } from '../../src/modules/content/application/ports/media_readiness_port.js';
import type {
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import {
  createContentDraft,
  directProvenance,
  withDraftStatus,
  type ContentDraft,
} from '../../src/modules/content/domain/content_draft.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { ContentMediaReadinessAdapter } from '../../src/modules/media/application/content_media_readiness.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { MediaService } from '../../src/modules/media/application/media_service.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaRestrictionAuthority,
} from '../../src/modules/media/application/ports/actor_authority_port.js';
import type { AttachmentReferencePort } from '../../src/modules/media/application/ports/attachment_reference_port.js';
import type { EntityScopePort } from '../../src/modules/media/application/ports/entity_scope_port.js';
import { attachmentsRevision } from '../../src/modules/media/domain/media_attachment.js';
import type { MediaPolicy } from '../../src/modules/media/domain/media_policy.js';
import { bodyFor, commands, servicePorts } from '../support/content_repository_scenarios.js';
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
const sha = 'a'.repeat(64);
const now = parseUtcInstant('2026-09-30T09:00:00.000Z');

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

class FakeEligibility implements PublisherEligibilityPort {
  deny = false;
  fail = false;
  readonly requests: PublisherEligibilityRequest[] = [];
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    this.requests.push(request);
    if (this.fail) return Promise.reject(new Error('identity authority unreachable'));
    return Promise.resolve({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: !this.deny,
      reason: this.deny ? 'membership_inactive' : 'eligible',
      authorityRevision: 1,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
  }
  evaluateDelegated(): Promise<PublisherEligibilityV1> {
    return Promise.reject(new Error('not used'));
  }
}

const references = {
  marketConfigRevisionId: 'mc-lv-1',
  taxonomyRevisionId: 'tx-1',
  localizationRevisionId: 'loc-1',
};

function contentDraft(mediaIds: readonly string[] = []): ContentDraft {
  return createContentDraft({
    draftId: ulid(61),
    contentId,
    typeId: 'place',
    publisherRef: { type: 'page', id: page },
    marketId: 'LV',
    body: {
      title: 'Vermanes garden greenhouse',
      media: {
        ...(mediaIds[0] === undefined ? {} : { coverImage: { mediaId: mediaIds[0] } }),
        gallery: mediaIds.slice(1).map((mediaId) => ({ mediaId })),
      },
    },
    referenceRevisions: references,
    createdByUserId: userA,
    provenance: directProvenance(userA),
    nowUtc: now,
  });
}

async function harness(enabledForReadiness: readonly string[] = ['image']) {
  const contentRepository = new InMemoryContentRepository();
  await contentRepository.transact((tx) => {
    tx.putDraft(contentDraft());
  });
  const eligibility = new FakeEligibility();
  const contentScope = new ContentMediaScope({ repository: contentRepository, eligibility });
  const mediaRepository = new InMemoryMediaRepository();
  const authority: MediaActorAuthorityPort = {
    evaluate: () => Promise.resolve({ allowed: true, authorityRevision: 1 }),
  };
  const restriction: MediaRestrictionAuthority & { trusted: Set<string> } = {
    trusted: new Set(['decision-1']),
    verifyRestriction(input) {
      return Promise.resolve(this.trusted.has(input.decisionRef));
    },
  };
  const objectStore = new FakeObjectStore();
  let clockMs = Date.parse('2026-09-30T09:00:00.000Z');
  const clock: ServerClock = { now: () => new Date(clockMs) };
  let counter = 1000;
  const ids = { newId: () => ulid(++counter) };
  // Wiring: Content's answers satisfy Media's ports and Media's adapter satisfies Content's.
  const entityScope: EntityScopePort = contentScope;
  const referencePort: AttachmentReferencePort = contentScope;
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
    repository: mediaRepository,
    authority,
    restrictionAuthority: restriction,
    references: referencePort,
    objectStore,
    clock,
    ids,
  });
  const service = new MediaService({
    repository: mediaRepository,
    authority,
    entityScope,
    objectStore,
    scanner: new FakeScanner(),
    processor: new FakeProcessor(),
    clock,
    ids,
    enabledFamilies: new Set(['image'] as const),
    policy: testPolicy,
    deletion,
  });
  const adapter = new ContentMediaReadinessAdapter({
    repository: mediaRepository,
    enabledFamilies: new Set(enabledForReadiness as ['image']),
  });
  const contentPort: MediaReadinessPort = adapter;
  return {
    service,
    deletion,
    adapter,
    contentPort,
    contentRepository,
    contentScope,
    eligibility,
    mediaRepository,
    objectStore,
    restriction,
    advance: (seconds: number) => {
      clockMs += seconds * 1000;
    },
  };
}
type Harness = Awaited<ReturnType<typeof harness>>;

let keySerial = 0;
const key = (label: string): string => `${label}-${String(++keySerial).padStart(6, '0')}`;
const intent = (over: Record<string, unknown> = {}) => ({
  publisherRef: { type: 'page', id: page },
  entityIntent: { domain: 'content', entityId: contentId, purpose: 'contentMedia' },
  ...over,
});
const createCommand = (payload: Record<string, unknown> = intent()) => ({
  schemaVersion: 1,
  commandType: 'createUploadSession',
  idempotencyKey: key('create'),
  payload: {
    family: 'image',
    marketId: 'LV',
    visibilityClass: 'publicDerived',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 2048,
    ...payload,
  },
});
const command = (commandType: string, payload: Record<string, unknown>) => ({
  schemaVersion: 1,
  commandType,
  idempotencyKey: key(commandType),
  payload,
});
const denial = (code: string) => ({ kind: 'rejected', code });

async function ok<T>(promise: Promise<{ kind: string }>): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return (result as unknown as { data: T }).data;
}

function stored(h: Harness, assetId: string) {
  const asset = h.mediaRepository.snapshot().assets.find((item) => item.assetId === assetId);
  assert.ok(asset);
  return asset;
}

async function bound(h: Harness, payload: Record<string, unknown> = intent()) {
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, createCommand(payload)),
  );
  h.objectStore.put(stored(h, session.assetId).objectKeyHandle, {
    providerGeneration: 'g-1001',
    byteLength: 2048,
    sha256: sha,
    detectedMediaType: 'image/jpeg',
  });
  return { session, assetId: session.assetId };
}

async function readyAsset(h: Harness, payload: Record<string, unknown> = intent()) {
  const { session, assetId } = await bound(h, payload);
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
  const ready = await ok<MediaAssetV1>(
    h.service.execute(
      actorA,
      command('finalizeAsset', {
        assetId,
        expectedAssetRevision: validating.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
  );
  assert.equal(ready.lifecycle, 'ready');
  return ready;
}

const checkInput = (mediaIds: readonly string[], over: Record<string, unknown> = {}) => ({
  contentId,
  typeId: 'place' as const,
  marketId: 'LV' as const,
  publisherRef: { type: 'page' as const, id: page },
  mediaIds,
  ...over,
});

void test('Content answers Media only from its own draft, Publisher, market and eligibility', async () => {
  const h = await harness();
  // The exact draft, Publisher, market and an eligible actor: allowed, and it binds.
  const allowed = await ok<{ assetId: string }>(h.service.execute(actorA, createCommand()));
  assert.equal(stored(h, allowed.assetId).entityBinding?.entityId, contentId);
  assert.equal(h.eligibility.requests.at(-1)?.action, 'update');
  const foreign = [
    [
      'unknown content',
      intent({ entityIntent: { domain: 'content', entityId: ulid(99), purpose: 'contentMedia' } }),
    ],
    ['wrong publisher', intent({ publisherRef: { type: 'page', id: ulid(51) } })],
    ['wrong market', { ...intent(), marketId: 'EE' }],
  ] as const;
  for (const [label, payload] of foreign)
    assert.deepEqual(
      await h.service.execute(actorA, createCommand(payload)),
      denial('entity_scope_denied'),
      label,
    );
  h.eligibility.deny = true;
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('entity_scope_denied'));
  h.eligibility.deny = false;
  h.eligibility.fail = true;
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('entity_scope_denied'));
  h.eligibility.fail = false;
  // A submitted draft is frozen.
  await h.contentRepository.transact(async (tx) => {
    const draft = await tx.draftByContentId(contentId);
    assert.ok(draft);
    tx.putDraft(withDraftStatus(draft, 'submitted', now));
  });
  assert.deepEqual(await h.service.execute(actorA, createCommand()), denial('entity_scope_denied'));
  assert.equal(h.mediaRepository.snapshot().assets.length, 1);
});

void test('a ready asset yields generation-pinned evidence and a canonical media revision', async () => {
  const h = await harness();
  const asset = await readyAsset(h);
  const result = await h.contentPort.check(checkInput([asset.assetId]));
  assert.equal(result.ready, true);
  if (!result.ready) return;
  const expected: MediaAttachmentV1[] = [
    {
      assetId: asset.assetId,
      sourceGeneration: 'g-1001',
      variantManifestRevision: asset.variantManifestRevision ?? '',
      purpose: 'contentMedia',
    },
  ];
  assert.deepEqual(result.attachments, expected);
  assert.equal(result.mediaRevision, attachmentsRevision(expected));
  // Checking is evidence only: it changed nothing in Media.
  assert.equal(stored(h, asset.assetId).revision, asset.revision);
  // No media at all is ready with the canonical revision of the empty list.
  const empty = await h.contentPort.check(checkInput([]));
  assert.deepEqual(empty, { ready: true, mediaRevision: attachmentsRevision([]), attachments: [] });
  // Duplicated ids are one attachment.
  const twice = await h.contentPort.check(checkInput([asset.assetId, asset.assetId]));
  assert.deepEqual(twice.ready && twice.attachments.length, 1);
});

void test('the media revision changes with the set of attachments', async () => {
  const h = await harness();
  const first = await readyAsset(h);
  const second = await readyAsset(h);
  const one = await h.contentPort.check(checkInput([first.assetId]));
  const both = await h.contentPort.check(checkInput([second.assetId, first.assetId]));
  assert.ok(one.ready && both.ready);
  assert.notEqual(one.mediaRevision, both.mediaRevision);
  // Order of the ids never matters.
  const reversed = await h.contentPort.check(checkInput([first.assetId, second.assetId]));
  assert.ok(reversed.ready);
  assert.equal(reversed.mediaRevision, both.mediaRevision);
});

void test('unknown, foreign, unfinished, restricted, deleted and disabled-family media is not ready', async () => {
  const h = await harness();
  const asset = await readyAsset(h);
  const reasonOf = async (ids: readonly string[], over: Record<string, unknown> = {}) => {
    const result = await h.contentPort.check(checkInput(ids, over));
    return result.ready ? 'ready' : result.reason;
  };
  assert.equal(await reasonOf([ulid(9999)]), 'asset_unknown');
  assert.equal(await reasonOf([asset.assetId], { contentId: ulid(98) }), 'foreign_binding');
  assert.equal(
    await reasonOf([asset.assetId], { publisherRef: { type: 'page', id: ulid(51) } }),
    'foreign_binding',
  );
  assert.equal(await reasonOf([asset.assetId], { marketId: 'EE' }), 'foreign_binding');
  // An asset without any binding is never attachable.
  const unbound = await bound(h, {});
  assert.equal(await reasonOf([unbound.assetId]), 'foreign_binding');
  // A bound asset that is not ready yet.
  const pending = await bound(h);
  assert.equal(await reasonOf([pending.assetId]), 'not_ready');
  // Restriction (system) then deletion.
  const restricted = await ok<MediaAssetV1>(
    h.deletion.applyRestriction(
      command('applyRestriction', {
        assetId: asset.assetId,
        decisionRef: 'decision-1',
        restricted: true,
      }),
    ),
  );
  assert.equal(restricted.deliveryDisabled, true);
  assert.equal(await reasonOf([asset.assetId]), 'restricted');
  const other = await readyAsset(h);
  await ok(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: other.assetId, expectedAssetRevision: other.revision }),
    ),
  );
  assert.equal(await reasonOf([other.assetId]), 'deleted');
  // A family that is not enabled is never ready.
  const strict = await harness([]);
  const enabled = await readyAsset(strict);
  const result = await strict.contentPort.check(checkInput([enabled.assetId]));
  assert.deepEqual(result, { ready: false, reason: 'policy_unavailable' });
});

void test('rollback verifies exactly the pinned references and refuses stale generations', async () => {
  const h = await harness();
  const asset = await readyAsset(h);
  const live = await h.contentPort.check(checkInput([asset.assetId]));
  assert.ok(live.ready);
  const pinned = live.attachments;
  const again = await h.contentPort.check(checkInput([asset.assetId], { pinned }));
  assert.deepEqual(again, live);
  // The stored generation moved on: the pinned reference is stale.
  const [first] = pinned;
  assert.ok(first);
  const wrongGeneration = await h.contentPort.check(
    checkInput([asset.assetId], { pinned: [{ ...first, sourceGeneration: 'g-other' }] }),
  );
  assert.deepEqual(wrongGeneration, { ready: false, reason: 'stale_generation' });
  const wrongManifest = await h.contentPort.check(
    checkInput([asset.assetId], {
      pinned: [{ ...first, variantManifestRevision: 'f'.repeat(64) }],
    }),
  );
  assert.deepEqual(wrongManifest, { ready: false, reason: 'stale_generation' });
  // The set must match: an extra id or a missing pinned id is stale, not ready.
  const extra = await readyAsset(h);
  assert.deepEqual(
    await h.contentPort.check(checkInput([asset.assetId, extra.assetId], { pinned })),
    {
      ready: false,
      reason: 'stale_generation',
    },
  );
  assert.deepEqual(await h.contentPort.check(checkInput([], { pinned })), {
    ready: false,
    reason: 'stale_generation',
  });
  // A pinned reference to an asset that is deleted afterwards is refused.
  await ok(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
  );
  assert.deepEqual(await h.contentPort.check(checkInput([asset.assetId], { pinned })), {
    ready: false,
    reason: 'deleted',
  });
});

void test('an asset still referenced by a Content draft is not deletable, until the draft drops it', async () => {
  const h = await harness();
  const asset = await readyAsset(h);
  await h.contentRepository.transact((tx) => {
    tx.putDraft(contentDraft([asset.assetId]));
  });
  assert.equal(await h.contentScope.isReferenced(asset.assetId), true);
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
    denial('asset_referenced'),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
  await h.contentRepository.transact((tx) => {
    tx.putDraft(contentDraft([]));
  });
  assert.equal(await h.contentScope.isReferenced(asset.assetId), false);
  await ok(
    h.service.execute(
      actorA,
      command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
  );
  assert.equal(stored(h, asset.assetId).lifecycle, 'deleted');
});

void test('another user cannot use, read or delete the asset through the Content path', async () => {
  const h = await harness();
  const asset = await readyAsset(h);
  const actorB: MediaActor = { userId: userB, sessionId: ulid(102) };
  assert.deepEqual(
    await h.service.execute(
      actorB,
      command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
    denial('not_found'),
  );
  // Media asks Content to authorize the exact actor: another user is not the draft's Publisher member.
  h.eligibility.deny = true;
  assert.deepEqual(await h.service.execute(actorB, createCommand()), denial('entity_scope_denied'));
});

void test('a private or protected original never becomes part of a public revision', async () => {
  const h = await harness();
  for (const visibilityClass of ['private', 'protected']) {
    const asset = await readyAsset(h, intent({ visibilityClass }));
    assert.deepEqual(await h.contentPort.check(checkInput([asset.assetId])), {
      ready: false,
      reason: 'restricted',
    });
  }
});

/** Fails the test instead of hanging it when two modules wait for each other. */
function withDeadline<T>(work: Promise<T>, label: string): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => reject(new Error(`${label}: no progress (deadlock)`)), 5000);
  });
  return Promise.race([work, deadline]).finally(() => clearTimeout(timer));
}

void test('Content and Media never wait for each other while holding a transaction', async () => {
  const h = await harness();
  const contentService = new ContentPublicationService({
    repository: h.contentRepository,
    ...servicePorts(),
    // The real Media readiness adapter, exactly as Content is wired to it in production code.
    media: h.adapter,
  });
  const owner = ulid(1);
  const c = commands(owner);
  const actor = { userId: owner, sessionId: ulid(101) };
  for (let round = 0; round < 12; round += 1) {
    const draft = await contentService.execute(actor, c.create(bodyFor(owner)));
    assert.equal(draft.kind, 'succeeded');
    const created = (draft as { data: { draftId: string; contentId: string } }).data;
    // Submit (Content transaction -> Media readiness) racing an upload session
    // (Media transaction -> Content entity scope) and a delete (Media -> Content references).
    const results = await withDeadline(
      Promise.all([
        contentService.execute(actor, c.submit(created.draftId, 1)),
        h.service.execute(
          actor,
          createCommand({
            publisherRef: { type: 'user', id: owner },
            entityIntent: {
              domain: 'content',
              entityId: created.contentId,
              purpose: 'contentMedia',
            },
          }),
        ),
        h.service.execute(
          actor,
          command('deleteAsset', { assetId: ulid(9000 + round), expectedAssetRevision: 1 }),
        ),
      ]),
      `round ${String(round)}`,
    );
    assert.equal(results.length, 3);
    // Rolling back while media is being attached must not wedge either module.
    const rollback = await withDeadline(
      Promise.all([
        contentService.execute(actor, c.activate(created.contentId, ulid(8000 + round), 1)),
        h.service.execute(
          actor,
          createCommand({
            publisherRef: { type: 'user', id: owner },
            entityIntent: {
              domain: 'content',
              entityId: created.contentId,
              purpose: 'contentMedia',
            },
          }),
        ),
      ]),
      `rollback round ${String(round)}`,
    );
    assert.equal(rollback.length, 2);
  }
});
