import type { Firestore } from 'firebase-admin/firestore';

import {
  ContentPublicationService,
  type ContentPublicationServiceDeps,
} from '../application/content_publication_service.js';
import type { ContentStorageLimits } from '../domain/storage_limits.js';
import { FirestoreContentRepository } from './firestore_content_repository.js';

export class ContentPersistenceDisabledError extends Error {
  constructor() {
    super('Content persistence is disabled: the default-off flag was not set explicitly');
    this.name = 'ContentPersistenceDisabledError';
  }
}

export interface EmulatorContentCompositionOptions {
  /** Default-off flag; anything but an explicit `true` refuses the composition. */
  readonly contentPersistenceEnabled?: boolean;
  readonly firestore: Firestore;
  readonly environment?: NodeJS.ProcessEnv;
  readonly limits?: Partial<ContentStorageLimits>;
  /** Every port stays supplied by the caller; nothing here grants authority. */
  readonly ports: Omit<ContentPublicationServiceDeps, 'repository'>;
}

/**
 * Binds the Content service to the Emulator-only Firestore repository (BCK-07
 * v0.12 §38). It is not exported from the Functions entry and creates no
 * endpoint; the repository itself refuses any environment but the loopback
 * `demo-recharge` Emulator, so this factory adds only the default-off flag.
 */
export function createEmulatorContentService(options: EmulatorContentCompositionOptions): {
  readonly service: ContentPublicationService;
  readonly repository: FirestoreContentRepository;
} {
  if (options.contentPersistenceEnabled !== true) throw new ContentPersistenceDisabledError();
  const repository = new FirestoreContentRepository(options.firestore, {
    ...(options.limits === undefined ? {} : { limits: options.limits }),
    ...(options.environment === undefined ? {} : { environment: options.environment }),
  });
  return { service: new ContentPublicationService({ ...options.ports, repository }), repository };
}
