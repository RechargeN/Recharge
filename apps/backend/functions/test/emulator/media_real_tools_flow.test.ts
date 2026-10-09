// D1 Storage path with the real local tools (amendment §9, §10): the Emulator
// composition switched to the local tools service started by stand-d1-gate
// (L1 test mode). Run only by the D1 gate, which passes the service access.
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createServer, type AddressInfo } from 'node:net';
import { test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';
import sharp from 'sharp';

import type { MediaAssetV1, UploadSessionV1 } from '../../src/contracts/media_v1.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import {
  createEmulatorMediaComposition,
  type EmulatorMediaComposition,
} from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import type { EntityId } from '../../src/shared/ids.js';
import { createStandContentService, standEventBody } from '../stand/stand_content.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import * as samples from '../support/media_samples.js';

const accessFile = process.env.RECHARGE_MEDIA_TOOLS_ACCESS;
const skip =
  accessFile === undefined ? 'run by scripts/stand-d1-gate.mjs (needs the local tools)' : false;
const access =
  accessFile === undefined
    ? { port: 0, token: '', standSignaturesOnly: false }
    : (JSON.parse(readFileSync(accessFile, 'utf8')) as {
        port: number;
        token: string;
        standSignaturesOnly: boolean;
      });

const firestore = emulatorFirestore();
const bucket = getStorage().bucket('demo-recharge.appspot.com');
const toolsEnv = (port: number, exemption: boolean) => ({
  ...process.env,
  RECHARGE_MEDIA_TOOLS: 'local-real',
  RECHARGE_MEDIA_TOOLS_PORT: String(port),
  RECHARGE_MEDIA_TOOLS_TOKEN: access.token,
  ...(exemption ? { RECHARGE_MEDIA_TOOLS_DATABASE: 'stand-signatures-only' } : {}),
});
const compose = (environment: NodeJS.ProcessEnv) =>
  createEmulatorMediaComposition({ firestore, bucket: bucket as never, environment });
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const run = randomUUID().slice(0, 8);
let counter = 0;

async function closedPort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((resolve) => probe.listen(0, '127.0.0.1', () => resolve()));
  const { port } = probe.address() as AddressInfo;
  await new Promise<void>((resolve) => probe.close(() => resolve()));
  return port;
}

async function world(media: EmulatorMediaComposition) {
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const nowUtc = new Date().toISOString();
  const reviewer = randomUUID();
  const creator = randomUUID();
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
    pagePolicy: new LocalPageCreationPolicy(true, 2),
  });
  for (const [label, userId] of [
    ['reviewer', reviewer],
    ['creator', creator],
  ] as const)
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:d1-${run}-${label}`,
      },
      proposedUserId: userId,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
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
  const sessionId = randomUUID();
  await authority.sessions.issue({
    userId: creator,
    sessionId,
    firebaseUid: `d1-${run}-creator`,
    installationId: `d1-${run}-installation`,
    issuedAtUtc: nowUtc,
    snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
  });
  const actor = { userId: creator as EntityId, sessionId: sessionId as EntityId };
  const { service: content } = createStandContentService(firestore, media);
  const publisherRef = { type: 'page', id: pageId as EntityId } as const;
  const draft = await content.execute(actor, {
    schemaVersion: 1,
    commandType: 'createDraft',
    idempotencyKey: `d1-draft-${run}`,
    payload: { typeId: 'event', publisherRef, marketId: 'LV', body: standEventBody(randomUUID()) },
  });
  assert.equal(draft.kind, 'succeeded', JSON.stringify(draft));
  const contentId = (draft as { data: { contentId: string } }).data.contentId;
  return { actor, publisherRef, contentId };
}

type World = Awaited<ReturnType<typeof world>>;

/** Upload through the Emulator transfer, confirm, then finalize with `finalizer`. */
async function upload(
  media: EmulatorMediaComposition,
  finalizer: EmulatorMediaComposition,
  scene: World,
  bytes: Buffer,
  declaredMediaType: string,
) {
  counter += 1;
  const key = `d1-${run}-${counter}`;
  const created = await media.service.execute(scene.actor, {
    schemaVersion: 1,
    commandType: 'createUploadSession',
    idempotencyKey: `${key}-session`,
    payload: {
      family: 'image',
      marketId: 'LV',
      visibilityClass: 'publicDerived',
      declaredMediaType,
      declaredByteLength: bytes.length,
      publisherRef: scene.publisherRef,
      entityIntent: {
        domain: 'content',
        entityId: scene.contentId as EntityId,
        purpose: 'contentMedia',
      },
    },
  });
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
  const session = (created as { data: UploadSessionV1 }).data;
  const asset = await media.repository.transact((tx) => tx.asset(session.assetId));
  assert.ok(asset);
  await media.objectStore.put(asset.objectKeyHandle, bytes);
  const confirmed = await media.service.execute(scene.actor, {
    schemaVersion: 1,
    commandType: 'confirmUpload',
    idempotencyKey: `${key}-confirm`,
    payload: {
      uploadSessionId: session.uploadSessionId,
      expectedSha256: sha256(bytes),
      expectedByteLength: bytes.length,
    },
  });
  assert.equal(confirmed.kind, 'succeeded', JSON.stringify(confirmed));
  const uploaded = (confirmed as { data: MediaAssetV1 }).data;
  const finalized = await finalizer.service.execute(scene.actor, {
    schemaVersion: 1,
    commandType: 'finalizeAsset',
    idempotencyKey: `${key}-finalize`,
    payload: {
      assetId: session.assetId,
      expectedAssetRevision: uploaded.revision,
      sourceProviderGeneration: uploaded.sourceGenerationRef?.providerGeneration ?? '',
      expectedSha256: sha256(bytes),
      expectedByteLength: bytes.length,
    },
  });
  assert.equal(finalized.kind, 'succeeded', JSON.stringify(finalized));
  const view = (finalized as { data: MediaAssetV1 }).data;
  const receipts = await media.repository.transact((tx) => tx.receiptsForAsset(session.assetId));
  return { view, receipts, key };
}

let realComposition: EmulatorMediaComposition | undefined;
/** The L1 test-mode composition, built only when the gate supplied the service. */
const realMedia = () => (realComposition ??= compose(toolsEnv(access.port, true)));
let scene: World | undefined;
const sceneOnce = async () => (scene ??= await world(realMedia()));

void test(
  'a JPEG with GPS becomes ready; the stored variants are bare and match their hashes',
  { skip, timeout: 120_000 },
  async () => {
    const bytes = await samples.jpegWithGps();
    const { view, receipts } = await upload(
      realMedia(),
      realMedia(),
      await sceneOnce(),
      bytes,
      'image/jpeg',
    );
    assert.equal(view.lifecycle, 'ready', JSON.stringify(view));
    const receipt = receipts.at(-1);
    assert.equal(receipt?.scan.toolRevision, 'clamav-1.5.4/stand-marker-1/official-db-absent');
    assert.match(
      receipt?.processing?.toolRevision ?? '',
      /^sharp-0\.35\.5\/libvips-[\d.]+\/win32-x64-native$/u,
    );
    const asset = await realMedia().repository.transact((tx) => tx.asset(view.assetId));
    assert.deepEqual(asset?.variantRefs.map((variant) => variant.profile).sort(), [
      'display',
      'thumb',
    ]);
    for (const variant of asset?.variantRefs ?? []) {
      const [stored] = await bucket.file(`media-variant/${variant.variantId}`).download();
      assert.equal(sha256(stored), variant.sha256);
      assert.equal(stored.length, variant.byteLength);
      const metadata = await sharp(stored).metadata();
      assert.equal(metadata.format, 'webp');
      assert.equal(metadata.exif, undefined);
      for (const marker of ['Exif', 'GPS', 'Recharge'])
        assert.equal(stored.includes(Buffer.from(marker)), false, marker);
    }
    const first = asset?.variantRefs[0];
    assert.ok(first);
    assert.equal(await realMedia().objectStore.removeVariant(first.variantId), 'removed');
    assert.equal(await realMedia().objectStore.removeVariant(first.variantId), 'absent');
  },
);

void test(
  'the stand signature blocks the asset through the Storage path',
  { skip, timeout: 120_000 },
  async () => {
    const bytes = Buffer.concat([await samples.jpeg(), samples.markerText]);
    const { view, receipts } = await upload(
      realMedia(),
      realMedia(),
      await sceneOnce(),
      bytes,
      'image/jpeg',
    );
    assert.equal(view.lifecycle, 'blocked');
    assert.equal(receipts.at(-1)?.scan.result, 'rejected');
  },
);

void test(
  'normal mode: without the client exemption a clean file stays quarantined',
  { skip, timeout: 120_000 },
  async () => {
    const normal = compose(toolsEnv(access.port, false));
    const { view, receipts } = await upload(
      realMedia(),
      normal,
      await sceneOnce(),
      await samples.jpeg(),
      'image/jpeg',
    );
    assert.equal(view.lifecycle, 'quarantined');
    assert.equal(receipts.at(-1)?.scan.result, 'inconclusive');
  },
);

void test(
  'scanner unavailable: quarantined, then a retry with the service up is ready',
  { skip, timeout: 120_000 },
  async () => {
    const down = compose(toolsEnv(await closedPort(), true));
    const scene = await sceneOnce();
    const bytes = await samples.png();
    const { view, key } = await upload(realMedia(), down, scene, bytes, 'image/png');
    assert.equal(view.lifecycle, 'quarantined');
    const retried = await realMedia().service.execute(scene.actor, {
      schemaVersion: 1,
      commandType: 'retryProcessing',
      idempotencyKey: `${key}-retry`,
      payload: {
        assetId: view.assetId,
        expectedAssetRevision: view.revision,
        sourceProviderGeneration: view.sourceGenerationRef?.providerGeneration ?? '',
      },
    });
    assert.equal(retried.kind, 'succeeded', JSON.stringify(retried));
    assert.equal((retried as { data: MediaAssetV1 }).data.lifecycle, 'ready');
  },
);

void test(
  'a polyglot tail never reaches a stored variant',
  { skip, timeout: 120_000 },
  async () => {
    const { view } = await upload(
      realMedia(),
      realMedia(),
      await sceneOnce(),
      await samples.jpegWithHtmlTail(),
      'image/jpeg',
    );
    assert.equal(view.lifecycle, 'ready');
    const asset = await realMedia().repository.transact((tx) => tx.asset(view.assetId));
    for (const variant of asset?.variantRefs ?? []) {
      const [stored] = await bucket.file(`media-variant/${variant.variantId}`).download();
      assert.equal(stored.includes(Buffer.from('RECHARGE-POLYGLOT-TAIL')), false);
    }
  },
);

void test(
  'SVG and a disguised PNG never get past the first bytes',
  { skip, timeout: 120_000 },
  async () => {
    const scene = await sceneOnce();
    for (const [bytes, declared] of [
      [samples.svg, 'image/png'],
      [await samples.png(), 'image/jpeg'],
    ] as const) {
      counter += 1;
      const created = await realMedia().service.execute(scene.actor, {
        schemaVersion: 1,
        commandType: 'createUploadSession',
        idempotencyKey: `d1-${run}-${counter}-session`,
        payload: {
          family: 'image',
          marketId: 'LV',
          visibilityClass: 'publicDerived',
          declaredMediaType: declared,
          declaredByteLength: bytes.length,
          publisherRef: scene.publisherRef,
          entityIntent: {
            domain: 'content',
            entityId: scene.contentId as EntityId,
            purpose: 'contentMedia',
          },
        },
      });
      const session = (created as { data: UploadSessionV1 }).data;
      const asset = await realMedia().repository.transact((tx) => tx.asset(session.assetId));
      assert.ok(asset);
      await realMedia().objectStore.put(asset.objectKeyHandle, bytes);
      const confirmed = await realMedia().service.execute(scene.actor, {
        schemaVersion: 1,
        commandType: 'confirmUpload',
        idempotencyKey: `d1-${run}-${counter}-confirm`,
        payload: {
          uploadSessionId: session.uploadSessionId,
          expectedSha256: sha256(bytes),
          expectedByteLength: bytes.length,
        },
      });
      assert.deepEqual(
        [confirmed.kind, confirmed.kind === 'rejected' ? confirmed.code : ''],
        ['rejected', 'signature_mismatch'],
      );
    }
  },
);
