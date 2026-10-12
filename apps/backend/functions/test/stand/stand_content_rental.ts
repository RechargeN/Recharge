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
 * D3.3 stand Rental / Equipment (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §6): one
 * fixed Rental published through Content only: an empty draft, a cover and two
 * gallery photos through Media, the full body (confirmed and attested by the
 * publishing user), submit, a staff approval through C2 and the owner's
 * publish. The Rental authoring flag is enabled here and nowhere else on the
 * stand. Every command repeats the same key and payload within a run.
 */
export interface StandContentRentalManifest {
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

export const standSeedRental = Object.freeze({
  pageLabel: 'studio',
  approveReason: 'stand seed: the seeded Rental is approved for publication',
  // Stable permanent ids of the inventory group and the occupancy block.
  groupId: 'b3d3a3c1-0000-4000-8000-00000000d331',
  blockId: 'b3d3a3c1-0000-4000-8000-00000000d332',
  // The same tiny PNGs as the stand Place; Media binds them to another content.
  images: standSeedPlace.images,
  keys: Object.freeze({
    draft: 'stand-seed-rental-draft',
    cover: 'stand-seed-rental-cover',
    gallery: 'stand-seed-rental-gallery',
    bind: 'stand-seed-rental-bind',
    submit: 'stand-seed-rental-submit',
    approve: 'stand-seed-rental-approve',
    publish: 'stand-seed-rental-publish',
  }),
});

export const standSeedRentalSteps = [
  'draft',
  'cover',
  'gallery-1',
  'gallery-2',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedRentalStep = (typeof standSeedRentalSteps)[number];

/**
 * The stand Rental's anchor time: the start of the current UTC day. A replay
 * within one gate run sends the identical payload; the coverage and the
 * attestation stay fresh for the test policy (D3.3 §6).
 */
export function standRentalAnchorUtc(now: Date = new Date()): string {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  ).toISOString();
}

export const plusDays = (iso: string, days: number): string =>
  new Date(Date.parse(iso) + days * 24 * 60 * 60 * 1000).toISOString();

/**
 * A complete Rental under the Emulator test policy (§2 Q1a/Q1b:
 * `water_activities/kayak` needs a safety notice), confirmed and attested at
 * [anchorUtc] by [actorUserId], the user who submits and publishes (§2 Q3).
 */
export function standRentalBody(input: {
  readonly actorUserId: string;
  readonly mediaRefs: readonly string[];
  readonly anchorUtc: string;
  readonly groupId?: string;
  readonly blockId?: string;
}): Record<string, unknown> {
  const groupId = input.groupId ?? standSeedRental.groupId;
  const anchor = input.anchorUtc;
  return {
    title: 'Kipsala sea kayak rental',
    shortDescription: 'Two-seat sea kayaks with paddles and life vests for day trips',
    fullDescription:
      'Stable two-seat sea kayaks for calm-water trips along the Daugava. Paddles and life vests are included; a short safety briefing is given at handover.',
    categoryId: 'water_activities',
    subcategoryId: 'kayak',
    categoryConfirmed: true,
    mediaRefs: [...input.mediaRefs],
    inventoryGroups: [
      {
        id: groupId,
        label: 'Two-seat sea kayak',
        quantity: 4,
        condition: 'good',
        includedAccessories: ['paddle', 'life vest'],
        status: 'available',
      },
    ],
    availability: {
      timeZoneId: 'Europe/Riga',
      coverage: {
        startsAtUtc: anchor,
        endsAtUtc: plusDays(anchor, 30),
        confirmedAtUtc: anchor,
      },
      blocks: [
        {
          id: input.blockId ?? standSeedRental.blockId,
          groupId,
          startsAtUtc: plusDays(anchor, 2),
          endsAtUtc: plusDays(anchor, 3),
          unitsBlocked: 1,
          source: 'maintenance',
          status: 'active',
          revision: 1,
          createdByUserId: input.actorUserId,
          createdAtUtc: anchor,
          updatedAtUtc: anchor,
        },
      ],
    },
    handover: {
      pickupPlaceName: 'Kipsala boat dock',
      publicAreaLabel: 'Kipsala, Riga',
      publicGeo: { latitude: 56.9535, longitude: 24.079 },
      publicGeoPrecisionMeters: 500,
      disclosure: 'approximate_area',
      scheduleMode: 'by_arrangement',
      deliveryAvailable: false,
    },
    terms: {
      offeredMinMinutes: 60,
      offeredMaxMinutes: 4320,
      idRequiredAtHandover: false,
      safetyNotice: 'Life vests are mandatory on the water; stay within the marked area.',
      includedAccessoriesConfirmation: true,
    },
    pricing: {
      currencyCode: 'EUR',
      billingUnitMinutes: 60,
      rateSteps: [{ minUnits: 1, unitPrice: { minorUnits: 1500, currencyCode: 'EUR' } }],
      billingRounding: 'started_unit',
      deposit: {
        amount: { minorUnits: 5000, currencyCode: 'EUR' },
        collectionMethod: 'at_handover',
        terms: 'Returned after the kayak is inspected at return.',
      },
      damagePolicy: 'Damage beyond normal wear is charged at repair cost.',
      cancellationPolicyId: 'standard',
    },
    fulfillment: { mode: 'external_link', externalBookingUrl: 'https://rent.example.lv/kayak' },
    attestation: {
      policyVersion: '1.0',
      acceptedAtUtc: anchor,
      acceptedByUserId: input.actorUserId,
      hasRightToOffer: true,
      listingAccurate: true,
      prohibitedItemsAcknowledged: true,
    },
  };
}

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_rental_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** The Emulator composition of the Rental callables (Event and Rental enabled). */
function rentalComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['event', 'rental'] as const),
    }),
  };
}

export async function seedContentRental(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentRentalManifest }> {
  const existing = (await readStandManifest(firestore))?.contentRental;
  if (existing !== undefined) return { reused: true, manifest: existing };
  await enableStandFlag(firestore, contentFlagIds.rentalAuthoring, new Date().toISOString());
  const checkpoint = (step: StandSeedRentalStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand rental seed interrupted after ${step} (test hook)`);
  };
  const { media, composition } = rentalComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const pageId = pageIdOf(standSeedRental.pageLabel);
  const { keys, images } = standSeedRental;

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
        typeId: 'rental',
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
    checkpoint(`gallery-${index + 1}` as StandSeedRentalStep);
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
        body: standRentalBody({
          actorUserId: draft.createdByUserId,
          mediaRefs: [coverAssetId, ...galleryAssetIds],
          anchorUtc: standRentalAnchorUtc(),
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
      reason: standSeedRental.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_rental_approve_refused:${JSON.stringify(approved.receipt)}`);
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

  const manifest: StandContentRentalManifest = {
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
  await writeStandManifest(firestore, { contentRental: manifest });
  return { reused: false, manifest };
}

async function requiredRental(firestore: Firestore): Promise<StandContentRentalManifest> {
  const rental = (await readStandManifest(firestore))?.contentRental;
  if (rental === undefined) throw new Error('stand Rental is not seeded');
  return rental;
}

/** Pointer state of the stand Rental, as the owner services stored it. */
export async function standRentalStatus(firestore: Firestore) {
  const rental = await requiredRental(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(rental.contentId).get()
  ).data();
  return { manifest: rental, pointer: pointer ?? null };
}

/**
 * §6 `rental verify`: the pointer shows the seeded revision; the revision's
 * `mediaRefs` are exactly the ready assets (cover first); Catalog excludes the
 * Rental as a disabled type; the Booking handoff ignored every Rental effect. Catalog
 * and handoff are delivered once more first (both idempotent), so the check
 * does not depend on trigger timing.
 */
export async function verifyStandRental(firestore: Firestore): Promise<readonly string[]> {
  const rental = await requiredRental(firestore);
  const problems: string[] = [];
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(rental.contentId).get()
  ).data();
  if (pointer?.currentPublishedRevisionId !== rental.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Rental is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(rental.publishedRevisionId),
  );
  if (revision?.typeId !== 'rental') problems.push('published revision is not a Rental');
  const bodyIds = (revision?.body.mediaRefs as readonly string[] | undefined) ?? [];
  const seededIds = [rental.coverAssetId, ...rental.galleryAssetIds];
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
    .where('contentId', '==', rental.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Rental');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', rental.contentId)
    .get();
  if (effects.empty) problems.push('the Rental produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(rental.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Rental');
  return problems;
}
