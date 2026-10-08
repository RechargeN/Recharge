import type { Firestore } from 'firebase-admin/firestore';

import { systemServerClock, type ServerClock } from '../../../shared/server_clock.js';
import { ContentPublicationFeed } from '../../content/infrastructure/content_publication_feed.js';
import { EmulatorSyntheticReferenceData } from '../../content/infrastructure/emulator_reference_data.js';
import { FirestoreContentRepository } from '../../content/infrastructure/firestore_content_repository.js';
import { CatalogProjector } from '../application/catalog_projector.js';
import { CatalogQueryService } from '../application/catalog_query_service.js';
import { CatalogReconciler } from '../application/catalog_reconciler.js';
import { CatalogSets } from '../application/catalog_sets.js';
import type { ContentCatalogSource } from '../application/ports.js';
import { ContentFeedCatalogSource, ReferenceDataRevisions } from './content_catalog_source.js';
import { FirestoreCatalogRepository } from './firestore_catalog_repository.js';

/**
 * Local Catalog on the Emulator (E1). It has no Functions entry and no
 * automatic trigger: delivery runs only when the stand tooling or a test calls
 * the projector. Reference revisions are the synthetic Emulator constants.
 */
export function createEmulatorCatalogComposition(
  firestore: Firestore,
  options: {
    readonly clock?: ServerClock;
    readonly environment?: NodeJS.ProcessEnv;
    /** Tests wrap the source to simulate an unavailable read. */
    readonly source?: (source: ContentCatalogSource) => ContentCatalogSource;
  } = {},
) {
  const clock = options.clock ?? systemServerClock;
  const environment = options.environment ?? process.env;
  const repository = new FirestoreCatalogRepository(firestore, environment);
  const contentRepository = new FirestoreContentRepository(firestore, { environment });
  const base = new ContentFeedCatalogSource(
    new ContentPublicationFeed(firestore, contentRepository),
  );
  const source = options.source === undefined ? base : options.source(base);
  const projector = new CatalogProjector({ repository, source, clock });
  const reconciler = new CatalogReconciler(repository, source, projector, clock);
  const sets = new CatalogSets(repository, source, projector, reconciler, clock);
  const query = new CatalogQueryService(
    repository,
    new ReferenceDataRevisions(new EmulatorSyntheticReferenceData()),
    clock,
  );
  return Object.freeze({ repository, source, projector, reconciler, sets, query });
}
