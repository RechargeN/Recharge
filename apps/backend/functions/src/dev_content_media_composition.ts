import { randomUUID } from 'node:crypto';
import type { App } from 'firebase-admin/app';
import type { Firestore } from 'firebase-admin/firestore';

import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import type { ContentTypeId } from './contracts/content_v1.js';
import { handleContentCommand, handleContentQuery } from './content_entry.js';
import { handleMediaBytes, handleMediaCommand, handleMediaQuery } from './media_entry.js';
import { ContentPublicationService } from './modules/content/application/content_publication_service.js';
import type { ModerationDispositionPort } from './modules/content/application/ports/moderation_disposition_port.js';
import { emulatorCompositionRules } from './modules/content/infrastructure/emulator_activity_dependencies.js';
import { EmulatorSyntheticReferenceData } from './modules/content/infrastructure/emulator_reference_data.js';
import { FirestoreContentRepository } from './modules/content/infrastructure/firestore_content_repository.js';
import { IdentityPublisherEligibility } from './modules/content/infrastructure/identity_publisher_eligibility.js';
import { FirestoreIdentityAuthorityRepository } from './modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import type { IdTokenSource } from './modules/media/infrastructure/cloud_tools_client.js';
import { createDevMediaComposition } from './modules/media/infrastructure/dev_media_composition.js';
import { bookingAccessCapability } from './shared/booking_access_authority.js';
import { resolveBookingActor } from './shared/auth_context.js';
import type { EntityId } from './shared/ids.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/**
 * N3a.2 dev-cloud Content + Media for recharge-dev-n2a01 (owner-approved plan
 * 2026-11-07). Exactly one authoring type (Place). Owners create, update and
 * read their own draft and attach images that the real ClamAV/sharp services
 * check. Submission, publication, withdrawal, import and every staff path are
 * closed here: no review exists in dev, so nothing can become public, and
 * nothing is deleted (D-07).
 */
export const devContentTypes: ReadonlySet<ContentTypeId> = new Set<ContentTypeId>(['place']);

/** The only owner operations the dev runtime serves; everything else is `capability_denied`. */
export const devOperations = Object.freeze({
  contentCommandV1: Object.freeze(['createDraft', 'updateDraft']),
  contentQueryV1: Object.freeze(['getDraft', 'getPublicationStatus']),
  mediaCommandV1: Object.freeze(['createUploadSession', 'confirmUpload', 'finalizeAsset']),
  mediaQueryV1: Object.freeze(['getAssetStatus', 'getProcessingReceipt']),
  uploadMediaBytesV1: Object.freeze([] as string[]),
});
export type DevCallableName = keyof typeof devOperations;

/** No moderation exists in dev: no profile is available and no disposition is ever verified. */
export const closedModeration: ModerationDispositionPort = Object.freeze({
  profileFor: () => Promise.resolve({ available: false } as const),
  verifyDisposition: () => Promise.resolve({ verified: false } as const),
});

export interface DevContentMedia {
  readonly content: ContentPublicationService;
  readonly media: ReturnType<typeof createDevMediaComposition>;
}

export function createDevContentMedia(input: {
  readonly app: App;
  readonly firestore: Firestore;
  readonly environment: NodeJS.ProcessEnv;
  readonly clock?: ServerClock;
  readonly idToken?: IdTokenSource;
}): DevContentMedia {
  const clock = input.clock ?? systemServerClock;
  const media = createDevMediaComposition({
    app: input.app,
    firestore: input.firestore,
    environment: input.environment,
    clock,
    ...(input.idToken === undefined ? {} : { idToken: input.idToken }),
  });
  const content = new ContentPublicationService({
    repository: new FirestoreContentRepository(input.firestore, {
      environment: input.environment,
    }),
    eligibility: new IdentityPublisherEligibility(
      new FirestoreIdentityAuthorityRepository(input.firestore),
    ),
    referenceData: new EmulatorSyntheticReferenceData(),
    moderation: closedModeration,
    media: media.readiness,
    clock,
    ids: { newId: () => randomUUID() as EntityId },
    enabledTypes: devContentTypes,
    compositionRules: emulatorCompositionRules,
  });
  return Object.freeze({ content, media });
}

const rejected = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });

function operationOf(callable: DevCallableName, data: unknown): string | undefined {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return undefined;
  const record = data as Record<string, unknown>;
  const value = callable.startsWith('content')
    ? callable.endsWith('QueryV1')
      ? record.queryType
      : record.commandType
    : callable === 'mediaQueryV1'
      ? record.queryType
      : record.commandType;
  return typeof value === 'string' ? value : undefined;
}

/**
 * One dev request after the Firebase ID token was verified (`firebaseUid`):
 * the Recharge Session from the payload is checked against Firestore exactly
 * like the Emulator path (`FirestoreBookingAccessAuthority`), then the reviewed
 * owner handler runs with the dev composition.
 */
export async function handleDevContentMedia(input: {
  readonly callable: DevCallableName;
  readonly firebaseUid: string;
  readonly data: unknown;
  readonly firestore: Firestore;
  readonly compose: () => DevContentMedia;
  readonly now?: () => Date;
}): Promise<Readonly<Record<string, unknown>>> {
  const allowed = devOperations[input.callable];
  if (input.callable !== 'uploadMediaBytesV1') {
    const operation = operationOf(input.callable, input.data);
    if (operation === undefined || !allowed.includes(operation))
      return rejected('capability_denied');
  }
  const sessionContext =
    typeof input.data === 'object' && input.data !== null && !Array.isArray(input.data)
      ? (input.data as Record<string, unknown>).sessionContext
      : undefined;
  const actor = resolveBookingActor({ uid: input.firebaseUid, token: {} }, sessionContext);
  if (!actor.ok) return rejected('unauthenticated');
  const decision = await new FirestoreBookingAccessAuthority(input.firestore).authorize(
    actor.actor,
    (input.now ?? (() => new Date()))(),
    bookingAccessCapability,
  );
  if (!decision.allowed) return rejected('unauthenticated');
  const ids = {
    userId: decision.userId as never,
    sessionId: actor.actor.sessionId as never,
  };
  const { content, media } = input.compose();
  switch (input.callable) {
    case 'contentCommandV1':
      return handleContentCommand(
        { actor: ids, firestore: input.firestore, enabledTypes: devContentTypes, content },
        input.data,
      );
    case 'contentQueryV1':
      return handleContentQuery(
        { actor: ids, firestore: input.firestore, enabledTypes: devContentTypes, content },
        input.data,
      );
    case 'mediaCommandV1':
      return handleMediaCommand(
        { actor: ids, firestore: input.firestore, composition: media },
        input.data,
      );
    case 'mediaQueryV1':
      return handleMediaQuery(
        { actor: ids, firestore: input.firestore, composition: media },
        input.data,
      );
    case 'uploadMediaBytesV1':
      return handleMediaBytes(
        { actor: ids, firestore: input.firestore, composition: media },
        input.data,
      );
  }
}
