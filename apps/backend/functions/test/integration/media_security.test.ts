import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import type { MediaAssetV1 } from '../../src/contracts/media_v1.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import { MediaService } from '../../src/modules/media/application/media_service.js';
import type {
  MediaActor,
  MediaActorAuthorityPort,
  MediaAuthorityRequest,
  MediaAuthorityResult,
} from '../../src/modules/media/application/ports/actor_authority_port.js';
import type { MediaPolicy } from '../../src/modules/media/domain/media_policy.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { FakeProcessor } from '../../src/modules/media/infrastructure/fake_processor.js';
import { FakeScanner } from '../../src/modules/media/infrastructure/fake_scanner.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';

const ulid = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const userA = ulid(1);
const userB = ulid(2);
const pageX = ulid(50);
const pageY = ulid(51);
const contentX = ulid(60);
const actorA: MediaActor = { userId: userA, sessionId: ulid(101) };
const actorB: MediaActor = { userId: userB, sessionId: ulid(102) };
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
      mandatoryVariantProfiles: ['display'],
      validationProfileRevision: 'vp-test-1',
    },
  },
};

class FakeAuthority implements MediaActorAuthorityPort {
  readonly members = new Set<string>();
  readonly disabledMarkets = new Set<string>();
  readonly revokedSessions = new Set<string>();
  evaluate(request: MediaAuthorityRequest): Promise<MediaAuthorityResult> {
    const deny = (
      reason: 'session_invalid' | 'membership_inactive' | 'capability_denied' | 'market_disabled',
    ) => Promise.resolve({ allowed: false as const, reason });
    if (this.revokedSessions.has(request.actor.sessionId)) return deny('session_invalid');
    if (this.disabledMarkets.has(request.marketId)) return deny('market_disabled');
    if (
      request.publisherRef?.type === 'page' &&
      !this.members.has(`${request.actor.userId}:${request.publisherRef.id}`)
    )
      return deny('membership_inactive');
    return Promise.resolve({ allowed: true, authorityRevision: 1 });
  }
}

function harness() {
  const repository = new InMemoryMediaRepository();
  const authority = new FakeAuthority();
  authority.members.add(`${userA}:${pageX}`);
  authority.members.add(`${userB}:${pageY}`);
  const objectStore = new FakeObjectStore();
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
    restrictionAuthority: { verifyRestriction: () => Promise.resolve({ verified: false }) },
    references: { isReferenced: () => Promise.resolve(false) },
    objectStore,
    clock,
    ids,
  });
  const service = new MediaService({
    repository,
    authority,
    // The owning domain confirms only Page X's own content for its own member.
    entityScope: {
      authorize: (request) =>
        Promise.resolve(
          request.publisherRef.id === pageX && request.entity.entityId === contentX
            ? { allowed: true, entityRevision: 1 }
            : { allowed: false },
        ),
    },
    objectStore,
    scanner: new FakeScanner(),
    processor: new FakeProcessor(),
    clock,
    ids,
    enabledFamilies: new Set(['image'] as const),
    policy: testPolicy,
    deletion,
  });
  return { service, repository, authority, objectStore };
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
const createPayload = (over: Record<string, unknown> = {}) => ({
  family: 'image',
  marketId: 'LV',
  visibilityClass: 'publicDerived',
  declaredMediaType: 'image/jpeg',
  declaredByteLength: 2048,
  ...over,
});
const pageXIntent = {
  publisherRef: { type: 'page', id: pageX },
  entityIntent: { domain: 'content', entityId: contentX, purpose: 'contentMedia' },
};
const denial = (code: string) => ({ kind: 'rejected', code });

async function ok<T>(promise: Promise<{ kind: string }>): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return (result as unknown as { data: T }).data;
}

function stored(h: Harness, assetId: string) {
  const asset = h.repository.snapshot().assets.find((item) => item.assetId === assetId);
  assert.ok(asset);
  return asset;
}

async function ready(h: Harness) {
  const session = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, command('createUploadSession', createPayload(pageXIntent))),
  );
  h.objectStore.put(stored(h, session.assetId).objectKeyHandle, {
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
  const asset = await ok<MediaAssetV1>(
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
  return { session, asset };
}

// ---------------------------------------------------------------------------
// Negative security tests (BCK-14 v0.4 §34.6)
// ---------------------------------------------------------------------------

void test('another verified user cannot confirm, finalize, retry, delete, detach or read the asset', async () => {
  const h = harness();
  const { session, asset } = await ready(h);
  const attempts = await Promise.all([
    h.service.execute(
      actorB,
      command('confirmUpload', {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
    h.service.execute(
      actorB,
      command('finalizeAsset', {
        assetId: asset.assetId,
        expectedAssetRevision: asset.revision,
        sourceProviderGeneration: 'g-1001',
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
    h.service.execute(
      actorB,
      command('retryProcessing', {
        assetId: asset.assetId,
        expectedAssetRevision: asset.revision,
        sourceProviderGeneration: 'g-1001',
      }),
    ),
    h.service.execute(
      actorB,
      command('deleteAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
    h.service.execute(
      actorB,
      command('detachAsset', { assetId: asset.assetId, expectedAssetRevision: asset.revision }),
    ),
    h.service.query(actorB, {
      schemaVersion: 1,
      queryType: 'getAssetStatus',
      payload: { assetId: asset.assetId },
    }),
  ]);
  for (const result of attempts) assert.deepEqual(result, denial('not_found'));
  assert.equal(stored(h, asset.assetId).lifecycle, 'ready');
});

void test('Page membership is exact: another Page, or a Page without membership, cannot upload', async () => {
  const h = harness();
  // User B belongs to Page Y only.
  assert.deepEqual(
    await h.service.execute(actorB, command('createUploadSession', createPayload(pageXIntent))),
    denial('membership_inactive'),
  );
  // User A is not a member of Page Y and cannot borrow B's Page.
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('createUploadSession', createPayload({ publisherRef: { type: 'page', id: pageY } })),
    ),
    denial('membership_inactive'),
  );
  // Even a member cannot bind Page Y's media to Page X's content: the owning domain refuses.
  assert.deepEqual(
    await h.service.execute(
      actorB,
      command(
        'createUploadSession',
        createPayload({
          publisherRef: { type: 'page', id: pageY },
          entityIntent: pageXIntent.entityIntent,
        }),
      ),
    ),
    denial('entity_scope_denied'),
  );
  assert.equal(h.repository.snapshot().assets.length, 0);
});

void test('cross-market use is denied by authority and by the owning domain', async () => {
  const h = harness();
  h.authority.disabledMarkets.add('EE');
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('createUploadSession', createPayload({ marketId: 'EE' })),
    ),
    denial('market_disabled'),
  );
  // The owning domain recorded the entity in LV only.
  h.authority.members.add(`${userA}:${pageX}`);
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command(
        'createUploadSession',
        createPayload({
          ...pageXIntent,
          marketId: 'LT',
          publisherRef: { type: 'page', id: pageY },
        }),
      ),
    ),
    denial('membership_inactive'),
  );
});

void test('a revoked membership or Session stops every later step immediately', async () => {
  const membership = harness();
  const first = await ready(membership);
  membership.authority.members.delete(`${userA}:${pageX}`);
  assert.deepEqual(
    await membership.service.execute(
      actorA,
      command('deleteAsset', {
        assetId: first.asset.assetId,
        expectedAssetRevision: first.asset.revision,
      }),
    ),
    denial('membership_inactive'),
  );
  assert.deepEqual(
    await membership.service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getAssetStatus',
      payload: { assetId: first.asset.assetId },
    }),
    denial('membership_inactive'),
  );
  const session = harness();
  const second = await ready(session);
  session.authority.revokedSessions.add(actorA.sessionId);
  assert.deepEqual(
    await session.service.execute(
      actorA,
      command('deleteAsset', {
        assetId: second.asset.assetId,
        expectedAssetRevision: second.asset.revision,
      }),
    ),
    denial('unauthenticated'),
  );
  assert.equal(stored(session, second.asset.assetId).lifecycle, 'ready');
});

void test('guessed identifiers and client-chosen paths reach nothing', async () => {
  const h = harness();
  const { session } = await ready(h);
  const own = await ok<{ uploadSessionId: string; assetId: string }>(
    h.service.execute(actorA, command('createUploadSession', createPayload(pageXIntent))),
  );
  // Bytes exist only under the first asset's backend-chosen handle: the second session sees none.
  assert.deepEqual(
    await h.service.execute(
      actorA,
      command('confirmUpload', {
        uploadSessionId: own.uploadSessionId,
        expectedSha256: sha,
        expectedByteLength: 2048,
      }),
    ),
    denial('object_missing'),
  );
  for (const guessed of [ulid(4242), ulid(1), session.uploadSessionId.replace(/.$/u, '0')])
    assert.deepEqual(
      await h.service.execute(
        actorA,
        command('confirmUpload', {
          uploadSessionId: guessed,
          expectedSha256: sha,
          expectedByteLength: 2048,
        }),
      ),
      denial('not_found'),
    );
  for (const field of ['objectKey', 'objectKeyHandle', 'bucket', 'path', 'publicUrl'])
    assert.deepEqual(
      await h.service.execute(
        actorA,
        command('createUploadSession', createPayload({ [field]: 'x' })),
      ),
      denial('invalid_contract'),
      field,
    );
});

void test('System instructions are never accepted from a user, even the owner', async () => {
  const h = harness();
  const { asset } = await ready(h);
  for (const [type, payload] of [
    ['applyRestriction', { assetId: asset.assetId, decisionRef: 'd-1', restricted: true }],
    ['reconcileOrphan', { assetId: asset.assetId }],
  ] as const)
    assert.deepEqual(
      await h.service.execute(actorA, command(type, payload)),
      denial('capability_denied'),
      type,
    );
  assert.equal(stored(h, asset.assetId).deliveryDisabled, false);
});

// ---------------------------------------------------------------------------
// Static boundary checks (BCK-14-AC-76, AC-80, AC-82)
// ---------------------------------------------------------------------------

function sourceFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((name) => {
    const full = path.join(directory, name);
    if (statSync(full).isDirectory()) return sourceFiles(full);
    return full.endsWith('.ts') ? [full] : [];
  });
}

const srcRoot = path.resolve(process.cwd(), 'src');
const mediaDir = path.join(srcRoot, 'modules', 'media');
const read = (file: string) => readFileSync(file, 'utf8');

void test('Media stays framework-neutral, offline and free of delivery or cloud code', () => {
  const forbidden = [
    /from ['"]firebase/u,
    /from ['"]@google-cloud/u,
    /from ['"]firebase-functions/u,
    /from ['"]firebase-admin/u,
    /process\.env/u,
    /\bfetch\(/u,
    /from ['"]node:(https?|net|fs|child_process)['"]/u,
    /getSignedUrl|signedUrl|requestDelivery|getDeliveryHandle|createReadStream/u,
  ];
  const sdk = new Set([
    'infrastructure/emulator_media_composition.ts',
    'infrastructure/firestore_media_repository.ts',
    // D2: read-only feed of committed Media facts for the owning domain.
    'infrastructure/media_effect_feed.ts',
  ]);
  const environment = new Set([...sdk, 'infrastructure/storage_emulator_object_store.ts']);
  // D1: only the local tools client may open a loopback HTTP connection.
  const localToolsClient = 'infrastructure/local_tools_client.ts';
  const withoutHttp = /from ['"]node:(https|net|fs|child_process)['"]/u;
  const patternsFor = (relative: string) =>
    forbidden
      .filter(
        (_, index) =>
          !(sdk.has(relative) && (index === 0 || index === 3)) &&
          !(environment.has(relative) && index === 4),
      )
      .map((pattern) =>
        relative === localToolsClient && pattern === forbidden[6] ? withoutHttp : pattern,
      );
  for (const file of sourceFiles(mediaDir))
    for (const pattern of patternsFor(path.relative(mediaDir, file).replaceAll('\\', '/')))
      assert.equal(
        pattern.test(read(file)),
        false,
        `${path.relative(srcRoot, file)} ${String(pattern)}`,
      );
  const http = "import { request } from 'node:http';";
  assert.equal(
    patternsFor(localToolsClient).some((pattern) => pattern.test(http)),
    false,
  );
  assert.ok(patternsFor('infrastructure/image_pipeline.ts').some((pattern) => pattern.test(http)));
  for (const other of [
    "from 'node:net'",
    "from 'node:fs'",
    "from 'node:child_process'",
    'process.env',
  ])
    assert.ok(
      patternsFor(localToolsClient).some((pattern) => pattern.test(other)),
      other,
    );
  const foreign = "import { getFirestore } from 'firebase-admin/firestore';";
  assert.ok(patternsFor('domain/foreign.ts').some((pattern) => pattern.test(foreign)));
  assert.ok(patternsFor('infrastructure/foreign.ts').some((pattern) => pattern.test(foreign)));
  // Even approved adapters cannot acquire a delivery/read-URL surface.
  assert.ok(
    patternsFor('infrastructure/emulator_media_composition.ts').some((pattern) =>
      pattern.test('getSignedUrl()'),
    ),
  );
});

void test('Media and Content never import each other and nothing exports Media to the runtime', () => {
  for (const file of sourceFiles(mediaDir))
    assert.equal(/modules\/content\//u.test(read(file).replaceAll('\\', '/')), false, file);
  const contentDir = path.join(srcRoot, 'modules', 'content');
  for (const file of sourceFiles(contentDir))
    assert.equal(/modules\/media\//u.test(read(file).replaceAll('\\', '/')), false, file);
  const offenders = sourceFiles(srcRoot)
    .filter((file) => !file.startsWith(mediaDir + path.sep))
    .filter((file) => /modules\/media\//u.test(read(file).replaceAll('\\', '/')));
  assert.deepEqual(
    offenders.map((file) => path.relative(srcRoot, file)),
    // D2: the composition root of Content's reaction to late Media restriction.
    ['content_entry.ts', 'media_effects_entry.ts', 'media_entry.ts'],
  );
  const entry = read(path.join(srcRoot, 'index.ts'));
  assert.doesNotMatch(entry, /from ['"]\.\/modules\/media\//u);
  assert.deepEqual(
    [...entry.matchAll(/export const (\w+)\s*=/gu)]
      .map((match) => match[1]!)
      .filter((name) => /media/iu.test(name))
      .sort(),
    // D2 adds the delivery gate, the Media-fact trigger and the sweeps.
    [
      'consumeMediaEffectV1',
      'mediaCommandV1',
      'mediaDeliveryV1',
      'mediaQueryV1',
      'reconcileMediaReferencesV1',
      'uploadMediaBytesV1',
    ],
  );
});

void test('D2 delivery: bytes only — no URL, handle or cache surface, nothing logged', () => {
  const gate = read(path.join(mediaDir, 'application', 'media_delivery_gate.ts'));
  const entry = read(path.join(srcRoot, 'media_entry.ts'));
  const index = read(path.join(srcRoot, 'index.ts'));
  const surface =
    /getSignedUrl|signedUrl|publicUrl|downloadUrl|Cache-Control|max-age|createReadStream|https?:\/\//iu;
  assert.equal(surface.test(gate), false, 'gate');
  assert.equal(surface.test(entry), false, 'entry');
  assert.equal(/\blog(?:Error|ger)?\b|console\./u.test(gate), false, 'the gate logs nothing');
  const callable = index.slice(
    index.indexOf('export const mediaDeliveryV1'),
    index.indexOf('export const consumeMediaEffectV1'),
  );
  assert.ok(callable.includes('handleMediaDelivery(caller, request.data)'));
  assert.equal(/logError|console\./u.test(callable), false, 'no bytes or ids are logged');
  // The Media-fact trigger logs only the consumer outcome (ids and codes).
  const trigger = index.slice(
    index.indexOf('export const consumeMediaEffectV1'),
    index.indexOf('export const reconcileMediaReferencesV1'),
  );
  assert.ok(trigger.includes("logError('media_effect_consumer_incomplete', outcome)"));
  // Every refusal after the Session check is `not_found`: nothing is revealed.
  assert.deepEqual(
    [...new Set([...gate.matchAll(/rejected\('([a-z_]+)'\)/gu)].map((match) => match[1]))],
    ['not_found'],
  );
});

void test('only the Media application services write Media records', () => {
  const writers = new Set([
    path.join('application', 'media_service.ts'),
    path.join('application', 'media_deletion_service.ts'),
    path.join('application', 'orphan_reconciler.ts'),
  ]);
  const offenders = sourceFiles(mediaDir)
    .filter((file) => !file.includes(`${path.sep}infrastructure${path.sep}`))
    .filter((file) => !file.endsWith(`${path.sep}repositories.ts`))
    .filter((file) => /\.(putAsset|putSession|putReceipt|putDeletion)\(/u.test(read(file)))
    .map((file) => path.relative(mediaDir, file))
    .filter((file) => !writers.has(file));
  assert.deepEqual(offenders, []);
});

void test('adapters: the fakes are labelled FAKE and the D1 local tools modules are named', () => {
  const infrastructure = path.join(mediaDir, 'infrastructure');
  const names = readdirSync(infrastructure).sort();
  assert.deepEqual(names, [
    'clamd_protocol.ts',
    'emulator_media_composition.ts',
    'fake_object_store.ts',
    'fake_processor.ts',
    'fake_scanner.ts',
    'firestore_media_repository.ts',
    'identity_media_authority.ts',
    'image_pipeline.ts',
    'in_memory_media_repository.ts',
    'local_tools_client.ts',
    'local_tools_protocol.ts',
    'media_effect_feed.ts',
    'media_tool_limits.ts',
    'storage_emulator_object_store.ts',
  ]);
  for (const name of names.filter((item) => item.startsWith('fake_')))
    assert.match(read(path.join(infrastructure, name)), /\bFAKE\b/u, name);
  // The real tools replace the fakes only behind the stand's explicit switch.
  const composition = read(path.join(infrastructure, 'emulator_media_composition.ts'));
  assert.ok(composition.includes('localToolsConfigFrom(environment)'));
  assert.ok(composition.includes('tools === null ? new FakeScanner()'));
  assert.ok(composition.includes('tools === null ? new FakeProcessor()'));
});

void test('D1 real tools: sharp only in the image pipeline, loaders blocked first, nothing kept', () => {
  const keepsMetadata =
    /\b(keepMetadata|keepExif|withMetadata|withExif|withExifMerge|keepIccProfile|withIccProfile)\s*\(/u;
  for (const file of sourceFiles(mediaDir)) {
    const relative = path.relative(mediaDir, file).replaceAll('\\', '/');
    const source = read(file);
    assert.equal(/unlimited:\s*true/u.test(source), false, relative);
    assert.equal(keepsMetadata.test(source), false, relative);
    if (relative !== 'infrastructure/image_pipeline.ts')
      assert.equal(/from ['"]sharp['"]/u.test(source), false, relative);
  }
  const pipeline = read(path.join(mediaDir, 'infrastructure', 'image_pipeline.ts'));
  assert.ok(pipeline.includes("sharp.block({ operation: ['VipsForeignLoad'] });"));
  assert.ok(pipeline.indexOf('sharp.block(') < pipeline.indexOf('sharp.unblock('));
  assert.ok(
    pipeline.indexOf('const runtime = configurePipeline();') <
      pipeline.indexOf('await sharp(bytes'),
  );
  const composition = read(path.join(mediaDir, 'infrastructure', 'emulator_media_composition.ts'));
  assert.equal(/image_pipeline|clamd_protocol/u.test(composition), false);
});

// ---------------------------------------------------------------------------
// Local acceptance traceability (BCK-14 v0.4 §34.6, §34.7 and §34.5)
// Each requirement names the tests that are its evidence; the matrix fails if a
// named test disappears or is renamed, so acceptance cannot silently erode.
// ---------------------------------------------------------------------------

const testRoot = path.resolve(process.cwd(), 'test');
const files = {
  contract: 'contract/media_fixture_parity.test.ts',
  domain: 'unit/media/media_domain.test.ts',
  transitions: 'unit/media/media_transitions.test.ts',
  variant: 'unit/media/media_variant.test.ts',
  retention: 'unit/media/media_retention_policy.test.ts',
  upload: 'integration/media_upload_service.test.ts',
  readiness: 'integration/media_content_readiness.test.ts',
  deletion: 'integration/media_deletion_reconcile.test.ts',
  privacy: 'integration/media_privacy_boundary.test.ts',
  security: 'integration/media_security.test.ts',
  contentService: 'integration/content_publication_service.test.ts',
} as const;

const acceptanceMatrix: ReadonlyArray<
  readonly [requirement: string, evidence: ReadonlyArray<readonly [keyof typeof files, string]>]
> = [
  [
    'schema/TypeScript parity, fixtures and forward rejection',
    [
      ['contract', 'media schemas accept canonical fixtures'],
      ['contract', 'schema enums equal the TypeScript vocabulary'],
    ],
  ],
  [
    'AC-76 closed map, no export, worker, Firebase or cloud code',
    [
      ['security', 'Media stays framework-neutral, offline and free of delivery or cloud code'],
      ['security', 'Media and Content never import each other'],
      ['security', 'only the Media application services write Media records'],
    ],
  ],
  [
    'AC-77 unified lifecycle, quarantine exit only by retry, no late return to ready',
    [
      ['transitions', 'the implemented lifecycle table equals the specified one'],
      ['transitions', 'every single hop is allowed exactly when the table lists it'],
      ['transitions', 'quarantine has no exit except an explicit retry or deletion'],
      ['transitions', 'a disabled asset never moves back towards ready'],
      ['upload', 'quarantine exits only through an explicit retry on the same generation'],
      ['upload', 'a late result after the asset was disabled never brings it back to ready'],
    ],
  ],
  [
    'AC-78 entity binding only through the owning-domain scope',
    [
      ['upload', 'an entity intent is trusted only if the owning domain confirms the exact scope'],
      [
        'readiness',
        'Content answers Media only from its own draft, Publisher, market and eligibility',
      ],
      ['security', 'Page membership is exact'],
    ],
  ],
  [
    'AC-79 readiness is evidence, the owning domain stores pinned references, rollback verifies them',
    [
      [
        'readiness',
        'a ready asset yields generation-pinned evidence and a canonical media revision',
      ],
      [
        'readiness',
        'rollback verifies exactly the pinned references and refuses stale generations',
      ],
      [
        'contentService',
        'publish freezes the generation-pinned media attachments into the immutable revision',
      ],
      ['contentService', 'readiness at submit is evidence only and never attaches'],
      ['contentService', 'rollback verifies exactly the references stored in the target revision'],
    ],
  ],
  [
    'AC-80 fake adapters are never production or safety evidence',
    [
      [
        'security',
        'adapters: the fakes are labelled FAKE and the D1 local tools modules are named',
      ],
      ['variant', 'the manifest is bound to the pinned source generation and its profiles'],
    ],
  ],
  [
    'AC-81 no invented policy; absent accepted policy fails closed',
    [
      ['upload', 'policy is never invented and families are disabled unless listed'],
      ['domain', 'policy is never invented'],
      ['retention', 'no retention period is invented'],
      ['deletion', 'reconcile needs an accepted retention policy'],
    ],
  ],
  [
    'AC-82 no delivery, signer, mobile, Firebase, cloud, push or merge',
    [
      ['privacy', 'there is no delivery surface in this slice'],
      ['security', 'System instructions are never accepted from a user'],
    ],
  ],
  [
    'idempotency conflict and concurrency',
    [
      ['upload', 'semantic idempotency replays equal commands and rejects a changed payload'],
      ['upload', 'concurrent duplicate creates produce exactly one asset'],
      ['upload', 'finalize and retry are idempotent and never double-process'],
      ['deletion', 'deletion is idempotent, revision-checked and owner-only'],
    ],
  ],
  [
    'cross-user, cross-Page, cross-market and revocation denial',
    [
      [
        'security',
        'another verified user cannot confirm, finalize, retry, delete, detach or read the asset',
      ],
      ['security', 'Page membership is exact'],
      ['security', 'cross-market use is denied by authority and by the owning domain'],
      ['security', 'a revoked membership or Session stops every later step immediately'],
      ['security', 'guessed identifiers and client-chosen paths reach nothing'],
    ],
  ],
  [
    'scan and processing outcomes drive the lifecycle (orchestration only)',
    [
      ['upload', 'an inconclusive or failed scan keeps the asset quarantined'],
      ['upload', 'a rejected scan or processor result blocks the asset'],
      ['upload', 'a failed processor or unverifiable variants never produce ready'],
    ],
  ],
  [
    'immutable variants and manifest',
    [
      ['variant', 'variant history is immutable'],
      ['variant', 'the manifest is bound to the pinned source generation'],
      ['domain', 'the variant manifest needs every mandatory profile'],
    ],
  ],
  [
    'deletion is tombstone-first, confirmed, and cannot be undone',
    [
      ['deletion', 'deleting a ready asset tombstones delivery first'],
      ['deletion', 'unconfirmed cleanup leaves the asset deleting'],
      ['deletion', 'a restriction cannot lift a deletion'],
      ['privacy', 'the deletion tombstone keeps identity only and nothing can resurrect it'],
    ],
  ],
  [
    'references, detach and orphan cleanup fail closed',
    [
      ['deletion', 'a referenced asset is never deleted, and doubt counts as referenced'],
      ['deletion', 'a late reference between decision and cleanup wins over deletion'],
      ['deletion', 'orphan reconcile marks, waits out the grace and only then deletes'],
      [
        'retention',
        'an unreferenced asset is marked, then deleted only after the grace of its state',
      ],
      ['readiness', 'an asset still referenced by a Content draft is not deletable'],
    ],
  ],
  [
    'privacy boundary',
    [
      ['privacy', 'no outward value carries object keys, URLs or bucket detail'],
      ['privacy', 'effects and audit carry only ids, revisions, times and outcomes'],
      ['privacy', 'private and protected assets never expose public variant metadata'],
      ['privacy', 'a foreign asset is indistinguishable from an unknown one'],
      ['readiness', 'a private or protected original never becomes part of a public revision'],
    ],
  ],
  [
    'AC-83 a stored result never outlives the caller authority',
    [
      ['deletion', 'a stored result is not a standing permission'],
      ['contentService', 'a stored result is not a standing permission'],
    ],
  ],
  [
    'AC-84 no module waits for another while holding a transaction',
    [['readiness', 'Content and Media never wait for each other while holding a transaction']],
  ],
  [
    'AC-85 an abandoned attempt is recovered and a late result is refused',
    [
      ['deletion', 'an attempt whose result never arrived is recovered after its lease'],
      ['retention', 'an attempt without a result is abandoned only after its lease'],
    ],
  ],
  [
    'AC-86 a deletion hold never lifts an authoritative restriction',
    [
      [
        'deletion',
        'a deletion hold never lifts an authoritative restriction placed while it was open',
      ],
      ['deletion', 'lifting a restriction keeps delivery disabled while a deletion hold is open'],
      ['deletion', 'a deletion hold nobody came back for is released after the lease'],
      ['retention', 'a stale deletion hold is released after the lease'],
    ],
  ],
  [
    'AC-87 a deletion holder acts only while its own hold is valid',
    [
      ['deletion', 'an expired holder cannot delete'],
      ['deletion', 'a valid hold of another worker refuses'],
      ['retention', 'a stale deletion hold is released after the lease'],
    ],
  ],
  [
    'restriction is a verified system instruction',
    [['deletion', 'a restriction is a verified system instruction and never a user command']],
  ],
  [
    'D1 real local tools are bounded, labelled and behind an explicit switch',
    [
      [
        'security',
        'adapters: the fakes are labelled FAKE and the D1 local tools modules are named',
      ],
      [
        'security',
        'D1 real tools: sharp only in the image pipeline, loaders blocked first, nothing kept',
      ],
    ],
  ],
];

/**
 * D1: shown on this Windows PC with the real local tools
 * (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md), not on Linux and not in cloud.
 */
const windowsLocalEvidence = [
  'decompression-bomb detection',
  'EXIF minimization',
  'transform determinism',
  'real object generation and hash',
  'scan detection path with the stand test signature',
];

/** Still absent: open until the Linux gate and the owner decisions. */
const realEvidenceAbsent = [
  'malware detection with official signatures (EICAR, Linux gate)',
  'official signature database freshness',
  'Linux evidence of the native tools',
  'quota and rate limits',
  'legal or safety hold',
];

void test('local acceptance matrix: every requirement is backed by a named, existing test', () => {
  const sources = new Map<string, string>();
  for (const [name, relative] of Object.entries(files))
    sources.set(name, readFileSync(path.join(testRoot, relative), 'utf8'));
  const missing: string[] = [];
  for (const [requirement, evidence] of acceptanceMatrix) {
    if (evidence.length === 0) missing.push(`${requirement}: no evidence listed`);
    for (const [file, title] of evidence)
      if (!sources.get(file)?.includes(title))
        missing.push(`${requirement}: "${title}" not in ${file}`);
  }
  assert.deepEqual(missing, []);
  assert.ok(acceptanceMatrix.length >= 19);
});

void test('the specification records the acceptance criteria and the evidence that is still absent', () => {
  const spec = readFileSync(
    path.resolve(
      process.cwd(),
      '..',
      '..',
      '..',
      'docs',
      'product',
      'MEDIA_STORAGE_BACKEND_SPEC.md',
    ),
    'utf8',
  );
  for (let number = 76; number <= 87; number += 1)
    assert.ok(spec.includes(`BCK-14-AC-${String(number)}`), `AC-${String(number)}`);
  assert.ok(spec.includes('real scanner/processor evidence: Windows-local only (D1)'));
  // Every behaviour is named either as Windows-local evidence or as still absent,
  // so neither can be mistaken for full coverage.
  assert.equal(windowsLocalEvidence.length, 5);
  assert.equal(realEvidenceAbsent.length, 5);
  for (const item of ['bomb', 'EXIF', 'determinism', 'limits', 'EICAR', 'Linux gate', 'official'])
    assert.ok(spec.includes(item), item);
});
