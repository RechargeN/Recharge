import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import type { MediaActor } from './modules/media/application/ports/actor_authority_port.js';
import { toMediaWireResult, type MediaResultType } from './modules/media/domain/failures.js';
import { isSessionExpired } from './modules/media/domain/upload_session.js';
import {
  createEmulatorMediaComposition,
  type EmulatorMediaComposition,
} from './modules/media/infrastructure/emulator_media_composition.js';
import { parseUtcInstant } from './shared/utc_instant.js';
import { systemServerClock } from './shared/server_clock.js';

const emulatorBucket = 'demo-recharge.appspot.com';

const commandResultTypes: Readonly<Record<string, MediaResultType>> = Object.freeze({
  createUploadSession: 'uploadSession',
  confirmUpload: 'assetStatus',
  finalizeAsset: 'assetStatus',
});
const queryResultTypes: Readonly<Record<string, MediaResultType>> = Object.freeze({
  getAssetStatus: 'assetStatus',
  getProcessingReceipt: 'processingReceipt',
});

/** Server-resolved caller. The Session was already validated by the Booking access authority. */
export interface MediaCaller {
  readonly actor: MediaActor;
  readonly firestore: Firestore;
}

export function mediaComposition(firestore: Firestore): EmulatorMediaComposition {
  const app = getApps().find((candidate) => candidate.name === '[DEFAULT]') ?? initializeApp();
  return createEmulatorMediaComposition({
    firestore,
    bucket: getStorage(app).bucket(emulatorBucket) as never,
  });
}

export function mediaFirestore(): Firestore | undefined {
  if (
    process.env.FUNCTIONS_EMULATOR !== 'true' ||
    process.env.GCLOUD_PROJECT !== 'demo-recharge' ||
    process.env.FIRESTORE_EMULATOR_HOST === undefined
  ) {
    return undefined;
  }
  const app =
    getApps().find((candidate) => candidate.name === '[DEFAULT]') ??
    initializeApp({ projectId: 'demo-recharge' });
  return getFirestore(app);
}

function stripTransport(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}

export async function handleMediaCommand(
  caller: MediaCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const body = stripTransport(data);
  const commandType =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>).commandType
      : undefined;
  const resultType = typeof commandType === 'string' ? commandResultTypes[commandType] : undefined;
  if (resultType === undefined) {
    // Delete, detach and system instructions are never a client command here.
    return { schemaVersion: 1, kind: 'rejected', code: 'capability_denied' };
  }
  const { service } = mediaComposition(caller.firestore);
  return toMediaWireResult(resultType, await service.execute(caller.actor, body));
}

export async function handleMediaQuery(
  caller: MediaCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const body = stripTransport(data);
  const queryType =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>).queryType
      : undefined;
  const resultType = typeof queryType === 'string' ? queryResultTypes[queryType] : undefined;
  if (resultType === undefined) {
    return { schemaVersion: 1, kind: 'rejected', code: 'invalid_contract' };
  }
  const { service } = mediaComposition(caller.firestore);
  return toMediaWireResult(resultType, await service.query(caller.actor, body));
}

/**
 * Emulator-only byte transfer. Real providers hand the client an upload target;
 * the Emulator cannot sign one and Storage rules stay closed, so the owner of an
 * open upload session sends the bytes here and the backend writes them through
 * the Admin SDK. The caller never learns or chooses the object key.
 */
export async function handleMediaBytes(
  caller: MediaCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const reject = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });
  const body = stripTransport(data);
  if (typeof body !== 'object' || body === null || Array.isArray(body))
    return reject('invalid_contract');
  const record = body as Record<string, unknown>;
  const keys = Object.keys(record).sort().join(',');
  if (
    keys !== 'bytesBase64,schemaVersion,uploadSessionId' ||
    record.schemaVersion !== 1 ||
    typeof record.uploadSessionId !== 'string' ||
    typeof record.bytesBase64 !== 'string' ||
    record.bytesBase64.length > 2_000_000
  )
    return reject('invalid_contract');
  const composition = mediaComposition(caller.firestore);
  const now = parseUtcInstant(systemServerClock.now().toISOString());
  const decision = await composition.repository.transact(async (tx) => {
    const session = await tx.session(record.uploadSessionId as string);
    // Another subject's session does not exist for the caller.
    if (session === null || session.ownerSubjectId !== caller.actor.userId)
      return { code: 'not_found' } as const;
    const asset = await tx.asset(session.assetId);
    if (asset === null) return { code: 'not_found' } as const;
    return { session, asset } as const;
  });
  if ('code' in decision) return reject(decision.code);
  const { session, asset } = decision;
  // The same backend-time upload authority as the Media service applies.
  const allowed = await composition.authority.evaluate({
    actor: caller.actor,
    marketId: asset.marketId,
    ...(asset.publisherRef === undefined ? {} : { publisherRef: asset.publisherRef }),
    family: asset.family,
    action: 'upload',
    nowUtc: now,
  });
  if (!allowed.allowed)
    return reject(allowed.reason === 'session_invalid' ? 'unauthenticated' : allowed.reason);
  if (session.state !== 'open' || isSessionExpired(session, now)) return reject('session_expired');
  if (asset.lifecycle !== 'reserved' && asset.lifecycle !== 'uploading')
    return reject('invalid_state');
  const bytes = Buffer.from(record.bytesBase64, 'base64');
  if (bytes.length === 0 || bytes.length > session.maxBytes) return reject('limit_exceeded');
  if (bytes.length !== session.declaredByteLength) return reject('generation_mismatch');
  await composition.objectStore.put(asset.objectKeyHandle, bytes);
  return {
    schemaVersion: 1,
    kind: 'succeeded',
    resultType: 'bytesAccepted',
    data: { uploadSessionId: session.uploadSessionId, received: bytes.length },
  };
}
