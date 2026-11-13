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
import { standSeedSession, uploadStandImage } from './stand_content_session.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor } from './stand_media.js';

/**
 * D3.6 stand Class / Workshop (D3_6_CLASS_WORKSHOP_PUBLICATION_AMENDMENT.md §6.5):
 * one fixed CW-V1 series published through Content only — an empty draft, a
 * cover and two gallery photos through Media, the full body with the server's
 * author, submit, a staff approval through C2 and the owner's publish. The Class
 * flag is enabled here and nowhere else on the stand. Every command repeats the
 * same key and payload on every run; the declared classes are fixed future dates.
 */
export interface StandContentClassWorkshopManifest {
  readonly publisherUserId: string;
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

export const standSeedClassWorkshop = Object.freeze({
  occurrenceIds: Object.freeze([
    'c1a55000-0000-4000-8000-00000000d361',
    'c1a55000-0000-4000-8000-00000000d362',
  ]),
  moduleIds: Object.freeze([
    'c1a55000-0000-4000-8000-00000000d371',
    'c1a55000-0000-4000-8000-00000000d372',
  ]),
  approveReason: 'stand seed: the seeded Class / Workshop is approved for publication',
  // The same tiny PNGs as the stand Session; Media binds them per content.
  images: standSeedSession.images,
  keys: Object.freeze({
    draft: 'stand-seed-class-workshop-draft',
    cover: 'stand-seed-class-workshop-cover',
    gallery: 'stand-seed-class-workshop-gallery',
    bind: 'stand-seed-class-workshop-bind',
    submit: 'stand-seed-class-workshop-submit',
    approve: 'stand-seed-class-workshop-approve',
    publish: 'stand-seed-class-workshop-publish',
  }),
});

export const standSeedClassWorkshopSteps = [
  'draft',
  'cover',
  'gallery-1',
  'gallery-2',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedClassWorkshopStep = (typeof standSeedClassWorkshopSteps)[number];

/**
 * A complete CW-V1 fixed series (workshops_masterclasses/pottery, two classes
 * on 2027-05-15 and 2027-05-22, 10:00–13:00 Europe/Riga = UTC+3) inside the LV
 * service area, with the server's author of the draft.
 */
export function standClassWorkshopBody(input: {
  readonly coverMediaId: string;
  readonly galleryMediaIds: readonly string[];
  readonly occurrenceIds?: readonly string[];
  readonly moduleIds?: readonly string[];
}): Record<string, unknown> {
  const occurrences = input.occurrenceIds ?? standSeedClassWorkshop.occurrenceIds;
  const modules = input.moduleIds ?? standSeedClassWorkshop.moduleIds;
  return {
    title: 'Riga pottery course',
    shortDescription: 'Two hands-on wheel throwing classes in Riga.',
    fullDescription:
      'A guided two-class pottery course: learn centring and throwing on the wheel, then take home your own cup after firing.',
    contentLocale: 'en',
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    criteria: { skill_level: 'beginner', equipment_provided: 'provided' },
    location: {
      countryCode: 'LV',
      city: 'Riga',
      venueName: 'Clay studio',
      addressLine1: 'Riga studio 1',
      latitude: 56.9496,
      longitude: 24.1052,
      pinConfirmed: true,
    },
    media: {
      coverImage: { mediaId: input.coverMediaId, altText: { en: 'Potter at the wheel' } },
      gallery: input.galleryMediaIds.map((mediaId) => ({
        mediaId,
        altText: { en: 'Pottery course gallery image' },
      })),
      rightsConfirmed: true,
    },
    class_workshop: {
      schema_version: 1,
      offering_kind: 'course',
      context_kind: 'fixed_series',
      delivery_format: 'offline',
      public_location_mode: 'point',
      timezone_id: 'Europe/Riga',
      timezone_confirmed: true,
      dst_policy_version: 1,
      occurrences: [
        {
          id: occurrences[0],
          local_date: '2027-05-15',
          start_minute_local: 600,
          end_minute_local: 780,
          start_at_utc: '2027-05-15T07:00:00.000Z',
          end_at_utc: '2027-05-15T10:00:00.000Z',
        },
        {
          id: occurrences[1],
          local_date: '2027-05-22',
          start_minute_local: 600,
          end_minute_local: 780,
          start_at_utc: '2027-05-22T07:00:00.000Z',
          end_at_utc: '2027-05-22T10:00:00.000Z',
        },
      ],
      instructor: { same_as_publisher: true },
      learning: {
        outcomes: ['Centre clay on the wheel', 'Throw a simple cup'],
        modules: [
          { id: modules[0], title: 'Wedging and centring' },
          { id: modules[1], title: 'Throwing a cup' },
        ],
        prerequisites: { mode: 'none', items: [] },
      },
      included_materials: ['Clay', 'Glazes'],
      requirements: [],
      declared_group_limit: 8,
      price: {
        mode: 'fixed',
        amount_minor: 8000,
        currency_code: 'EUR',
        scope: 'per_person_full_series',
      },
      enrollment: { mode: 'external', external_url: 'https://studio.example.org/pottery' },
    },
  };
}

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_class_workshop_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

function classWorkshopComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['class_workshop'] as const),
    }),
  };
}

export async function seedContentClassWorkshop(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentClassWorkshopManifest }> {
  const existing = (await readStandManifest(firestore))?.contentClassWorkshop;
  if (existing !== undefined) return { reused: true, manifest: existing };
  await enableStandFlag(firestore, contentFlagIds.classWorkshopAuthoring, new Date().toISOString());
  const checkpoint = (step: StandSeedClassWorkshopStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(
        `stand class workshop seed interrupted after ${step} (test hook)`,
      );
  };
  const { media, composition } = classWorkshopComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const publisherUserId = creator.userId;
  const { keys, images } = standSeedClassWorkshop;

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
        typeId: 'class_workshop',
        publisherRef: { type: 'user', id: publisherUserId },
        marketId: 'LV',
        body: {},
      },
    }),
  );
  checkpoint('draft');
  const upload = (key: string, bytes: Buffer) =>
    uploadStandImage(media, creator, { key, bytes, publisherUserId, contentId: draft.contentId });
  const coverAssetId = await upload(keys.cover, images.cover);
  checkpoint('cover');
  const galleryAssetIds: string[] = [];
  for (const [index, bytes] of images.gallery.entries()) {
    galleryAssetIds.push(await upload(`${keys.gallery}-${index + 1}`, bytes));
    checkpoint(`gallery-${index + 1}` as StandSeedClassWorkshopStep);
  }

  expectSucceeded(
    'bind',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: keys.bind,
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: standClassWorkshopBody({
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
      reason: standSeedClassWorkshop.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(
      `stand_seed_class_workshop_approve_refused:${JSON.stringify(approved.receipt)}`,
    );
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

  const manifest: StandContentClassWorkshopManifest = {
    publisherUserId,
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
  await writeStandManifest(firestore, { contentClassWorkshop: manifest });
  return { reused: false, manifest };
}

async function requiredClassWorkshop(
  firestore: Firestore,
): Promise<StandContentClassWorkshopManifest> {
  const value = (await readStandManifest(firestore))?.contentClassWorkshop;
  if (value === undefined) throw new Error('stand Class / Workshop is not seeded');
  return value;
}

/** Pointer of the stand Class, as the owner services stored it. */
export async function standClassWorkshopStatus(firestore: Firestore) {
  const value = await requiredClassWorkshop(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(value.contentId).get()
  ).data();
  return { manifest: value, pointer: pointer ?? null };
}

/**
 * `class-workshop verify`: the pointer shows the seeded revision; its media are
 * exactly the ready assets; Catalog excludes Class as a disabled type; the
 * Booking handoff ignored every Class effect (no outbox record, no state).
 */
export async function verifyStandClassWorkshop(firestore: Firestore): Promise<readonly string[]> {
  const value = await requiredClassWorkshop(firestore);
  const problems: string[] = [];
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(value.contentId).get()
  ).data() as Record<string, unknown> | undefined;
  if (pointer?.currentPublishedRevisionId !== value.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Class is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(value.publishedRevisionId),
  );
  if (revision?.typeId !== 'class_workshop') problems.push('published revision is not a Class');
  const media = revision?.body.media as
    { coverImage?: { mediaId?: string }; gallery?: { mediaId?: string }[] } | undefined;
  const bodyIds = [
    media?.coverImage?.mediaId,
    ...(media?.gallery ?? []).map((item) => item.mediaId),
  ];
  const seededIds = [value.coverAssetId, ...value.galleryAssetIds];
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
    .where('contentId', '==', value.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Class');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', value.contentId)
    .get();
  if (effects.empty) problems.push('the Class produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(value.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Class');
  return problems;
}
