import { PlaceLinkService } from '../application/place_link_service.js';
import { PublishedObjectLinkService } from '../application/published_object_link_service.js';
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
 * runtime entry itself: E2 triggers and stand tooling call this composition.
 * Activity taxonomy is the pinned canonical local artifact; other reference
 * revisions retain their existing synthetic Emulator constants.
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
  const activityEnabled = environment.RECHARGE_TEST_ACTIVITY_CATALOG === 'true';
  const references = new EmulatorSyntheticReferenceData();
  const base = new ContentFeedCatalogSource(
    new ContentPublicationFeed(firestore, contentRepository),
    references,
  );
  const source = options.source === undefined ? base : options.source(base);
  const placeLinks = new PlaceLinkService(
    source,
    environment.RECHARGE_TEST_ACTIVITY_LINKED_PLACE === 'true',
  );
  // D3.4: exact-id relations to every listing type, for Collection membership.
  const publishedObjects = new PublishedObjectLinkService(
    source,
    environment.RECHARGE_TEST_COLLECTION_MEMBERSHIP === 'true',
  );
  const projector = new CatalogProjector({ repository, source, clock, activityEnabled });
  const reconciler = new CatalogReconciler(repository, source, projector, clock);
  const sets = new CatalogSets(repository, source, projector, reconciler, clock);
  const query = new CatalogQueryService(
    repository,
    new ReferenceDataRevisions(references),
    clock,
    activityEnabled,
    placeLinks,
    publishedObjects,
  );
  return Object.freeze({
    repository,
    source,
    projector,
    reconciler,
    sets,
    query,
    placeLinks,
    publishedObjects,
  });
}
