// D3.1 §2.2 (PLACE_D3_1_PUBLICATION_AMENDMENT.md): the operation matrix of the
// Emulator-only `contentCommandV1` / `contentQueryV1` over HTTP through the
// Functions Emulator, row by row, with the exact refusal code. The Place used
// for hide, reads, publish and activate is created through the owner services
// first; the flags are restored exactly as they were before this file. It
// also sends every body of the shared Create compatibility fixture (§5.7) over
// the wire: the answer is `validation_failed` and carries no validator code.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import type { DocumentData } from 'firebase-admin/firestore';

import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { readContentJson } from '../../src/contracts/content_schema_registry.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import { standSeedPlace } from '../stand/stand_content_place.js';
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { createPlaceWorld, expectData } from '../support/content_place_world.js';

const firestore = emulatorFirestore();
const flags = [contentFlagIds.eventAuthoring, contentFlagIds.placeAuthoring] as const;
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
    createdAtUtc: '2026-10-10T00:00:00.000Z',
  });
  await pointer.set({ key, activeRevision: 1, pointerRevision: 1 });
}

async function setFlags(event: boolean, place: boolean): Promise<void> {
  await setFlag(contentFlagIds.eventAuthoring, event);
  await setFlag(contentFlagIds.placeAuthoring, place);
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
});

const world = createPlaceWorld(firestore, 'd31-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d31-call-${(sequence += 1)}-${String(body.commandType)}`,
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

const createOf = async (typeId: 'event' | 'place') => {
  const { pageId } = await world.actors;
  return command({
    commandType: 'createDraft',
    payload: { typeId, publisherRef: { type: 'page', id: pageId }, marketId: 'LV', body: {} },
  });
};

/** A published Place with a second approved submission and its current draft revision. */
let placed:
  | {
      contentId: string;
      draftId: string;
      publishedRevisionId: string;
      pendingSubmissionId: string;
      draftRevision: number;
    }
  | undefined;

async function place() {
  if (placed !== undefined) return placed;
  const published = await world.publishedPlace();
  const revised = expectData<{ revision: number }>(
    await world.update(published.draftId, published.revision, {
      ...published.body,
      title: 'Kronvalda park pond and fountain',
    }),
    'revise',
  );
  const pending = expectData<{ submissionId: string }>(
    await world.submit(published.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: published.contentId,
      submissionId: pending.submissionId,
    }),
    'reapprove',
  );
  placed = {
    contentId: published.contentId,
    draftId: published.draftId,
    publishedRevisionId: published.publishedRevisionId,
    pendingSubmissionId: pending.submissionId,
    draftRevision: revised.revision,
  };
  return placed;
}

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

void test('row off/off: the whole Content surface is closed', async () => {
  const current = await place();
  await setFlags(false, false);
  assert.equal(code(await createOf('place')), 'rejected:type_disabled');
  assert.equal(code(await createOf('event')), 'rejected:type_disabled');
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

void test('row Event on / Place off: Place authoring refused, hide and reads allowed', async () => {
  const current = await place();
  await setFlags(true, false);
  assert.equal(code(await createOf('place')), 'rejected:type_disabled');
  assert.equal(code(await createOf('event')), 'succeeded');
  assert.equal(
    code(
      await command({
        commandType: 'updateDraft',
        payload: { draftId: current.draftId, expectedRevision: current.draftRevision, body: {} },
      }),
    ),
    'rejected:type_disabled',
  );
  assert.equal(
    code(
      await command({
        commandType: 'submitForPublication',
        payload: { draftId: current.draftId, expectedDraftRevision: current.draftRevision },
      }),
    ),
    'rejected:type_disabled',
  );
  assert.equal(
    code(
      await command({
        commandType: 'publishApprovedRevision',
        payload: { submissionId: current.pendingSubmissionId, expectedPointerRevision: 1 },
      }),
    ),
    'rejected:type_disabled',
  );
  assert.equal(
    code(
      await command({
        commandType: 'activatePublishedRevision',
        payload: {
          contentId: current.contentId,
          publishedRevisionId: current.publishedRevisionId,
          expectedPointerRevision: 1,
        },
      }),
    ),
    'rejected:type_disabled',
  );
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

void test('row Event off / Place on: Event authoring refused, Place allowed', async () => {
  await setFlags(false, true);
  assert.equal(code(await createOf('event')), 'rejected:type_disabled');
  assert.equal(code(await createOf('place')), 'succeeded');
});

void test('row on/on: both types may be authored', async () => {
  await setFlags(true, true);
  assert.equal(code(await createOf('event')), 'succeeded');
  assert.equal(code(await createOf('place')), 'succeeded');
});

void test('§5.7: every Create compatibility body is refused over the wire with its public fields', async () => {
  await setFlags(false, true);
  const { cases } = (await readContentJson('fixtures/place_create_compat.json')) as {
    cases: readonly {
      name: string;
      expectedIssues: readonly string[];
      expectedViolations: readonly { code: string; fieldPath: string }[];
      body: Record<string, unknown>;
    }[];
  };
  /**
   * One fixture body under the server's own author, saved and submitted over
   * the wire. `realMedia` replaces the fixture's placeholder media ids with
   * ready assets bound to this draft.
   */
  async function submitCase(item: (typeof cases)[number], realMedia: boolean) {
    const created = expectData<{
      draftId: string;
      contentId: string;
      revision: number;
      createdByUserId: string;
    }>(await createOf('place'), `${item.name}: create`);
    let media = item.body.media;
    if (realMedia) {
      const gallery: { mediaId: string }[] = [];
      for (const bytes of standSeedPlace.images.gallery)
        gallery.push({ mediaId: await world.upload(created.contentId, bytes) });
      media = {
        coverImage: {
          mediaId: await world.upload(created.contentId, standSeedPlace.images.cover),
        },
        gallery,
      };
    }
    const body = {
      ...item.body,
      media,
      provenance: {
        ...(item.body.provenance as Record<string, unknown>),
        submittedByUserId: created.createdByUserId,
      },
    };
    const bound = expectData<{ revision: number }>(
      await command({
        commandType: 'updateDraft',
        payload: { draftId: created.draftId, expectedRevision: created.revision, body },
      }),
      `${item.name}: update`,
    );
    return command({
      commandType: 'submitForPublication',
      payload: { draftId: created.draftId, expectedDraftRevision: bound.revision },
    });
  }

  const [valid, ...refused] = cases;
  assert.ok(valid !== undefined && valid.expectedIssues.length === 0);
  // The accepted body passes with real media; with the fixture's placeholder
  // media it passes validation and stops at Media readiness, which Content
  // checks only after validation. So every other case below is refused by
  // validation, not by its placeholder media.
  assert.equal(code(await submitCase(valid, true)), 'succeeded', valid.name);
  assert.equal(code(await submitCase(valid, false)), 'rejected:media_not_ready', valid.name);
  // M1 stage 3 (3-A): each refusal names its public field, exactly as the fixture.
  for (const item of refused)
    assert.deepEqual(
      await submitCase(item, false),
      {
        schemaVersion: 1,
        kind: 'rejected',
        code: 'validation_failed',
        violations: item.expectedViolations,
      },
      item.name,
    );
});
