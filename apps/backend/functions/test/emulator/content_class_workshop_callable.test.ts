// D3.6 HTTP flag matrix and valid/invalid Class submission through real owner services.
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
import { createClassWorkshopWorld } from '../support/content_class_workshop_world.js';

const firestore = emulatorFirestore();
const flags = [
  contentFlagIds.eventAuthoring,
  contentFlagIds.placeAuthoring,
  contentFlagIds.activityAuthoring,
  contentFlagIds.rentalAuthoring,
  contentFlagIds.collectionAuthoring,
  contentFlagIds.sessionAuthoring,
  contentFlagIds.classWorkshopAuthoring,
] as const;
type EnvironmentId = 'local' | 'dev' | 'stage' | 'prod';
const refs = (capabilityId: string, environmentId: EnvironmentId = 'local') => {
  const key = featureFlagKey(environmentId, 'LV', capabilityId);
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

async function setFlag(
  capabilityId: string,
  enabled: boolean,
  environmentId: EnvironmentId = 'local',
): Promise<void> {
  const { key, revision, pointer } = refs(capabilityId, environmentId);
  await revision.set({
    schemaVersion: 1,
    revision: 1,
    environmentId,
    marketId: 'LV',
    capabilityId,
    enabled,
    createdAtUtc: '2026-10-19T00:00:00.000Z',
  });
  await pointer.set({ key, activeRevision: 1, pointerRevision: 1 });
}

async function deleteFlag(capabilityId: string): Promise<void> {
  const { revision, pointer } = refs(capabilityId);
  await revision.delete();
  await pointer.delete();
}

const snapshotKeys = [
  ...flags.map((id) => [id, 'local'] as const),
  [contentFlagIds.classWorkshopAuthoring, 'prod'] as const,
];
before(async () => {
  for (const [capabilityId, environmentId] of snapshotKeys) {
    const { revision, pointer } = refs(capabilityId, environmentId);
    saved.set(`${environmentId}:${capabilityId}`, {
      revision: (await revision.get()).data(),
      pointer: (await pointer.get()).data(),
    });
  }
});

after(async () => {
  for (const [capabilityId, environmentId] of snapshotKeys) {
    const { revision, pointer } = refs(capabilityId, environmentId);
    const previous = saved.get(`${environmentId}:${capabilityId}`);
    if (previous?.revision === undefined) await revision.delete();
    else await revision.set(previous.revision);
    if (previous?.pointer === undefined) await pointer.delete();
    else await pointer.set(previous.pointer);
  }
});

const world = createClassWorkshopWorld(firestore, 'd36-callable');
let sequence = 0;

async function command(body: Record<string, unknown>) {
  const { creator } = await world.actors;
  const response = await callBookingFunction(
    'contentCommandV1',
    {
      schemaVersion: 1,
      idempotencyKey: `d36-call-${(sequence += 1)}-${String(body.commandType)}`,
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

void test('Class absent/off/other-environment flag closes entry; its flag enables only Class, personal scope', async () => {
  for (const id of flags) await setFlag(id, false);
  const { creator, pageId } = await world.actors;
  const payload = {
    typeId: 'class_workshop',
    marketId: 'LV',
    publisherRef: { type: 'user', id: creator.actor.userId },
    body: {},
  };
  assert.equal((await command({ commandType: 'createDraft', payload })).code, 'type_disabled');
  // Absent flag record means off.
  await deleteFlag(contentFlagIds.classWorkshopAuthoring);
  assert.equal((await command({ commandType: 'createDraft', payload })).code, 'type_disabled');
  // A flag of another environment does not open the local/LV Emulator entry.
  await setFlag(contentFlagIds.classWorkshopAuthoring, true, 'prod');
  assert.equal((await command({ commandType: 'createDraft', payload })).code, 'type_disabled');
  await setFlag(contentFlagIds.classWorkshopAuthoring, true);
  assert.equal((await command({ commandType: 'createDraft', payload })).kind, 'succeeded');
  for (const typeId of ['event', 'place', 'activity', 'rental', 'collection', 'session'])
    assert.equal(
      (await command({ commandType: 'createDraft', payload: { ...payload, typeId } })).code,
      'type_disabled',
      typeId,
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

void test('Class HTTP submits a valid CW-V1 body with real Media; refuses legacy and Booking claims', async () => {
  await setFlag(contentFlagIds.classWorkshopAuthoring, true);
  const d = await world.boundClass();
  const result = await command({
    commandType: 'submitForPublication',
    payload: { draftId: d.draftId, expectedDraftRevision: d.revision },
  });
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  for (const key of ['eventSlots', 'spotsLeft', 'confirmed']) {
    const bad = await world.boundClass((body) => ({ ...body, [key]: true }));
    const refusal = await command({
      commandType: 'submitForPublication',
      payload: { draftId: bad.draftId, expectedDraftRevision: bad.revision },
    });
    assert.equal(refusal.code, 'validation_failed', key);
    // Public refusal details never echo the internal issue text.
    assert.ok(!JSON.stringify(refusal).includes('unknown_field'));
  }
  const status = await query('getPublicationStatus', { contentId: d.contentId });
  assert.equal(status.kind, 'succeeded');
});
