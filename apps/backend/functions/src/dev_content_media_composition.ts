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
import { FirestoreLibraryService } from './modules/library/firestore_library_service.js';
import { handleDiscoverQuery } from './catalog_entry.js';
import type { IdTokenSource } from './modules/media/infrastructure/cloud_tools_client.js';
import { createDevMediaComposition } from './modules/media/infrastructure/dev_media_composition.js';
import { bookingAccessCapability } from './shared/booking_access_authority.js';
import { resolveBookingActor } from './shared/auth_context.js';
import type { EntityId } from './shared/ids.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/**
 * N3a.2 dev-cloud Content + Media (owner-approved plan 2026-11-07). Owners
 * create, update and read their own draft and attach images that the real
 * ClamAV/sharp services check. Owner decision 2026-11-19 (variant B): content
 * publishes without pre-publication review — moderation acts on reports — so
 * the owner may submit, publish and withdraw their own Place or Event. Import
 * and every staff path stay closed; nothing is deleted (D-07).
 */
export const devContentTypes: ReadonlySet<ContentTypeId> = new Set<ContentTypeId>([
  'place',
  'event',
]);

/**
 * Pilot 2.2 (owner 2026-11-21, variant A): Session and Class/Workshop join Place
 * and Event only with the runtime's deploy switch `P2_SESSION_CLASS_ENABLED`;
 * publication without Booking (external link), as validated by Content.
 */
export const pilotContentTypes: readonly ContentTypeId[] = Object.freeze([
  'session',
  'class_workshop',
]);

export function devContentTypesFor(environment: NodeJS.ProcessEnv): ReadonlySet<ContentTypeId> {
  return environment.P2_SESSION_CLASS_ENABLED === 'true'
    ? new Set<ContentTypeId>([...devContentTypes, ...pilotContentTypes])
    : devContentTypes;
}

/** The only owner operations the dev runtime serves; everything else is `capability_denied`. */
export const devOperations = Object.freeze({
  contentCommandV1: Object.freeze([
    'createDraft',
    'updateDraft',
    'submitForPublication',
    'publishApprovedRevision',
    'withdrawPublication',
  ]),
  contentQueryV1: Object.freeze(['getDraft', 'getPublicationStatus']),
  // N4b (A34 staging 2026-11-15): retryProcessing lets the owner have a
  // quarantined asset (scanner unavailable) processed again; the server bounds
  // the attempts and nothing is deleted.
  mediaCommandV1: Object.freeze([
    'createUploadSession',
    'confirmUpload',
    'finalizeAsset',
    'retryProcessing',
  ]),
  mediaQueryV1: Object.freeze(['getAssetStatus', 'getProcessingReceipt']),
  uploadMediaBytesV1: Object.freeze([] as string[]),
  // Pilot 2.1 (owner 2026-11-21): the owner's Library. The Library service
  // validates its exact request shape (its query has no type field).
  libraryCommandV1: Object.freeze(['addFavorite', 'removeFavorite', 'recordVisit', 'removeVisit']),
  libraryQueryV1: Object.freeze([] as string[]),
  // Pilot 2.3 (owner 2026-11-21): Discover reads over the cloud Catalog.
  discoverQueryV1: Object.freeze([
    'feed',
    'search',
    'map',
    'details',
    'publishedObject',
    'publishedObjectCandidates',
    'placeLink',
    'placeCandidates',
  ]),
});

/**
 * Pilot 2.3 temporary Catalog limits (owner 2026-11-21; not final, BCK08-OD-04/
 * 05/08/10 stay open): page at most 20, radius at most 50 km, at most 3 Discover
 * reads per second per user (in memory: the dev runtime runs one instance).
 */
export const pilotCatalogLimits = Object.freeze({
  pageSizeMax: 20,
  radiusKmMax: 50,
  readsPerSecond: 3,
});
const discoverReads = new Map<string, number[]>();

export function discoverRateAllowed(userId: string, nowMs: number): boolean {
  const recent = (discoverReads.get(userId) ?? []).filter((at) => nowMs - at < 1000);
  if (recent.length >= pilotCatalogLimits.readsPerSecond) {
    discoverReads.set(userId, recent);
    return false;
  }
  recent.push(nowMs);
  discoverReads.set(userId, recent);
  if (discoverReads.size > 1000) discoverReads.clear();
  return true;
}

/** Applies the page and radius limits; a radius above the limit is refused. */
export function limitDiscoverRequest(data: unknown): { data: unknown } | { refused: string } {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return { data };
  const request = data as Record<string, unknown>;
  const payload = request.payload as Record<string, unknown> | undefined;
  const query = payload?.query as Record<string, unknown> | undefined;
  if (query === undefined || query === null || typeof query !== 'object') return { data };
  const geo = query.geo as Record<string, unknown> | undefined;
  if (typeof geo?.radiusKm === 'number' && geo.radiusKm > pilotCatalogLimits.radiusKmMax)
    return { refused: 'radius_too_large' };
  if (typeof query.pageSize === 'number' && query.pageSize > pilotCatalogLimits.pageSizeMax)
    return {
      data: {
        ...request,
        payload: { ...payload, query: { ...query, pageSize: pilotCatalogLimits.pageSizeMax } },
      },
    };
  return { data };
}
export type DevCallableName = keyof typeof devOperations;

/**
 * Owner decision 2026-11-19 (variant B): no pre-publication review; a
 * submission is approved by this recorded policy decision and moderation acts
 * on reports afterwards. Seller-declaration eligibility for paid content is
 * not moderation and still applies. No disposition is verified here (the cloud
 * has no staff decisions yet).
 */
export const ownerPostModerationPolicy = Object.freeze({
  profileId: 'owner.post-moderation',
  policyRevision: 'owner-2026-11-19-post-moderation-1',
  policyDecisionId: 'owner-decision-2026-11-19-publish-without-pre-review',
});
export const postModeration: ModerationDispositionPort = Object.freeze({
  profileFor: () =>
    Promise.resolve({
      available: true,
      profileId: ownerPostModerationPolicy.profileId,
      requiresPrePublicationModeration: false,
      policyRevision: ownerPostModerationPolicy.policyRevision,
      policyDecisionId: ownerPostModerationPolicy.policyDecisionId,
    } as const),
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
    moderation: postModeration,
    media: media.readiness,
    clock,
    ids: { newId: () => randomUUID() as EntityId },
    enabledTypes: devContentTypesFor(input.environment),
    compositionRules: emulatorCompositionRules,
  });
  return Object.freeze({ content, media });
}

const rejected = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });

function operationOf(callable: DevCallableName, data: unknown): string | undefined {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return undefined;
  const record = data as Record<string, unknown>;
  if (callable === 'libraryCommandV1')
    return typeof record.commandType === 'string' ? record.commandType : undefined;
  if (callable === 'discoverQueryV1')
    return typeof record.queryType === 'string' ? record.queryType : undefined;
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
  /** Pilot 2.1: the Library deploy switch (`P2_LIBRARY_ENABLED`); closed when absent. */
  readonly libraryEnabled?: boolean;
  /** Pilot 2.2: the enabled Content types; Place and Event when absent. */
  readonly contentTypes?: ReadonlySet<ContentTypeId>;
  /** Pilot 2.3: the Catalog deploy switch (`P2_CATALOG_ENABLED`); closed when absent. */
  readonly catalogEnabled?: boolean;
}): Promise<Readonly<Record<string, unknown>>> {
  const allowed = devOperations[input.callable];
  if (input.callable !== 'uploadMediaBytesV1' && input.callable !== 'libraryQueryV1') {
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
  if (input.callable === 'discoverQueryV1') {
    if (input.catalogEnabled !== true) return rejected('feature_disabled');
    const now = (input.now ?? (() => new Date()))();
    if (!discoverRateAllowed(decision.userId, now.getTime())) return rejected('rate_limited');
    const limited = limitDiscoverRequest(input.data);
    if ('refused' in limited) return rejected(limited.refused);
    // Find People stays off in the cloud (OD-11).
    return handleDiscoverQuery(
      { firestore: input.firestore, userId: decision.userId, findPeopleEnabled: false },
      limited.data,
    );
  }
  if (input.callable === 'libraryCommandV1' || input.callable === 'libraryQueryV1') {
    // The Library service re-authorizes the same Session inside its transaction.
    const library = new FirestoreLibraryService(input.firestore, systemServerClock, {
      cloud: { enabled: input.libraryEnabled === true },
    });
    const data = withoutSessionContext(input.data);
    return input.callable === 'libraryCommandV1'
      ? library.command(actor.actor, data)
      : library.query(actor.actor, data);
  }
  const ids = {
    userId: decision.userId as never,
    sessionId: actor.actor.sessionId as never,
  };
  const { content, media } = input.compose();
  switch (input.callable) {
    case 'contentCommandV1':
      return handleContentCommand(
        {
          actor: ids,
          firestore: input.firestore,
          enabledTypes: input.contentTypes ?? devContentTypes,
          content,
        },
        input.data,
      );
    case 'contentQueryV1':
      return handleContentQuery(
        {
          actor: ids,
          firestore: input.firestore,
          enabledTypes: input.contentTypes ?? devContentTypes,
          content,
        },
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

function withoutSessionContext(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}
