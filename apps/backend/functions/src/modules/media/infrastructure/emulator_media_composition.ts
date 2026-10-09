import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import type { MediaFamily } from '../../../contracts/media_v1.js';
import { systemServerClock, type ServerClock } from '../../../shared/server_clock.js';
import type { EntityId } from '../../../shared/ids.js';
import { ContentMediaScope } from '../../content/application/content_media_scope.js';
import { FirestoreContentRepository } from '../../content/infrastructure/firestore_content_repository.js';
import { IdentityPublisherEligibility } from '../../content/infrastructure/identity_publisher_eligibility.js';
import { FirestoreIdentityAuthorityRepository } from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { ContentMediaReadinessAdapter } from '../application/content_media_readiness.js';
import { MediaService } from '../application/media_service.js';
import type { MediaPolicy } from '../domain/media_policy.js';
import { FakeProcessor } from './fake_processor.js';
import { FakeScanner } from './fake_scanner.js';
import { FirestoreMediaRepository } from './firestore_media_repository.js';
import { IdentityMediaActorAuthority } from './identity_media_authority.js';
import {
  LocalToolsProcessor,
  LocalToolsScanner,
  localToolsConfigFrom,
} from './local_tools_client.js';
import {
  StorageEmulatorObjectStore,
  type StorageBucketLike,
} from './storage_emulator_object_store.js';

/**
 * EXPLICIT MARKING. The scanner and processor in this composition are the
 * existing fakes: they prove that the service orchestrates scan, processing and
 * readiness correctly, NOT that any malware, unsafe content or transformation
 * defect is detected. Receipts carry the `fake-*` tool revisions, and the policy
 * below is a synthetic Emulator policy, not an accepted product policy.
 */
export const emulatorMediaEvidence =
  'fake scanner and fake processor: orchestration only, no detection or transformation';

/**
 * D1 (amendment §10): only when the stand sets `RECHARGE_MEDIA_TOOLS=local-real`
 * do the scanner and processor become the local tools service (ClamAV with the
 * stand's test signature, sharp). Local Windows evidence only; the policy stays
 * the synthetic Emulator policy below.
 */
export const localToolsMediaEvidence =
  'local ClamAV and sharp behind the local tools service: Windows-local evidence, stand test signature only';

/** Synthetic, TEST-ONLY policy for the local Emulator stand. */
export const emulatorMediaPolicy: MediaPolicy = Object.freeze({
  revision: 'test-only-emulator-media-policy-1',
  families: Object.freeze({
    image: Object.freeze({
      allowedMediaTypes: Object.freeze(['image/png', 'image/jpeg', 'image/webp']),
      maxBytes: 1_048_576,
      sessionTtlSeconds: 900,
      maxProcessingAttempts: 3,
      mandatoryVariantProfiles: Object.freeze(['display', 'thumb']),
      validationProfileRevision: 'test-only-emulator-validation-1',
    }),
  }),
});

export const emulatorMediaFamilies: ReadonlySet<MediaFamily> = new Set<MediaFamily>(['image']);
export const emulatorMediaMarkets: ReadonlySet<string> = new Set<string>(['LV']);

export interface EmulatorMediaComposition {
  readonly service: MediaService;
  readonly objectStore: StorageEmulatorObjectStore;
  readonly authority: IdentityMediaActorAuthority;
  readonly repository: FirestoreMediaRepository;
  /** Content's question to Media: is this exact Media revision ready? */
  readonly readiness: ContentMediaReadinessAdapter;
  /** Media's question to Content: may this actor bind media to this exact draft? */
  readonly contentScope: ContentMediaScope;
}

export function createEmulatorMediaComposition(input: {
  readonly firestore: Firestore;
  readonly bucket: StorageBucketLike;
  readonly clock?: ServerClock;
  readonly environment?: NodeJS.ProcessEnv;
}): EmulatorMediaComposition {
  const environment = input.environment ?? process.env;
  const identity = new FirestoreIdentityAuthorityRepository(input.firestore);
  const repository = new FirestoreMediaRepository(input.firestore, environment);
  const objectStore = new StorageEmulatorObjectStore(input.bucket, environment);
  const contentScope = new ContentMediaScope({
    repository: new FirestoreContentRepository(input.firestore, { environment }),
    eligibility: new IdentityPublisherEligibility(identity),
  });
  const authority = new IdentityMediaActorAuthority(identity, emulatorMediaMarkets);
  const tools = localToolsConfigFrom(environment);
  const service = new MediaService({
    repository,
    authority,
    entityScope: contentScope,
    objectStore,
    scanner: tools === null ? new FakeScanner() : new LocalToolsScanner(tools, objectStore),
    processor: tools === null ? new FakeProcessor() : new LocalToolsProcessor(tools, objectStore),
    clock: input.clock ?? systemServerClock,
    ids: { newId: () => randomUUID() as EntityId },
    enabledFamilies: emulatorMediaFamilies,
    policy: emulatorMediaPolicy,
  });
  const readiness = new ContentMediaReadinessAdapter({
    repository,
    enabledFamilies: emulatorMediaFamilies,
  });
  return Object.freeze({ service, objectStore, authority, repository, readiness, contentScope });
}
