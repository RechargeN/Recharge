import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import {
  standCollectionBody,
  type StandCollectionItemInput,
} from '../stand/stand_content_collection.js';
import { standSeedPlace } from '../stand/stand_content_place.js';
import { createPlaceWorld, expectData } from './content_place_world.js';

export { expectData };

/**
 * D3.4 Emulator world (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §3): the D3.1
 * Place world with Collection enabled as well, so member Places and the
 * Collection that references them are published by the same verified Creator
 * and Page through Content, Media and C2 moderation. Membership is answered by
 * the Catalog-owned evaluator, which reads `RECHARGE_TEST_COLLECTION_MEMBERSHIP`
 * when the composition is built: callers set it before creating the world.
 */
export function createCollectionWorld(firestore: Firestore, label: string) {
  const world = createPlaceWorld(firestore, label, {
    enabledTypes: new Set(['event', 'place', 'collection'] as const),
  });

  async function emptyCollectionDraft() {
    const { pageId } = await world.actors;
    return expectData<{ draftId: string; contentId: string; revision: number }>(
      await world.execute({
        commandType: 'createDraft',
        payload: {
          typeId: 'collection',
          publisherRef: { type: 'page', id: pageId },
          marketId: 'LV',
          body: {},
        },
      }),
      'createDraft collection',
    );
  }

  /** A Collection draft with a ready cover and the body bound at revision 2. */
  async function boundCollection(
    members: readonly { readonly contentId: string; readonly objectType?: string }[],
    options: { readonly acknowledged?: readonly string[] } = {},
  ) {
    const draft = await emptyCollectionDraft();
    const cover = await world.upload(draft.contentId, standSeedPlace.images.cover);
    const items = members.map((member, index): StandCollectionItemInput => ({
      itemId: randomUUID(),
      objectId: member.contentId,
      ...(member.objectType === undefined ? {} : { objectType: member.objectType }),
      title: `Stop ${index + 1}`,
      order: index,
    }));
    const body = standCollectionBody({
      coverMediaId: cover,
      items,
      reviewedRevision: draft.revision + 1,
      ...(options.acknowledged === undefined ? {} : { acknowledged: options.acknowledged }),
    });
    const bound = expectData<{ revision: number }>(
      await world.update(draft.draftId, draft.revision, body),
      'bind collection',
    );
    return { ...draft, revision: bound.revision, cover, body };
  }

  /** Submit, staff approval and the owner's publish of a bound Collection. */
  async function publishCollection(collection: Awaited<ReturnType<typeof boundCollection>>) {
    const submission = expectData<{ submissionId: string }>(
      await world.submit(collection.draftId, collection.revision),
      'submit collection',
    );
    expectData(
      await world.decide('approve', {
        contentId: collection.contentId,
        submissionId: submission.submissionId,
      }),
      'approve collection',
    );
    const published = expectData<{ publishedRevisionId: string }>(
      await world.publishApproved(submission.submissionId, 0),
      'publish collection',
    );
    return { ...collection, submissionId: submission.submissionId, ...published };
  }

  /** Three freshly published member Places. */
  async function members(count = 3) {
    const places = [];
    for (let index = 0; index < count; index += 1) places.push(await world.publishedPlace());
    return places;
  }

  return { ...world, emptyCollectionDraft, boundCollection, publishCollection, members };
}
