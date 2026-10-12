// D3.4 §2.2 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md): the operation matrix of
// the Emulator-only `contentCommandV1` / `contentQueryV1` over HTTP through the
// Functions Emulator for Collection, row by row, with the exact refusal code.
// The Collection used for hide and reads is published in-process first (with
// the local membership switch); the flags are restored exactly as they were
// before this file. Over the wire a complete Collection follows the Functions'
// own membership switch: without it the answer is `validation_failed`.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import type { DocumentData } from 'firebase-admin/firestore';

import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import { standCollectionBody } from '../stand/stand_content_collection.js';
import { standSeedPlace } from '../stand/stand_content_place.js';
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { createCollectionWorld, expectData } from '../support/content_collection_world.js';

const switchName = 'RECHARGE_TEST_COLLECTION_MEMBERSHIP';
// The Functions Emulator inherits the environment this file was started with.
const functionsSwitch = process.env[switchName] === 'true';
const previousSwitch = process.env[switchName];
process.env[switchName] = 'true';

const firestore = emulatorFirestore();
const flags = [
  contentFlagIds.eventAuthoring,
  contentFlagIds.placeAuthoring,
  contentFlagIds.activityAuthoring,
  contentFlagIds.collectionAuthoring,
] as const;
const refs = (capabilityId: string) => {
  const key = featureFlagKey('local', 'LV', capabilityId);
  return {
    key,
    revision: firestore
      .collection(featureFlagRevisionCollection)
      .doc(featureFlagRevisionDocumentId(key, 1)),
    pointer: firestore.collection(featureFlagPointerCollection).doc(key),
  };
};
const saved = new Map<
  string,
  { revision: DocumentData | undefined; pointer: DocumentData | undefined }
>();

async function setFlag(capabilityId: string, enabled: boolean): Promise<void> {
  const { key, revision, pointer } = refs(capabilityId);
  await revision.set({
    schemaVersion: 1,
    revision: 1,
    environmentId: 'local',
    marketId: 'LV',
    capabilityId,
    enabled,
    createdAtUtc: '2026-10-12T00:00:00.000Z',
  });
  await pointer.set({ key, activeRevision: 1, pointerRevision: 1 });
}

async function setFlags(
  event: boolean,
  place: boolean,
  activity: boolean,
  collection: boolean,
): Promise<void> {
  await setFlag(contentFlagIds.eventAuthoring, event);
  await setFlag(contentFlagIds.placeAuthoring, place);
  await setFlag(contentFlagIds.activityAuthoring, activity);
  await setFlag(contentFlagIds.collectionAuthoring, collection);
}

before(async () => {
  for (const capabilityId of flags) {
    const { revision, pointer } = refs(capabilityId);
    saved.set(capabilityId, {
      revision: (await revision.get()).data(),
      pointer: (await pointer.get()).data(),
    });
  }
});

after(async () => {
  for (const capabilityId of flags) {
    const { revision, pointer } = refs(capabilityId);
    const before = saved.get(capabilityId);
    if (before?.revision === undefined) await revision.delete();
    else await revision.set(before.revision);
    if (before?.pointer === undefined) await pointer.delete();
    else await pointer.set(before.pointer);
  }
  if (previousSwitch === undefined) delete process.env[switchName];
  else process.env[switchName] = previousSwitch;
});

const world = createCollectionWorld(firestore, 'd34-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d34-call-${(sequence += 1)}-${String(body.commandType)}`,
      ...body,
    },
    creator.idToken,
  );
  return response.body.result as { kind: string; code?: string; data?: unknown };
}

async function query(queryType: string, payload: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentQueryV1',
    { schemaVersion: 1, queryType, payload },
    creator.idToken,
  );
  return response.body.result as { kind: string; code?: string; data?: unknown };
}

const createOf = async (typeId: 'event' | 'place' | 'activity' | 'collection') => {
  const { pageId } = await world.actors;
  return command({
    commandType: 'createDraft',
    payload: { typeId, publisherRef: { type: 'page', id: pageId }, marketId: 'LV', body: {} },
  });
};

/** A published Collection with a second approved submission and its current draft revision. */
let published:
  | {
      contentId: string;
      draftId: string;
      publishedRevisionId: string;
      pendingSubmissionId: string;
      draftRevision: number;
    }
  | undefined;

async function collection() {
  if (published !== undefined) return published;
  const first = await world.publishCollection(await world.boundCollection(await world.members()));
  const revised = expectData<{ revision: number }>(
    await world.update(first.draftId, first.revision, {
      ...first.body,
      title: 'Quiet corners of central Riga, second edition',
      compositionReview: {
        draftRevision: first.revision + 1,
        reviewedAtUtc: '2026-10-12T09:00:00.000Z',
        acknowledgedUnavailableStableKeys: [],
      },
    }),
    'revise',
  );
  const pending = expectData<{ submissionId: string }>(
    await world.submit(first.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: first.contentId,
      submissionId: pending.submissionId,
    }),
    'reapprove',
  );
  published = {
    contentId: first.contentId,
    draftId: first.draftId,
    publishedRevisionId: first.publishedRevisionId,
    pendingSubmissionId: pending.submissionId,
    draftRevision: revised.revision,
  };
  return published;
}

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

void test('row all off: the whole Content surface is closed for Collection', async () => {
  const current = await collection();
  await setFlags(false, false, false, false);
  assert.equal(code(await createOf('collection')), 'rejected:type_disabled');
  assert.equal(
    code(
      await command({
        commandType: 'withdrawPublication',
        payload: { contentId: current.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
      }),
    ),
    'rejected:type_disabled',
  );
  assert.equal(
    code(await query('getPublicationStatus', { contentId: current.contentId })),
    'rejected:type_disabled',
  );
});

void test('row Event, Place and Activity on / Collection off: Collection authoring refused, hide and reads allowed', async () => {
  const current = await collection();
  await setFlags(true, true, true, false);
  assert.equal(code(await createOf('collection')), 'rejected:type_disabled');
  assert.equal(code(await createOf('place')), 'succeeded');
  for (const [label, body] of [
    [
      'update',
      {
        commandType: 'updateDraft',
        payload: { draftId: current.draftId, expectedRevision: current.draftRevision, body: {} },
      },
    ],
    [
      'submit',
      {
        commandType: 'submitForPublication',
        payload: { draftId: current.draftId, expectedDraftRevision: current.draftRevision },
      },
    ],
    [
      'publish',
      {
        commandType: 'publishApprovedRevision',
        payload: { submissionId: current.pendingSubmissionId, expectedPointerRevision: 1 },
      },
    ],
    [
      'activate',
      {
        commandType: 'activatePublishedRevision',
        payload: {
          contentId: current.contentId,
          publishedRevisionId: current.publishedRevisionId,
          expectedPointerRevision: 1,
        },
      },
    ],
  ] as const)
    assert.equal(code(await command(body)), 'rejected:type_disabled', label);
  assert.equal(code(await query('getDraft', { draftId: current.draftId })), 'succeeded');
  assert.equal(
    code(await query('getPublishedRevision', { contentId: current.contentId })),
    'succeeded',
  );
  assert.equal(
    code(
      await command({
        commandType: 'withdrawPublication',
        payload: { contentId: current.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
      }),
    ),
    'succeeded',
  );
  const status = await query('getPublicationStatus', { contentId: current.contentId });
  assert.equal(
    (status.data as { pointer: { visibility: string } }).pointer.visibility,
    'withdrawn',
  );
});

void test('row Collection on only: the other types are refused, Collection allowed', async () => {
  await setFlags(false, false, false, true);
  assert.equal(code(await createOf('event')), 'rejected:type_disabled');
  assert.equal(code(await createOf('place')), 'rejected:type_disabled');
  assert.equal(code(await createOf('activity')), 'rejected:type_disabled');
  assert.equal(code(await createOf('collection')), 'succeeded');
});

void test('row all on: each of the four types may be authored', async () => {
  await setFlags(true, true, true, true);
  for (const typeId of ['event', 'place', 'activity', 'collection'] as const)
    assert.equal(code(await createOf(typeId)), 'succeeded', typeId);
});

void test('over the wire a complete Collection follows the Functions membership switch', async () => {
  await setFlags(false, true, false, true);
  const places = await world.members();
  const draft = expectData<{ draftId: string; contentId: string; revision: number }>(
    await createOf('collection'),
    'create',
  );
  const cover = await world.upload(draft.contentId, standSeedPlace.images.cover);
  const bound = expectData<{ revision: number }>(
    await command({
      commandType: 'updateDraft',
      payload: {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: standCollectionBody({
          coverMediaId: cover,
          reviewedRevision: draft.revision + 1,
          items: places.map((place, index) => ({
            itemId: `c0d34a00-0000-4000-8000-${String(900000000000 + index)}`,
            objectId: place.contentId,
            title: `Stop ${index + 1}`,
            order: index,
          })),
        }),
      },
    }),
    'bind',
  );
  const submitted = await command({
    commandType: 'submitForPublication',
    payload: { draftId: draft.draftId, expectedDraftRevision: bound.revision },
  });
  assert.equal(code(submitted), functionsSwitch ? 'succeeded' : 'rejected:validation_failed');
  // A refusal carries no internal membership code.
  if (!functionsSwitch)
    assert.deepEqual(submitted, { schemaVersion: 1, kind: 'rejected', code: 'validation_failed' });
});
