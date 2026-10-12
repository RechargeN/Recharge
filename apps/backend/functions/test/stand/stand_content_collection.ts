import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import {
  readStandManifest,
  StandSeedInterrupted,
  writeStandManifest,
} from './stand_content_event.js';
import { standPlaceBody, standSeedPlace, uploadStandImage } from './stand_content_place.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor, pageIdOf } from './stand_media.js';

/**
 * D3.4 stand Collection (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §7): three
 * fixed member Places and one Collection that references them by exact id,
 * all published through Content only (empty draft, cover through Media, full
 * body, submit, staff approval, owner publish). The Place and Collection
 * authoring flags are enabled here and nowhere else on the stand. Membership
 * is answered by the Catalog-owned evaluator, so the stand must run with
 * `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true`. Every command repeats the same
 * key and payload on every run.
 */
export interface StandContentCollectionManifest {
  readonly pageId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly coverAssetId: string;
  readonly approveDecisionId: string;
  /** Every id of the member Places, so the stand digest can name them. */
  readonly members: readonly StandCollectionMemberManifest[];
  readonly completedAtUtc: string;
}

export interface StandCollectionMemberManifest {
  readonly title: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly coverAssetId: string;
  readonly approveDecisionId: string;
}

export const standSeedCollection = Object.freeze({
  pageLabel: 'studio',
  approveReason: 'stand seed: the seeded Collection is approved for publication',
  memberTitles: Object.freeze([
    'Kronvalda park pond',
    'Vērmanes garden fountain',
    'Esplanāde chess corner',
  ]),
  memberPeriodIds: Object.freeze([
    'a6f1d3c2-0000-4000-8000-00000000d341',
    'a6f1d3c2-0000-4000-8000-00000000d342',
    'a6f1d3c2-0000-4000-8000-00000000d343',
  ]),
  itemIds: Object.freeze([
    'c0d34a00-0000-4000-8000-00000000d341',
    'c0d34a00-0000-4000-8000-00000000d342',
    'c0d34a00-0000-4000-8000-00000000d343',
  ]),
  sectionId: 'c0d34a00-0000-4000-8000-00000000d3a0',
  keys: Object.freeze({
    member: 'stand-seed-collection-member',
    draft: 'stand-seed-collection-draft',
    cover: 'stand-seed-collection-cover',
    bind: 'stand-seed-collection-bind',
    submit: 'stand-seed-collection-submit',
    approve: 'stand-seed-collection-approve',
    publish: 'stand-seed-collection-publish',
  }),
});

export const standSeedCollectionSteps = [
  'member-1',
  'member-2',
  'member-3',
  'draft',
  'cover',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedCollectionStep = (typeof standSeedCollectionSteps)[number];

export interface StandCollectionItemInput {
  readonly itemId: string;
  readonly objectId: string;
  readonly objectType?: string;
  readonly title: string;
  readonly sectionId?: string;
  readonly order: number;
  readonly curatorNote?: string;
  readonly highlight?: boolean;
}

/**
 * A complete Collection under the canonical taxonomy (`travel_tours` /
 * `hidden_gems_tour` exists in Category System v1.4.3). Items reference
 * published objects by exact id; the composition review belongs to the draft
 * revision the binding update produces (`reviewedRevision`) and acknowledges
 * exactly `acknowledged`.
 */
export function standCollectionBody(input: {
  readonly coverMediaId: string;
  readonly items: readonly StandCollectionItemInput[];
  readonly reviewedRevision: number;
  readonly acknowledged?: readonly string[];
  readonly sections?: readonly {
    readonly id: string;
    readonly title: string;
    readonly order: number;
  }[];
}): Record<string, unknown> {
  return {
    title: 'Quiet corners of central Riga',
    shortDescription: 'Three calm stops a short walk apart',
    categoryId: 'travel_tours',
    subcategoryId: 'hidden_gems_tour',
    media: { coverImage: { mediaId: input.coverMediaId }, gallery: [] },
    areaLabel: 'Riga centre',
    anchor: { latitude: 56.9545, longitude: 24.1155 },
    budgetTier: 'free',
    visibility: 'public',
    sections: (input.sections ?? []).map((section) => ({ ...section })),
    items: input.items.map((item) => ({
      id: item.itemId,
      ref: { objectId: item.objectId, objectType: item.objectType ?? 'place' },
      snapshot: { title: item.title },
      sourceStatus: 'ready',
      order: item.order,
      ...(item.sectionId === undefined ? {} : { sectionId: item.sectionId }),
      ...(item.curatorNote === undefined ? {} : { curatorNote: item.curatorNote }),
      ...(item.highlight === undefined ? {} : { highlight: item.highlight }),
    })),
    compositionReview: {
      draftRevision: input.reviewedRevision,
      reviewedAtUtc: '2026-10-12T08:00:00.000Z',
      acknowledgedUnavailableStableKeys: [...(input.acknowledged ?? [])],
    },
  };
}

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_collection_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** The Emulator composition of the authoring callables with Place and Collection on. */
function collectionComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['event', 'place', 'collection'] as const),
    }),
  };
}

export async function seedContentCollection(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentCollectionManifest }> {
  const existing = (await readStandManifest(firestore))?.contentCollection;
  if (existing !== undefined) return { reused: true, manifest: existing };
  const now = new Date().toISOString();
  await enableStandFlag(firestore, contentFlagIds.placeAuthoring, now);
  await enableStandFlag(firestore, contentFlagIds.collectionAuthoring, now);
  const checkpoint = (step: StandSeedCollectionStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand collection seed interrupted after ${step} (test hook)`);
  };
  const { media, composition } = collectionComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const staff = await actorFor(firestore, 'staff');
  const pageId = pageIdOf(standSeedCollection.pageLabel);
  const { keys } = standSeedCollection;
  const execute = (label: string, command: Record<string, unknown>) =>
    composition.content
      .execute(creator, { schemaVersion: 1, ...command })
      .then((result) => ({ label, result }));

  /** One owner path through Content: empty draft, cover, body, submit, approve, publish. */
  async function publish(
    prefix: string,
    typeId: 'place' | 'collection',
    body: (draft: { readonly createdByUserId: string; readonly cover: string }) => unknown,
    reason: string,
    after?: (step: 'draft' | 'cover' | 'bind' | 'submit' | 'approve' | 'publish') => void,
  ) {
    const created = await execute(`${prefix}_draft`, {
      commandType: 'createDraft',
      idempotencyKey: `${prefix}-draft`,
      payload: { typeId, publisherRef: { type: 'page', id: pageId }, marketId: 'LV', body: {} },
    });
    const draft = expectSucceeded<{
      draftId: string;
      contentId: string;
      createdByUserId: string;
    }>(created.label, created.result);
    after?.('draft');
    const cover = await uploadStandImage(media, creator, {
      key: `${prefix}-cover`,
      bytes: standSeedPlace.images.cover,
      pageId,
      contentId: draft.contentId,
    });
    after?.('cover');
    // Revisions are those this exact sequence produces (1 after create, 2 after the binding).
    const bound = await execute(`${prefix}_bind`, {
      commandType: 'updateDraft',
      idempotencyKey: `${prefix}-bind`,
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: body({ createdByUserId: draft.createdByUserId, cover }),
      },
    });
    expectSucceeded(bound.label, bound.result);
    after?.('bind');
    const submitted = await execute(`${prefix}_submit`, {
      commandType: 'submitForPublication',
      idempotencyKey: `${prefix}-submit`,
      payload: { draftId: draft.draftId, expectedDraftRevision: 2 },
    });
    const submission = expectSucceeded<{ submissionId: string }>(submitted.label, submitted.result);
    after?.('submit');
    const approved = expectSucceeded<{
      decision: { decisionId: string };
      receipt: { outcome: string };
    }>(
      `${prefix}_approve`,
      await composition.moderation.service.decide(staff, {
        schemaVersion: 1,
        action: 'approve',
        idempotencyKey: `${prefix}-approve`,
        reason,
        target: { contentId: draft.contentId, submissionId: submission.submissionId },
      }),
    );
    if (approved.receipt.outcome === 'refused')
      throw new Error(`stand_seed_collection_${prefix}_approve_refused`);
    after?.('approve');
    const published = await execute(`${prefix}_publish`, {
      commandType: 'publishApprovedRevision',
      idempotencyKey: `${prefix}-publish`,
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    });
    const revision = expectSucceeded<{ publishedRevisionId: string }>(
      published.label,
      published.result,
    );
    after?.('publish');
    return {
      ...draft,
      cover,
      submissionId: submission.submissionId,
      publishedRevisionId: revision.publishedRevisionId,
      approveDecisionId: approved.decision.decisionId,
    };
  }

  const members: StandCollectionMemberManifest[] = [];
  for (const [index, title] of standSeedCollection.memberTitles.entries()) {
    const member = await publish(
      `${keys.member}-${index + 1}`,
      'place',
      ({ createdByUserId, cover }) => ({
        ...standPlaceBody({
          submittedByUserId: createdByUserId,
          coverMediaId: cover,
          galleryMediaIds: [],
          periodId: standSeedCollection.memberPeriodIds[index]!,
        }),
        title,
      }),
      `stand seed: Collection member ${index + 1} is approved for publication`,
    );
    members.push({
      title,
      contentId: member.contentId,
      draftId: member.draftId,
      submissionId: member.submissionId,
      publishedRevisionId: member.publishedRevisionId,
      coverAssetId: member.cover,
      approveDecisionId: member.approveDecisionId,
    });
    checkpoint(`member-${index + 1}` as StandSeedCollectionStep);
  }

  const collection = await publish(
    'stand-seed-collection',
    'collection',
    ({ cover }) =>
      standCollectionBody({
        coverMediaId: cover,
        reviewedRevision: 2,
        sections: [{ id: standSeedCollection.sectionId, title: 'Parks', order: 0 }],
        items: members.map((member, index) => ({
          itemId: standSeedCollection.itemIds[index]!,
          objectId: member.contentId,
          title: member.title,
          order: index < 2 ? index : 0,
          ...(index < 2 ? { sectionId: standSeedCollection.sectionId } : {}),
          curatorNote: `Stop ${index + 1}`,
          ...(index === 0 ? { highlight: true } : {}),
        })),
      }),
    standSeedCollection.approveReason,
    (step) => checkpoint(step),
  );

  const manifest: StandContentCollectionManifest = {
    pageId,
    contentId: collection.contentId,
    draftId: collection.draftId,
    submissionId: collection.submissionId,
    publishedRevisionId: collection.publishedRevisionId,
    coverAssetId: collection.cover,
    approveDecisionId: collection.approveDecisionId,
    members,
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentCollection: manifest });
  return { reused: false, manifest };
}

async function requiredCollection(firestore: Firestore): Promise<StandContentCollectionManifest> {
  const collection = (await readStandManifest(firestore))?.contentCollection;
  if (collection === undefined) throw new Error('stand Collection is not seeded');
  return collection;
}

/** Pointer state of the stand Collection, as the owner service stored it. */
export async function standCollectionStatus(firestore: Firestore) {
  const collection = await requiredCollection(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(collection.contentId).get()
  ).data();
  return { manifest: collection, pointer: pointer ?? null };
}

/**
 * §7 `collection verify`: the pointer shows the seeded revision, whose items
 * reference exactly the three member Places; every member is visible; the
 * cover is ready; Catalog excludes the Collection as a disabled type (no
 * Collection model exists there) and the Booking handoff ignored it.
 */
export async function verifyStandCollection(firestore: Firestore): Promise<readonly string[]> {
  const collection = await requiredCollection(firestore);
  const problems: string[] = [];
  const doc = async (name: string, id: string) =>
    (await firestore.collection(name).doc(id).get()).data() as Record<string, unknown> | undefined;
  const pointer = await doc(contentCollections.pointers, collection.contentId);
  if (pointer?.currentPublishedRevisionId !== collection.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Collection is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(collection.publishedRevisionId),
  );
  if (revision?.typeId !== 'collection') problems.push('published revision is not a Collection');
  const refs = ((revision?.body.items ?? []) as { ref?: { objectId?: string } }[]).map(
    (item) => item.ref?.objectId,
  );
  const memberIds = collection.members.map((member) => member.contentId);
  if (JSON.stringify(refs) !== JSON.stringify(memberIds))
    problems.push(`items ${JSON.stringify(refs)} differ from members ${JSON.stringify(memberIds)}`);
  for (const member of collection.members) {
    const memberPointer = await doc(contentCollections.pointers, member.contentId);
    if (memberPointer?.visibility !== 'visible') problems.push(`member ${member.title} is hidden`);
  }
  const asset = await mediaFor(firestore).repository.transact((tx) =>
    tx.asset(collection.coverAssetId),
  );
  if (asset?.lifecycle !== 'ready')
    problems.push(`cover ${collection.coverAssetId} is ${asset?.lifecycle ?? 'absent'}`);

  const catalog = createEmulatorCatalogComposition(firestore);
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const versions = await firestore
    .collection(catalogCollections.versions)
    .where('contentId', '==', collection.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Collection');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', collection.contentId)
    .get();
  if (effects.empty) problems.push('the Collection produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(collection.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Collection');
  return problems;
}
