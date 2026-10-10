import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import {
  readStandManifest,
  StandSeedInterrupted,
  writeStandManifest,
} from './stand_content_event.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor, pageIdOf } from './stand_media.js';

/**
 * D3.1 stand Place (PLACE_D3_1_PUBLICATION_AMENDMENT.md §7): one fixed Place
 * published through Content only — an empty draft (§5.4), a cover and two
 * gallery photos through Media, the full body with the server's author, submit,
 * a staff approval through C2 and the owner's publish. The Place authoring flag
 * is enabled here and nowhere else on the stand, so the other gates keep their
 * state. Every command repeats the same key and payload on every run.
 */
export interface StandContentPlaceManifest {
  readonly pageId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly createdByUserId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly coverAssetId: string;
  readonly galleryAssetIds: readonly string[];
  readonly approveDecisionId: string;
  readonly completedAtUtc: string;
}

const png = (base64: string) => Buffer.from(base64, 'base64');

export const standSeedPlace = Object.freeze({
  pageLabel: 'studio',
  periodId: 'a6f1d3c2-0000-4000-8000-00000000d301',
  approveReason: 'stand seed: the seeded Place is approved for publication',
  images: Object.freeze({
    cover: png(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPQ6w4HAAH7ARF0JhTpAAAAAElFTkSuQmCC',
    ),
    gallery: [
      png(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNwa9oCAAKOAX3Ic40cAAAAAElFTkSuQmCC',
      ),
      png(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGO4tVQBAAP8AaCR7d5RAAAAAElFTkSuQmCC',
      ),
    ],
  }),
  keys: Object.freeze({
    draft: 'stand-seed-place-draft',
    cover: 'stand-seed-place-cover',
    gallery: 'stand-seed-place-gallery',
    bind: 'stand-seed-place-bind',
    submit: 'stand-seed-place-submit',
    approve: 'stand-seed-place-approve',
    publish: 'stand-seed-place-publish',
  }),
});

export const standSeedPlaceSteps = [
  'draft',
  'cover',
  'gallery-1',
  'gallery-2',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedPlaceStep = (typeof standSeedPlaceSteps)[number];

/**
 * A complete Place under the Emulator Place taxonomy (§2.3:
 * `outdoor_nature_walking/park` requires `difficulty`), inside the LV service
 * area, with the server's author of the draft.
 */
export function standPlaceBody(input: {
  readonly submittedByUserId: string;
  readonly coverMediaId: string;
  readonly galleryMediaIds: readonly string[];
  readonly periodId?: string;
}): Record<string, unknown> {
  return {
    title: 'Kronvalda park pond',
    placeKind: 'publicSpace',
    relationshipToPlace: 'visitor',
    shortDescription: 'Quiet city park with a pond and benches',
    contentLocale: 'en',
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'park',
    criteria: { difficulty: 'easy' },
    location: {
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      formattedAddress: 'Kronvalda bulvaris, Riga',
      point: { latitude: 56.9586, longitude: 24.1066 },
      timezoneId: 'Europe/Riga',
      accuracy: 'rooftop',
      pinConfirmed: true,
    },
    hours: {
      mode: 'regular',
      weeklyPeriods: [
        {
          id: input.periodId ?? standSeedPlace.periodId,
          dayOfWeek: 1,
          openMinute: 420,
          closeMinute: 1320,
          closesNextDay: false,
        },
      ],
      exceptions: [],
    },
    operationalStatus: { status: 'operating' },
    pricing: { entryType: 'free', currencyCode: 'EUR' },
    media: {
      coverImage: { mediaId: input.coverMediaId },
      gallery: input.galleryMediaIds.map((mediaId) => ({ mediaId })),
    },
    provenance: {
      sourceType: 'creatorSubmission',
      submittedByUserId: input.submittedByUserId,
      relationshipClaim: 'visitor',
      createdAtUtc: '2026-10-10T08:00:00.000Z',
      lastConfirmedAtUtc: '2026-10-10T08:00:00.000Z',
    },
  };
}

const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_place_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** Media lifecycles before the bytes were confirmed: only then are bytes written. */
const beforeConfirm = new Set(['reserved', 'uploading']);

/** The Emulator composition of the Place callables (Event and Place enabled). */
function placeComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['event', 'place'] as const),
    }),
  };
}

async function uploadStandImage(
  media: ReturnType<typeof mediaFor>,
  creator: ContentActor,
  input: {
    readonly key: string;
    readonly bytes: Buffer;
    readonly pageId: string;
    readonly contentId: string;
  },
): Promise<string> {
  const session = expectSucceeded<{ uploadSessionId: string; assetId: string }>(
    `${input.key}_session`,
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: `${input.key}:session`,
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: input.bytes.length,
        publisherRef: { type: 'page', id: input.pageId },
        entityIntent: { domain: 'content', entityId: input.contentId, purpose: 'contentMedia' },
      },
    }),
  );
  const asset = await media.repository.transact((tx) => tx.asset(session.assetId));
  if (asset === null) throw new Error(`stand_seed_place_asset_missing:${input.key}`);
  // Bytes are written only before confirmation; a resumed seed never replaces
  // the object whose generation Media already pinned.
  if (beforeConfirm.has(asset.lifecycle))
    await media.objectStore.put(asset.objectKeyHandle, input.bytes);
  const uploaded = expectSucceeded<{
    revision: number;
    sourceGenerationRef: { providerGeneration: string };
  }>(
    `${input.key}_confirm`,
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `${input.key}:confirm`,
      payload: {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha256(input.bytes),
        expectedByteLength: input.bytes.length,
      },
    }),
  );
  expectSucceeded(
    `${input.key}_finalize`,
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: `${input.key}:finalize`,
      payload: {
        assetId: session.assetId,
        expectedAssetRevision: uploaded.revision,
        sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(input.bytes),
        expectedByteLength: input.bytes.length,
      },
    }),
  );
  return session.assetId;
}

export async function seedContentPlace(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentPlaceManifest }> {
  const existing = (await readStandManifest(firestore))?.contentPlace;
  if (existing !== undefined) return { reused: true, manifest: existing };
  await enableStandFlag(firestore, contentFlagIds.placeAuthoring, new Date().toISOString());
  const checkpoint = (step: StandSeedPlaceStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand place seed interrupted after ${step} (test hook)`);
  };
  const { media, composition } = placeComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const pageId = pageIdOf(standSeedPlace.pageLabel);
  const { keys, images } = standSeedPlace;

  // §5.4: the draft starts empty, so a replay of the same key always matches.
  const draft = expectSucceeded<{
    draftId: string;
    contentId: string;
    revision: number;
    createdByUserId: string;
  }>(
    'draft',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: keys.draft,
      payload: {
        typeId: 'place',
        publisherRef: { type: 'page', id: pageId },
        marketId: 'LV',
        body: {},
      },
    }),
  );
  checkpoint('draft');
  const upload = (key: string, bytes: Buffer) =>
    uploadStandImage(media, creator, { key, bytes, pageId, contentId: draft.contentId });
  const coverAssetId = await upload(keys.cover, images.cover);
  checkpoint('cover');
  const galleryAssetIds: string[] = [];
  for (const [index, bytes] of images.gallery.entries()) {
    galleryAssetIds.push(await upload(`${keys.gallery}-${index + 1}`, bytes));
    checkpoint(`gallery-${index + 1}` as StandSeedPlaceStep);
  }

  // Revisions are the ones this exact sequence produces (1 after create, 2 after
  // the binding), so a replay sends the identical command.
  expectSucceeded(
    'bind',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: keys.bind,
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: standPlaceBody({
          submittedByUserId: draft.createdByUserId,
          coverMediaId: coverAssetId,
          galleryMediaIds: galleryAssetIds,
        }),
      },
    }),
  );
  checkpoint('bind');

  const submission = expectSucceeded<{ submissionId: string }>(
    'submit',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: keys.submit,
      payload: { draftId: draft.draftId, expectedDraftRevision: 2 },
    }),
  );
  checkpoint('submit');

  const staff = await actorFor(firestore, 'staff');
  const approved = expectSucceeded<{
    decision: { decisionId: string };
    receipt: { outcome: string };
  }>(
    'approve',
    await composition.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: keys.approve,
      reason: standSeedPlace.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_place_approve_refused:${JSON.stringify(approved.receipt)}`);
  checkpoint('approve');

  const published = expectSucceeded<{ publishedRevisionId: string }>(
    'publish',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: keys.publish,
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
  );
  checkpoint('publish');

  const manifest: StandContentPlaceManifest = {
    pageId,
    contentId: draft.contentId,
    draftId: draft.draftId,
    createdByUserId: draft.createdByUserId,
    submissionId: submission.submissionId,
    publishedRevisionId: published.publishedRevisionId,
    coverAssetId,
    galleryAssetIds,
    approveDecisionId: approved.decision.decisionId,
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentPlace: manifest });
  return { reused: false, manifest };
}

async function requiredPlace(firestore: Firestore): Promise<StandContentPlaceManifest> {
  const place = (await readStandManifest(firestore))?.contentPlace;
  if (place === undefined) throw new Error('stand Place is not seeded');
  return place;
}

/** Pointer and draft state of the stand Place, as the owner services stored them. */
export async function standPlaceStatus(firestore: Firestore) {
  const place = await requiredPlace(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(place.contentId).get()
  ).data();
  return { manifest: place, pointer: pointer ?? null };
}

/**
 * §7 `place verify`: the pointer shows the seeded revision; the revision's
 * media are exactly the ready assets; Catalog excludes the Place as a disabled
 * type; the Booking handoff ignored every Place effect (no outbox record).
 * Catalog and handoff are delivered once more first (both idempotent next to
 * the E2 trigger), so the check does not depend on trigger timing.
 */
export async function verifyStandPlace(firestore: Firestore): Promise<readonly string[]> {
  const place = await requiredPlace(firestore);
  const problems: string[] = [];
  const doc = async (collection: string, id: string) =>
    (await firestore.collection(collection).doc(id).get()).data() as
      Record<string, unknown> | undefined;
  const pointer = await doc(contentCollections.pointers, place.contentId);
  if (pointer?.currentPublishedRevisionId !== place.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Place is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(place.publishedRevisionId),
  );
  if (revision?.typeId !== 'place') problems.push('published revision is not a Place');
  const media = revision?.body.media as
    { coverImage?: { mediaId?: string }; gallery?: { mediaId?: string }[] } | undefined;
  const bodyIds = [
    media?.coverImage?.mediaId,
    ...(media?.gallery ?? []).map((item) => item.mediaId),
  ];
  const seededIds = [place.coverAssetId, ...place.galleryAssetIds];
  if (JSON.stringify(bodyIds) !== JSON.stringify(seededIds))
    problems.push(
      `revision media ${JSON.stringify(bodyIds)} differ from ${JSON.stringify(seededIds)}`,
    );
  const assets = mediaFor(firestore);
  for (const assetId of seededIds) {
    const asset = await assets.repository.transact((tx) => tx.asset(assetId));
    if (asset?.lifecycle !== 'ready')
      problems.push(`asset ${assetId} is ${asset?.lifecycle ?? 'absent'}`);
  }

  const catalog = createEmulatorCatalogComposition(firestore);
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const versions = await firestore
    .collection(catalogCollections.versions)
    .where('contentId', '==', place.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Place');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', place.contentId)
    .get();
  if (effects.empty) problems.push('the Place produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(place.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Place');
  return problems;
}
