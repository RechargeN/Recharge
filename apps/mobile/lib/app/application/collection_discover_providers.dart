import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/domain/entities/published_collection_discovery_entity.dart';
import '../../features/discover/domain/repositories/collection_item_resolution_repository.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';
import '../di/service_locator.dart';

/// App-level composition, not `features/discover/application/` — reads
/// only through the Discover-owned `PublishedCollectionDiscoveryPort`
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14), same layering as
/// `scenario_object_intake_providers.dart`. There is no separate
/// "Discover collection rendering" kill switch: when
/// `collectionPublishingEnabled` is off, nothing is ever written to the
/// discovery store, so `loadActiveCollections()` is naturally empty —
/// gating the read side too would just be dead code, not a real safeguard.
final activeCollectionsProvider =
    FutureProvider.autoDispose<List<PublishedCollectionDiscoveryEntity>>((
      ref,
    ) {
      return sl<PublishedCollectionDiscoveryPort>().loadActiveCollections();
    });

final collectionByIdProvider = FutureProvider.autoDispose
    .family<PublishedCollectionDiscoveryEntity?, String>((
      ref,
      collectionId,
    ) {
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
