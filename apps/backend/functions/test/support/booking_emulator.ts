import assert from 'node:assert/strict';
import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { bookingCollections, exactBookingCollectionNames } from '../../src/booking/transactions.js';
import { bookingFlagIds } from '../../src/shared/feature_flags.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';

export function emulatorFirestore(): Firestore {
  assert.equal(process.env.GCLOUD_PROJECT, 'demo-recharge');
  assert.equal(process.env.FUNCTIONS_EMULATOR, 'true');
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
  const app = getApps().length === 0 ? initializeApp({ projectId: 'demo-recharge' }) : getApp();
  return getFirestore(app);
}

export async function cleanupBookingEmulator(firestore = emulatorFirestore()): Promise<void> {
  for (const collectionName of exactBookingCollectionNames) {
    while (true) {
      const snapshot = await firestore.collection(collectionName).limit(200).get();
      if (snapshot.empty) break;
      const batch = firestore.batch();
      for (const document of snapshot.docs) batch.delete(document.ref);
      await batch.commit();
    }
  }
}

export async function assertBookingEmulatorClean(firestore = emulatorFirestore()): Promise<void> {
  for (const collectionName of exactBookingCollectionNames) {
    assert.equal(
      (await firestore.collection(collectionName).limit(1).get()).empty,
      true,
      collectionName,
    );
  }
}

export async function seedEvent(
  event: BookingEventProjection,
  firestore = emulatorFirestore(),
): Promise<void> {
  await firestore
    .collection(bookingCollections.eventProjections)
    .doc(event.occurrenceId)
    .set(event);
}

export async function setBookingFlags(
  enabled: boolean,
  firestore = emulatorFirestore(),
): Promise<void> {
  const batch = firestore.batch();
  for (const [kind, flagId] of Object.entries(bookingFlagIds)) {
    batch.set(firestore.collection(bookingCollections.featureFlags).doc(flagId), {
      schemaVersion: 1,
      enabled,
      environment: 'emulator',
      kind,
    });
  }
  await batch.commit();
}

export async function createAuthorizedActor(
  uid: string,
  claims: Readonly<Record<string, unknown>> = {
    accountState: 'active',
    capabilities: ['booking.self_service'],
  },
): Promise<string> {
  const auth = getAuth();
  const email = `${uid}@example.invalid`;
  const password = 'emulator-only-password-123';
  try {
    await auth.createUser({ uid, email, password });
  } catch (error) {
    if (!String(error).includes('uid-already-exists')) throw error;
  }
  await auth.setCustomUserClaims(uid, claims);
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
  const response = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-recharge`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = (await response.json()) as Record<string, unknown>;
  assert.equal(response.ok, true, JSON.stringify(body));
  assert.equal(typeof body.idToken, 'string');
  return String(body.idToken);
}

export async function callBookingFunction(
  functionName: string,
  data: unknown,
  idToken?: string,
): Promise<Readonly<{ status: number; body: Record<string, unknown> }>> {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (idToken !== undefined) headers.authorization = `Bearer ${idToken}`;
  const response = await fetch(`http://127.0.0.1:5001/demo-recharge/europe-west1/${functionName}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}
