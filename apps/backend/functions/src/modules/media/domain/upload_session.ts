import type {
  MediaEntityBindingV1,
  MediaFamily,
  UploadSessionState,
  UploadSessionV1,
} from '../../../contracts/media_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import { MediaDomainRefusal } from './failures.js';

/** Stored session: the wire view plus backend-only fields. */
export type UploadSession = DeepReadonly<UploadSessionV1> & {
  readonly objectKeyHandle: string;
  readonly declaredMediaType: string;
  readonly declaredByteLength: number;
};

export interface CreateUploadSessionInput {
  readonly uploadSessionId: EntityId;
  readonly assetId: EntityId;
  readonly ownerSubjectId: EntityId;
  readonly publisherRef?: PublisherRefV1;
  readonly entityIntent?: MediaEntityBindingV1;
  readonly marketId: MarketId;
  readonly family: MediaFamily;
  readonly allowedMediaTypes: readonly string[];
  readonly maxBytes: number;
  readonly ttlSeconds: number;
  readonly objectKeyHandle: string;
  readonly declaredMediaType: string;
  readonly declaredByteLength: number;
  readonly nowUtc: UtcInstant;
}

export function createUploadSession(input: CreateUploadSessionInput): UploadSession {
  if (
    !input.allowedMediaTypes.includes(input.declaredMediaType) ||
    input.declaredByteLength > input.maxBytes
  )
    throw new MediaDomainRefusal('limit_exceeded');
  const expiresAtUtc = parseUtcInstant(
    new Date(Date.parse(input.nowUtc) + input.ttlSeconds * 1000).toISOString(),
  );
  return deepFreeze({
    schemaVersion: 1,
    uploadSessionId: input.uploadSessionId,
    assetId: input.assetId,
    ownerSubjectId: input.ownerSubjectId,
    ...(input.publisherRef === undefined ? {} : { publisherRef: input.publisherRef }),
    ...(input.entityIntent === undefined ? {} : { entityIntent: input.entityIntent }),
    marketId: input.marketId,
    allowedFamily: input.family,
    allowedMediaTypes: [...input.allowedMediaTypes],
    maxBytes: input.maxBytes,
    expiresAtUtc,
    state: 'open',
    revision: 1,
    createdAtUtc: input.nowUtc,
    objectKeyHandle: input.objectKeyHandle,
    declaredMediaType: input.declaredMediaType,
    declaredByteLength: input.declaredByteLength,
  });
}

export function isSessionExpired(session: UploadSession, nowUtc: UtcInstant): boolean {
  return Date.parse(nowUtc) >= Date.parse(session.expiresAtUtc);
}

const sessionTransitions: Readonly<Record<UploadSessionState, readonly UploadSessionState[]>> = {
  open: ['completed', 'expired', 'aborted'],
  completed: [],
  expired: [],
  aborted: [],
};

export function withSessionState(
  session: UploadSession,
  state: UploadSessionState,
  nowUtc: UtcInstant,
): UploadSession {
  if (!sessionTransitions[session.state].includes(state))
    throw new MediaDomainRefusal('invalid_state');
  return deepFreeze({
    ...session,
    state,
    revision: session.revision + 1,
    ...(state === 'completed' ? { completedAtUtc: nowUtc } : {}),
  });
}

/** Wire view: the backend object key and the declared values stay server-side. */
export function toSessionView(session: UploadSession): DeepReadonly<UploadSessionV1> {
  const { objectKeyHandle, declaredMediaType, declaredByteLength, ...view } = session;
  void objectKeyHandle;
  void declaredMediaType;
  void declaredByteLength;
  return deepFreeze(view);
}
