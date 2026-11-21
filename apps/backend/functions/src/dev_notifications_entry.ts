import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { error as logError, info } from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import type { Response } from 'express';

import {
  consumeCloudBookingEffect,
  createDevNotifications,
  reconcileCloudBookingNotifications,
  handleDevNotifications,
  type DevNotificationsCallable,
} from './dev_notifications_composition.js';
import { failureShape } from './shared/failure_shape.js';
import { createDevFirebaseProviderIdentityVerifier } from './modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { loadTimeCloudProject, runtimeServiceAccount } from './shared/cloud_runtime_projects.js';

// N3c isolated entry (codebase n3c-notifications), owner-approved 2026-11-13.
// Not re-exported by index.ts. Callable wire protocol over onRequest, as in
// N2c/N3a.2: the mobile dev transport posts {data} with the Firebase ID token.
// N4a: dev or staging from the deploy environment (reviewed list, never production).
const projectId = loadTimeCloudProject(process.env);
const options = {
  region: 'europe-west1',
  memory: '256MiB' as const,
  cpu: 1,
  timeoutSeconds: 60,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  serviceAccount: runtimeServiceAccount('runtime-notifications', projectId),
  invoker: 'public' as const,
};
const maxBodyBytes = 16_384;

function app() {
  const existing = getApps().find((candidate) => candidate.name === 'recharge-dev-notifications');
  if (existing !== undefined && existing.options.projectId !== projectId)
    throw new Error('binding');
  return existing ?? initializeApp({ projectId }, 'recharge-dev-notifications');
}

/** The runtime switch and the owner allowlist; anything missing is 503 (fail closed). */
export function devNotificationsOpen(environment: NodeJS.ProcessEnv): readonly string[] | null {
  if (
    environment.GCLOUD_PROJECT !== projectId ||
    environment.N3C_DEV_ENABLED !== 'true' ||
    environment.FIRESTORE_EMULATOR_HOST !== undefined ||
    environment.FIREBASE_AUTH_EMULATOR_HOST !== undefined
  )
    return null;
  const allowed = (environment.N3C_ALLOWED_FIREBASE_UIDS ?? '')
    .split(',')
    .map((uid) => uid.trim())
    .filter(Boolean);
  if (allowed.length === 0 || allowed.some((uid) => !/^[A-Za-z0-9]{20,128}$/u.test(uid)))
    return null;
  return allowed;
}

async function dispatch(callable: DevNotificationsCallable, request: Request, response: Response) {
  response.set('Cache-Control', 'no-store');
  const allowed = devNotificationsOpen(process.env);
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
    const result = await handleDevNotifications({
      callable,
      firebaseUid: identity.firebaseUid,
      data: body.data,
      firestore,
      compose: () => createDevNotifications({ app: firebase, firestore }),
    });
    info('dev_notifications_result', {
      callable,
      kind: result.kind,
      code: typeof result.code === 'string' ? result.code : null,
    });
    response.status(200).json({ result });
  } catch (error) {
    // No request, SDK exception payloads, tokens or credentials in logs or responses.
    info('dev_notifications_failure', { callable, ...failureShape(error) });
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
  }
}

export const notificationsQueryV1 = onRequest(options, (req, res) =>
  dispatch('notificationsQueryV1', req, res),
);
export const notificationsCommandV1 = onRequest(options, (req, res) =>
  dispatch('notificationsCommandV1', req, res),
);
export const pushDeviceCommandV1 = onRequest(options, (req, res) =>
  dispatch('pushDeviceCommandV1', req, res),
);
export const sendSelfTestNotificationV1 = onRequest(options, (req, res) =>
  dispatch('sendSelfTestNotificationV1', req, res),
);

/** Push reconciliation: due retries and stale registrations, while the switch is on. */
const { invoker, ...scheduleOptions } = options;
void invoker; // Cloud Scheduler calls with the runtime identity; no public invoker.
export const reconcilePushV1 = onSchedule(
  { ...scheduleOptions, schedule: 'every 15 minutes', timeZone: 'Etc/UTC', retryCount: 0 },
  async () => {
    if (devNotificationsOpen(process.env) === null) return;
    const firebase = app();
    const firestore = getFirestore(firebase);
    // Round 1 (2026-11-21): with the Booking consumer switch on, the pass also
    // retries and catches up Booking effects (and still runs the push pass).
    if (bookingConsumeOpen(process.env)) {
      try {
        const report = await reconcileCloudBookingNotifications({ app: firebase, firestore });
        info('dev_booking_reconcile', {
          complete: report.complete,
          scanned: report.scanned,
          outcomes: report.outcomes,
          findings: report.findings.length,
          push: report.push ?? null,
        });
        return;
      } catch (error) {
        // A failed Booking pass (e.g. an index still building) is reported and
        // never stops the push pass below.
        logError('dev_booking_reconcile_failure', failureShape(error));
      }
    }
    const report = await createDevNotifications({ app: firebase, firestore }).push.reconcile();
    info('dev_push_reconcile', report);
  },
);

/**
 * Round 1 stage 1.3 (owner 2026-11-20): Booking effects reach the inbox and push
 * in the cloud. Deploy switch N3C_BOOKING_CONSUME_ENABLED on top of the runtime
 * switch (a new Operations switch would change the pinned execution manifest);
 * the pinned incident switch is checked per record. No retry: a missed record is
 * left for reconciliation, never redelivered blindly.
 */
export function bookingConsumeOpen(environment: NodeJS.ProcessEnv): boolean {
  return (
    devNotificationsOpen(environment) !== null && environment.N3C_BOOKING_CONSUME_ENABLED === 'true'
  );
}

export const consumeBookingNotificationEffectV1 = onDocumentCreated(
  { ...scheduleOptions, document: 'bookingOutbox/{outboxId}', retry: false },
  async (event) => {
    if (!bookingConsumeOpen(process.env)) return;
    const firebase = app();
    const firestore = getFirestore(firebase);
    try {
      const outcome = await consumeCloudBookingEffect({
        firestore,
        collection: 'bookingOutbox',
        outboxId: event.params.outboxId,
        data: event.data?.data(),
        compose: () => createDevNotifications({ app: firebase, firestore }),
      });
      info('dev_booking_effect_consumed', { outcome });
    } catch (error) {
      info('dev_booking_effect_failure', failureShape(error));
    }
  },
);
