// D3.3 §3 (RENTAL_D3_3_PUBLICATION_AMENDMENT.md): the Emulator-only
// `contentCommandV1` / `contentQueryV1` over HTTP through the Functions
// Emulator for Rental, row by row, with the exact refusal code; flags are
// restored exactly as they were before this file. It also sends every body of
// the shared Create compatibility fixture over the wire, re-anchored to today
// and attested by the calling Creator: the answer is `validation_failed`
// without validator codes (§2 Q7).
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
import { standRentalAnchorUtc, standSeedRental } from '../stand/stand_content_rental.js';
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { createRentalWorld, expectData } from '../support/content_rental_world.js';

const firestore = emulatorFirestore();
const flags = [
  contentFlagIds.eventAuthoring,
  contentFlagIds.placeAuthoring,
  contentFlagIds.activityAuthoring,
  contentFlagIds.rentalAuthoring,
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

async function setFlags(values: {
  event: boolean;
  place: boolean;
  activity: boolean;
  rental: boolean;
}): Promise<void> {
  await setFlag(contentFlagIds.eventAuthoring, values.event);
  await setFlag(contentFlagIds.placeAuthoring, values.place);
  await setFlag(contentFlagIds.activityAuthoring, values.activity);
  await setFlag(contentFlagIds.rentalAuthoring, values.rental);
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

const world = createRentalWorld(firestore, 'd33-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d33-call-${(sequence += 1)}-${String(body.commandType)}`,
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

const createOf = async (typeId: 'event' | 'rental') => {
  const { pageId } = await world.actors;
  return command({
    commandType: 'createDraft',
    payload: { typeId, publisherRef: { type: 'page', id: pageId }, marketId: 'LV', body: {} },
  });
};

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

let published:
  { contentId: string; draftId: string; publishedRevisionId: string; revision: number } | undefined;
async function rental() {
  if (published !== undefined) return published;
  const item = await world.publishedRental();
  published = {
    contentId: item.contentId,
    draftId: item.draftId,
    publishedRevisionId: item.publishedRevisionId,
    revision: item.revision,
  };
  return published;
}

void test('row all off: the whole Content surface is closed', async () => {
  const current = await rental();
  await setFlags({ event: false, place: false, activity: false, rental: false });
  assert.equal(code(await createOf('rental')), 'rejected:type_disabled');
  assert.equal(
    code(await query('getPublicationStatus', { contentId: current.contentId })),
    'rejected:type_disabled',
  );
});

void test('row Event on / Rental off: Rental authoring refused, hide and reads allowed', async () => {
  const current = await rental();
  await setFlags({ event: true, place: false, activity: false, rental: false });
  assert.equal(code(await createOf('rental')), 'rejected:type_disabled');
  assert.equal(code(await createOf('event')), 'succeeded');
  assert.equal(code(await query('getDraft', { draftId: current.draftId })), 'succeeded');
  assert.equal(
    code(
      await command({
        commandType: 'withdrawPublication',
        payload: { contentId: current.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
      }),
    ),
    'succeeded',
  );
});

void test('row Rental on: Rental authoring allowed; activation of a Rental revision is refused (Q4)', async () => {
  const current = await rental();
  await setFlags({ event: false, place: false, activity: false, rental: true });
  assert.equal(code(await createOf('event')), 'rejected:type_disabled');
  assert.equal(code(await createOf('rental')), 'succeeded');
  const status = expectData<{ pointer: { revision: number; visibility: string } }>(
    await query('getPublicationStatus', { contentId: current.contentId }),
    'status',
  );
  assert.equal(
    code(
      await command({
        commandType: 'activatePublishedRevision',
        payload: {
          contentId: current.contentId,
          publishedRevisionId: current.publishedRevisionId,
          expectedPointerRevision: status.pointer.revision,
        },
      }),
    ),
    'rejected:type_disabled',
  );
  const after = expectData<{ pointer: { revision: number; visibility: string } }>(
    await query('getPublicationStatus', { contentId: current.contentId }),
    'status after',
  );
  assert.deepEqual(after.pointer, status.pointer);
});

/** Moves every instant of a fixture body by [shiftMs]; ids and the rest stay. */
function shifted(value: unknown, shiftMs: number): unknown {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(value))
    return new Date(Date.parse(value) + shiftMs).toISOString();
  if (Array.isArray(value)) return value.map((item) => shifted(item, shiftMs));
  if (typeof value === 'object' && value !== null)
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, shifted(item, shiftMs)]),
    );
  return value;
}

void test('every Create compatibility body is refused over the wire with validation_failed only', async () => {
  await setFlags({ event: false, place: false, activity: false, rental: true });
  const fixture = (await readContentJson('fixtures/rental_create_compat.json')) as {
    actorUserId: string;
    nowUtc: string;
    cases: readonly {
      name: string;
      expectedIssues: readonly string[];
      body: Record<string, unknown>;
    }[];
  };
  const { creator } = await world.actors;
  // Re-anchor the fixture's clock to the start of today, and attest as the caller.
  const fixtureAnchor = Date.parse(fixture.nowUtc.slice(0, 10) + 'T00:00:00.000Z');
  const shiftMs = Date.parse(standRentalAnchorUtc()) - fixtureAnchor;
  const asCaller = (body: Record<string, unknown>) =>
    JSON.parse(
      JSON.stringify(shifted(body, shiftMs)).replaceAll(fixture.actorUserId, creator.actor.userId),
    ) as Record<string, unknown>;

  async function submitCase(item: (typeof fixture.cases)[number], realMedia: boolean) {
    const created = expectData<{ draftId: string; contentId: string; revision: number }>(
      await createOf('rental'),
      `${item.name}: create`,
    );
    const body = asCaller(item.body);
    if (realMedia) {
      const refs = [await world.upload(created.contentId, standSeedRental.images.cover)];
      for (const bytes of standSeedRental.images.gallery)
        refs.push(await world.upload(created.contentId, bytes));
      body.mediaRefs = refs;
    }
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

  const [valid, ...refused] = fixture.cases;
  assert.ok(valid !== undefined && valid.expectedIssues.length === 0);
  // The accepted body passes with real media; with the fixture's placeholder
  // media it passes validation and stops at Media readiness, which Content
  // checks only after validation, so every other case is refused by validation.
  assert.equal(code(await submitCase(valid, true)), 'succeeded', valid.name);
  assert.equal(code(await submitCase(valid, false)), 'rejected:media_not_ready', valid.name);
  for (const item of refused) {
    const answer = await submitCase(item, false);
    assert.equal(answer.kind, 'rejected', item.name);
    assert.equal(answer.code, 'validation_failed', item.name);
    assert.equal(JSON.stringify(answer).includes('rental.'), false, item.name);
  }
});
