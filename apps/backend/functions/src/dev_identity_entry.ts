import { createHmac, randomUUID } from 'node:crypto';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';
import { createDevFirebaseProviderIdentityVerifier } from './modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import { createDevIdentitySessionBinding } from './modules/identity_publisher/infrastructure/dev_identity_session_binding.js';
import { handleDevIdentityRequest } from './modules/identity_publisher/infrastructure/dev_identity_session_handler.js';
import { FirestoreAbuseRateLimiter } from './platform/security/firestore_abuse_rate_limiter.js';

const projectId = 'recharge-dev-n2a01';
const options = {
  region: 'europe-west1',
  memory: '256MiB' as const,
  cpu: 1,
  timeoutSeconds: 15,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  serviceAccount: 'runtime-identity@recharge-dev-n2a01.iam.gserviceaccount.com',
  invoker: 'public' as const,
  secrets: ['DEV_AUTH_INGRESS_HMAC'],
};

async function dispatch(callableName: string, request: Request, response: Response): Promise<void> {
  response.set('Cache-Control', 'no-store');
  if (
    process.env.GCLOUD_PROJECT !== projectId ||
    process.env.N2C_DEV_AUTH_ENABLED !== 'true' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined ||
    process.env.FIRESTORE_EMULATOR_HOST !== undefined ||
    request.rawBody.byteLength > 8192
  ) {
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
    return;
  }
  const key = process.env.DEV_AUTH_INGRESS_HMAC;
  const allowed = (process.env.N2C_ALLOWED_APP_IDS ?? '').split(',').filter(Boolean);
  const authorization = request.get('authorization');
  const provider = request.get('x-recharge-identity-provider');
  if (
    key === undefined ||
    Buffer.byteLength(key) < 32 ||
    authorization === undefined ||
    !/^Bearer [^\s]{1,8192}$/.test(authorization) ||
    (provider !== 'google' && provider !== 'apple') ||
    allowed.length === 0 ||
    allowed.some((id) => !/^1:420479958348:(android|ios):[a-f0-9]+$/.test(id))
  ) {
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
    return;
  }
  try {
    const existing = getApps().find((app) => app.name === 'recharge-dev-identity-runtime');
    if (existing !== undefined && existing.options.projectId !== projectId)
      throw new Error('binding');
    const app = existing ?? initializeApp({ projectId }, 'recharge-dev-identity-runtime');
    // App Check is observe-only in this dev slice. Admission identity is verified Firebase uid.
    const identity = await createDevFirebaseProviderIdentityVerifier(app).verifyIdentity(
      { provider, providerTenant: projectId, proof: authorization.slice(7) },
      new Date().toISOString(),
    );
    if (identity === null) {
      response.status(401).json({ error: { status: 'UNAUTHENTICATED' } });
      return;
    }
    const firestore = getFirestore(app);
    const limiter = new FirestoreAbuseRateLimiter(firestore);
    const result = await handleDevIdentityRequest(
      {
        method: request.method,
        callableName,
        body: request.rawBody,
        headers: {
          'content-type': request.get('content-type'),
          authorization: request.get('authorization'),
          'x-firebase-appcheck': request.get('x-firebase-appcheck'),
          'x-recharge-identity-provider': request.get('x-recharge-identity-provider'),
        },
      },
      {
        projectId,
        enabled: true,
        now: () => new Date(),
        sessions: createDevIdentitySessionBinding(app, allowed, {
          appCheckMode: 'observe',
          observeAppCheck: (state) => info('dev_app_check_observation', { state, mode: 'observe' }),
        }),
        appCheckMode: 'observe',
        admitRequest: async () => {
          const now = new Date();
          const address = createHmac('sha256', key)
            .update(`${now.toISOString().slice(0, 10)}|${identity.firebaseUid}`)
            .digest('hex');
          const id = randomUUID(); // Never let a client requestId bypass admission by replay.
          const decision = await limiter.consume({
            operation: 'identity.session.ingress',
            attemptRequestId: id,
            transportIdentityHash: address,
            installationId: `ingress-${address}`,
            environmentId: projectId,
            marketId: 'LV',
            now,
            correlationId: id,
          });
          return decision.allowed;
        },
      },
    );
    response.status(result.status).json(result.body);
  } catch {
    // No request/SDK exception payloads or credentials in logs/responses.
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
  }
}

// This isolated entry is not re-exported by index.ts and is not the default package main.
export const establishIdentitySessionV1 = onRequest(options, (req, res) =>
  dispatch('establishIdentitySessionV1', req, res),
);
export const refreshIdentitySessionV1 = onRequest(options, (req, res) =>
  dispatch('refreshIdentitySessionV1', req, res),
);
export const readIdentitySessionV1 = onRequest(options, (req, res) =>
  dispatch('readIdentitySessionV1', req, res),
);
export const recoverIdentitySessionsV1 = onRequest(options, (req, res) =>
  dispatch('recoverIdentitySessionsV1', req, res),
);
export const revokeIdentitySessionV1 = onRequest(options, (req, res) =>
  dispatch('revokeIdentitySessionV1', req, res),
);
