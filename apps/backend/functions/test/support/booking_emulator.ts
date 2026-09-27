import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { exactBookingCollectionNames } from '../../src/booking/transactions.js';
import { bookingFlagIds, identityFlagIds } from '../../src/shared/feature_flags.js';
import type { BookingEventProjection } from '../../src/booking/domain.js';
import { bookingIdentityCollections } from '../../src/booking/firestore_booking_access_authority.js';
import { identityAuthorityCollections } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  deliverEventBookingProjection,
  eventBookingDeliveryCollections,
} from '../../src/booking/event_projection_delivery.js';
import { seedEventBookingOutbox } from './event_outbox_seed.js';
import { abuseCollections } from '../../src/platform/security/firestore_abuse_rate_limiter.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';

const bookingAccessCollectionNames = Object.freeze([
  ...new Set([
    ...Object.values(bookingIdentityCollections),
    ...Object.values(identityAuthorityCollections),
  ]),
]);
const sessionContexts = new Map<
  string,
  Readonly<{ sessionId: string; sessionHandle: string; installationId: string }>
>();

export function bookingSessionContextFor(uid: string) {
  const installationId = `install-${uid}`;
  const sessionHandle = createHash('sha256').update(`handle:${uid}`).digest('base64url');
  return Object.freeze({ sessionId: `session-${uid}`, sessionHandle, installationId });
}

export function emulatorFirestore(): Firestore {
  assert.equal(process.env.GCLOUD_PROJECT, 'demo-recharge');
  assert.equal(process.env.FUNCTIONS_EMULATOR, 'true');
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
  const app = getApps().length === 0 ? initializeApp({ projectId: 'demo-recharge' }) : getApp();
  return getFirestore(app);
}

export async function cleanupBookingEmulator(firestore = emulatorFirestore()): Promise<void> {
  for (const collectionName of [
    ...exactBookingCollectionNames,
    ...bookingAccessCollectionNames,
    ...Object.values(eventBookingDeliveryCollections),
    ...Object.values(abuseCollections),
    featureFlagRevisionCollection,
    featureFlagPointerCollection,
  ]) {
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
  const outboxId = createHash('sha256')
    .update(`test-seed-event-v1|${event.eventId}|${event.occurrenceId}|${event.materialRevision}`)
    .digest('hex');
  const eventFact = {
    kind: 'EventRevisionPublished',
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: event.materialRevision,
    materialRevision: event.materialRevision,
    occurredAt: '2026-08-01T00:00:00.000Z',
    projection: event,
  } as const;
  const enqueued = await seedEventBookingOutbox(firestore, {
    outboxId,
    event: eventFact,
  });
  assert.ok(enqueued === 'created' || enqueued === 'replayed');
  const deliveryNowUtc = new Date().toISOString();
  let delivered = await deliverEventBookingProjection(firestore, outboxId, deliveryNowUtc);
  for (
    let attempt = 0;
    (delivered === 'lease_held' || delivered === 'lease_lost') && attempt < 100;
    attempt += 1
  ) {
    await new Promise((resolve) => setTimeout(resolve, 50));
    const status: unknown = (
      await firestore.collection(eventBookingDeliveryCollections.deliveries).doc(outboxId).get()
    ).get('status');
    if (status === 'delivered') delivered = 'replayed';
    if (status === 'deadLetter') delivered = 'dead_letter';
  }
  assert.ok(delivered === 'delivered' || delivered === 'replayed', String(delivered));
}

export async function setBookingFlags(
  enabled: boolean,
  firestore = emulatorFirestore(),
): Promise<void> {
  const batch = firestore.batch();
  for (const flagId of Object.values(bookingFlagIds)) {
    const key = featureFlagKey('local', 'LV', flagId);
    batch.set(
      firestore
        .collection(featureFlagRevisionCollection)
        .doc(featureFlagRevisionDocumentId(key, 1)),
      {
        schemaVersion: 1,
        revision: 1,
        environmentId: 'local',
        marketId: 'LV',
        capabilityId: flagId,
        enabled,
        createdAtUtc: '2026-09-24T00:00:00.000Z',
      },
    );
    batch.set(firestore.collection(featureFlagPointerCollection).doc(key), {
      key,
      activeRevision: 1,
      pointerRevision: 1,
    });
  }
  await batch.commit();
}

export async function setIdentitySessionFlag(
  enabled: boolean,
  firestore = emulatorFirestore(),
): Promise<void> {
  const capabilityId = identityFlagIds.establishSession;
  const key = featureFlagKey('local', 'LV', capabilityId);
  const batch = firestore.batch();
  batch.set(
    firestore.collection(featureFlagRevisionCollection).doc(featureFlagRevisionDocumentId(key, 1)),
    {
      schemaVersion: 1,
      revision: 1,
      environmentId: 'local',
      marketId: 'LV',
      capabilityId,
      enabled,
      createdAtUtc: '2026-09-24T00:00:00.000Z',
    },
  );
  batch.set(firestore.collection(featureFlagPointerCollection).doc(key), {
    key,
    activeRevision: 1,
    pointerRevision: 1,
  });
  await batch.commit();
}

export async function createAuthorizedActor(
  uid: string,
  claims: Readonly<Record<string, unknown>> = {
    accountState: 'active',
    capabilities: ['booking.self_service'],
  },
  domainUserId = uid,
): Promise<string> {
  const firestore = emulatorFirestore();
  const { sessionId, installationId, sessionHandle } = bookingSessionContextFor(uid);
  const handleHash = createHash('sha256').update(sessionHandle).digest('hex');
  const accountActive = claims.accountState === undefined || claims.accountState === 'active';
  const capabilityIds = Array.isArray(claims.capabilities)
    ? claims.capabilities.filter((value): value is string => typeof value === 'string')
    : ['booking.self_service'];
  const issuedAt = new Date();
  const issuedAtUtc = issuedAt.toISOString();
  const idleExpiresAtUtc = new Date(issuedAt.getTime() + 30 * 86_400_000).toISOString();
  const snapshotExpiresAtUtc = new Date(issuedAt.getTime() + 60 * 60_000).toISOString();
  const batch = firestore.batch();
  batch.set(firestore.collection(bookingIdentityCollections.accounts).doc(domainUserId), {
    schemaVersion: 1,
    userId: domainUserId,
    status: accountActive ? 'active' : 'blocked',
    revision: 1,
    securityRevision: 1,
    revokeBeforeSecurityRevision: 0,
    createdAtUtc: issuedAtUtc,
    updatedAtUtc: issuedAtUtc,
  });
  batch.set(firestore.collection(bookingIdentityCollections.sessions).doc(sessionId), {
    schemaVersion: 1,
    sessionId,
    userId: domainUserId,
    status: 'active',
    revision: 1,
    authzRevision: 1,
    firebaseUid: uid,
    installationId,
    handleHash,
    issuedAtUtc,
    lastSeenAtUtc: issuedAtUtc,
    idleExpiresAtUtc,
  });
  batch.set(firestore.collection(bookingIdentityCollections.accessSnapshots).doc(sessionId), {
    schemaVersion: 1,
    userId: domainUserId,
    sessionId,
    accountRevision: 1,
    sessionRevision: 1,
    authzRevision: 1,
    capabilityPolicyRevision: 1,
    capabilityIds,
    evaluatedAtUtc: issuedAtUtc,
    expiresAtUtc: snapshotExpiresAtUtc,
  });
  await batch.commit();
  const idToken = await createFirebaseActor(uid);
  sessionContexts.set(idToken, { sessionId, sessionHandle, installationId });
  return idToken;
}

export async function createFirebaseActor(uid: string): Promise<string> {
  const auth = getAuth();
  const email = `${uid}@example.invalid`;
  const password = 'emulator-only-password-123';
  try {
    await auth.createUser({ uid, email, password });
  } catch (error) {
    if (!String(error).includes('uid-already-exists')) throw error;
  }
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

export function registerSessionContext(
  idToken: string,
  context: Readonly<{ sessionId: string; sessionHandle: string; installationId: string }>,
): void {
  sessionContexts.set(idToken, context);
}

export async function callBookingFunction(
  functionName: string,
  data: unknown,
  idToken?: string,
): Promise<Readonly<{ status: number; body: Record<string, unknown> }>> {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (idToken !== undefined) headers.authorization = `Bearer ${idToken}`;
  const context = idToken === undefined ? undefined : sessionContexts.get(idToken);
  const callableData =
    context === undefined || typeof data !== 'object' || data === null || Array.isArray(data)
      ? data
      : { ...(data as Record<string, unknown>), sessionContext: context };
  const response = await fetch(`http://127.0.0.1:5001/demo-recharge/europe-west1/${functionName}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data: callableData }),
  });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}
