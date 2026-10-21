import { safetyRestricted } from '../../../shared/safety_instruction.js';
import { publisherUser, relationEffects } from '../../../shared/safety_visibility.js';
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
import { FirestoreFindPeoplePrivacy } from '../../content/infrastructure/find_people_privacy_adapter.js';

/**
 * Local Catalog on the Emulator (E1). It has no Functions entry and no
 * runtime entry itself: E2 triggers and stand tooling call this composition.
 * Activity taxonomy is the pinned canonical local artifact; other reference
 * revisions retain their existing synthetic Emulator constants.
 */
export function createEmulatorCatalogComposition(
  firestore: Firestore,
  options: {
    readonly viewerId?: string;
    readonly clock?: ServerClock;
    /** D3.7: the local `catalog.findPeople` flag, read by the caller (default off). */
    readonly findPeopleEnabled?: boolean;
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
  // I3 / BCK08-OD-04-S: the local Scenario family, off unless switched on.
  const scenarioEnabled = environment.RECHARGE_TEST_SCENARIO_CATALOG === 'true';
  const references = new EmulatorSyntheticReferenceData();
  const base = new ContentFeedCatalogSource(
    new ContentPublicationFeed(firestore, contentRepository),
    references,
  );
  const source = options.source === undefined ? base : options.source(base);
  const safetyAllowed = async (contentId: string) => {
    const pointer = await contentRepository.transact((tx) => tx.pointer(contentId));
    if (!pointer?.currentPublishedRevisionId) return false;
    const revision = await contentRepository.transact((tx) =>
      tx.publishedRevision(pointer.currentPublishedRevisionId!),
    );
    if (!revision) return false;
    const user = await publisherUser(firestore, revision.publisherRef);
    return !(await safetyRestricted(firestore, 'catalog', user ?? '', clock.now(), contentId));
  };
  const placeLinks = new PlaceLinkService(
    source,
    environment.RECHARGE_TEST_ACTIVITY_LINKED_PLACE === 'true',
    safetyAllowed,
  );
  // D3.4: exact-id relations to every listing type, for Collection membership.
  const publishedObjects = new PublishedObjectLinkService(
    source,
    environment.RECHARGE_TEST_COLLECTION_MEMBERSHIP === 'true',
    safetyAllowed,
  );
  // SCN-PUB-01 SP-08: exact-id status of Scenario stops. Read-only; Content and
  // Planning ask it only behind their own Scenario flags.
  const scenarioStops = new PublishedObjectLinkService(source, true, safetyAllowed);
  const findPeopleEnabled = options.findPeopleEnabled === true;
  const findPeoplePrivacy = new FirestoreFindPeoplePrivacy(firestore);
  const projector = new CatalogProjector({
    repository,
    source,
    clock,
    activityEnabled,
    scenarioEnabled,
    findPeopleEnabled,
  });
  const reconciler = new CatalogReconciler(repository, source, projector, clock);
  const sets = new CatalogSets(repository, source, projector, reconciler, clock);
  const query = new CatalogQueryService(
    repository,
    new ReferenceDataRevisions(references),
    clock,
    activityEnabled,
    placeLinks,
    publishedObjects,
    async (item, direct) => {
      // D3.7 §6: no anonymous reads; the fresh gate decides every response.
      if (item.typeId === 'find_people')
        return findPeoplePrivacy.catalogItemVisible({
          viewerUserId: options.viewerId,
          contentId: item.contentId,
          publishedRevisionId: item.publishedRevisionId,
          publisherRef: item.publisherRef,
          hostUserId: item.hostUserId,
          meetingEndUtc: item.occurrences[0]?.endAtUtc ?? null,
          nowUtc: clock.now().toISOString(),
        });
      const user = await publisherUser(firestore, item.publisherRef);
      if (user === null)
        return !(await safetyRestricted(firestore, 'catalog', '', clock.now(), item.contentId));
      if (await safetyRestricted(firestore, 'catalog', user, clock.now(), item.contentId))
        return false;
      if (!options.viewerId) return true;
      const effects = await relationEffects(firestore, options.viewerId, user);
      return !(effects.blocked || effects.muted) || (direct && item.typeId === 'event');
    },
    { enabled: scenarioEnabled, stops: scenarioStops },
    findPeopleEnabled,
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
    scenarioStops,
  });
}
