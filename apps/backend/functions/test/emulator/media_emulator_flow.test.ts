import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createHash } from 'node:crypto';
import { after, test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';

import type { MediaAssetV1, UploadSessionV1 } from '../../src/contracts/media_v1.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { MediaRepositoryConflict } from '../../src/modules/media/domain/failures.js';
import { createReservedAsset } from '../../src/modules/media/domain/media_asset.js';
import {
  createEmulatorMediaComposition,
  emulatorMediaEvidence,
} from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { detectMediaType } from '../../src/modules/media/infrastructure/storage_emulator_object_store.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { createStandContentService, standEventBody } from '../stand/stand_content.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const bucket = getStorage().bucket('demo-recharge.appspot.com');
const media = createEmulatorMediaComposition({ firestore, bucket: bucket as never });
const pngBase64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
const png = Buffer.from(pngBase64, 'base64');
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const run = randomUUID().slice(0, 8);

after(async () => {
  // Leave the shared Emulator tidy for the next test file.
  for (const name of Object.values(mediaCollections)) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
});

void test('the composition says what its fake adapters prove', () => {
  assert.match(emulatorMediaEvidence, /orchestration only/u);
});

void test('repository: compare-and-set, atomic failure and immutable receipts', async () => {
  const assetId = randomUUID() as EntityId;
  const asset = createReservedAsset({
    assetId,
    ownerSubjectId: randomUUID() as EntityId,
    marketId: 'LV',
    family: 'image',
    visibilityClass: 'private',
    policyRevision: 'test-only',
    objectKeyHandle: `objk:${randomUUID()}`,
    nowUtc: parseUtcInstant(new Date().toISOString()),
  });
  await media.repository.transact((tx) => tx.putAsset(asset, 0));
  assert.equal((await media.repository.transact((tx) => tx.asset(assetId)))?.revision, 1);

  await assert.rejects(
    media.repository.transact((tx) => tx.putAsset({ ...asset, revision: 2 }, 0)),
    MediaRepositoryConflict,
  );
  // A failure after a buffered write leaves nothing behind.
  await assert.rejects(
    media.repository.transact((tx) => {
      tx.putAsset({ ...asset, revision: 2 }, 1);
      throw new Error('abort');
    }),
    /abort/u,
  );
  assert.equal((await media.repository.transact((tx) => tx.asset(assetId)))?.revision, 1);
});

void test('object store measures stored bytes, never the declared type', async () => {
  const handle = `objk:${randomUUID()}`;
  assert.deepEqual(await media.objectStore.stat(handle), { kind: 'absent' });
  await media.objectStore.put(handle, png);
  const stat = await media.objectStore.stat(handle);
  assert.equal(stat.kind, 'complete');
  if (stat.kind !== 'complete') return;
  assert.equal(stat.detectedMediaType, 'image/png');
  assert.equal(stat.byteLength, png.length);
  assert.equal(stat.sha256, sha256(png));
  assert.equal(detectMediaType(Buffer.from('not an image at all')), 'application/octet-stream');
  assert.equal(await media.objectStore.remove(handle), 'removed');
  assert.equal(await media.objectStore.remove(handle), 'absent');
});

async function bootstrap() {
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const nowUtc = new Date().toISOString();
  const reviewer = randomUUID();
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
    pagePolicy: new LocalPageCreationPolicy(true, 2),
  });
  const account = async (label: string, userId: string) => {
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:media-${run}-${label}`,
      },
      proposedUserId: userId,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
  };
  const creator = randomUUID();
  const outsider = randomUUID();
  await account('reviewer', reviewer);
  await account('creator', creator);
  await account('outsider', outsider);
  await authority.creatorVerification.submit({
    userId: creator,
    verificationId: randomUUID(),
    evidenceRefIds: [randomUUID()],
    nowUtc,
  });
  await authority.creatorVerification.decide({
    reviewerId: reviewer,
    userId: creator,
    status: 'verified',
    nowUtc,
  });
  const pageId = randomUUID();
  await authority.pages.create({
    userId: creator,
    pageId,
    membershipId: randomUUID(),
    marketId: 'LV',
    nowUtc,
  });
  await authority.pages.decidePage({ reviewerId: reviewer, pageId, decision: 'verified', nowUtc });
  const session = async (userId: string) => {
    const sessionId = randomUUID();
    await authority.sessions.issue({
      userId,
      sessionId,
      firebaseUid: `media-${run}-${userId}`,
      installationId: `media-${run}-installation`,
      issuedAtUtc: nowUtc,
      snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
    });
    return { userId: userId as EntityId, sessionId: sessionId as EntityId };
  };
  return {
    pageId,
    creator: await session(creator),
    outsider: await session(outsider),
  };
}

void test(
  'upload, confirm and finalize bind to a Content draft and Content checks the exact revision',
  { timeout: 120_000 },
  async () => {
    const world = await bootstrap();
    const { service: content } = createStandContentService(firestore, media);
    const publisherRef = { type: 'page', id: world.pageId as EntityId } as const;

    const draftResult = await content.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: `c1-draft-${run}`,
      payload: {
        typeId: 'event',
        publisherRef,
        marketId: 'LV',
        body: standEventBody(randomUUID()),
      },
    });
    assert.equal(draftResult.kind, 'succeeded', JSON.stringify(draftResult));
    const draft = (
      draftResult as { data: { draftId: string; contentId: string; revision: number } }
    ).data;

    const createSession = (actor: typeof world.creator, key: string) =>
      media.service.execute(actor, {
        schemaVersion: 1,
        commandType: 'createUploadSession',
        idempotencyKey: key,
        payload: {
          family: 'image',
          marketId: 'LV',
          visibilityClass: 'publicDerived',
          declaredMediaType: 'image/png',
          declaredByteLength: png.length,
          publisherRef,
          entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
        },
      });

    // Another user cannot bind media to this draft or Publisher.
    const foreign = await createSession(world.outsider, `c1-foreign-${run}`);
    assert.equal(foreign.kind, 'rejected');

    const created = await createSession(world.creator, `c1-session-${run}`);
    assert.equal(created.kind, 'succeeded', JSON.stringify(created));
    const upload = (created as { data: UploadSessionV1 }).data;

    // Before any bytes exist, confirm is refused and Content sees no ready media.
    const early = await media.service.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `c1-early-${run}`,
      payload: {
        uploadSessionId: upload.uploadSessionId,
        expectedSha256: sha256(png),
        expectedByteLength: png.length,
      },
    });
    assert.deepEqual(
      [early.kind, early.kind === 'rejected' ? early.code : ''],
      ['rejected', 'object_missing'],
    );
    const notReady = await media.readiness.check({
      contentId: draft.contentId,
      typeId: 'event',
      marketId: 'LV',
      publisherRef,
      mediaIds: [upload.assetId],
    });
    assert.equal(notReady.ready, false);

    // The owner's bytes go through the Emulator-only transfer (the same call the
    // callable makes), then confirm and finalize.
    const asset = await media.repository.transact((tx) => tx.asset(upload.assetId));
    assert.ok(asset);
    await media.objectStore.put(asset.objectKeyHandle, png);
    const confirmed = await media.service.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `c1-confirm-${run}`,
      payload: {
        uploadSessionId: upload.uploadSessionId,
        expectedSha256: sha256(png),
        expectedByteLength: png.length,
      },
    });
    assert.equal(confirmed.kind, 'succeeded', JSON.stringify(confirmed));
    const uploaded = (confirmed as { data: MediaAssetV1 }).data;
    assert.ok(uploaded.sourceGenerationRef);

    const finalized = await media.service.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: `c1-finalize-${run}`,
      payload: {
        assetId: upload.assetId,
        expectedAssetRevision: uploaded.revision,
        sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(png),
        expectedByteLength: png.length,
      },
    });
    assert.equal(finalized.kind, 'succeeded', JSON.stringify(finalized));
    assert.equal((finalized as { data: MediaAssetV1 }).data.lifecycle, 'ready');
    const receipts = await media.repository.transact((tx) => tx.receiptsForAsset(upload.assetId));
    assert.match(receipts[0]?.scan.toolRevision ?? '', /^fake-/u, 'receipts say they are fake');

    // Content checks that exact Media revision, then accepts the submission.
    const ready = await media.readiness.check({
      contentId: draft.contentId,
      typeId: 'event',
      marketId: 'LV',
      publisherRef,
      mediaIds: [upload.assetId],
    });
    assert.equal(ready.ready, true);
    const updated = await content.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: `c1-update-${run}`,
      payload: {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: standEventBody(upload.assetId),
      },
    });
    assert.equal(updated.kind, 'succeeded', JSON.stringify(updated));
    const submitted = await content.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: `c1-submit-${run}`,
      payload: {
        draftId: draft.draftId,
        expectedDraftRevision: (updated as { data: { revision: number } }).data.revision,
      },
    });
    assert.equal(submitted.kind, 'succeeded', JSON.stringify(submitted));
  },
);
