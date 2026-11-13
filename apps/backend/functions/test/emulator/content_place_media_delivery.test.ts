// D3.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md §4, P15): delivery of a published
// Place's gallery photo through the D2 gate with real variant bytes from the
// D1 local tools (L1 test mode), so a refusal is proven against a delivery that
// worked: real bytes before a staff restriction, refused after it, still
// refused after the restriction is lifted without the publisher's activation
// (before and after Content reacts), real bytes again after the activation.
// Run by scripts/stand-d3-1-gate.mjs (needs the tools); skipped elsewhere.
// D10 reuses these same four cases with RECHARGE_MEDIA_DELIVERY_CONTENT_TYPE=activity.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';
import sharp from 'sharp';

import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { handleMediaDelivery } from '../../src/media_entry.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { FirestoreModerationRepository } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { MediaRestrictionVerifier } from '../../src/modules/moderation/infrastructure/media_restriction_verifier.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createActivityWorld } from '../support/content_activity_world.js';
import { createPlaceWorld, expectData } from '../support/content_place_world.js';
import * as samples from '../support/media_samples.js';

const contentType = process.env.RECHARGE_MEDIA_DELIVERY_CONTENT_TYPE ?? 'place';
assert.ok(
  contentType === 'place' || contentType === 'activity',
  'explicit supported delivery test type',
);
const contentLabel = contentType === 'activity' ? 'Activity' : 'Place';
const accessFile = process.env.RECHARGE_MEDIA_TOOLS_ACCESS;
const skip =
  accessFile === undefined ? 'run by scripts/stand-d3-1-gate.mjs (needs the local tools)' : false;
const access =
  accessFile === undefined
    ? { port: 0, token: '', standSignaturesOnly: false }
    : (JSON.parse(readFileSync(accessFile, 'utf8')) as {
        port: number;
        token: string;
        standSignaturesOnly: boolean;
      });

const firestore = emulatorFirestore();
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

type Scene = Awaited<ReturnType<typeof setup>>;
let scene: Scene | undefined;
let restriction = '';

async function setup() {
  const media = createEmulatorMediaComposition({
    firestore,
    bucket: getStorage().bucket('demo-recharge.appspot.com') as never,
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
  const makeWorld = contentType === 'activity' ? createActivityWorld : createPlaceWorld;
  const world = makeWorld(firestore, `d310-${contentType}-delivery`, {
    media,
    images: {
      cover: await samples.jpeg(64, 48),
      // The photo under test carries GPS metadata that its variant must not.
      gallery: [await samples.jpegWithGps(), await samples.jpeg(96, 72)],
      mediaType: 'image/jpeg',
    },
  });
  const place =
    'publishedActivity' in world ? await world.publishedActivity() : await world.publishedPlace();
  return {
    world,
    place,
    photo: place.gallery[0] as string,
    other: place.gallery[1] as string,
  };
}

async function current(): Promise<Scene> {
  scene ??= await setup();
  return scene;
}

async function deliver(assetId: string) {
  const { place } = await current();
  return (await handleMediaDelivery(
    { firestore },
    { schemaVersion: 1, contentId: place.contentId, assetId, profile: 'display' },
  )) as {
    kind: string;
    code?: string;
    data?: { sha256: string; format: string; bytesBase64: string };
  };
}

/** The delivered bytes are exactly the asset's display variant, a WebP without metadata. */
async function assertRealBytes(assetId: string): Promise<void> {
  const { world } = await current();
  const wire = await deliver(assetId);
  assert.equal(wire.kind, 'succeeded', JSON.stringify(wire).slice(0, 300));
  const bytes = Buffer.from(wire.data?.bytesBase64 ?? '', 'base64');
  assert.ok(bytes.length > 0);
  assert.equal(sha256(bytes), wire.data?.sha256);
  const asset = await world.media.repository.transact((tx) => tx.asset(assetId));
  const variant = asset?.variantRefs.find((item) => item.profile === 'display');
  assert.equal(variant?.sha256, wire.data?.sha256);
  const metadata = await sharp(bytes).metadata();
  assert.equal(metadata.format, 'webp');
  assert.equal(metadata.exif, undefined);
  for (const marker of ['Exif', 'GPS']) assert.equal(bytes.includes(Buffer.from(marker)), false);
}

const refused = { schemaVersion: 1, kind: 'rejected', code: 'not_found' };

void test(
  `before a restriction the ${contentLabel} photo is delivered as its real variant bytes`,
  { skip, timeout: 240_000 },
  async () => {
    const { photo, other } = await current();
    await assertRealBytes(photo);
    await assertRealBytes(other);
  },
);

void test(
  'after a staff restriction the photo is refused at once; the other photo is still delivered',
  { skip, timeout: 120_000 },
  async () => {
    const { world, photo, other, place } = await current();
    restriction = expectData<{ decision: { decisionId: string } }>(
      await world.decide('restrict_media', { assetId: photo }),
      'restrict_media',
    ).decision.decisionId;
    // Content has not reacted: no suppression yet, the refusal is Media's own.
    assert.equal((await world.pointer(place.contentId)).mediaSuppression, undefined);
    assert.deepEqual(await deliver(photo), refused);
    await assertRealBytes(other);
  },
);

void test(
  'after the lift without the publisher activating, the photo stays refused',
  { skip, timeout: 120_000 },
  async () => {
    const { world, photo, place } = await current();
    expectData(
      await world.decide('restore_media', { assetId: photo }, { restoresDecisionId: restriction }),
      'restore_media',
    );
    // Media is ready again, but the publisher confirmed an older epoch.
    assert.deepEqual(await deliver(photo), refused);
    // Content reacts from Media's state: the photo is suppressed, still refused.
    assert.equal(
      await contentMediaAvailability(firestore).reconcileContent(place.contentId),
      'suppressed',
    );
    const pointer = await world.pointer(place.contentId);
    assert.deepEqual(
      (pointer.mediaSuppression ?? []).map((item) => item.assetId),
      [photo],
    );
    assert.deepEqual(await deliver(photo), refused);
  },
);

void test(
  "after the publisher's activation the photo is delivered as real bytes again",
  { skip, timeout: 120_000 },
  async () => {
    const { world, photo, place } = await current();
    const pointer = await world.pointer(place.contentId);
    const activated = await world.activate(
      place.contentId,
      place.publishedRevisionId,
      pointer.revision,
    );
    assert.equal(activated.kind, 'succeeded', JSON.stringify(activated));
    assert.equal((await world.pointer(place.contentId)).mediaSuppression, undefined);
    await assertRealBytes(photo);
  },
);
