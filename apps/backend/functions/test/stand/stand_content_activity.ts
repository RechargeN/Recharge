import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
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
import { standSeedPlace, uploadStandImage } from './stand_content_place.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor, pageIdOf } from './stand_media.js';

/**
 * D3.2 stand Recharge Activity (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md §7): one
 * fixed Activity published through Content only — an empty draft, a cover and
 * two gallery photos through Media, the full body, submit, a staff approval
 * through C2 and the owner's publish. The Activity authoring flag is enabled
 * here and nowhere else on the stand, so the other gates keep their state.
 * Every command repeats the same key and payload on every run.
 */
export interface StandContentActivityManifest {
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

export const standSeedActivity = Object.freeze({
  pageLabel: 'studio',
  approveReason: 'stand seed: the seeded Activity is approved for publication',
  // The same tiny PNGs as the stand Place; Media binds them to another content.
  images: standSeedPlace.images,
  keys: Object.freeze({
    draft: 'stand-seed-activity-draft',
    cover: 'stand-seed-activity-cover',
    gallery: 'stand-seed-activity-gallery',
    bind: 'stand-seed-activity-bind',
    submit: 'stand-seed-activity-submit',
    approve: 'stand-seed-activity-approve',
    publish: 'stand-seed-activity-publish',
  }),
});

export const standSeedActivitySteps = [
  'draft',
  'cover',
  'gallery-1',
  'gallery-2',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedActivityStep = (typeof standSeedActivitySteps)[number];

/**
 * A complete Activity under the Emulator Activity taxonomy (§2.3:
 * `outdoor_nature_walking/forest_walk` requires `difficulty`), with its own
 * confirmed pin, access notes and no linked Place (§2.4).
 */
export function standActivityBody(input: {
  readonly coverMediaId: string;
  readonly galleryMediaIds: readonly string[];
}): Record<string, unknown> {
  return {
    title: 'Ķemeri bog boardwalk loop',
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'forest_walk',
    shortDescription: 'Easy boardwalk loop across the bog with a viewing tower',
    criteria: { difficulty: 'easy' },
    media: {
      coverImage: { mediaId: input.coverMediaId },
      gallery: input.galleryMediaIds.map((mediaId) => ({ mediaId })),
    },
    location: {
      latitude: 56.9142,
      longitude: 23.4706,
      pinConfirmed: true,
      addressLine: 'Ķemeri National Park, Jūrmala',
      accessNotes: 'Start at the car park by the visitor trail sign',
    },
    typicalDurationMinutes: { min: 60, max: 120 },
    suggestedGroupSize: { min: 1, max: 6 },
    bestTime: { timeOfDay: 'morning', season: 'any' },
  };
}

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_activity_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** The Emulator composition of the Activity callables (Event and Activity enabled). */
function activityComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['event', 'activity'] as const),
    }),
  };
}

export async function seedContentActivity(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentActivityManifest }> {
  const existing = (await readStandManifest(firestore))?.contentActivity;
  if (existing !== undefined) return { reused: true, manifest: existing };
  await enableStandFlag(firestore, contentFlagIds.activityAuthoring, new Date().toISOString());
  const checkpoint = (step: StandSeedActivityStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand activity seed interrupted after ${step} (test hook)`);
  };
  const { media, composition } = activityComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const pageId = pageIdOf(standSeedActivity.pageLabel);
  const { keys, images } = standSeedActivity;

  // The draft starts empty, so a replay of the same key always matches.
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
        typeId: 'activity',
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
    checkpoint(`gallery-${index + 1}` as StandSeedActivityStep);
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
        body: standActivityBody({ coverMediaId: coverAssetId, galleryMediaIds: galleryAssetIds }),
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
      reason: standSeedActivity.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_activity_approve_refused:${JSON.stringify(approved.receipt)}`);
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

  const manifest: StandContentActivityManifest = {
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
  await writeStandManifest(firestore, { contentActivity: manifest });
  return { reused: false, manifest };
}

async function requiredActivity(firestore: Firestore): Promise<StandContentActivityManifest> {
  const activity = (await readStandManifest(firestore))?.contentActivity;
  if (activity === undefined) throw new Error('stand Activity is not seeded');
  return activity;
}

/** Pointer state of the stand Activity, as the owner services stored it. */
export async function standActivityStatus(firestore: Firestore) {
  const activity = await requiredActivity(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(activity.contentId).get()
  ).data();
  return { manifest: activity, pointer: pointer ?? null };
}

/**
 * §7 `activity verify`: the pointer shows the seeded revision; the revision's
 * media are exactly the ready assets; Catalog excludes the Activity as a
 * disabled type; the Booking handoff ignored every Activity effect. Catalog
 * and handoff are delivered once more first (both idempotent), so the check
 * does not depend on trigger timing.
 */
export async function verifyStandActivity(firestore: Firestore): Promise<readonly string[]> {
  const activity = await requiredActivity(firestore);
  const problems: string[] = [];
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(activity.contentId).get()
  ).data();
  if (pointer?.currentPublishedRevisionId !== activity.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Activity is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(activity.publishedRevisionId),
  );
  if (revision?.typeId !== 'activity') problems.push('published revision is not an Activity');
  const media = revision?.body.media as
    { coverImage?: { mediaId?: string }; gallery?: { mediaId?: string }[] } | undefined;
  const bodyIds = [
    media?.coverImage?.mediaId,
    ...(media?.gallery ?? []).map((item) => item.mediaId),
  ];
  const seededIds = [activity.coverAssetId, ...activity.galleryAssetIds];
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
    .where('contentId', '==', activity.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Activity');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', activity.contentId)
    .get();
  if (effects.empty) problems.push('the Activity produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(activity.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Activity');
  return problems;
}
