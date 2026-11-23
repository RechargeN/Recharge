import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';

import {
  createDevContentMedia,
  devContentTypesFor,
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
/**
 * Gap plan round 1, item 1.3 (owner approval 2026-11-23): read endpoints the
 * app calls in parallel take 10 requests per instance. With concurrency 1 a
 * parallel request waited for the single instance and failed with 500
 * (staging contentQueryV1, 2026-11-19). maxInstances and cpu are unchanged, so
 * the cost ceiling is the same.
 */
export const readQueryConcurrency = 10;
const readOptions = { ...options, concurrency: readQueryConcurrency };
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

/**
 * Pilot 2.1 (owner 2026-11-21, variant A): the Library opens only with the
 * runtime and its own deploy switch; the pinned execution manifest is unchanged.
 */
export function libraryOpen(environment: NodeJS.ProcessEnv): boolean {
  return devRuntimeOpen(environment) !== null && environment.P2_LIBRARY_ENABLED === 'true';
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
      libraryEnabled: libraryOpen(process.env),
      contentTypes: devContentTypesFor(process.env),
      catalogEnabled:
        devRuntimeOpen(process.env) !== null && process.env.P2_CATALOG_ENABLED === 'true',
      routeEnabled: devRuntimeOpen(process.env) !== null && process.env.P2_ROUTE_ENABLED === 'true',
      planningEnabled:
        devRuntimeOpen(process.env) !== null && process.env.P2_PLANNING_ENABLED === 'true',
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
export const contentQueryV1 = onRequest(readOptions, (req, res) =>
  dispatch('contentQueryV1', req, res),
);
export const mediaCommandV1 = onRequest(options, (req, res) =>
  dispatch('mediaCommandV1', req, res),
);
export const mediaQueryV1 = onRequest(options, (req, res) => dispatch('mediaQueryV1', req, res));
export const uploadMediaBytesV1 = onRequest(options, (req, res) =>
  dispatch('uploadMediaBytesV1', req, res),
);

export const libraryCommandV1 = onRequest(options, (req, res) =>
  dispatch('libraryCommandV1', req, res),
);
export const libraryQueryV1 = onRequest(options, (req, res) =>
  dispatch('libraryQueryV1', req, res),
);

export const quickPlanCommandV1 = onRequest(options, (req, res) =>
  dispatch('quickPlanCommandV1', req, res),
);
export const quickPlanQueryV1 = onRequest(options, (req, res) =>
  dispatch('quickPlanQueryV1', req, res),
);
export const scenarioCommandV1 = onRequest(options, (req, res) =>
  dispatch('scenarioCommandV1', req, res),
);
export const scenarioQueryV1 = onRequest(options, (req, res) =>
  dispatch('scenarioQueryV1', req, res),
);
export const routeCommandV1 = onRequest(options, (req, res) =>
  dispatch('routeCommandV1', req, res),
);
export const routeQueryV1 = onRequest(options, (req, res) => dispatch('routeQueryV1', req, res));
export const discoverQueryV1 = onRequest(options, (req, res) =>
  dispatch('discoverQueryV1', req, res),
);

export { failureShape };
