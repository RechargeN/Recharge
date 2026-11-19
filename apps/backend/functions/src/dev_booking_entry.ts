import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import type { Response } from 'express';

import {
  createDevBookingComposition,
  handleDevBooking,
  isDevBookingCallable,
  type DevBookingCallable,
} from './dev_booking_composition.js';
import { createDevFirebaseProviderIdentityVerifier } from './modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import {
  loadTimeCloudProject,
  runtimeServiceAccount,
  stagingCloudProject,
} from './shared/cloud_runtime_projects.js';
import { failureShape } from './shared/failure_shape.js';
import { systemServerClock } from './shared/server_clock.js';
import {
  cloudEventDeliveryGate,
  processEventBookingOutboxDocument,
  runPendingEventBookingDeliveries,
} from './booking/event_projection_runtime.js';
import {
  cloudReconfirmationGate,
  runReconfirmationDeadlineWorker,
} from './booking/reconfirmation_deadline_worker.js';

// N4c isolated entry (codebase n4c-booking), owner-approved 2026-11-16. Not
// re-exported by index.ts. Callable wire protocol over onRequest, as in
// N2c/N3a.2/N3c: the mobile transport posts {data} with the Firebase ID token.
// dev or staging from the deploy environment (reviewed list, never production).
const projectId = loadTimeCloudProject(process.env);
const options = {
  region: 'europe-west1',
  memory: '256MiB' as const,
  cpu: 1,
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  serviceAccount: runtimeServiceAccount('runtime-booking', projectId),
  invoker: 'public' as const,
};
const maxBodyBytes = 16_384;

/**
 * Load-run limits (owner decision 2026-11-16: raised for the Booking load run in
 * staging only). Read at deploy from the staging `.env`; anything missing,
 * malformed or outside the reviewed bounds falls back to one instance and one
 * request, and dev always stays at 1/1.
 */
export function loadRunLimits(environment: NodeJS.ProcessEnv): {
  readonly maxInstances: number;
  readonly concurrency: number;
} {
  const bounded = (value: string | undefined, maximum: number) =>
    value !== undefined && /^[1-9][0-9]?$/u.test(value) && Number(value) <= maximum
      ? Number(value)
      : 1;
  if (environment.GCLOUD_PROJECT !== stagingCloudProject)
    return { maxInstances: 1, concurrency: 1 };
  return {
    maxInstances: bounded(environment.N4C_LOAD_MAX_INSTANCES, 3),
    concurrency: bounded(environment.N4C_LOAD_CONCURRENCY, 40),
  };
}

function app() {
  const existing = getApps().find((candidate) => candidate.name === 'recharge-dev-booking');
  if (existing !== undefined && existing.options.projectId !== projectId)
    throw new Error('binding');
  return existing ?? initializeApp({ projectId }, 'recharge-dev-booking');
}

function runtimeOpen(environment: NodeJS.ProcessEnv): boolean {
  return (
    environment.GCLOUD_PROJECT === projectId &&
    environment.N4C_BOOKING_ENABLED === 'true' &&
    environment.FIRESTORE_EMULATOR_HOST === undefined &&
    environment.FIREBASE_AUTH_EMULATOR_HOST === undefined
  );
}

/** The runtime switch and the owner allowlist; anything missing is 503 (fail closed). */
export function devBookingOpen(environment: NodeJS.ProcessEnv): readonly string[] | null {
  if (!runtimeOpen(environment)) return null;
  const allowed = (environment.N4C_ALLOWED_FIREBASE_UIDS ?? '')
    .split(',')
    .map((uid) => uid.trim())
    .filter(Boolean);
  if (allowed.length === 0 || allowed.some((uid) => !/^[A-Za-z0-9]{20,128}$/u.test(uid)))
    return null;
  return allowed;
}

/**
 * The staging load ingress is open only in staging, only while both switches are
 * on. It never opens in dev, whatever the environment says.
 */
export function devBookingLoadOpen(environment: NodeJS.ProcessEnv): boolean {
  return (
    runtimeOpen(environment) &&
    environment.GCLOUD_PROJECT === stagingCloudProject &&
    environment.N4C_LOAD_ENABLED === 'true'
  );
}

export const loadActorPattern = /^n4cload[0-9]{4}$/u;
export const loadOccurrencePrefix = 'occ_n4cload_';

/**
 * A load request names a synthetic actor and may only create against, or read the
 * availability of, a synthetic occurrence. Cancel, reconfirm and own reads are
 * bound to the synthetic actor's own Bookings by the ordinary authority.
 */
export function loadRequestAllowed(callable: DevBookingCallable, actor: unknown, data: unknown) {
  if (typeof actor !== 'string' || !loadActorPattern.test(actor)) return false;
  if (callable !== 'createInternalBookingV1' && callable !== 'getEventAvailabilityV1') return true;
  const payload =
    typeof data === 'object' && data !== null && !Array.isArray(data)
      ? (data as Record<string, unknown>).payload
      : undefined;
  const occurrenceId =
    typeof payload === 'object' && payload !== null
      ? (payload as Record<string, unknown>).occurrenceId
      : undefined;
  return typeof occurrenceId === 'string' && occurrenceId.startsWith(loadOccurrencePrefix);
}

/** The cost kill switch: stops new Booking creation; cancel and reads stay open. */
export function bookingCreateDisabled(environment: NodeJS.ProcessEnv): boolean {
  return environment.N4C_BOOKING_CREATE_DISABLE === 'true';
}

async function dispatch(callable: DevBookingCallable, request: Request, response: Response) {
  response.set('Cache-Control', 'no-store');
  const allowed = devBookingOpen(process.env);
  if (allowed === null || request.method !== 'POST' || request.rawBody.byteLength > maxBodyBytes) {
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
    return;
  }
  const authorization = request.get('authorization') ?? '';
  if (!/^Bearer [^\s]{1,8192}$/u.test(authorization)) {
    response.status(401).json({ error: { status: 'UNAUTHENTICATED' } });
    return;
  }
  try {
    const firebase = app();
    const verifier = createDevFirebaseProviderIdentityVerifier(firebase);
    const nowUtc = new Date().toISOString();
    const proof = authorization.slice(7);
    const identity =
      (await verifier.verifyIdentity(
        { provider: 'google', providerTenant: projectId, proof },
        nowUtc,
      )) ??
      (await verifier.verifyIdentity(
        { provider: 'apple', providerTenant: projectId, proof },
        nowUtc,
      ));
    if (identity === null || !allowed.includes(identity.firebaseUid)) {
      response.status(401).json({ error: { status: 'UNAUTHENTICATED' } });
      return;
    }
    const body = JSON.parse(request.rawBody.toString('utf8')) as { data?: unknown };
    const firestore = getFirestore(firebase);
    const result = await handleDevBooking({
      callable,
      firebaseUid: identity.firebaseUid,
      rawBody: request.rawBody,
      data: body.data,
      firestore,
      projectId,
      composition: createDevBookingComposition(firestore, bookingCreateDisabled(process.env)),
      ...(request.ip === undefined ? {} : { ip: request.ip }),
    });
    info('dev_booking_result', { callable, kind: result.kind });
    response.status(200).json({ result });
  } catch (error) {
    // No request, SDK exception payloads, tokens or credentials in logs or responses.
    info('dev_booking_failure', { callable, ...failureShape(error) });
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
  }
}

export const createInternalBookingV1 = onRequest(options, (req, res) =>
  dispatch('createInternalBookingV1', req, res),
);
export const cancelInternalBookingV1 = onRequest(options, (req, res) =>
  dispatch('cancelInternalBookingV1', req, res),
);
export const reconfirmInternalBookingV1 = onRequest(options, (req, res) =>
  dispatch('reconfirmInternalBookingV1', req, res),
);
export const getMyBookingV1 = onRequest(options, (req, res) =>
  dispatch('getMyBookingV1', req, res),
);
export const listMyBookingsV1 = onRequest(options, (req, res) =>
  dispatch('listMyBookingsV1', req, res),
);
export const getEventAvailabilityV1 = onRequest(options, (req, res) =>
  dispatch('getEventAvailabilityV1', req, res),
);

/**
 * Staging load ingress (N4c, owner choice 2026-11-16: synthetic participants).
 * Cloud Run IAM is the gate: the function is private, so only a caller holding
 * the invoker permission on it reaches the code — there is no shared secret and
 * no public path. The body names the Booking callable, a synthetic actor and the
 * ordinary {data}; the same pipeline, authority, rate limits and transactions run.
 */
export const bookingLoadV1 = onRequest(
  { ...options, ...loadRunLimits(process.env), invoker: 'private' as const },
  async (request, response) => {
    response.set('Cache-Control', 'no-store');
    if (
      !devBookingLoadOpen(process.env) ||
      request.method !== 'POST' ||
      request.rawBody.byteLength > maxBodyBytes
    ) {
      response.status(503).json({ error: { status: 'UNAVAILABLE' } });
      return;
    }
    let callable: unknown;
    try {
      const body = JSON.parse(request.rawBody.toString('utf8')) as {
        callable?: unknown;
        loadActor?: unknown;
        data?: unknown;
      };
      callable = body.callable;
      if (
        !isDevBookingCallable(callable) ||
        !loadRequestAllowed(callable, body.loadActor, body.data)
      ) {
        response.status(403).json({ error: { status: 'PERMISSION_DENIED' } });
        return;
      }
      const firestore = getFirestore(app());
      const result = await handleDevBooking({
        callable,
        firebaseUid: body.loadActor as string,
        rawBody: Buffer.from(JSON.stringify({ data: body.data }), 'utf8'),
        data: body.data,
        firestore,
        projectId,
        composition: createDevBookingComposition(firestore, bookingCreateDisabled(process.env)),
      });
      response.status(200).json({ result });
    } catch (error) {
      info('dev_booking_load_failure', {
        callable: isDevBookingCallable(callable) ? callable : null,
        ...failureShape(error),
      });
      response.status(503).json({ error: { status: 'UNAVAILABLE' } });
    }
  },
);

/**
 * Round 2.2 (owner approval 2026-11-19): Event → Booking delivery in the cloud.
 * The same workers as the Emulator (`index.ts`), bound to this runtime's
 * project and runtime account. Each one is also behind its Operations
 * emergency switch (round 2.1): in the cloud a missing switch is contained, so
 * a deploy delivers nothing until an operator opens it. A closed runtime does
 * nothing.
 */
const workerOptions = {
  region: 'europe-west1',
  memory: '256MiB' as const,
  cpu: 1,
  timeoutSeconds: 120,
  minInstances: 0,
  maxInstances: 1,
  serviceAccount: runtimeServiceAccount('runtime-booking', projectId),
};

export const consumeEventBookingOutboxV1 = onDocumentCreated(
  { ...workerOptions, document: 'eventBookingOutbox/{outboxId}', retry: false },
  async (event) => {
    if (!runtimeOpen(process.env)) return;
    const firestore = getFirestore(app());
    await processEventBookingOutboxDocument(
      firestore,
      event.params.outboxId,
      systemServerClock.now().toISOString(),
      cloudEventDeliveryGate(firestore),
    );
  },
);

export const retryEventBookingProjectionDeliveriesV1 = onSchedule(
  { ...workerOptions, schedule: 'every 5 minutes', retryCount: 0 },
  async () => {
    if (!runtimeOpen(process.env)) return;
    const firestore = getFirestore(app());
    await runPendingEventBookingDeliveries(
      firestore,
      systemServerClock.now().toISOString(),
      20,
      cloudEventDeliveryGate(firestore),
    );
  },
);

export const releaseMissedReconfirmationsV1 = onSchedule(
  { ...workerOptions, schedule: 'every 5 minutes', retryCount: 0 },
  async () => {
    if (!runtimeOpen(process.env)) return;
    const firestore = getFirestore(app());
    await runReconfirmationDeadlineWorker(
      firestore,
      systemServerClock.now().toISOString(),
      20,
      cloudReconfirmationGate(firestore),
    );
  },
);

// Round 2.2: the cloud Event → Booking handoff ships with this codebase (same
// runtime account, same release), behind its own runtime and Operations switches.
export { consumeContentEffectV1 } from './dev_content_effects_entry.js';
// Step 2 (owner decision 2026-11-20): the DSR intake, operator path and worker
// ship in this codebase under runtime-booking, behind the privacy switch.
export { privacyOperatorV1, privacyRequestV1, runPrivacyRequestsV1 } from './dev_privacy_entry.js';
