import { randomUUID } from 'node:crypto';
import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { EmulatorStaffAuthority } from '../../src/modules/moderation/infrastructure/emulator_staff_authority.js';
import type { ModerationAction } from '../../src/modules/moderation/domain/moderation.js';
import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { createStandContentService, standEventBody } from './stand_content.js';
import { actorFor, mediaFor, pageIdOf } from './stand_media.js';
import { standLinkedUserId } from './stand_session_fixture.js';

const coverPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

/** Content (with the C2 operator-review port) plus the moderation service, on the stand. */
export function createStandModeration(firestore: Firestore) {
  const media = mediaFor(firestore);
  const { composition } = createStandContentService(firestore, media);
  return {
    media,
    ports: { repository: composition.moderation.repository },
    contentService: composition.content,
    contentRepository: composition.contentRepository,
    moderation: composition.moderation,
  };
}

/** Bootstrap only: grants the moderation scope to the seeded staff Account. */
export async function grantStandStaff(firestore: Firestore, nowUtc: string): Promise<void> {
  const userId = await standLinkedUserId(firestore, 'staff');
  await new EmulatorStaffAuthority(
    firestore,
    new FirestoreIdentityAuthorityRepository(firestore),
  ).grant(userId, nowUtc);
}

const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function expectSucceeded<T>(label: string, result: { kind: string; data?: T; code?: string }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`${label} refused: ${JSON.stringify(result)}`);
  return result.data;
}

/**
 * Owner path to a submission waiting for review: draft, a real Media upload with
 * the existing fake scanner/processor, cover binding and submit. Nothing is
 * written around the owner services.
 */
export async function submitStandEventForReview(
  firestore: Firestore,
  userLabel: string,
  pageLabel: string,
) {
  return submitEventForReview(
    createStandModeration(firestore),
    await actorFor(firestore, userLabel),
    { type: 'page', id: pageIdOf(pageLabel) },
  );
}

/** The same owner path for any actor and Publisher (also used by the backend flow test). */
export async function submitEventForReview(
  stand: ReturnType<typeof createStandModeration>,
  actor: ContentActor,
  publisherRef: { readonly type: 'page'; readonly id: string },
) {
  const draft = expectSucceeded<{ draftId: string; contentId: string; revision: number }>(
    'createDraft',
    (await stand.contentService.execute(actor, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: `stand-c2-draft-${randomUUID()}`,
      payload: {
        typeId: 'event',
        publisherRef,
        marketId: 'LV',
        body: standEventBody(randomUUID()),
      },
    })) as never,
  );
  const intent = randomUUID();
  const session = expectSucceeded<{ uploadSessionId: string; assetId: string }>(
    'createUploadSession',
    (await stand.media.service.execute(actor, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: `${intent}:session`,
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: coverPng.length,
        publisherRef,
        entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
      },
    })) as never,
  );
  const asset = await stand.media.repository.transact((tx) => tx.asset(session.assetId));
  if (asset === null) throw new Error('asset missing after createUploadSession');
  await stand.media.objectStore.put(asset.objectKeyHandle, coverPng);
  const uploaded = expectSucceeded<{
    revision: number;
    sourceGenerationRef: { providerGeneration: string };
  }>(
    'confirmUpload',
    (await stand.media.service.execute(actor, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `${intent}:confirm`,
      payload: {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha256(coverPng),
        expectedByteLength: coverPng.length,
      },
    })) as never,
  );
  expectSucceeded(
    'finalizeAsset',
    (await stand.media.service.execute(actor, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: `${intent}:finalize`,
      payload: {
        assetId: session.assetId,
        expectedAssetRevision: uploaded.revision,
        sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(coverPng),
        expectedByteLength: coverPng.length,
      },
    })) as never,
  );
  const updated = expectSucceeded<{ revision: number }>(
    'updateDraft',
    (await stand.contentService.execute(actor, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: `stand-c2-update-${randomUUID()}`,
      payload: {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: standEventBody(session.assetId),
      },
    })) as never,
  );
  const submission = expectSucceeded<{ submissionId: string; state: string }>(
    'submitForPublication',
    (await stand.contentService.execute(actor, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: `stand-c2-submit-${randomUUID()}`,
      payload: { draftId: draft.draftId, expectedDraftRevision: updated.revision },
    })) as never,
  );
  return Object.freeze({
    contentId: draft.contentId,
    draftId: draft.draftId,
    submissionId: submission.submissionId,
    state: submission.state,
    assetId: session.assetId,
  });
}

/** Owner publishes an approved submission (the owner's own Content command). */
export async function publishStandSubmission(
  firestore: Firestore,
  userLabel: string,
  submissionId: string,
) {
  const stand = createStandModeration(firestore);
  const actor = await actorFor(firestore, userLabel);
  const submission = await stand.contentRepository.transact((tx) => tx.submission(submissionId));
  if (submission === null) throw new Error('submission not found');
  const pointer = await stand.contentRepository.transact((tx) => tx.pointer(submission.contentId));
  const result = await stand.contentService.execute(actor, {
    schemaVersion: 1,
    commandType: 'publishApprovedRevision',
    idempotencyKey: `stand-c2-publish-${randomUUID()}`,
    payload: { submissionId, expectedPointerRevision: pointer?.revision ?? 0 },
  });
  if (result.kind !== 'succeeded') return Object.freeze({ published: false, code: result.code });
  return Object.freeze({
    published: true,
    contentId: submission.contentId,
    publishedRevisionId: (result.data as { publishedRevisionId: string }).publishedRevisionId,
  });
}

/** The owner's own withdrawal, a separate action from moderation `withdraw`. */
export async function ownerWithdrawStandContent(
  firestore: Firestore,
  userLabel: string,
  contentId: string,
) {
  const stand = createStandModeration(firestore);
  const actor = await actorFor(firestore, userLabel);
  const pointer = await stand.contentRepository.transact((tx) => tx.pointer(contentId));
  const result = await stand.contentService.execute(actor, {
    schemaVersion: 1,
    commandType: 'withdrawPublication',
    idempotencyKey: `stand-c2-owner-withdraw-${randomUUID()}`,
    payload: { contentId, expectedPointerRevision: pointer?.revision ?? 0, mode: 'withdraw' },
  });
  return Object.freeze(
    result.kind === 'succeeded' ? { withdrawn: true } : { withdrawn: false, code: result.code },
  );
}

/** Read-only state of one Content item: pointer holds and submission states. */
export async function standContentStatus(firestore: Firestore, contentId: string) {
  const { contentRepository } = createStandModeration(firestore);
  const pointer = await contentRepository.transact((tx) => tx.pointer(contentId));
  const submissions = await contentRepository.transact((tx) => tx.submissionsForContent(contentId));
  return Object.freeze({
    pointer:
      pointer === null
        ? null
        : {
            revision: pointer.revision,
            visibility: pointer.visibility,
            currentPublishedRevisionId: pointer.currentPublishedRevisionId,
            ownerHold: pointer.ownerHold,
            moderationHold: pointer.moderationHold,
          },
    submissions: submissions.map((item) => ({
      submissionId: item.submissionId,
      state: item.state,
    })),
  });
}

export interface ModerateRequest {
  readonly as: string;
  readonly command: string;
  readonly args: readonly string[];
  readonly reason?: string;
  readonly key?: string;
  readonly decision?: string;
}

const actionByCommand: Readonly<Record<string, ModerationAction>> = {
  approve: 'approve',
  reject: 'reject',
  restrict: 'restrict',
  withdraw: 'withdraw',
  restore: 'restore',
};

/** The staff script: it holds no authority, the moderation service decides on every call. */
export async function runModerate(firestore: Firestore, request: ModerateRequest) {
  const stand = createStandModeration(firestore);
  const actor = await actorFor(firestore, request.as);
  if (request.command === 'queue') return stand.moderation.service.queue(actor);
  if (request.command === 'receipt') {
    const [decisionId] = request.args;
    if (decisionId === undefined) throw new Error('receipt <decisionId>');
    return stand.moderation.service.receipt(actor, decisionId);
  }
  const action = actionByCommand[request.command];
  const [subject] = request.args;
  if (action === undefined || subject === undefined) {
    throw new Error(
      'usage: approve|reject <submissionId> | restrict|withdraw <contentId> | restore <contentId> --decision <decisionId>',
    );
  }
  const review = action === 'approve' || action === 'reject';
  let contentId = subject;
  if (review) {
    const submission = await stand.contentRepository.transact((tx) => tx.submission(subject));
    if (submission === null) throw new Error('submission not found');
    contentId = submission.contentId;
  }
  return stand.moderation.service.decide(actor, {
    schemaVersion: 1,
    action,
    idempotencyKey: request.key ?? `op-${randomUUID()}`,
    reason: request.reason ?? '',
    target: review ? { contentId, submissionId: subject } : { contentId },
    ...(action === 'restore' ? { restoresDecisionId: request.decision } : {}),
  });
}
