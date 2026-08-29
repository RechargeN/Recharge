import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/application/collection_create_config.dart';
import '../../features/discover/domain/entities/published_collection_discovery_entity.dart';
import '../../features/discover/domain/repositories/collection_item_resolution_repository.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';
import '../di/service_locator.dart';

/// App-level composition, not `features/discover/application/` — reads
/// only through the Discover-owned `PublishedCollectionDiscoveryPort`
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14), same layering as
/// `scenario_object_intake_providers.dart`.
///
/// `collectionDiscoverEnabled` (§15 kill switch) is checked here, on the
/// read side, independently of `collectionPublishingEnabled` gating writes
/// on the Create side — the two are deliberately separate levers so
/// Discover's surface can be hidden on its own (e.g. an incident) without
/// freezing authors' ability to keep publishing, and vice versa.
final activeCollectionsProvider =
    FutureProvider.autoDispose<List<PublishedCollectionDiscoveryEntity>>((
      ref,
    ) {
      if (!sl<CollectionCreateRuntimeConfig>().collectionDiscoverEnabled) {
        return const <PublishedCollectionDiscoveryEntity>[];
      }
      return sl<PublishedCollectionDiscoveryPort>().loadActiveCollections();
    });

final collectionByIdProvider = FutureProvider.autoDispose
    .family<PublishedCollectionDiscoveryEntity?, String>((
      ref,
      collectionId,
    ) {
      if (!sl<CollectionCreateRuntimeConfig>().collectionDiscoverEnabled) {
        return null;
      }
      return sl<PublishedCollectionDiscoveryPort>().getActiveCollection(
        collectionId,
      );
    });

/// Live, batched resolution of one Collection's items for its Details page
/// (§13, §14) — never the authoring-time fallback snapshot. Keyed by
/// `collectionId` so re-opening the same Collection re-resolves instead of
/// reusing a stale result.
final collectionResolvedItemsProvider = FutureProvider.autoDispose
    .family<Map<String, CollectionResolvedItem>, String>((
      ref,
      collectionId,
    ) async {
      final PublishedCollectionDiscoveryEntity? entity = await ref.watch(
        collectionByIdProvider(collectionId).future,
      );
      if (entity == null) return const <String, CollectionResolvedItem>{};
      return sl<CollectionItemResolutionRepository>().resolveMany(
        entity.items,
      );
    });
