import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import type { EmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { mediaComposition } from '../../src/media_entry.js';
import {
  standRentalAnchorUtc,
  standRentalBody,
  standSeedRental,
} from '../stand/stand_content_rental.js';
import { createSignedPublishingActors, uploadReadyImage } from './content_event_world.js';
import { expectData } from './content_place_world.js';

export { expectData };

type Answer = { readonly kind: string; readonly code?: string; readonly data?: unknown };

/**
 * D3.3 Emulator world (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §3): a verified
 * Creator with a verified Page and a staff member, each with a Session and an
 * ID token for the callables; Media as the Functions compose it (with the D2
 * restriction verifier); Content with Event and Rental enabled, composed
 * exactly as the callables compose it (the TEST-ONLY Rental policy and the
 * closed Rental activation included). Rentals go through Content, Media and C2
 * moderation only; nothing is written to Content storage directly. The body is
 * confirmed and attested by the Creator at the start of the current UTC day.
 */
export function createRentalWorld(
  firestore: Firestore,
  label: string,
  options: {
    readonly media?: EmulatorMediaComposition;
    readonly images?: {
      readonly cover: Buffer;
      readonly gallery: readonly Buffer[];
      readonly mediaType: string;
    };
  } = {},
) {
  const media = options.media ?? mediaComposition(firestore);
  const images = options.images ?? { ...standSeedRental.images, mediaType: 'image/png' };
  const composition = eventAuthoringComposition(firestore, {
    media,
    enabledTypes: new Set(['event', 'rental'] as const),
  });
  const scope = `${label}-${randomUUID().slice(0, 8)}`;
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

  /** The draft starts empty; the server records its author. */
  async function emptyDraft() {
    const { pageId } = await actors;
    return expectData<{
      draftId: string;
      contentId: string;
      revision: number;
      createdByUserId: string;
    }>(
      await execute({
        commandType: 'createDraft',
        payload: {
          typeId: 'rental',
          publisherRef: { type: 'page', id: pageId },
          marketId: 'LV',
          body: {},
        },
      }),
      'createDraft',
    );
  }

  async function upload(contentId: string, bytes: Buffer): Promise<string> {
    const { creator, pageId } = await actors;
    const result = await uploadReadyImage(media, creator.actor, {
      publisherRef: { type: 'page', id: pageId },
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

  /** Draft with a ready cover and two gallery photos, bound with the full body. */
  async function boundRental(
    change: (body: Record<string, unknown>) => Record<string, unknown> = (b) => b,
  ) {
    const draft = await emptyDraft();
    const cover = await upload(draft.contentId, images.cover);
    const gallery = [];
    for (const bytes of images.gallery) gallery.push(await upload(draft.contentId, bytes));
    const { creator } = await actors;
    const body = change(
      standRentalBody({
        actorUserId: creator.actor.userId,
        mediaRefs: [cover, ...gallery],
        anchorUtc: standRentalAnchorUtc(),
      }),
    );
    const bound = expectData<{ revision: number }>(
      await update(draft.draftId, draft.revision, body),
      'bind',
    );
    return { ...draft, revision: bound.revision, cover, gallery, body };
  }

  /** The whole owner path: bound draft, submit, staff approval, owner publish. */
  async function publishedRental(
    change: (body: Record<string, unknown>) => Record<string, unknown> = (b) => b,
  ) {
    const rental = await boundRental(change);
    const submission = expectData<{ submissionId: string }>(
      await submit(rental.draftId, rental.revision),
      'submit',
    );
    expectData(
      await decide('approve', {
        contentId: rental.contentId,
        submissionId: submission.submissionId,
      }),
      'approve',
    );
    const published = expectData<{ publishedRevisionId: string }>(
      await publishApproved(submission.submissionId, 0),
      'publish',
    );
    return { ...rental, submissionId: submission.submissionId, ...published };
  }

  return {
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
    boundRental,
    publishedRental,
  };
}
