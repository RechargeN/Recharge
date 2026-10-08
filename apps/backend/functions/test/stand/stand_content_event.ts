import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { createStandContentService, standEventBody } from './stand_content.js';
import { actorFor, mediaFor, pageIdOf } from './stand_media.js';

/**
 * Stand manifest: the links between the seeded objects and the ids the owner
 * services returned. It is stand metadata written only by the stand tooling
 * (like the flag bootstrap), never domain state; tests read the ids from here.
 */
export const standManifestCollection = 'standManifest';
const standManifestDocument = 'seed';

export interface StandContentEventManifest {
  readonly pageId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly assetId: string;
  readonly uploadSessionId: string;
  readonly approveDecisionId: string;
  readonly completedAtUtc: string;
}

export interface StandManifest {
  readonly schemaVersion: 1;
  readonly base?: { readonly completedAtUtc: string };
  readonly contentEvent?: StandContentEventManifest;
}

export async function readStandManifest(firestore: Firestore): Promise<StandManifest | null> {
  const snapshot = await firestore
    .collection(standManifestCollection)
    .doc(standManifestDocument)
    .get();
  return snapshot.exists ? (snapshot.data() as StandManifest) : null;
}

export async function writeStandManifest(
  firestore: Firestore,
  patch: Partial<Omit<StandManifest, 'schemaVersion'>>,
): Promise<void> {
  await firestore
    .collection(standManifestCollection)
    .doc(standManifestDocument)
    .set(
      { schemaVersion: 1, ...(JSON.parse(JSON.stringify(patch)) as Record<string, unknown>) },
      { merge: true },
    );
}

/**
 * Fixed inputs of the seeded Event. Every owner command is sent with the same
 * payload and idempotency key on every run, so a repeated or interrupted seed
 * replays the stored results instead of creating a second draft, asset,
 * decision or revision.
 */
export const standSeedEvent = Object.freeze({
  pageLabel: 'studio',
  slotId: 'f4b5c6d7-0000-4000-8000-00000000e001',
  placeholderCoverId: 'f4b5c6d7-0000-4000-8000-00000000e000',
  approveReason: 'stand seed: the seeded Event is approved for publication',
  keys: Object.freeze({
    draft: 'stand-seed-event-draft',
    cover: 'stand-seed-event-cover',
    bind: 'stand-seed-event-bind-cover',
    submit: 'stand-seed-event-submit',
    approve: 'stand-seed-event-approve',
    publish: 'stand-seed-event-publish',
  }),
});

export const standSeedEventSteps = [
  'draft',
  'cover',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedEventStep = (typeof standSeedEventSteps)[number];

/** Test hook: a seed that stops on purpose after a step, to prove the resume. */
export class StandSeedInterrupted extends Error {}

const coverPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_event_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** Media lifecycles before the bytes were confirmed: only then are bytes written. */
const beforeConfirm = new Set(['reserved', 'uploading']);

/**
 * The stand's Event, created through the Content path only: Creator draft, a
 * real Media upload (existing fake scanner/processor), cover binding, submit,
 * a staff approval through the C2 moderation service, and the owner's publish.
 * The Booking test Event stays a separate synthetic Event-outbox fixture.
 */
export async function seedContentEvent(
  firestore: Firestore,
  options: {
    /** Brings back a live Session for a stand user when none is active. */
    readonly recover: (label: 'creator' | 'staff') => Promise<void>;
    readonly interruptAfter?: string | undefined;
  },
): Promise<StandContentEventManifest> {
  const live = async (label: 'creator' | 'staff'): Promise<ContentActor> => {
    try {
      return await actorFor(firestore, label);
    } catch {
      await options.recover(label);
      return actorFor(firestore, label);
    }
  };
  const checkpoint = (step: StandSeedEventStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand seed interrupted after ${step} (test hook)`);
  };
  const media = mediaFor(firestore);
  const { composition } = createStandContentService(firestore, media);
  const creator = await live('creator');
  const pageId = pageIdOf(standSeedEvent.pageLabel);
  const publisherRef = { type: 'page', id: pageId } as const;
  const { keys } = standSeedEvent;

  const draft = expectSucceeded<{ draftId: string; contentId: string; revision: number }>(
    'draft',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: keys.draft,
      payload: {
        typeId: 'event',
        publisherRef,
        marketId: 'LV',
        body: standEventBody(standSeedEvent.placeholderCoverId, standSeedEvent.slotId),
      },
    }),
  );
  checkpoint('draft');

  const session = expectSucceeded<{ uploadSessionId: string; assetId: string }>(
    'upload_session',
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: `${keys.cover}:session`,
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: coverPng.length,
        publisherRef,
        entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
      },
    }),
  );
  const asset = await media.repository.transact((tx) => tx.asset(session.assetId));
  if (asset === null) throw new Error('stand_seed_event_asset_missing');
  // Bytes are written only before confirmation; a resumed seed never replaces
  // the object whose generation Media already pinned.
  if (beforeConfirm.has(asset.lifecycle))
    await media.objectStore.put(asset.objectKeyHandle, coverPng);
  const uploaded = expectSucceeded<{
    revision: number;
    sourceGenerationRef: { providerGeneration: string };
  }>(
    'confirm',
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: `${keys.cover}:confirm`,
      payload: {
        uploadSessionId: session.uploadSessionId,
        expectedSha256: sha256(coverPng),
        expectedByteLength: coverPng.length,
      },
    }),
  );
  expectSucceeded(
    'finalize',
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: `${keys.cover}:finalize`,
      payload: {
        assetId: session.assetId,
        expectedAssetRevision: uploaded.revision,
        sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(coverPng),
        expectedByteLength: coverPng.length,
      },
    }),
  );
  checkpoint('cover');

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
        body: standEventBody(session.assetId, standSeedEvent.slotId),
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

  const staff = await live('staff');
  const approved = expectSucceeded<{
    decision: { decisionId: string };
    receipt: { outcome: string };
  }>(
    'approve',
    await composition.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: keys.approve,
      reason: standSeedEvent.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_event_approve_refused:${JSON.stringify(approved.receipt)}`);
  checkpoint('approve');

  const creatorAgain = await live('creator');
  const published = expectSucceeded<{ publishedRevisionId: string }>(
    'publish',
    await composition.content.execute(creatorAgain, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: keys.publish,
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
  );
  checkpoint('publish');

  const manifest: StandContentEventManifest = {
    pageId,
    contentId: draft.contentId,
    draftId: draft.draftId,
    submissionId: submission.submissionId,
    publishedRevisionId: published.publishedRevisionId,
    assetId: session.assetId,
    uploadSessionId: session.uploadSessionId,
    approveDecisionId: approved.decision.decisionId,
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentEvent: manifest });
  return manifest;
}
