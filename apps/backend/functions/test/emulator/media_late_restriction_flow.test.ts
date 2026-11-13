// D2 on the Emulator (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md §11): a real cover
// processed by the D1 local tools, published through Content, Media and staff
// moderation, delivered through the gate, then restricted, lifted, suppressed,
// confirmed again, rebuilt and swept — with Firestore and Storage Emulator.
// T1, T2, T3, T5, T8, T10. Run by scripts/stand-d2-gate.mjs (needs the tools).
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';
import sharp from 'sharp';

import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { eventBookingHandoffCollections } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import {
  contentMediaAvailability,
  reconcileMediaReferences,
} from '../../src/media_effects_entry.js';
import { handleMediaDelivery } from '../../src/media_entry.js';
import { revocationEpochOf } from '../../src/modules/media/domain/media_asset.js';
import type { MediaRetentionPolicy } from '../../src/modules/media/domain/media_retention.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { FirestoreModerationRepository } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { MediaRestrictionVerifier } from '../../src/modules/moderation/infrastructure/media_restriction_verifier.js';
import type { EntityId } from '../../src/shared/ids.js';
import { createContentEventWorld } from '../support/content_event_world.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import * as samples from '../support/media_samples.js';

const accessFile = process.env.RECHARGE_MEDIA_TOOLS_ACCESS;
const skip =
  accessFile === undefined ? 'run by scripts/stand-d2-gate.mjs (needs the local tools)' : false;
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
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
let offsetMs = 0;
/** TEST-ONLY managed clock: R2 needs the orphan grace to pass. */
const clock = { now: () => new Date(Date.now() + offsetMs) };
/** Synthetic, explicitly TEST-ONLY retention of the D2 gate (§8); not a product policy. */
const d2GateTestOnlyRetention: MediaRetentionPolicy = {
  revision: 'd2-gate-test-only-retention-1',
  orphanGraceSeconds: 60,
  quarantinedRetentionSeconds: 60,
  blockedRetentionSeconds: 60,
  inFlightAttemptLeaseSeconds: 60,
  deletionHoldLeaseSeconds: 30,
  deletionReceiptRetentionSeconds: 600,
};
const allFlags = { isEnabled: () => Promise.resolve(true) };

let scene:
  | (Awaited<ReturnType<typeof setup>> & { readonly contentId: string; readonly asset: string })
  | undefined;

async function setup() {
  const media = createEmulatorMediaComposition({
    firestore,
    bucket: bucket as never,
    environment: {
      ...process.env,
      RECHARGE_MEDIA_TOOLS: 'local-real',
      RECHARGE_MEDIA_TOOLS_PORT: String(access.port),
      RECHARGE_MEDIA_TOOLS_TOKEN: access.token,
      ...(access.standSignaturesOnly
        ? { RECHARGE_MEDIA_TOOLS_DATABASE: 'stand-signatures-only' }
        : {}),
    },
    restrictionAuthority: new MediaRestrictionVerifier(
      new FirestoreModerationRepository(firestore),
    ),
  });
  const world = createContentEventWorld(firestore, `d2-${randomUUID().slice(0, 6)}`, {
    media,
    cover: { bytes: await samples.jpegWithGps(), mediaType: 'image/jpeg' },
  });
  const catalog = createEmulatorCatalogComposition(firestore);
  const handoff = createEmulatorEventBookingHandoff(firestore).handoff;
  const availability = contentMediaAvailability(firestore);
  return { media, world, catalog, handoff, availability };
}

/** Internal registration, so the Booking handoff really has occurrences to keep. */
const withRegistration = (body: Record<string, unknown>) => ({
  ...body,
  participants: { capacityMode: 'known', capacity: 20 },
  registration: {
    mode: 'internal',
    confirmationMode: 'instant',
    maxPartySize: 2,
    opensMinutesBeforeStart: 525_600,
    closesMinutesBeforeStart: 60,
    cancellationClosesMinutesBeforeStart: 120,
  },
});

async function sceneOnce() {
  if (scene !== undefined) return scene;
  const base = await setup();
  const contentId = await base.world.publish({
    title: 'Glaze night',
    date: '2035-10-10',
    transform: withRegistration,
  });
  scene = { ...base, contentId, asset: base.world.coverOf(contentId) };
  return scene;
}

async function deliver(profile = 'display') {
  const current = await sceneOnce();
  return handleMediaDelivery(
    { firestore },
    { schemaVersion: 1, contentId: current.contentId, assetId: current.asset, profile },
  );
}

/** The listed cover id, `null` without a cover, `undefined` when not listed. */
async function catalogCover(): Promise<string | null | undefined> {
  const current = await sceneOnce();
  const set = await current.catalog.sets.ensureActive();
  await current.catalog.projector.deliverFromContent(set.setId);
  const details = await current.catalog.query.details({ contentId: current.contentId });
  assert.equal(details.kind, 'succeeded', JSON.stringify(details));
  if (details.kind !== 'succeeded' || details.item === null) return undefined;
  return details.item.coverMediaId;
}

async function staffDecision(action: 'restrict_media' | 'restore_media', restores?: string) {
  const current = await sceneOnce();
  const { staff } = await current.world.actors;
  const result = await current.world.content.moderation.service.decide(staff, {
    schemaVersion: 1,
    action,
    idempotencyKey: `d2-${action}-${randomUUID()}`,
    reason: 'cover reported as unsafe',
    target: { assetId: current.asset },
    ...(restores === undefined ? {} : { restoresDecisionId: restores }),
  });
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  if (result.kind !== 'succeeded') throw new Error('refused');
  assert.equal(result.data.receipt.outcome, 'applied', JSON.stringify(result.data.receipt));
  return result.data.decision.decisionId;
}

const outboxCount = async () =>
  (await firestore.collection(eventBookingHandoffCollections.outbox).get()).size;

let restrictionDecision = '';

void test(
  'T1: the published cover is delivered as its real variant bytes',
  { skip, timeout: 180_000 },
  async () => {
    const current = await sceneOnce();
    const wire = (await deliver()) as {
      kind: string;
      resultType: string;
      data: { sha256: string; byteLength: number; format: string; bytesBase64: string };
    };
    assert.equal(wire.kind, 'succeeded', JSON.stringify(wire).slice(0, 300));
    assert.equal(wire.resultType, 'mediaDelivery');
    const bytes = Buffer.from(wire.data.bytesBase64, 'base64');
    assert.equal(sha256(bytes), wire.data.sha256);
    const asset = await current.media.repository.transact((tx) => tx.asset(current.asset));
    const variant = asset?.variantRefs.find((item) => item.profile === 'display');
    assert.equal(variant?.sha256, wire.data.sha256);
    const metadata = await sharp(bytes).metadata();
    assert.equal(metadata.format, 'webp');
    assert.equal(metadata.exif, undefined);
    for (const marker of ['Exif', 'GPS']) assert.equal(bytes.includes(Buffer.from(marker)), false);
    assert.equal(await catalogCover(), current.asset);
    assert.deepEqual(
      await handleMediaDelivery({ firestore }, { schemaVersion: 1, contentId: current.contentId }),
      { schemaVersion: 1, kind: 'rejected', code: 'invalid_contract' },
    );
    assert.deepEqual(
      await handleMediaDelivery(
        { firestore },
        { schemaVersion: 1, contentId: randomUUID(), assetId: current.asset, profile: 'display' },
      ),
      { schemaVersion: 1, kind: 'rejected', code: 'not_found' },
    );
  },
);

void test(
  'T2: a staff restriction refuses the next delivery while Content and Catalog are stale',
  { skip, timeout: 120_000 },
  async () => {
    const current = await sceneOnce();
    restrictionDecision = await staffDecision('restrict_media');
    assert.deepEqual(await deliver(), { schemaVersion: 1, kind: 'rejected', code: 'not_found' });
    // Nothing reacted yet: no suppression, and the Catalog still lists the cover id.
    assert.equal((await current.world.pointer(current.contentId)).mediaSuppression, undefined);
    assert.equal(await catalogCover(), current.asset);
  },
);

void test(
  'T3: lifted while Content did not run — still refused; suppressed; confirmed by the publisher only',
  { skip, timeout: 180_000 },
  async () => {
    const current = await sceneOnce();
    await staffDecision('restore_media', restrictionDecision);
    const lifted = await current.media.repository.transact((tx) => tx.asset(current.asset));
    assert.equal(lifted?.deliveryDisabled, false);
    assert.ok(lifted !== null && revocationEpochOf(lifted) === 1);
    assert.deepEqual(await deliver(), { schemaVersion: 1, kind: 'rejected', code: 'not_found' });
    // T5: a worker reconciled and died before recording; the consumer finishes.
    assert.equal(await current.availability.reconcileContent(current.contentId), 'suppressed');
    await current.handoff.deliver();
    const outboxBefore = await outboxCount();
    const report = await current.availability.deliverMediaEffects();
    assert.equal(report.stoppedAt, null, JSON.stringify(report));
    const pointer = await current.world.pointer(current.contentId);
    assert.deepEqual(
      (pointer.mediaSuppression ?? []).map((item) => [item.assetId, item.reason]),
      [[current.asset, 'revoked']],
    );
    const mediaFacts = await firestore
      .collection('contentEffects')
      .where('contentId', '==', current.contentId)
      .where('kind', '==', 'ContentMediaAvailabilityChanged')
      .get();
    assert.equal(mediaFacts.size, 1, 'exactly one suppression after the lost worker');
    assert.equal(await catalogCover(), null);
    // The publisher confirms the current revision again.
    const revisionId = pointer.currentPublishedRevisionId;
    assert.ok(revisionId);
    const confirmed = await current.world.activate(current.contentId, revisionId);
    assert.equal(confirmed.kind, 'succeeded', JSON.stringify(confirmed));
    const after = await current.world.pointer(current.contentId);
    assert.equal(after.mediaSuppression, undefined);
    assert.deepEqual(after.mediaConfirmations, [
      { assetId: current.asset as EntityId, revocationEpoch: 1 },
    ]);
    assert.equal((await deliver()).kind, 'succeeded');
    assert.equal(await catalogCover(), current.asset);
    // Booking: the suppression and the confirmation produced no fact at all.
    const handoff = await current.handoff.deliver();
    assert.equal(handoff.stoppedAt, null, JSON.stringify(handoff));
    assert.equal(await outboxCount(), outboxBefore);
  },
);

void test(
  'T8: rebuild, activation and rollback of the Catalog never bring a suppressed cover back',
  { skip, timeout: 300_000 },
  async () => {
    const current = await sceneOnce();
    const decision = await staffDecision('restrict_media');
    await current.availability.deliverMediaEffects();
    assert.equal(await catalogCover(), null);
    const active = await current.catalog.sets.ensureActive();
    const rebuilt = await current.catalog.sets.rebuild();
    assert.equal(rebuilt.report.complete, true, JSON.stringify(rebuilt.report.findings));
    const activated = await current.catalog.sets.activate(rebuilt.setId, active.setId);
    assert.equal(activated.ok, true, JSON.stringify(activated));
    assert.equal(await catalogCover(), null, 'rebuilt from facts: still suppressed');
    const rolledBack = await current.catalog.sets.rollback(rebuilt.setId);
    assert.equal(rolledBack.ok, true, JSON.stringify(rolledBack));
    assert.equal(await catalogCover(), null, 'rolled back: still suppressed');
    // Leave the scene confirmed again for the sweep below.
    await staffDecision('restore_media', decision);
    const pointer = await current.world.pointer(current.contentId);
    const revisionId = pointer.currentPublishedRevisionId;
    assert.ok(revisionId);
    assert.equal((await current.world.activate(current.contentId, revisionId)).kind, 'succeeded');
    assert.equal(await catalogCover(), current.asset);
  },
);

void test(
  'T10: R1 finds nothing to do; R2 deletes a real orphan with the test-only policy and keeps the cover',
  { skip, timeout: 300_000 },
  async () => {
    const current = await sceneOnce();
    const { creator, pageId } = await current.world.actors;
    // An image bound to the Content but never attached to the body: an orphan.
    const bytes = await samples.jpeg();
    const session = await current.media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: `d2-orphan-${randomUUID()}`,
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/jpeg',
        declaredByteLength: bytes.length,
        publisherRef: { type: 'page', id: pageId },
        entityIntent: { domain: 'content', entityId: current.contentId, purpose: 'contentMedia' },
      },
    });
    assert.equal(session.kind, 'succeeded', JSON.stringify(session));
    const { assetId, uploadSessionId } = (
      session as { data: { assetId: string; uploadSessionId: string } }
    ).data;
    const stored = await current.media.repository.transact((tx) => tx.asset(assetId));
    assert.ok(stored);
    await current.media.objectStore.put(stored.objectKeyHandle, bytes);
    const confirmed = await current.media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `d2-orphan-confirm-${randomUUID()}`,
      payload: { uploadSessionId, expectedSha256: sha256(bytes), expectedByteLength: bytes.length },
    });
    const uploaded = (
      confirmed as {
        data: { revision: number; sourceGenerationRef: { providerGeneration: string } };
      }
    ).data;
    const finalized = await current.media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: `d2-orphan-finalize-${randomUUID()}`,
      payload: {
        assetId,
        expectedAssetRevision: uploaded.revision,
        sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(bytes),
        expectedByteLength: bytes.length,
      },
    });
    assert.equal(finalized.kind, 'succeeded', JSON.stringify(finalized));
    const orphan = await current.media.repository.transact((tx) => tx.asset(assetId));
    assert.ok(orphan !== null && orphan.lifecycle === 'ready');
    const variantFiles = orphan.variantRefs.map((variant) => `media-variant/${variant.variantId}`);

    // The stand has no retention policy: nothing is deleted.
    const stand = await reconcileMediaReferences(firestore, { flags: allFlags, clock });
    assert.notEqual(stand.orphans, 'disabled');
    if (stand.orphans !== 'disabled')
      assert.ok((stand.orphans.refused.policy_unavailable ?? 0) > 0);
    assert.notEqual(stand.references, 'disabled');
    if (stand.references !== 'disabled') assert.equal(stand.references.suppressed, 0);

    // The D2 gate's test-only policy: mark, let the grace pass, delete.
    const marked = await reconcileMediaReferences(firestore, {
      flags: allFlags,
      clock,
      retention: d2GateTestOnlyRetention,
    });
    assert.ok(marked.orphans !== 'disabled' && marked.orphans.actions.marked >= 1);
    offsetMs += 61_000;
    const deleted = await reconcileMediaReferences(firestore, {
      flags: allFlags,
      clock,
      retention: d2GateTestOnlyRetention,
    });
    assert.ok(deleted.orphans !== 'disabled' && deleted.orphans.actions.deleted >= 1);
    const gone = await current.media.repository.transact((tx) => tx.asset(assetId));
    assert.equal(gone?.lifecycle, 'deleted');
    for (const file of variantFiles)
      assert.equal((await bucket.file(file).exists())[0], false, file);
    // The cover is referenced by the draft and the revision: kept and still delivered.
    const cover = await current.media.repository.transact((tx) => tx.asset(current.asset));
    assert.equal(cover?.lifecycle, 'ready');
    assert.equal((await deliver()).kind, 'succeeded');
  },
);
