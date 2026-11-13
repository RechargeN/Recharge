import { randomUUID } from 'node:crypto';
import { getStorage } from 'firebase-admin/storage';
import type { Firestore } from 'firebase-admin/firestore';

import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { FirestoreModerationRepository } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { MediaRestrictionVerifier } from '../../src/modules/moderation/infrastructure/media_restriction_verifier.js';
import type { EntityId } from '../../src/shared/ids.js';
import { createStandContentService, standEventBody } from './stand_content.js';
import { standPages, standUsers } from './stand_plan.js';
import { standLinkedUserId } from './stand_session_fixture.js';

const emulatorBucket = 'demo-recharge.appspot.com';

export function mediaFor(firestore: Firestore) {
  return createEmulatorMediaComposition({
    firestore,
    bucket: getStorage().bucket(emulatorBucket) as never,
    // D2 §7: the same verifier as the runtime; only recorded staff decisions restrict.
    restrictionAuthority: new MediaRestrictionVerifier(
      new FirestoreModerationRepository(firestore),
    ),
  });
}

/** The latest live Session of a stand user, as the backend resolved it. */
export async function actorFor(firestore: Firestore, label: string): Promise<ContentActor> {
  const userId = await standLinkedUserId(firestore, label);
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const sessions = await repository.transact((tx) => tx.sessionsForUser(userId));
  const live = sessions
    .filter((session) => session.status === 'active')
    .sort((left, right) => (left.issuedAtUtc < right.issuedAtUtc ? 1 : -1))[0];
  if (live === undefined) throw new Error(`no live Session for ${label}`);
  return { userId: userId as EntityId, sessionId: live.sessionId };
}

export function pageIdOf(pageLabel: string): string {
  const page = standPages.find((candidate) => candidate.label === pageLabel);
  if (page === undefined) throw new Error(`unknown stand page: ${pageLabel}`);
  return page.pageId;
}

/** Creates an Event Content draft through the Content owner service. */
export async function createStandContentDraft(
  firestore: Firestore,
  userLabel: string,
  pageLabel: string,
) {
  if (!standUsers.some((user) => user.label === userLabel)) throw new Error('unknown user');
  const { service } = createStandContentService(firestore, mediaFor(firestore));
  const actor = await actorFor(firestore, userLabel);
  const result = await service.execute(actor, {
    schemaVersion: 1,
    commandType: 'createDraft',
    idempotencyKey: `stand-c1-draft-${randomUUID()}`,
    payload: {
      typeId: 'event',
      publisherRef: { type: 'page', id: pageIdOf(pageLabel) },
      marketId: 'LV',
      // The real cover is bound after the upload; this is only a placeholder id.
      body: standEventBody(randomUUID()),
    },
  });
  if (result.kind !== 'succeeded') throw new Error(`draft refused: ${JSON.stringify(result)}`);
  const draft = result.data as { readonly draftId: string; readonly contentId: string };
  return Object.freeze({
    contentId: draft.contentId,
    draftId: draft.draftId,
    pageId: pageIdOf(pageLabel),
  });
}

/**
 * Asks Content whether the exact Media asset is ready for this draft: the cover
 * is bound to the draft body and the draft is submitted, which is where Content
 * calls Media readiness. Nothing is published.
 */
export async function checkContentMediaReadiness(
  firestore: Firestore,
  userLabel: string,
  draftId: string,
  assetId: string,
) {
  const media = mediaFor(firestore);
  const { service, repository } = createStandContentService(firestore, media);
  const actor = await actorFor(firestore, userLabel);
  const draft = await repository.transact((tx) => tx.draft(draftId));
  if (draft === null) throw new Error('draft not found');
  const readiness = await media.readiness.check({
    contentId: draft.contentId,
    typeId: draft.typeId,
    marketId: draft.marketId,
    publisherRef: draft.publisherRef,
    mediaIds: [assetId],
  });
  const updated = await service.execute(actor, {
    schemaVersion: 1,
    commandType: 'updateDraft',
    idempotencyKey: `stand-c1-update-${randomUUID()}`,
    payload: {
      draftId,
      expectedRevision: draft.revision,
      body: standEventBody(assetId),
    },
  });
  if (updated.kind !== 'succeeded') {
    return Object.freeze({ ready: readiness.ready, updated: false, submitted: false });
  }
  const revision = (updated.data as { readonly revision: number }).revision;
  const submitted = await service.execute(actor, {
    schemaVersion: 1,
    commandType: 'submitForPublication',
    idempotencyKey: `stand-c1-submit-${randomUUID()}`,
    payload: { draftId, expectedDraftRevision: revision },
  });
  return Object.freeze({
    ready: readiness.ready,
    ...(readiness.ready
      ? { mediaRevision: readiness.mediaRevision }
      : { reason: readiness.reason }),
    updated: true,
    submitted: submitted.kind === 'succeeded',
    ...(submitted.kind === 'rejected' ? { submitRefusal: submitted.code } : {}),
  });
}
