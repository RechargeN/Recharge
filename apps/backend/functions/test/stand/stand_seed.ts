import { getAuth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import {
  deliverEventBookingProjection,
  eventBookingDeliveryCollections,
} from '../../src/booking/event_projection_delivery.js';
import type { EventBookingProjectionEvent } from '../../src/booking/event_projection_consumer.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import {
  callBookingFunction,
  createFirebaseActor,
  emulatorFirestore,
  registerSessionContext,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { seedEventBookingOutbox } from '../support/event_outbox_seed.js';
import { enableStandFlags } from './stand_flags.js';
import {
  readStandManifest,
  seedContentEvent,
  writeStandManifest,
  type StandContentEventManifest,
} from './stand_content_event.js';
import { grantStandStaff } from './stand_moderation.js';
import { assertStandEnvironment, isAuthUserNotFound } from './stand_guard.js';
import {
  standBookings,
  standCreatorVerification,
  standEmulatorPassword,
  standEvent,
  standMarketId,
  standMaximumOwnedPages,
  standPages,
  standUsers,
  type StandUserLabel,
} from './stand_plan.js';

export interface StandSeedResult {
  readonly users: number;
  readonly pages: number;
  readonly bookings: number;
  /** The Event created through the Content path (C3). */
  readonly contentEvent: StandContentEventManifest;
  /** True when an earlier complete seed was found and reused instead of repeated. */
  readonly reused: boolean;
}

export class StandAlreadySeededError extends Error {}

/**
 * Seeds the stand only through owner paths: Auth Emulator + the Identity
 * Session callable, Identity owner services, the Event-outbox fixture with the
 * Booking projection delivery, and the Booking callables.
 */
export async function seedStand(
  env: NodeJS.ProcessEnv = process.env,
  firestore: Firestore = emulatorFirestore(),
): Promise<StandSeedResult> {
  assertStandEnvironment(env);
  const existing = await existingSeed(firestore);
  const options = {
    // A resumed seed may find no live Session (tests revoke them): recover a new one.
    recover: async (label: 'creator' | 'staff') => {
      await recoverStandSession(label, `-resume-${Date.now()}`);
    },
    interruptAfter: env.STAND_SEED_INTERRUPT_AFTER,
  };
  if (existing !== 'fresh') {
    // The base was completed earlier: reuse it, and finish (or reuse) the
    // Content Event by replaying its idempotent commands.
    const manifest = await readStandManifest(firestore);
    const contentEvent = manifest?.contentEvent ?? (await seedContentEvent(firestore, options));
    return Object.freeze({
      users: standUsers.length,
      pages: standPages.length,
      bookings: standBookings.length,
      contentEvent,
      reused: true,
    });
  }
  const nowUtc = new Date().toISOString();
  await enableStandFlags(firestore, nowUtc);

  const tokens = new Map<StandUserLabel, string>();
  const userIds = new Map<StandUserLabel, string>();
  for (const user of standUsers) {
    const idToken = await createFirebaseActor(user.firebaseUid);
    tokens.set(user.label, idToken);
    const response = await callBookingFunction(
      'establishIdentitySessionV1',
      {
        schemaVersion: 1,
        commandType: 'establishIdentitySession',
        requestId: `stand-identity-${user.label}`,
        installationId: user.installationId,
      },
      idToken,
    );
    const result = response.body.result as Record<string, unknown> | undefined;
    if (result?.kind !== 'succeeded') {
      throw new Error(`session_failed:${user.label}:${JSON.stringify(result)}`);
    }
    const context = (result.data as Record<string, Record<string, string>>).sessionContext;
    if (
      context?.userId === undefined ||
      context.sessionId === undefined ||
      context.sessionHandle === undefined ||
      context.installationId === undefined
    ) {
      throw new Error(`session_incomplete:${user.label}`);
    }
    registerSessionContext(idToken, {
      sessionId: context.sessionId,
      sessionHandle: context.sessionHandle,
      installationId: context.installationId,
    });
    userIds.set(user.label, context.userId);
  }

  await bootstrapCreatorAndPages(firestore, userIds, nowUtc);
  // Creator verification bumps the Account authority revision and revokes the older
  // Session fence, so the Creator recovers a fresh Session through the owner callable.
  await recoverCreatorSession(tokens);
  // C2: test-only staff registry entry for the seeded staff Account (not production IAM).
  await grantStandStaff(firestore, nowUtc);
  // Booking-test fixture only: a synthetic Event-outbox Event for the Booking checks.
  await publishFixtureEvent(firestore);
  const bookings = await createBookings(tokens);
  await writeStandManifest(firestore, { base: { completedAtUtc: new Date().toISOString() } });
  const contentEvent = await seedContentEvent(firestore, options);
  return Object.freeze({
    users: standUsers.length,
    pages: standPages.length,
    bookings,
    contentEvent,
    reused: false,
  });
}

/**
 * `fresh`: no stand user exists. `base`: every user exists and the manifest says
 * the base seed completed. Anything in between is a partial base that cannot be
 * resumed safely: it is refused and the stand must be reset.
 */
async function existingSeed(firestore: Firestore): Promise<'fresh' | 'base'> {
  let found = 0;
  for (const user of standUsers) {
    try {
      await getAuth().getUser(user.firebaseUid);
      found += 1;
    } catch (error) {
      if (!isAuthUserNotFound(error)) throw error;
    }
  }
  if (found === 0) return 'fresh';
  const manifest = await readStandManifest(firestore);
  if (found === standUsers.length && manifest?.base !== undefined) return 'base';
  throw new StandAlreadySeededError(
    'stand contains a partial base seed; reset the stand before seeding again',
  );
}

/**
 * Bounded demo-recharge bootstrap: one Creator verification and two pages,
 * decided by the staff Account. The staff reviewer set exists only inside this
 * seed process; ordinary sign-in never receives Creator or staff authority.
 */
async function bootstrapCreatorAndPages(
  firestore: Firestore,
  userIds: ReadonlyMap<StandUserLabel, string>,
  nowUtc: string,
): Promise<void> {
  const creatorId = required(userIds.get('creator'), 'creator');
  const staffId = required(userIds.get('staff'), 'staff');
  const authority = new IdentityPublisherAuthority({
    repository: new FirestoreIdentityAuthorityRepository(firestore),
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([staffId])),
    pagePolicy: new LocalPageCreationPolicy(true, standMaximumOwnedPages),
  });
  await authority.creatorVerification.submit({
    userId: creatorId,
    verificationId: standCreatorVerification.verificationId,
    evidenceRefIds: standCreatorVerification.evidenceRefIds,
    nowUtc,
  });
  await authority.creatorVerification.decide({
    reviewerId: staffId,
    userId: creatorId,
    status: 'verified',
    nowUtc,
  });
  for (const page of standPages) {
    await authority.pages.create({
      userId: creatorId,
      pageId: page.pageId,
      membershipId: page.membershipId,
      marketId: standMarketId,
      nowUtc,
    });
    await authority.pages.decidePage({
      reviewerId: staffId,
      pageId: page.pageId,
      decision: 'verified',
      nowUtc,
    });
  }
}

async function recoverCreatorSession(tokens: Map<StandUserLabel, string>): Promise<void> {
  tokens.set('creator', await recoverStandSession('creator'));
}

/** A fresh live Session for an existing stand user, through the owner recovery callable. */
async function recoverStandSession(label: StandUserLabel, requestSuffix = ''): Promise<string> {
  const user = required(
    standUsers.find((candidate) => candidate.label === label),
    label,
  );
  const idToken = await signInStandUser(user.firebaseUid);
  const response = await callBookingFunction(
    'recoverIdentitySessionsV1',
    {
      schemaVersion: 1,
      commandType: 'recoverIdentitySessions',
      requestId: `stand-identity-${label}-recover${requestSuffix}`,
      installationId: user.installationId,
    },
    idToken,
  );
  const result = response.body.result as Record<string, unknown> | undefined;
  if (result?.kind !== 'succeeded') {
    throw new Error(`session_recover_failed:${label}:${JSON.stringify(result)}`);
  }
  const context = (result.data as Record<string, Record<string, string>>).sessionContext;
  if (
    context?.sessionId === undefined ||
    context.sessionHandle === undefined ||
    context.installationId === undefined
  ) {
    throw new Error(`session_recover_incomplete:${label}`);
  }
  registerSessionContext(idToken, {
    sessionId: context.sessionId,
    sessionHandle: context.sessionHandle,
    installationId: context.installationId,
  });
  return idToken;
}

/** Fresh sign-in for an existing Auth Emulator user (recent auth for Session recovery). */
async function signInStandUser(uid: string): Promise<string> {
  const host = required(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'auth emulator host');
  const response = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-recharge`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: `${uid}@example.invalid`,
        password: standEmulatorPassword,
        returnSecureToken: true,
      }),
    },
  );
  const body = (await response.json()) as Record<string, unknown>;
  if (!response.ok || typeof body.idToken !== 'string') throw new Error(`sign_in_failed:${uid}`);
  return body.idToken;
}

async function publishFixtureEvent(firestore: Firestore): Promise<void> {
  const publisherPage = standPages.find((page) => page.label === standEvent.publisherPageLabel);
  const projection = finiteEvent({
    eventId: standEvent.eventId,
    occurrenceId: standEvent.occurrenceId,
    materialRevision: standEvent.materialRevision,
    publisherRef: { type: 'page', id: required(publisherPage, 'publisher page').pageId },
    occurrenceStartsAt: standEvent.occurrenceStartsAt,
    occurrenceEndsAt: standEvent.occurrenceEndsAt,
    registrationWindow: {
      opensAt: standEvent.registrationOpensAt,
      closesAt: standEvent.registrationClosesAt,
    },
    cancellationDeadline: standEvent.cancellationDeadline,
    totalCapacity: standEvent.totalCapacity,
    poolId: standEvent.poolId,
    channel: standEvent.channel,
  });
  const fact: EventBookingProjectionEvent = {
    kind: 'EventRevisionPublished',
    eventId: standEvent.eventId,
    occurrenceId: standEvent.occurrenceId,
    materialRevision: standEvent.materialRevision,
    publicationRevision: standEvent.materialRevision,
    occurredAt: standEvent.publishedAt,
    projection,
  };
  const enqueued = await seedEventBookingOutbox(firestore, {
    outboxId: standEvent.outboxId,
    event: fact,
  });
  if (enqueued === 'conflict') throw new Error('stand_event_outbox_conflict');
  let delivered = await deliverEventBookingProjection(
    firestore,
    standEvent.outboxId,
    new Date().toISOString(),
  );
  // The Event trigger may deliver concurrently; wait for the recorded outcome.
  for (
    let attempt = 0;
    attempt < 100 && delivered !== 'delivered' && delivered !== 'replayed';
    attempt += 1
  ) {
    if (delivered !== 'lease_held' && delivered !== 'lease_lost') break;
    await new Promise((resolve) => setTimeout(resolve, 100));
    const status: unknown = (
      await firestore
        .collection(eventBookingDeliveryCollections.deliveries)
        .doc(standEvent.outboxId)
        .get()
    ).get('status');
    if (status === 'delivered') delivered = 'replayed';
  }
  if (delivered !== 'delivered' && delivered !== 'replayed') {
    throw new Error(`stand_event_delivery_failed:${String(delivered)}`);
  }
}

async function createBookings(tokens: ReadonlyMap<StandUserLabel, string>): Promise<number> {
  for (const plan of standBookings) {
    const idToken = required(tokens.get(plan.user), plan.user);
    const command = createCommand({
      requestId: plan.requestId,
      idempotencyKey: plan.idempotencyKey,
      occurredAgainstEventRevision: standEvent.materialRevision,
      payload: {
        occurrenceId: standEvent.occurrenceId,
        inventoryPoolId: standEvent.poolId,
        channel: standEvent.channel,
        participantUnits: plan.participantUnits,
        namedGuests: [],
      },
    });
    const created = await callBookingFunction('createInternalBookingV1', command, idToken);
    const result = created.body.result as Record<string, unknown> | undefined;
    if (result?.kind !== 'succeeded') {
      throw new Error(`booking_failed:${plan.label}:${JSON.stringify(result)}`);
    }
    const booking = result.booking as Record<string, unknown>;
    const bookingId = String(booking.id);
    if (plan.cancelAfterCreate) {
      const cancelled = await callBookingFunction(
        'cancelInternalBookingV1',
        {
          schemaVersion: 1,
          commandType: 'cancelBooking',
          requestId: `${plan.requestId}-cancel`,
          idempotencyKey: `${plan.idempotencyKey}-cancel`,
          expectedBookingRevision: booking.revision,
          payload: { bookingId, reasonCode: 'user_cancelled' },
        },
        idToken,
      );
      const cancelResult = cancelled.body.result as Record<string, unknown> | undefined;
      if (cancelResult?.kind !== 'succeeded') {
        throw new Error(`booking_cancel_failed:${plan.label}:${JSON.stringify(cancelResult)}`);
      }
    }
  }
  return standBookings.length;
}

function required<T>(value: T | undefined, label: string): T {
  if (value === undefined) throw new Error(`stand_seed_missing:${label}`);
  return value;
}
