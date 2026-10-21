// D3.5 HTTP flag matrix and valid/invalid Session submission through real owner services.
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
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { randomUUID } from 'node:crypto';
import { createSessionWorld, expectData } from '../support/content_session_world.js';

const firestore = emulatorFirestore();
const flags = [
  contentFlagIds.eventAuthoring,
  contentFlagIds.placeAuthoring,
  contentFlagIds.activityAuthoring,
  contentFlagIds.rentalAuthoring,
  contentFlagIds.collectionAuthoring,
  contentFlagIds.sessionAuthoring,
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
    createdAtUtc: '2026-10-10T00:00:00.000Z',
  });
  await pointer.set({ key, activeRevision: 1, pointerRevision: 1 });
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

const world = createSessionWorld(firestore, 'd35-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d35-call-${(sequence += 1)}-${String(body.commandType)}`,
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

void test('Session absent/off flag closes entry; its flag enables only Session and personal scope', async () => {
  for (const id of flags) await setFlag(id, false);
  const { creator, pageId } = await world.actors;
  const payload = {
    typeId: 'session',
    marketId: 'LV',
    publisherRef: { type: 'user', id: creator.actor.userId },
    body: {},
  };
  assert.equal((await command({ commandType: 'createDraft', payload })).code, 'type_disabled');
  await setFlag(contentFlagIds.sessionAuthoring, true);
  assert.equal((await command({ commandType: 'createDraft', payload })).kind, 'succeeded');
  for (const typeId of ['event', 'place', 'activity', 'rental', 'collection'])
    assert.equal(
      (await command({ commandType: 'createDraft', payload: { ...payload, typeId } })).code,
      'type_disabled',
    );
  assert.notEqual(
    (await command({ commandType: 'createDraft', payload: { ...payload, typeId: 'unknown_type' } }))
      .kind,
    'succeeded',
  );
  assert.equal(
    (
      await command({
        commandType: 'createDraft',
        payload: { ...payload, publisherRef: { type: 'page', id: pageId } },
      })
    ).kind,
    'rejected',
  );
});
after(() => world.cleanup());
void test('Session HTTP submits valid typed body with real Media; rejects legacy/Booking claims', async () => {
  await setFlag(contentFlagIds.sessionAuthoring, true);
  const d = await world.boundSession();
  const result = await command({
    commandType: 'submitForPublication',
    payload: { draftId: d.draftId, expectedDraftRevision: d.revision },
  });
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  for (const key of ['eventSlots', 'capacity', 'confirmed']) {
    const bad = await world.boundSession((body) => ({ ...body, [key]: true }));
    const refusal = await command({
      commandType: 'submitForPublication',
      payload: { draftId: bad.draftId, expectedDraftRevision: bad.revision },
    });
    assert.equal(refusal.code, 'validation_failed');
    assert.ok(!JSON.stringify(refusal).includes('unknown_field'));
  }
  const status = await query('getPublicationStatus', { contentId: d.contentId });
  assert.equal(status.kind, 'succeeded');
});

void test('Session HTTP source read is owner-only and does not leak private exception or audit data', async () => {
  await setFlag(contentFlagIds.sessionAuthoring, true);
  const { creator, staff } = await world.actors;
  const marker = 'private-session-exception-' + randomUUID();
  const d = await world.boundSession((body) => ({
    ...body,
    session: {
      ...(body.session as Record<string, unknown>),
      exceptions: [
        {
          id: randomUUID(),
          start_date_local: '2026-10-25',
          end_date_local: '2026-10-25',
          all_day: true,
          private_note: marker,
          created_by_user_id: creator.actor.userId,
          created_at_utc: '2026-10-18T00:00:00.000Z',
        },
      ],
    },
  }));
  const sub = expectData<{ submissionId: string }>(
    await command({
      commandType: 'submitForPublication',
      payload: { draftId: d.draftId, expectedDraftRevision: d.revision },
    }),
    'submit',
  );
  expectData(
    await world.decide('approve', { contentId: d.contentId, submissionId: sub.submissionId }),
    'review',
  );
  const pub = expectData<{ publishedRevisionId: string }>(
    await command({
      commandType: 'publishApprovedRevision',
      payload: { submissionId: sub.submissionId, expectedPointerRevision: 0 },
    }),
    'publish',
  );
  const stored = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(pub.publishedRevisionId),
  );
  assert.ok(stored);
  const own = expectData<{ body: unknown; bodyHash: string }>(
    await query('getPublishedRevision', { contentId: d.contentId }),
    'owner source',
  );
  assert.deepEqual(own.body, stored.body);
  assert.equal(own.bodyHash, stored.bodyHash);
  assert.ok(JSON.stringify(own.body).includes(marker));
  const response = await callBookingFunction(
    'contentQueryV1',
    { schemaVersion: 1, queryType: 'getPublishedRevision', payload: { contentId: d.contentId } },
    staff.idToken,
  );
  const result = response.body.result as { kind: string; code?: string };
  assert.equal(result.kind, 'rejected');
  for (const forbidden of [marker, 'private_note', 'created_by_user_id', 'created_at_utc'])
    assert.ok(!JSON.stringify(result).includes(forbidden), forbidden);
  assert.deepEqual(
    await world.composition.contentRepository.transact((tx) =>
      tx.publishedRevision(pub.publishedRevisionId),
    ),
    stored,
  );
});
