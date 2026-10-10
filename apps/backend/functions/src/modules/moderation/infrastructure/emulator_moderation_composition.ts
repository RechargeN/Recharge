import type { Firestore } from 'firebase-admin/firestore';

import { systemServerClock, type ServerClock } from '../../../shared/server_clock.js';
import type { ContentPublicationService } from '../../content/application/content_publication_service.js';
import type { FirestoreContentRepository } from '../../content/infrastructure/firestore_content_repository.js';
import { FirestoreIdentityAuthorityRepository } from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { ModerationService } from '../application/moderation_service.js';
import type { MediaModerationPort } from '../application/ports.js';
import { ContentModerationAdapter } from './content_moderation_adapter.js';
import { EmulatorStaffAuthority } from './emulator_staff_authority.js';
import { FirestoreModerationRepository } from './firestore_moderation_repository.js';
import { ModerationDecisionVerifier } from './moderation_decision_verifier.js';

/**
 * Emulator-only moderation composition. The verifier is Content's moderation
 * port, so Content is built from it first; the operator service is built from
 * that Content service afterwards. Staff authority is the stand bootstrap
 * registry (see `EmulatorStaffAuthority`), not production IAM.
 */
export function createEmulatorModerationPorts(
  firestore: Firestore,
  environment: NodeJS.ProcessEnv = process.env,
) {
  const repository = new FirestoreModerationRepository(firestore, environment);
  return Object.freeze({ repository, verifier: new ModerationDecisionVerifier(repository) });
}

export function createEmulatorModerationService(input: {
  readonly firestore: Firestore;
  readonly repository: FirestoreModerationRepository;
  readonly contentRepository: FirestoreContentRepository;
  readonly contentService: ContentPublicationService;
  /** D2: Media's verified restriction path for `restrict_media` / `restore_media`. */
  readonly media?: MediaModerationPort;
  readonly clock?: ServerClock;
  readonly environment?: NodeJS.ProcessEnv;
}) {
  const environment = input.environment ?? process.env;
  const staff = new EmulatorStaffAuthority(
    input.firestore,
    new FirestoreIdentityAuthorityRepository(input.firestore),
    environment,
  );
  const service = new ModerationService({
    repository: input.repository,
    staff,
    content: new ContentModerationAdapter(
      input.firestore,
      input.contentRepository,
      input.contentService,
    ),
    ...(input.media === undefined ? {} : { media: input.media }),
    clock: input.clock ?? systemServerClock,
  });
  return Object.freeze({ service, staff, repository: input.repository });
}
