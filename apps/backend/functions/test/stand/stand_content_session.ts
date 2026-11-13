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
import { actorFor, mediaFor } from './stand_media.js';

/**
 * D3.5 stand Session (PLACE_D3_1_PUBLICATION_AMENDMENT.md §7): one fixed Session
 * published through Content only — an empty draft (§5.4), a cover and two
 * gallery photos through Media, the full body with the server's author, submit,
 * a staff approval through C2 and the owner's publish. The Session authoring flag
 * is enabled here and nowhere else on the stand, so the other gates keep their
 * state. Every command repeats the same key and payload on every run.
 */
export interface StandContentSessionManifest {
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

const png = (base64: string) => Buffer.from(base64, 'base64');

export const standSeedSession = Object.freeze({
  creatorLabel: 'studio',
  periodId: 'a6f1d3c2-0000-4000-8000-00000000d305',
  approveReason: 'stand seed: the seeded Session is approved for publication',
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
    draft: 'stand-seed-session-draft',
    cover: 'stand-seed-session-cover',
    gallery: 'stand-seed-session-gallery',
    bind: 'stand-seed-session-bind',
    submit: 'stand-seed-session-submit',
    approve: 'stand-seed-session-approve',
    publish: 'stand-seed-session-publish',
  }),
});

export const standSeedSessionSteps = [
  'draft',
  'cover',
  'gallery-1',
  'gallery-2',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedSessionStep = (typeof standSeedSessionSteps)[number];

/**
 * A complete Session under the pinned Session taxonomy (sport/tennis), inside the LV service
 * area, with the server's author of the draft.
 */
export function standSessionBody(input: {
  readonly submittedByUserId: string;
  readonly coverMediaId: string;
  readonly galleryMediaIds: readonly string[];
  readonly periodId?: string;
}): Record<string, unknown> {
  const body = {
    title: 'Riga tennis court',
    shortDescription: 'A fixed tennis court in central Riga.',
    fullDescription:
      'A single fixed court for a private party. Check the external booking site for current availability and terms.',
    contentLocale: 'en',
    categoryId: 'sport',
    subcategoryId: 'tennis',
    location: {
      countryCode: 'LV',
      city: 'Riga',
      venueName: 'Tennis court',
      addressLine1: 'Riga court 1',
      latitude: 56.9496,
      longitude: 24.1052,
      pinConfirmed: true,
    },
    media: {
      coverImage: {
        mediaId: '33333333-3333-4333-8333-333333333333',
        altText: { en: 'Tennis court overview' },
      },
      gallery: [] as { mediaId: string; altText: { en: string } }[],
      rightsConfirmed: true,
    },
    session: {
      schema_version: 1,
      resource_name: 'Tennis court',
      timezone_id: 'Europe/Riga',
      timezone_confirmed: true,
      amenity_ids: [],
      max_party_size: 4,
      schedule: {
        schedule_revision: 1,
        dst_policy_version: 1,
        slot_duration_minutes: 60,
        buffer_after_slot_minutes: 10,
        min_notice_minutes: 0,
        projection_window_days: 30,
        weekly_rules: [
          {
            id: '22222222-2222-4222-8222-222222222222',
            iso_weekday: 1,
            start_minute_local: 540,
            end_minute_local_exclusive: 780,
          },
        ],
      },
      exceptions: [],
      price: {
        mode: 'free',
      },
      external_booking_url: 'https://booking.example.org/court',
      revision: 1,
    },
  };
  body.media = {
    rightsConfirmed: true,
    coverImage: { mediaId: input.coverMediaId, altText: { en: 'Tennis court overview' } },
    gallery: input.galleryMediaIds.map((mediaId) => ({
      mediaId,
      altText: { en: 'Tennis court gallery image' },
    })),
  };
  body.session.schedule.weekly_rules[0]!.id = input.periodId ?? standSeedSession.periodId;
  return body;
}

const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_session_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** Media lifecycles before the bytes were confirmed: only then are bytes written. */
const beforeConfirm = new Set(['reserved', 'uploading']);

/** The Emulator composition of the Session callables (Event and Session enabled). */
function sessionComposition(firestore: Firestore) {
  const media = mediaFor(firestore);
  return {
    media,
    composition: eventAuthoringComposition(firestore, {
      media,
      enabledTypes: new Set(['session'] as const),
    }),
  };
}

/** One stand photo through C1 Media (also used by the D3.2 stand Activity). */
export async function uploadStandImage(
  media: ReturnType<typeof mediaFor>,
  creator: ContentActor,
  input: {
    readonly key: string;
    readonly bytes: Buffer;
    readonly publisherUserId: string;
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
        publisherRef: { type: 'user', id: input.publisherUserId },
        entityIntent: { domain: 'content', entityId: input.contentId, purpose: 'contentMedia' },
      },
    }),
  );
  const asset = await media.repository.transact((tx) => tx.asset(session.assetId));
  if (asset === null) throw new Error(`stand_seed_session_asset_missing:${input.key}`);
  // Bytes are written only before confirmation; a resumed seed never resessions
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

export async function seedContentSession(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentSessionManifest }> {
  const existing = (await readStandManifest(firestore))?.contentSession;
  if (existing !== undefined) return { reused: true, manifest: existing };
  await enableStandFlag(firestore, contentFlagIds.sessionAuthoring, new Date().toISOString());
  const checkpoint = (step: StandSeedSessionStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand session seed interrupted after ${step} (test hook)`);
  };
  const { media, composition } = sessionComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const publisherUserId = creator.userId;
  const { keys, images } = standSeedSession;

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
        typeId: 'session',
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
    checkpoint(`gallery-${index + 1}` as StandSeedSessionStep);
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
        body: standSessionBody({
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
      reason: standSeedSession.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_session_approve_refused:${JSON.stringify(approved.receipt)}`);
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

  const manifest: StandContentSessionManifest = {
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
  await writeStandManifest(firestore, { contentSession: manifest });
  return { reused: false, manifest };
}

async function requiredSession(firestore: Firestore): Promise<StandContentSessionManifest> {
  const session = (await readStandManifest(firestore))?.contentSession;
  if (session === undefined) throw new Error('stand Session is not seeded');
  return session;
}

/** Pointer and draft state of the stand Session, as the owner services stored them. */
export async function standSessionStatus(firestore: Firestore) {
  const session = await requiredSession(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(session.contentId).get()
  ).data();
  return { manifest: session, pointer: pointer ?? null };
}

/**
 * §7 `session verify`: the pointer shows the seeded revision; the revision's
 * media are exactly the ready assets; Catalog excludes the Session as a disabled
 * type; the Booking handoff ignored every Session effect (no outbox record).
 * Catalog and handoff are delivered once more first (both idempotent next to
 * the E2 trigger), so the check does not depend on trigger timing.
 */
export async function verifyStandSession(firestore: Firestore): Promise<readonly string[]> {
  const session = await requiredSession(firestore);
  const problems: string[] = [];
  const doc = async (collection: string, id: string) =>
    (await firestore.collection(collection).doc(id).get()).data() as
      Record<string, unknown> | undefined;
  const pointer = await doc(contentCollections.pointers, session.contentId);
  if (pointer?.currentPublishedRevisionId !== session.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Session is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(session.publishedRevisionId),
  );
  if (revision?.typeId !== 'session') problems.push('published revision is not a Session');
  const media = revision?.body.media as
    { coverImage?: { mediaId?: string }; gallery?: { mediaId?: string }[] } | undefined;
  const bodyIds = [
    media?.coverImage?.mediaId,
    ...(media?.gallery ?? []).map((item) => item.mediaId),
  ];
  const seededIds = [session.coverAssetId, ...session.galleryAssetIds];
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
    .where('contentId', '==', session.contentId)
    .get();
  if (versions.empty) problems.push('Catalog has no record of the Session');
  for (const version of versions.docs) {
    const data = version.data();
    if (data.state !== 'excluded' || data.reason !== 'type_disabled')
      problems.push(`Catalog version ${version.id} is ${data.state}/${data.reason}`);
  }

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', session.contentId)
    .get();
  if (effects.empty) problems.push('the Session produced no Content effect');
  for (const effect of effects.docs) {
    const effectId = String(effect.data().effectId);
    const receipt = await repository.transact((tx) => tx.receipt(effectId));
    if (receipt === null) problems.push(`no handoff receipt for ${effectId}`);
    else if (receipt.outcome !== 'ignored' || receipt.outboxIds.length !== 0)
      problems.push(`handoff did not ignore ${effectId}: ${receipt.outcome}`);
  }
  if ((await repository.transact((tx) => tx.state(session.contentId))) !== null)
    problems.push('Booking handoff holds a state for the Session');
  return problems;
}
