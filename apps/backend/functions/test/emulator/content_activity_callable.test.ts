// D3.2 §2.2 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md): the operation matrix of
// the Emulator-only `contentCommandV1` / `contentQueryV1` over HTTP through the
// Functions Emulator for Activity, row by row, with the exact refusal code. The
// Activity used for hide, reads, publish and activate is created through the
// owner services first; the flags are restored exactly as they were before
// this file. It also sends every body of the shared Create compatibility
// fixture (§5.7) over the wire: the answer is `validation_failed` and carries
// stable public codes and field paths, without field values.
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
import { standSeedActivity } from '../stand/stand_content_activity.js';
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { createActivityWorld, expectData } from '../support/content_activity_world.js';

const firestore = emulatorFirestore();
const flags = [
  contentFlagIds.eventAuthoring,
  contentFlagIds.placeAuthoring,
  contentFlagIds.activityAuthoring,
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
    createdAtUtc: '2026-10-11T00:00:00.000Z',
  });
  await pointer.set({ key, activeRevision: 1, pointerRevision: 1 });
}

async function setFlags(event: boolean, place: boolean, activity: boolean): Promise<void> {
  await setFlag(contentFlagIds.eventAuthoring, event);
  await setFlag(contentFlagIds.placeAuthoring, place);
  await setFlag(contentFlagIds.activityAuthoring, activity);
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

const world = createActivityWorld(firestore, 'd32-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d32-call-${(sequence += 1)}-${String(body.commandType)}`,
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

const createOf = async (typeId: 'event' | 'place' | 'activity') => {
  const { pageId } = await world.actors;
  return command({
    commandType: 'createDraft',
    payload: { typeId, publisherRef: { type: 'page', id: pageId }, marketId: 'LV', body: {} },
  });
};

/** A published Activity with a second approved submission and its current draft revision. */
let placed:
  | {
      contentId: string;
      draftId: string;
      publishedRevisionId: string;
      pendingSubmissionId: string;
      draftRevision: number;
    }
  | undefined;

async function activity() {
  if (placed !== undefined) return placed;
  const published = await world.publishedActivity();
  const revised = expectData<{ revision: number }>(
    await world.update(published.draftId, published.revision, {
      ...published.body,
      title: 'Ķemeri bog boardwalk long loop',
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

void test('row all off: the whole Content surface is closed', async () => {
  const current = await activity();
  await setFlags(false, false, false);
  assert.equal(code(await createOf('activity')), 'rejected:type_disabled');
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

void test('row Event and Place on / Activity off: Activity authoring refused, hide and reads allowed', async () => {
  const current = await activity();
  await setFlags(true, true, false);
  assert.equal(code(await createOf('activity')), 'rejected:type_disabled');
  assert.equal(code(await createOf('event')), 'succeeded');
  assert.equal(code(await createOf('place')), 'succeeded');
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

void test('row Activity on only: Event and Place authoring refused, Activity allowed', async () => {
  await setFlags(false, false, true);
  assert.equal(code(await createOf('event')), 'rejected:type_disabled');
  assert.equal(code(await createOf('place')), 'rejected:type_disabled');
  assert.equal(code(await createOf('activity')), 'succeeded');
});

void test('row all on: each of the three types may be authored', async () => {
  await setFlags(true, true, true);
  assert.equal(code(await createOf('event')), 'succeeded');
  assert.equal(code(await createOf('place')), 'succeeded');
  assert.equal(code(await createOf('activity')), 'succeeded');
});

void test('§5.7: every Create compatibility body is refused over the wire with stable field violations', async () => {
  await setFlags(false, false, true);
  const { cases } = (await readContentJson('fixtures/activity_create_compat.json')) as {
    cases: readonly {
      name: string;
      expectedIssues: readonly string[];
      expectedViolations: readonly { code: string; fieldPath: string }[];
      body: Record<string, unknown>;
    }[];
  };
  /**
   * One fixture body saved and submitted over the wire. `realMedia` replaces
   * the fixture's placeholder media ids with ready assets bound to this draft.
   */
  async function submitCase(item: (typeof cases)[number], realMedia: boolean) {
    const created = expectData<{ draftId: string; contentId: string; revision: number }>(
      await createOf('activity'),
      `${item.name}: create`,
    );
    let media = item.body.media;
    if (realMedia) {
      const gallery: { mediaId: string }[] = [];
      for (const bytes of standSeedActivity.images.gallery)
        gallery.push({ mediaId: await world.upload(created.contentId, bytes) });
      media = {
        coverImage: {
          mediaId: await world.upload(created.contentId, standSeedActivity.images.cover),
        },
        gallery,
      };
    }
    const bound = expectData<{ revision: number }>(
      await command({
        commandType: 'updateDraft',
        payload: {
          draftId: created.draftId,
          expectedRevision: created.revision,
          body: { ...item.body, media },
        },
      }),
      `${item.name}: update`,
    );
    return command({
      commandType: 'submitForPublication',
      payload: { draftId: created.draftId, expectedDraftRevision: bound.revision },
    });
  }

  const [valid] = cases;
  const refused = cases.filter((item) => item.expectedIssues.length > 0);
  assert.ok(valid !== undefined && valid.expectedIssues.length === 0);
  // The accepted body passes with real media; with the fixture's placeholder
  // media it passes validation and stops at Media readiness, which Content
  // checks only after validation. So every other case below is refused by
  // validation (or the composition rules), not by its placeholder media.
  assert.equal(code(await submitCase(valid, true)), 'succeeded', valid.name);
  assert.equal(code(await submitCase(valid, false)), 'rejected:media_not_ready', valid.name);
  // Boundary controls need only domain acceptance + readiness: avoid extra uploads.
  for (const item of cases.filter((entry) => entry !== valid && entry.expectedIssues.length === 0))
    assert.equal(code(await submitCase(item, false)), 'rejected:media_not_ready', item.name);
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
