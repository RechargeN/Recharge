// D2 §4 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): the access boundary of the
// Emulator-only `mediaDeliveryV1` callable, called over HTTP through the
// Functions Emulator — not only read from the source. No token, a token
// without a Session, and a Session with the `media.delivery` flag absent or
// off are refused with their exact code before any delivery is attempted; with
// the flag on the request reaches the gate. The flag and every Session and Auth
// user this file creates are restored afterwards.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';
import { getAuth } from 'firebase-admin/auth';
import type { DocumentData } from 'firebase-admin/firestore';

import { bookingIdentityCollections } from '../../src/booking/firestore_booking_access_authority.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { mediaFlagIds } from '../../src/shared/feature_flags.js';
import {
  bookingSessionContextFor,
  callBookingFunction,
  createAuthorizedActor,
  createFirebaseActor,
  emulatorFirestore,
} from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const key = featureFlagKey('local', 'LV', mediaFlagIds.delivery);
const revisionRef = firestore
  .collection(featureFlagRevisionCollection)
  .doc(featureFlagRevisionDocumentId(key, 1));
const pointerRef = firestore.collection(featureFlagPointerCollection).doc(key);
const users: string[] = [];
let saved: { revision: DocumentData | undefined; pointer: DocumentData | undefined } | undefined;

async function setDeliveryFlag(enabled: boolean | 'absent'): Promise<void> {
  if (enabled === 'absent') {
    await revisionRef.delete();
    await pointerRef.delete();
    return;
  }
  await revisionRef.set({
    schemaVersion: 1,
    revision: 1,
    environmentId: 'local',
    marketId: 'LV',
    capabilityId: mediaFlagIds.delivery,
    enabled,
    createdAtUtc: '2026-10-10T00:00:00.000Z',
  });
  await pointerRef.set({ key, activeRevision: 1, pointerRevision: 1 });
}

const uid = (label: string) => {
  const value = `d2-${label}-${randomUUID().slice(0, 8)}`;
  users.push(value);
  return value;
};

before(async () => {
  saved = {
    revision: (await revisionRef.get()).data(),
    pointer: (await pointerRef.get()).data(),
  };
});

after(async () => {
  // The flag exactly as it was before this file.
  if (saved?.revision === undefined) await revisionRef.delete();
  else await revisionRef.set(saved.revision);
  if (saved?.pointer === undefined) await pointerRef.delete();
  else await pointerRef.set(saved.pointer);
  // Every Session record and Auth user created here.
  for (const user of users) {
    const { sessionId } = bookingSessionContextFor(user);
    await firestore.collection(bookingIdentityCollections.accounts).doc(user).delete();
    await firestore.collection(bookingIdentityCollections.sessions).doc(sessionId).delete();
    await firestore.collection(bookingIdentityCollections.accessSnapshots).doc(sessionId).delete();
    await getAuth()
      .deleteUser(user)
      .catch((error: unknown) => {
        if (!String(error).includes('user-not-found')) throw error;
      });
  }
});

const request = () => ({
  schemaVersion: 1,
  contentId: randomUUID(),
  assetId: randomUUID(),
  profile: 'display',
});

async function code(data: unknown, idToken?: string): Promise<unknown> {
  const response = await callBookingFunction('mediaDeliveryV1', data, idToken);
  assert.equal(response.status, 200, JSON.stringify(response.body));
  const result = response.body.result as Record<string, unknown>;
  assert.equal(result.schemaVersion, 1);
  assert.equal(result.kind, 'rejected', JSON.stringify(result));
  return result.code;
}

void test('without any token the callable refuses as unauthenticated', async () => {
  await setDeliveryFlag(true);
  assert.equal(await code(request()), 'unauthenticated');
});

void test('a Firebase token without a Session is refused as unauthenticated', async () => {
  await setDeliveryFlag(true);
  const token = await createFirebaseActor(uid('no-session'));
  assert.equal(await code(request(), token), 'unauthenticated');
});

void test('a valid Session with the flag absent or off is refused before delivery', async () => {
  const token = await createAuthorizedActor(uid('flag'));
  await setDeliveryFlag('absent');
  assert.equal(await code(request(), token), 'capability_denied');
  await setDeliveryFlag(false);
  assert.equal(await code(request(), token), 'capability_denied');
});

void test('with a Session and the flag on, the request reaches the gate', async () => {
  const token = await createAuthorizedActor(uid('on'));
  await setDeliveryFlag(true);
  // Nothing is published under these ids: the gate reveals nothing.
  assert.equal(await code(request(), token), 'not_found');
  assert.equal(
    await code({ schemaVersion: 1, contentId: randomUUID() }, token),
    'invalid_contract',
  );
  assert.equal(
    await code({ ...request(), url: 'https://example.invalid/x' }, token),
    'invalid_contract',
  );
});
