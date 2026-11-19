import { createHash, randomUUID } from 'node:crypto';

import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { info } from 'firebase-functions/logger';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import type { Response } from 'express';

import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import { createDevFirebaseProviderIdentityVerifier } from './modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { PrivacyDomainTaskRunner } from './modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from './modules/privacy_orchestration/application/privacy_orchestration_service.js';
import {
  PrivacyRequestIntake,
  type PrivacyIntakeResult,
} from './modules/privacy_orchestration/application/privacy_request_intake.js';
import type { PrivacyLegalHoldScope } from './modules/privacy_orchestration/domain/privacy_legal_hold.js';
import {
  FirestorePrivacyLegalHoldService,
  privacyHoldCollections,
} from './modules/privacy_orchestration/infrastructure/firestore_privacy_legal_hold_service.js';
import {
  FirestorePrivacyOrchestrationRepository,
  privacyOrchestrationCollections,
} from './modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { resolveBookingActor } from './shared/auth_context.js';
import { loadTimeCloudProject, runtimeServiceAccount } from './shared/cloud_runtime_projects.js';
import { failureShape } from './shared/failure_shape.js';
import { systemServerClock } from './shared/server_clock.js';

// Step 2 (owner decisions 2026-11-20: Privacy under runtime-booking, media
// objects stay blocked, access counts records only, operator path for synthetic
// subjects, one 5-minute worker). Shipped in the n4c-booking codebase; not
// re-exported by index.ts. Everything is contained unless the deploy opens it
// (N5D_PRIVACY_ENABLED; a new Operations switch would change the pinned
// execution manifest); dev or staging only, never production.
const projectId = loadTimeCloudProject(process.env);
const maxBodyBytes = 8_192;
const options = {
  region: 'europe-west1',
  memory: '256MiB' as const,
  cpu: 1,
  timeoutSeconds: 60,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  serviceAccount: runtimeServiceAccount('runtime-booking', projectId),
};

/** RFC 9562 UUIDv5 (SHA-1, name-based) without a new dependency. */
export function uuidV5(name: string, namespace: string): string {
  const hash = createHash('sha1')
    .update(Buffer.from(namespace.replace(/-/gu, ''), 'hex'))
    .update(name, 'utf8')
    .digest();
  hash[6] = (hash[6]! & 0x0f) | 0x50;
  hash[8] = (hash[8]! & 0x3f) | 0x80;
  const hex = hash.subarray(0, 16).toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** Deterministic synthetic subjects; the operator path accepts nothing else. */
export const syntheticSubjectNamespace = '8f6f3c2e-6b1d-5d3a-9a51-2f6c1b7e4d10';
export const syntheticPrivacySubjects: readonly string[] = Object.freeze(
  Array.from({ length: 20 }, (_, index) =>
    uuidV5(`n5d-synthetic-${String(index + 1)}`, syntheticSubjectNamespace),
  ),
);
export const syntheticHoldOperator = 'n5d-operator';

function app() {
  const existing = getApps().find((candidate) => candidate.name === 'recharge-dev-privacy');
  if (existing !== undefined && existing.options.projectId !== projectId)
    throw new Error('binding');
  return existing ?? initializeApp({ projectId }, 'recharge-dev-privacy');
}

/** Same runtime switch and owner allowlist as the Booking entry; missing → closed. */
export function devPrivacyOpen(environment: NodeJS.ProcessEnv): readonly string[] | null {
  if (
    environment.GCLOUD_PROJECT !== projectId ||
    environment.N4C_BOOKING_ENABLED !== 'true' ||
    environment.FIRESTORE_EMULATOR_HOST !== undefined ||
    environment.FIREBASE_AUTH_EMULATOR_HOST !== undefined
  )
    return null;
  const allowed = (environment.N4C_ALLOWED_FIREBASE_UIDS ?? '')
    .split(',')
    .map((uid) => uid.trim())
    .filter(Boolean);
  if (allowed.length === 0 || allowed.some((uid) => !/^[A-Za-z0-9]{20,128}$/u.test(uid)))
    return null;
  return allowed;
}

/** The deploy-time privacy switch; anything but an explicit `true` is closed. */
export function privacySwitchOpen(environment: NodeJS.ProcessEnv = process.env): boolean {
  return environment.N5D_PRIVACY_ENABLED === 'true';
}

function compose(firestore: Firestore) {
  const repository = new FirestorePrivacyOrchestrationRepository(firestore);
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  return {
    repository,
    service,
    intake: new PrivacyRequestIntake(firestore, service, repository),
  };
}

const requestTypes = ['access', 'erasure', 'restriction'] as const;
type RequestType = (typeof requestTypes)[number];
const isRequestType = (value: unknown): value is RequestType =>
  typeof value === 'string' && (requestTypes as readonly string[]).includes(value);
const idempotencyPattern = /^[A-Za-z0-9._:-]{8,128}$/u;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u;

function record(value: unknown): Readonly<Record<string, unknown>> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

const rejected = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });
const fromIntake = (result: PrivacyIntakeResult) =>
  result.ok ? { schemaVersion: 1, kind: 'succeeded', request: result.view } : rejected(result.code);

/**
 * One request of the signed-in subject: submit a DSR or read the status of
 * one of their own requests. The subject is the server-verified Session user;
 * the client never names it.
 */
export async function handlePrivacyRequest(input: {
  readonly firestore: Firestore;
  readonly firebaseUid: string;
  readonly data: unknown;
  readonly nowUtc: string;
}): Promise<Readonly<Record<string, unknown>>> {
  const data = record(input.data);
  if (data === undefined || data.schemaVersion !== 1) return rejected('invalid_contract');
  const actor = resolveBookingActor({ uid: input.firebaseUid, token: {} }, data.sessionContext);
  if (!actor.ok) return rejected('access_denied');
  if (!privacySwitchOpen()) return rejected('temporarily_unavailable');
  const { intake, repository } = compose(input.firestore);
  const payload = record(data.payload);
  if (data.commandType === 'submitPrivacyRequest') {
    if (
      payload === undefined ||
      typeof payload.requestId !== 'string' ||
      !uuidPattern.test(payload.requestId) ||
      !isRequestType(payload.requestType) ||
      typeof payload.idempotencyKey !== 'string' ||
      !idempotencyPattern.test(payload.idempotencyKey)
    )
      return rejected('invalid_contract');
    return fromIntake(
      await intake.submitForSession(actor.actor, {
        requestId: payload.requestId,
        requestType: payload.requestType,
        idempotencyKey: payload.idempotencyKey,
        nowUtc: input.nowUtc,
      }),
    );
  }
  if (data.commandType === 'getPrivacyRequest') {
    if (
      payload === undefined ||
      typeof payload.requestId !== 'string' ||
      !uuidPattern.test(payload.requestId)
    )
      return rejected('invalid_contract');
    const decision = await new FirestoreBookingAccessAuthority(input.firestore).authorize(
      actor.actor,
      new Date(input.nowUtc),
    );
    if (!decision.allowed) return rejected('access_denied');
    const request = await repository.get(payload.requestId);
    // Another person's request reads exactly like a missing one.
    if (request === null || request.subjectId !== decision.userId)
      return rejected('request_not_found');
    return { schemaVersion: 1, kind: 'succeeded', request: await intake.view(request) };
  }
  return rejected('invalid_contract');
}

/**
 * Operator path (owner decision 2026-11-20, option 3a): the same intake and
 * worker for the deterministic synthetic subjects only, plus placing and
 * releasing a legal hold over them. Cloud Run IAM is the gate.
 */
export async function handlePrivacyOperator(input: {
  readonly firestore: Firestore;
  readonly body: unknown;
  readonly nowUtc: string;
}): Promise<Readonly<Record<string, unknown>>> {
  const body = record(input.body);
  if (body === undefined) return rejected('invalid_contract');
  const subjectId = body.subjectId;
  if (typeof subjectId !== 'string' || !syntheticPrivacySubjects.includes(subjectId))
    return rejected('subject_not_synthetic');
  if (!privacySwitchOpen()) return rejected('temporarily_unavailable');
  const { intake, repository } = compose(input.firestore);
  switch (body.operation) {
    case 'submit': {
      if (
        typeof body.requestId !== 'string' ||
        !uuidPattern.test(body.requestId) ||
        !isRequestType(body.requestType) ||
        typeof body.idempotencyKey !== 'string' ||
        !idempotencyPattern.test(body.idempotencyKey)
      )
        return rejected('invalid_contract');
      return fromIntake(
        await intake.submitForVerifiedSubject(subjectId, {
          requestId: body.requestId,
          requestType: body.requestType,
          idempotencyKey: body.idempotencyKey,
          nowUtc: input.nowUtc,
        }),
      );
    }
    case 'status': {
      if (typeof body.requestId !== 'string') return rejected('invalid_contract');
      const request = await repository.get(body.requestId);
      if (request === null || request.subjectId !== subjectId) return rejected('request_not_found');
      return { schemaVersion: 1, kind: 'succeeded', request: await intake.view(request) };
    }
    case 'run': {
      return {
        schemaVersion: 1,
        kind: 'succeeded',
        run: await runPrivacyWork(input.firestore, input.nowUtc),
      };
    }
    case 'placeHold':
    case 'releaseHold': {
      const holds = new FirestorePrivacyLegalHoldService(input.firestore);
      await input.firestore
        .collection(privacyHoldCollections.authority)
        .doc(syntheticHoldOperator)
        .set({ active: true }, { merge: true });
      if (typeof body.holdId !== 'string') return rejected('invalid_contract');
      if (body.operation === 'releaseHold') {
        const released = await holds.release({
          actorId: syntheticHoldOperator,
          holdId: body.holdId,
          expectedRevision: Number(body.expectedRevision),
          nowUtc: input.nowUtc,
        });
        return released.ok
          ? { schemaVersion: 1, kind: 'succeeded', hold: released.hold }
          : rejected(released.code);
      }
      const scope = record(body.scope) as PrivacyLegalHoldScope | undefined;
      if (scope === undefined) return rejected('invalid_contract');
      const placed = await holds.place({
        actorId: syntheticHoldOperator,
        holdId: body.holdId,
        subjectId,
        scope,
        basisRef: 'n5d-synthetic-check',
        reviewAtUtc: new Date(Date.parse(input.nowUtc) + 30 * 86_400_000).toISOString(),
        nowUtc: input.nowUtc,
      });
      return placed.ok
        ? { schemaVersion: 1, kind: 'succeeded', hold: placed.hold }
        : rejected(placed.code);
    }
    default:
      return rejected('invalid_contract');
  }
}

/**
 * The worker: runs open domain tasks within bounded work, then reconciles every
 * request it touched. Media objects are never deleted here (no Storage right;
 * their records stay blocked) and Emulator-only modules are swept without owner
 * appliers (`cloudRuntime`).
 */
export async function runPrivacyWork(
  firestore: Firestore,
  nowUtc: string,
  limit = 20,
): Promise<Readonly<{ tasks: number; requests: number }>> {
  if (!privacySwitchOpen()) return { tasks: 0, requests: 0 };
  const { repository, service } = compose(firestore);
  const runner = new PrivacyDomainTaskRunner(firestore, repository, service, {
    leaseOwner: `privacy-worker:${randomUUID()}`,
    cloudRuntime: true,
  });
  const open = await firestore
    .collection(privacyOrchestrationCollections.tasks)
    .where('status', 'in', ['pending', 'dispatched'])
    .limit(limit)
    .get();
  const requests = new Set<string>();
  for (const document of open.docs) {
    const requestId = document.get('requestId') as unknown;
    const taskId = document.get('taskId') as unknown;
    if (typeof requestId !== 'string' || typeof taskId !== 'string') continue;
    requests.add(requestId);
    for (let step = 0; step < 20; step += 1) {
      const outcome = await runner.runTask({ requestId, taskId, nowUtc });
      if (outcome !== 'progress') break;
    }
  }
  for (const requestId of requests) {
    const current = await repository.get(requestId);
    if (current !== null) await service.reconcile(requestId, current.revision, nowUtc);
  }
  return { tasks: open.size, requests: requests.size };
}

async function dispatch(request: Request, response: Response) {
  response.set('Cache-Control', 'no-store');
  const allowed = devPrivacyOpen(process.env);
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
    const nowUtc = systemServerClock.now().toISOString();
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
    const result = await handlePrivacyRequest({
      firestore: getFirestore(firebase),
      firebaseUid: identity.firebaseUid,
      data: body.data,
      nowUtc,
    });
    info('dev_privacy_result', { kind: result.kind });
    response.status(200).json({ result });
  } catch (error) {
    info('dev_privacy_failure', failureShape(error));
    response.status(503).json({ error: { status: 'UNAVAILABLE' } });
  }
}

export const privacyRequestV1 = onRequest({ ...options, invoker: 'public' as const }, dispatch);

export const privacyOperatorV1 = onRequest(
  { ...options, invoker: 'private' as const },
  async (request, response) => {
    response.set('Cache-Control', 'no-store');
    if (
      devPrivacyOpen(process.env) === null ||
      request.method !== 'POST' ||
      request.rawBody.byteLength > maxBodyBytes
    ) {
      response.status(503).json({ error: { status: 'UNAVAILABLE' } });
      return;
    }
    try {
      const result = await handlePrivacyOperator({
        firestore: getFirestore(app()),
        body: JSON.parse(request.rawBody.toString('utf8')) as unknown,
        nowUtc: systemServerClock.now().toISOString(),
      });
      info('dev_privacy_operator_result', { kind: result.kind });
      response.status(200).json({ result });
    } catch (error) {
      info('dev_privacy_operator_failure', failureShape(error));
      response.status(503).json({ error: { status: 'UNAVAILABLE' } });
    }
  },
);

export const runPrivacyRequestsV1 = onSchedule(
  { ...options, schedule: 'every 5 minutes', retryCount: 0, timeoutSeconds: 300 },
  async () => {
    if (devPrivacyOpen(process.env) === null) return;
    const result = await runPrivacyWork(getFirestore(app()), systemServerClock.now().toISOString());
    info('dev_privacy_worker', result);
  },
);
