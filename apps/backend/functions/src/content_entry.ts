import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import type { ContentTypeId } from './contracts/content_v1.js';
import type { ContentPublicationService } from './modules/content/application/content_publication_service.js';
import type { ContentActor } from './modules/content/application/ports/publisher_eligibility_port.js';
import {
  isContentTypeAvailable,
  resolveContentType,
} from './modules/content/domain/content_type_registry.js';
import { toContentWireResult, type ContentResultType } from './modules/content/domain/failures.js';
import { createEmulatorCatalogComposition } from './modules/catalog/infrastructure/emulator_catalog_composition.js';
import { emulatorCompositionRules } from './modules/content/infrastructure/emulator_activity_dependencies.js';
import { emulatorActivationClosedTypes } from './modules/content/infrastructure/emulator_rental_dependencies.js';
import { createEmulatorContentService } from './modules/content/infrastructure/emulator_content_composition.js';
import { EmulatorSyntheticReferenceData } from './modules/content/infrastructure/emulator_reference_data.js';
import type { FirestoreContentRepository } from './modules/content/infrastructure/firestore_content_repository.js';
import { IdentityPublisherEligibility } from './modules/content/infrastructure/identity_publisher_eligibility.js';
import { FirestoreIdentityAuthorityRepository } from './modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import type { EmulatorMediaComposition } from './modules/media/infrastructure/emulator_media_composition.js';
import {
  createEmulatorModerationPorts,
  createEmulatorModerationService,
} from './modules/moderation/infrastructure/emulator_moderation_composition.js';
import { MediaModerationAdapter } from './modules/moderation/infrastructure/media_moderation_adapter.js';
import type { EntityId } from './shared/ids.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';
import { mediaComposition } from './media_entry.js';

/**
 * Types the Emulator-only authoring path may ever enable: Event (C3), Place
 * (D3.1), Recharge Activity (D3.2) and Rental / Equipment (D3.3). Every other
 * type stays off here, with or without a validator.
 */
export const emulatorAuthoringTypes: readonly ContentTypeId[] = Object.freeze([
  'event',
  'place',
  'activity',
  'rental',
]);

/** D3.1 §2.2, D3.2 §2.2, D3.3: the authoring types whose own flag is on. */
export function authoringTypesFor(flags: {
  readonly eventAuthoring: boolean;
  readonly placeAuthoring: boolean;
  readonly activityAuthoring: boolean;
  readonly rentalAuthoring: boolean;
}): ReadonlySet<ContentTypeId> {
  return new Set<ContentTypeId>([
    ...(flags.eventAuthoring ? (['event'] as const) : []),
    ...(flags.placeAuthoring ? (['place'] as const) : []),
    ...(flags.activityAuthoring ? (['activity'] as const) : []),
    ...(flags.rentalAuthoring ? (['rental'] as const) : []),
  ]);
}

/**
 * A type outside `emulatorAuthoringTypes`, or one without an available
 * validator, can never be enabled: the composition refuses to be built.
 */
export function assertEmulatorAuthoringTypes(types: ReadonlySet<string>): void {
  for (const typeId of types) {
    const entry = resolveContentType(typeId);
    if (
      !emulatorAuthoringTypes.includes(typeId as ContentTypeId) ||
      entry === null ||
      !isContentTypeAvailable(entry)
    )
      throw new Error(`content_authoring_type_not_allowed:${typeId}`);
  }
}

/**
 * C3/D3.1/D3.2 Emulator-only authoring. Content is composed with the real ports it
 * already has: Identity publisher eligibility (Session, verified Creator, exact
 * Page), Media readiness of the exact revision, and the C2 moderation verifier,
 * which makes review mandatory before publication. Only the given authoring
 * types are enabled (default `event`), and only here; the default composition
 * enables nothing. Reference data is the synthetic Emulator data (see
 * `EmulatorSyntheticReferenceData`); what this composition cannot resolve
 * fails closed through `emulatorCompositionRules` (D3.2 §2.4).
 */
export interface EventAuthoringComposition {
  readonly content: ContentPublicationService;
  readonly contentRepository: FirestoreContentRepository;
  readonly media: EmulatorMediaComposition;
  readonly moderation: ReturnType<typeof createEmulatorModerationService>;
}

export function eventAuthoringComposition(
  firestore: Firestore,
  options: {
    readonly media?: EmulatorMediaComposition;
    readonly clock?: ServerClock;
    /** D3.1: the enabled authoring types (default: Event only, as in C3). */
    readonly enabledTypes?: ReadonlySet<ContentTypeId>;
  } = {},
): EventAuthoringComposition {
  const enabledTypes = options.enabledTypes ?? new Set<ContentTypeId>(['event']);
  assertEmulatorAuthoringTypes(enabledTypes);
  const media = options.media ?? mediaComposition(firestore);
  const clock = options.clock ?? systemServerClock;
  const moderationPorts = createEmulatorModerationPorts(firestore);
  const { service, repository } = createEmulatorContentService({
    contentPersistenceEnabled: true,
    firestore,
    ports: {
      eligibility: new IdentityPublisherEligibility(
        new FirestoreIdentityAuthorityRepository(firestore),
      ),
      referenceData: new EmulatorSyntheticReferenceData(),
      moderation: moderationPorts.verifier,
      media: media.readiness,
      clock,
      ids: { newId: () => randomUUID() as EntityId },
      enabledTypes,
      // D3.3 Q4: re-activating a Rental revision stays closed (§2 Q4).
      activationClosedTypes: emulatorActivationClosedTypes,
      compositionRules:
        process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE === 'true'
          ? new Map([...emulatorCompositionRules].filter(([type]) => type !== 'activity'))
          : emulatorCompositionRules,
      ...(process.env.RECHARGE_TEST_ACTIVITY_LINKED_PLACE === 'true'
        ? {
            enforceLinkedPlaceEligibility: true,
            linkedPlaceEligibility: createEmulatorCatalogComposition(firestore).placeLinks,
          }
        : {}),
    },
  });
  const moderation = createEmulatorModerationService({
    firestore,
    repository: moderationPorts.repository,
    contentRepository: repository,
    contentService: service,
    // D2 §7: staff restrict or restore one Media asset through Media's own path.
    media: new MediaModerationAdapter(media.repository, media.deletion),
    clock,
  });
  return Object.freeze({ content: service, contentRepository: repository, media, moderation });
}

/** Server-resolved caller. The Session was already validated by the access authority. */
export interface ContentCaller {
  readonly actor: ContentActor;
  readonly firestore: Firestore;
  /** D3.1 §2.2: authoring types whose flag is on for this call. */
  readonly enabledTypes: ReadonlySet<ContentTypeId>;
}

// Owner commands only. Moderation dispositions and delegated-import inputs are
// refused by the Content service itself; nothing else is reachable here.
const commandResultTypes: Readonly<Record<string, ContentResultType>> = Object.freeze({
  createDraft: 'draft',
  updateDraft: 'draft',
  submitForPublication: 'submission',
  publishApprovedRevision: 'publishedRevision',
  withdrawPublication: 'publicationPointer',
  activatePublishedRevision: 'publicationPointer',
});
const queryResultTypes: Readonly<Record<string, ContentResultType>> = Object.freeze({
  getDraft: 'draft',
  getPublicationStatus: 'publicationStatus',
  getPublishedRevision: 'publishedRevision',
});

function stripTransport(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}

function field(body: unknown, name: string): unknown {
  return typeof body === 'object' && body !== null
    ? (body as Record<string, unknown>)[name]
    : undefined;
}

export async function handleContentCommand(
  caller: ContentCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const body = stripTransport(data);
  const commandType = field(body, 'commandType');
  const resultType = typeof commandType === 'string' ? commandResultTypes[commandType] : undefined;
  if (resultType === undefined)
    return { schemaVersion: 1, kind: 'rejected', code: 'capability_denied' };
  const { content } = eventAuthoringComposition(caller.firestore, {
    enabledTypes: caller.enabledTypes,
  });
  return toContentWireResult(resultType, await content.execute(caller.actor, body));
}

export async function handleContentQuery(
  caller: ContentCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const body = stripTransport(data);
  const queryType = field(body, 'queryType');
  const resultType = typeof queryType === 'string' ? queryResultTypes[queryType] : undefined;
  if (resultType === undefined)
    return { schemaVersion: 1, kind: 'rejected', code: 'capability_denied' };
  const { content } = eventAuthoringComposition(caller.firestore, {
    enabledTypes: caller.enabledTypes,
  });
  return toContentWireResult(resultType, await content.query(caller.actor, body));
}
