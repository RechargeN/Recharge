import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/application/collection_discover_providers.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';
import '../../domain/repositories/collection_item_resolution_repository.dart';
import '../renderers/collection_details_renderer.dart';
import '../shell/details_renderer.dart';
import '../shell/details_shell.dart';

/// Reader-facing Details for one published Collection
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §13). A dedicated page rather
/// than a branch inside the large generic `DiscoverDetailsPage` — Collection
/// has no single coordinate/CTA shape to fit that page's point-object
/// layout, and this keeps the change additive instead of touching a
/// heavily shared file (see the session's option-2 decision).
///
/// Since `DTL-CLG-01`, rendering itself lives in [CollectionDetailsRenderer]
/// under [DetailsShell] (`DTL-FND-01`) — this page only combines the two
/// providers a Collection Details view needs (the entity itself, and its
/// resolved items) into one [DetailsScreenState], exactly mirroring how
/// `DiscoverDetailsPage` composes `CompatibilityObjectRenderer`.
class CollectionDetailsPage extends ConsumerWidget {
  const CollectionDetailsPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublishedCollectionDiscoveryEntity?> entityAsync = ref
        .watch(collectionByIdProvider(collectionId));
    final AsyncValue<Map<String, CollectionResolvedItem>> resolvedAsync = ref
        .watch(collectionResolvedItemsProvider(collectionId));

    return DetailsShell(
      state: _stateFor(
        entityAsync: entityAsync,
        resolvedAsync: resolvedAsync,
        onRetry: () {
          ref.invalidate(collectionByIdProvider(collectionId));
          ref.invalidate(collectionResolvedItemsProvider(collectionId));
        },
      ),
    );
  }

  DetailsScreenState _stateFor({
    required AsyncValue<PublishedCollectionDiscoveryEntity?> entityAsync,
    required AsyncValue<Map<String, CollectionResolvedItem>> resolvedAsync,
    required VoidCallback onRetry,
  }) {
    // Two independent providers feed one Collection Details view (the
    // entity, and its resolved items) — both must have settled, with
    // neither in error, before this can be `available`. `resolvedAsync`
    // resolves to an empty map (not an error) when the entity itself is
    // missing, so the entity's own null-check below is what decides
    // `notFound`, not `resolvedAsync`.
    if (entityAsync.isLoading || resolvedAsync.isLoading) {
      return const DetailsScreenLoading();
    }
    if (entityAsync.hasError || resolvedAsync.hasError) {
      return DetailsScreenUnavailable(
        reason: DetailsUnavailableReason.temporarilyUnavailable,
        onRetry: onRetry,
      );
    }
    final PublishedCollectionDiscoveryEntity? entity = entityAsync.value;
    if (entity == null) {
      return const DetailsScreenUnavailable(
        reason: DetailsUnavailableReason.notFound,
      );
    }
    return DetailsScreenAvailable(
      renderer: DetailsRendererRegistry(<
        DetailsRendererFamily,
        DetailsRendererBuilder
      >{
        DetailsRendererFamily.collection: () => CollectionDetailsRenderer(
          entity: entity,
          resolvedItems: resolvedAsync.value ?? const <String, CollectionResolvedItem>{},
        ),
      }).build(DetailsRendererFamily.collection),
    );
  }
}
