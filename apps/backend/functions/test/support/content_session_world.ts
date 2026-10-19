import { providerSubjectKey } from '../../src/modules/identity_publisher/domain/auth_identity.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { eventBookingHandoffCollections } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';
import { eventBookingDeliveryCollections } from '../../src/booking/event_projection_delivery.js';
import { bookingCollections } from '../../src/booking/transactions.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { getAuth } from 'firebase-admin/auth';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import type { ContentTypeId } from '../../src/contracts/content_v1.js';
import type { EmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { mediaComposition } from '../../src/media_entry.js';
import { standSessionBody, standSeedSession } from '../stand/stand_content_session.js';
import { createSignedPublishingActors, uploadReadyImage } from './content_event_world.js';

type Answer = { readonly kind: string; readonly code?: string; readonly data?: unknown };

export function expectData<T>(result: Answer, label: string): T {
  assert.equal(result.kind, 'succeeded', `${label}: ${JSON.stringify(result)}`);
  return result.data as T;
}

/**
 * D3.5 Emulator world: a verified
 * Creator with a verified Page and a staff member, each with a Session and an
 * ID token for the callables; Media as the Functions compose it (with the D2
 * restriction verifier); Content with Event and Session enabled. Sessions go
 * through Content, Media and C2 moderation only; nothing is written to Content
 * storage directly. Every label is unique per run.
 */
export function createSessionWorld(
  firestore: Firestore,
  label: string,
  options: {
    /** A Media composition of the caller's (e.g. with the D1 local tools). */
    readonly media?: EmulatorMediaComposition;
    /** Real images of the caller's (default: the stand Session's 1x1 PNGs). */
    readonly images?: {
      readonly cover: Buffer;
      readonly gallery: readonly Buffer[];
      readonly mediaType: string;
    };
    /** D3.4: the enabled authoring set (default: Event and Session, as in D3.5). */
    readonly enabledTypes?: ReadonlySet<ContentTypeId>;
  } = {},
) {
  const media = options.media ?? mediaComposition(firestore);
  const images = options.images ?? { ...standSeedSession.images, mediaType: 'image/png' };
  const composition = eventAuthoringComposition(firestore, {
    media,
    enabledTypes: options.enabledTypes ?? new Set(['event', 'session'] as const),
  });
  const scope = `${label}-${randomUUID()}`;
  let sequence = 0;
  const key = (name: string) => `${scope}-${name}-${(sequence += 1)}`;

  const actors = createSignedPublishingActors(firestore, scope);

  const execute = async (command: Record<string, unknown>): Promise<Answer> => {
    const { creator } = await actors;
    return await composition.content.execute(creator.actor, {
      schemaVersion: 1,
      idempotencyKey: key(String(command.commandType)),
      ...command,
    });
  };

  /** §5.4: the draft starts empty; the server records its author. */
  async function emptyDraft() {
    const { creator } = await actors;
    return expectData<{
      draftId: string;
      contentId: string;
      revision: number;
      createdByUserId: string;
    }>(
      await execute({
        commandType: 'createDraft',
        payload: {
          typeId: 'session',
          publisherRef: { type: 'user', id: creator.actor.userId },
          marketId: 'LV',
          body: {},
        },
      }),
      'createDraft',
    );
  }

  async function upload(contentId: string, bytes: Buffer): Promise<string> {
    const { creator } = await actors;
    const result = await uploadReadyImage(media, creator.actor, {
      publisherRef: { type: 'user', id: creator.actor.userId },
      contentId,
      bytes,
      mediaType: images.mediaType,
      key,
    });
    return result.assetId;
  }

  const update = (draftId: string, expectedRevision: number, body: unknown) =>
    execute({ commandType: 'updateDraft', payload: { draftId, expectedRevision, body } });
  const submit = (draftId: string, expectedDraftRevision: number) =>
    execute({ commandType: 'submitForPublication', payload: { draftId, expectedDraftRevision } });
  const publishApproved = (submissionId: string, expectedPointerRevision: number) =>
    execute({
      commandType: 'publishApprovedRevision',
      payload: { submissionId, expectedPointerRevision },
    });
  const withdraw = (contentId: string, expectedPointerRevision: number) =>
    execute({
      commandType: 'withdrawPublication',
      payload: { contentId, expectedPointerRevision, mode: 'withdraw' },
    });
  const activate = (
    contentId: string,
    publishedRevisionId: string,
    expectedPointerRevision: number,
  ) =>
    execute({
      commandType: 'activatePublishedRevision',
      payload: { contentId, publishedRevisionId, expectedPointerRevision },
    });

  /** A staff decision through the C2 moderation service. */
  async function decide(
    action: string,
    target: Record<string, string>,
    extra: Record<string, unknown> = {},
  ) {
    const { staff } = await actors;
    return (await composition.moderation.service.decide(staff.actor, {
      schemaVersion: 1,
      action,
      idempotencyKey: key(action),
      reason: `${label} staff decision`,
      target,
      ...extra,
    })) as Answer;
  }

  async function pointer(contentId: string) {
    const current = await composition.contentRepository.transact((tx) => tx.pointer(contentId));
    assert.ok(current, `pointer of ${contentId}`);
    return current;
  }

  /** Draft with a ready cover and two gallery photos, bound with the server's author. */
  async function boundSession(
    change: (body: Record<string, unknown>) => Record<string, unknown> = (b) => b,
  ) {
    const draft = await emptyDraft();
    const cover = await upload(draft.contentId, images.cover);
    const gallery = [];
    for (const bytes of images.gallery) gallery.push(await upload(draft.contentId, bytes));
    const body = change(
      standSessionBody({
        submittedByUserId: draft.createdByUserId,
        coverMediaId: cover,
        galleryMediaIds: gallery,
        periodId: randomUUID(),
      }),
    );
    const bound = expectData<{ revision: number }>(
      await update(draft.draftId, draft.revision, body),
      'bind',
    );
    return { ...draft, revision: bound.revision, cover, gallery, body };
  }

  /** The whole owner path: bound draft, submit, staff approval, owner publish. */
  async function publishedSession() {
    const session = await boundSession();
    const submission = expectData<{ submissionId: string }>(
      await submit(session.draftId, session.revision),
      'submit',
    );
    expectData(
      await decide('approve', {
        contentId: session.contentId,
        submissionId: submission.submissionId,
      }),
      'approve',
    );
    const published = expectData<{ publishedRevisionId: string }>(
      await publishApproved(submission.submissionId, 0),
      'publish',
    );
    return { ...session, submissionId: submission.submissionId, ...published };
  }

  /** Only this world's UUID-bound fixtures, never a global Emulator reset. */
  async function cleanup() {
    assert.equal(process.env.GCLOUD_PROJECT, 'demo-recharge');
    assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
    const sharedCollections = new Set<string>([
      catalogCollections.sets,
      catalogCollections.active,
      catalogCollections.reports,
      contentCollections.mediaAvailabilityStatus,
      eventBookingHandoffCollections.status,
      eventBookingDeliveryCollections.discoveryCheckpoints,
      bookingCollections.reconfirmationDeadlineCheckpoints,
      notificationCollections.checkpoints,
    ]);
    const sharedBefore = [];
    for (const name of sharedCollections)
      for (const doc of (await firestore.collection(name).get()).docs) sharedBefore.push(doc.ref);
    const identity = await actors;
    const owned = new Set(
      [
        identity.creator.actor.userId,
        identity.staff.actor.userId,
        identity.pageId,
        identity.creator.firebaseUid,
        identity.staff.firebaseUid,
      ].map(String),
    );
    // The shared actor factory also creates a reviewer account, without an
    // Auth login. Resolve that exact synthetic proof through the Identity owner
    // rather than treating any reviewer mentioned by a record as ours.
    const reviewerKey = providerSubjectKey({
      provider: 'google',
      providerTenant: 'demo-recharge-emulator',
      providerSubject: `${scope}-reviewer`,
      verifiedAtUtc: new Date().toISOString(),
    });
    const reviewer = await new FirestoreIdentityAuthorityRepository(firestore).transact((tx) =>
      tx.identityBySubjectHash(reviewerKey),
    );
    owned.add(scope);
    owned.add(reviewerKey);
    if (reviewer !== null) owned.add(reviewer.userId);
    const keys = new Set<string>();
    const variants = new Set<string>();
    const includesOwned = (value: unknown, seen = new WeakSet<object>()): boolean => {
      if (typeof value === 'string') return [...owned].some((id) => value.includes(id));
      if (value === null || typeof value !== 'object' || seen.has(value)) return false;
      seen.add(value);
      return Object.values(value).some((child) => includesOwned(child, seen));
    };
    for (const actor of [identity.creator, identity.staff]) {
      try {
        await getAuth().deleteUser(actor.firebaseUid);
      } catch (error) {
        if ((error as { code?: string }).code !== 'auth/user-not-found') throw error;
      }
    }
    let quiet = 0;
    let removed = 0;
    for (let pass = 0; pass < 10 && quiet < 2; pass++) {
      let count = 0;
      for (const collection of await firestore.listCollections()) {
        // Shared delivery cursors/reports can mention our last effect. They are
        // not owned fixture aggregates and must never be deleted or expanded.
        if (sharedCollections.has(collection.id)) continue;
        for (const document of (await collection.get()).docs) {
          // All fixture identities/records use UUID/ULID/hash ids. A fixed
          // short document may be shared even when it mentions our last effect.
          if (document.id.length < 24) continue;
          const data = document.data() as Record<string, unknown>;
          if (!includesOwned(data) && !includesOwned(document.id)) continue;
          if (document.id.length >= 24) owned.add(document.id);
          if (collection.id === mediaCollections.assets) {
            if (typeof data.objectKeyHandle === 'string') keys.add(data.objectKeyHandle);
            const values = data.variantRefs;
            if (Array.isArray(values))
              for (const item of values as unknown[])
                if (
                  typeof item === 'object' &&
                  item !== null &&
                  'variantId' in item &&
                  typeof item.variantId === 'string'
                )
                  variants.add(item.variantId);
          }
          await firestore.recursiveDelete(document.ref);
          count++;
        }
      }
      for (const handle of keys) assert.notEqual(await media.objectStore.remove(handle), 'failed');
      for (const variant of variants)
        assert.notEqual(await media.objectStore.removeVariant(variant), 'failed');
      removed += count;
      quiet = count === 0 ? quiet + 1 : 0;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    assert.equal(quiet, 2, 'Session own fixtures did not settle to empty');
    for (const handle of keys) assert.equal((await media.objectStore.stat(handle)).kind, 'absent');
    for (const ref of sharedBefore)
      assert.ok((await ref.get()).exists, `cleanup removed shared ${ref.path}`);
    process.stdout.write(
      `Session fixture cleanup: ${removed} owned documents removed; source objects absent; shared checkpoints retained\n`,
    );
  }

  return {
    cleanup,
    actors,
    media,
    composition,
    key,
    execute,
    emptyDraft,
    upload,
    update,
    submit,
    publishApproved,
    withdraw,
    activate,
    decide,
    pointer,
    boundSession,
    publishedSession,
  };
}
