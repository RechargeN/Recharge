import { randomUUID } from 'node:crypto';
import type { App } from 'firebase-admin/app';
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
import {
  CloudToolsProcessor,
  CloudToolsScanner,
  cloudToolsConfigFrom,
  type IdTokenSource,
} from './cloud_tools_client.js';
import { createDevCloudObjectStore, type DevCloudObjectStore } from './dev_cloud_object_store.js';
import { FirestoreMediaRepository } from './firestore_media_repository.js';
import { IdentityMediaActorAuthority } from './identity_media_authority.js';

/**
 * N3a.2 dev-cloud Media composition for recharge-dev-n2a01 only: Firestore
 * (Media chain guard), the dev bucket adapter (N3a), the real ClamAV and sharp
 * services on private Cloud Run (N3b). No fake tool, no local tools, no
 * retention, orphan sweep, deletion or delivery: nothing here deletes or
 * publishes (D-07). Anything missing or mis-set throws, so Media does not start.
 */

/** D-08 dev-test values, not BCK14-OD-03/04 (same limits as the Emulator policy). */
export const devMediaPolicy: MediaPolicy = Object.freeze({
  revision: 'dev-test-media-policy-1',
  families: Object.freeze({
    image: Object.freeze({
      allowedMediaTypes: Object.freeze(['image/png', 'image/jpeg', 'image/webp']),
      maxBytes: 1_048_576,
      sessionTtlSeconds: 900,
      maxProcessingAttempts: 3,
      mandatoryVariantProfiles: Object.freeze(['display', 'thumb']),
      validationProfileRevision: 'dev-test-validation-1',
    }),
  }),
});

export const devMediaFamilies: ReadonlySet<MediaFamily> = new Set<MediaFamily>(['image']);
export const devMediaMarkets: ReadonlySet<string> = new Set<string>(['LV']);

export interface DevMediaComposition {
  readonly service: MediaService;
  readonly objectStore: DevCloudObjectStore;
  readonly authority: IdentityMediaActorAuthority;
  readonly repository: FirestoreMediaRepository;
  readonly readiness: ContentMediaReadinessAdapter;
  readonly contentScope: ContentMediaScope;
}

export function createDevMediaComposition(input: {
  readonly app: App;
  readonly firestore: Firestore;
  readonly environment: NodeJS.ProcessEnv;
  readonly clock?: ServerClock;
  /** Tests only; production uses the metadata server. */
  readonly idToken?: IdTokenSource;
}): DevMediaComposition {
  const { environment } = input;
  const tools =
    input.idToken === undefined
      ? cloudToolsConfigFrom(environment)
      : cloudToolsConfigFrom(environment, input.idToken);
  if (tools === null) throw new Error('dev_media_requires_dev_cloud_tools');
  const identity = new FirestoreIdentityAuthorityRepository(input.firestore);
  const repository = new FirestoreMediaRepository(input.firestore, environment);
  const objectStore = createDevCloudObjectStore(
    input.app,
    devMediaPolicy.families.image?.maxBytes ?? 0,
    environment,
  );
  const contentScope = new ContentMediaScope({
    repository: new FirestoreContentRepository(input.firestore, { environment }),
    eligibility: new IdentityPublisherEligibility(identity),
  });
  const authority = new IdentityMediaActorAuthority(identity, devMediaMarkets);
  const service = new MediaService({
    repository,
    authority,
    entityScope: contentScope,
    objectStore,
    scanner: new CloudToolsScanner(tools.scanner, objectStore),
    processor: new CloudToolsProcessor(tools.processor, objectStore),
    clock: input.clock ?? systemServerClock,
    ids: { newId: () => randomUUID() as EntityId },
    enabledFamilies: devMediaFamilies,
    policy: devMediaPolicy,
  });
  const readiness = new ContentMediaReadinessAdapter({
    repository,
    enabledFamilies: devMediaFamilies,
  });
  return Object.freeze({ service, objectStore, authority, repository, readiness, contentScope });
}
