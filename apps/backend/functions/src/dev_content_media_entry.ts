import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';

import {
  createDevContentMedia,
  handleDevContentMedia,
  type DevCallableName,
} from './dev_content_media_composition.js';
import { failureShape } from './shared/failure_shape.js';
import { createDevFirebaseProviderIdentityVerifier } from './modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { loadTimeCloudProject, runtimeServiceAccount } from './shared/cloud_runtime_projects.js';

// N3a.2 isolated entry (codebase n3a2-content-media). Not re-exported by
// index.ts. Callable wire protocol over onRequest, as in N2c: the mobile dev
// transport posts {data} with the Firebase ID token and receives {result}.
// N4a: dev or staging from the deploy environment (reviewed list, never production).
const projectId = loadTimeCloudProject(process.env);
const options = {
  region: 'europe-west1',
  memory: '512MiB' as const,
  cpu: 1,
  timeoutSeconds: 120,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  serviceAccount: runtimeServiceAccount('runtime-media', projectId),
  invoker: 'public' as const,
  secrets: ['MEDIA_TOOLS_TOKEN'],
};
/** 1 MiB image as base64 plus the envelope. */
const maxBodyBytes = 1_500_000;

function app() {
  const existing = getApps().find((candidate) => candidate.name === 'recharge-dev-content-media');
  if (existing !== undefined && existing.options.projectId !== projectId)
    throw new Error('binding');
  return existing ?? initializeApp({ projectId }, 'recharge-dev-content-media');
}

/** The runtime switch and the owner allowlist; anything missing is 503 (fail closed). */
export function devRuntimeOpen(environment: NodeJS.ProcessEnv): readonly string[] | null {
  if (
    environment.GCLOUD_PROJECT !== projectId ||
    environment.N3A2_DEV_ENABLED !== 'true' ||
    environment.RECHARGE_DEV_RUNTIME !== 'content-media' ||
    environment.RECHARGE_MEDIA_STORAGE !== 'dev-cloud' ||
    environment.RECHARGE_MEDIA_TOOLS !== 'dev-cloud' ||
    environment.FIRESTORE_EMULATOR_HOST !== undefined ||
    environment.FIREBASE_AUTH_EMULATOR_HOST !== undefined
  )
    return null;
  const allowed = (environment.N3A2_ALLOWED_FIREBASE_UIDS ?? '')
    .split(',')
    .map((uid) => uid.trim())
    .filter(Boolean);
  if (allowed.length === 0 || allowed.some((uid) => !/^[A-Za-z0-9]{20,128}$/u.test(uid)))
    return null;
  return allowed;
}

async function dispatch(callable: DevCallableName, request: Request, response: Response) {
  response.set('Cache-Control', 'no-store');
  const allowed = devRuntimeOpen(process.env);
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
    // App Check stays observe-only in dev (N2c decision); only presence is logged.
    info('dev_app_check_observation', {
      present: (request.get('x-firebase-appcheck') ?? '') !== '',
      callable,
    });
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
    const result = await handleDevContentMedia({
      callable,
      firebaseUid: identity.firebaseUid,
      data: body.data,
      firestore,
      compose: () =>
        createDevContentMedia({
          app: firebase,
          firestore,
          // Secret Manager injects MEDIA_TOOLS_TOKEN; the tools client reads its own name.
          environment: {
            ...process.env,
            RECHARGE_MEDIA_TOOLS_TOKEN: process.env.MEDIA_TOOLS_TOKEN,
          },
        }),
    });
    info('dev_content_media_result', {
      callable,
      kind: result.kind,
      code: typeof result.code === 'string' ? result.code : null,
    });
    response.status(200).json({ result });
  } catch (error) {
    // No request, SDK exception payloads or credentials in logs or responses.
    info('dev_content_media_failure', { callable, ...failureShape(error) });
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
  }
}

export const contentCommandV1 = onRequest(options, (req, res) =>
  dispatch('contentCommandV1', req, res),
);
export const contentQueryV1 = onRequest(options, (req, res) =>
  dispatch('contentQueryV1', req, res),
);
export const mediaCommandV1 = onRequest(options, (req, res) =>
  dispatch('mediaCommandV1', req, res),
);
export const mediaQueryV1 = onRequest(options, (req, res) => dispatch('mediaQueryV1', req, res));
export const uploadMediaBytesV1 = onRequest(options, (req, res) =>
  dispatch('uploadMediaBytesV1', req, res),
);

export { failureShape };
