import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import type { ContentTypeId } from '../../src/contracts/content_v1.js';
import { standClassWorkshopBody } from '../stand/stand_content_class_workshop.js';
import { standSeedSession } from '../stand/stand_content_session.js';
import { createSessionWorld, expectData } from './content_session_world.js';

export { expectData };

/**
 * D3.6 Emulator world. It reuses the D3.5 world for actors, Media, C2
 * moderation and the UUID-scoped fixture cleanup (only owned documents, shared
 * checkpoints retained) and adds Class drafts. Classes go through Content,
 * Media and C2 moderation only; nothing is written to Content storage directly.
 */
export function createClassWorkshopWorld(
  firestore: Firestore,
  label: string,
  options: { readonly enabledTypes?: ReadonlySet<ContentTypeId> } = {},
) {
  const world = createSessionWorld(firestore, label, {
    enabledTypes: options.enabledTypes ?? new Set(['class_workshop'] as const),
  });

  /** The draft starts empty; the server records its author. */
  async function emptyDraft() {
    const { creator } = await world.actors;
    return expectData<{
      draftId: string;
      contentId: string;
      revision: number;
      createdByUserId: string;
    }>(
      await world.execute({
        commandType: 'createDraft',
        payload: {
          typeId: 'class_workshop',
          publisherRef: { type: 'user', id: creator.actor.userId },
          marketId: 'LV',
          body: {},
        },
      }),
      'createDraft',
    );
  }

  /** Draft with a ready cover and two gallery photos, bound to a CW-V1 series. */
  async function boundClass(
    change: (body: Record<string, unknown>) => Record<string, unknown> = (b) => b,
  ) {
    const draft = await emptyDraft();
    const cover = await world.upload(draft.contentId, standSeedSession.images.cover);
    const gallery: string[] = [];
    for (const bytes of standSeedSession.images.gallery)
      gallery.push(await world.upload(draft.contentId, bytes));
    const body = change(
      standClassWorkshopBody({
        coverMediaId: cover,
        galleryMediaIds: gallery,
        occurrenceIds: [randomUUID(), randomUUID()],
        moduleIds: [randomUUID(), randomUUID()],
      }),
    );
    const bound = expectData<{ revision: number }>(
      await world.update(draft.draftId, draft.revision, body),
      'bind',
    );
    return { ...draft, revision: bound.revision, cover, gallery, body };
  }

  /** The whole owner path: bound draft, submit, staff approval, owner publish. */
  async function publishedClass(
    change?: (body: Record<string, unknown>) => Record<string, unknown>,
  ) {
    const value = await boundClass(change);
    const submission = expectData<{ submissionId: string }>(
      await world.submit(value.draftId, value.revision),
      'submit',
    );
    expectData(
      await world.decide('approve', {
        contentId: value.contentId,
        submissionId: submission.submissionId,
      }),
      'approve',
    );
    const published = expectData<{ publishedRevisionId: string }>(
      await world.publishApproved(submission.submissionId, 0),
      'publish',
    );
    return { ...value, submissionId: submission.submissionId, ...published };
  }

  return { ...world, emptyDraft, boundClass, publishedClass };
}
