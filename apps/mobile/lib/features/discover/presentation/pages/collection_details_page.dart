import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/application/collection_discover_providers.dart';
import '../../../../app/router/route_names.dart';
import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';
import '../../domain/repositories/collection_item_resolution_repository.dart';
import '../widgets/collection_details_mini_map.dart';

/// Reader-facing Details for one published Collection
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §13). A dedicated page rather
/// than a branch inside the large generic `DiscoverDetailsPage` — Collection
/// has no single coordinate/CTA shape to fit that page's point-object
/// layout, and this keeps the change additive instead of touching a
/// heavily shared file (see the session's option-2 decision).
class CollectionDetailsPage extends ConsumerWidget {
  const CollectionDetailsPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublishedCollectionDiscoveryEntity?> entityAsync = ref
        .watch(collectionByIdProvider(collectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: entityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text('Could not load this Collection: $error')),
        data: (PublishedCollectionDiscoveryEntity? entity) {
          if (entity == null) {
            return const Center(child: Text('This Collection is not available.'));
          }
          return _CollectionDetailsBody(entity: entity);
        },
      ),
    );
  }
}

class _CollectionDetailsBody extends ConsumerWidget {
  const _CollectionDetailsBody({required this.entity});

  final PublishedCollectionDiscoveryEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, CollectionResolvedItem>> resolvedAsync = ref
        .watch(collectionResolvedItemsProvider(entity.collectionId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          entity.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(entity.shortDescription),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: Text(entity.areaLabel)),
            if (entity.budgetTier != null) Chip(label: Text(entity.budgetTier!)),
            Chip(label: Text('${entity.itemCount} items')),
            Chip(label: Text('By ${entity.publisherName}')),
          ],
        ),
        const SizedBox(height: 16),
        resolvedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) =>
              Text('Could not load items: $error'),
          data: (Map<String, CollectionResolvedItem> resolved) {
            final List<CollectionResolvedItem> ordered = entity.items
                .map(
                  (PublishedCollectionItemRef ref) => resolved[ref.stableKey],
                )
                .whereType<CollectionResolvedItem>()
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CollectionDetailsMiniMap(resolvedItems: ordered),
                const SizedBox(height: 16),
                ..._groupedSections(entity, resolved, context),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _groupedSections(
    PublishedCollectionDiscoveryEntity entity,
    Map<String, CollectionResolvedItem> resolved,
    BuildContext context,
  ) {
    final Map<String?, List<PublishedCollectionItemRef>> bySection =
        <String?, List<PublishedCollectionItemRef>>{};
    for (final PublishedCollectionItemRef ref in entity.items) {
      bySection.putIfAbsent(ref.sectionId, () => <PublishedCollectionItemRef>[]).add(ref);
    }
    final List<Widget> widgets = <Widget>[];
    final List<PublishedCollectionSectionRef> sortedSections = entity.sections
        .toList()
      ..sort(
        (
          PublishedCollectionSectionRef a,
          PublishedCollectionSectionRef b,
        ) => a.order.compareTo(b.order),
      );
    for (final PublishedCollectionSectionRef section in sortedSections) {
      final List<PublishedCollectionItemRef> refs =
          bySection[section.id] ?? const <PublishedCollectionItemRef>[];
      if (refs.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
      final List<PublishedCollectionItemRef> sortedRefs =
          List<PublishedCollectionItemRef>.of(refs)
            ..sort(
              (PublishedCollectionItemRef a, PublishedCollectionItemRef b) =>
                  a.order.compareTo(b.order),
            );
      for (final PublishedCollectionItemRef ref in sortedRefs) {
        widgets.add(_itemTile(ref, resolved[ref.stableKey], context));
      }
    }
    final List<PublishedCollectionItemRef> unsectioned = (bySection[null] ?? const <PublishedCollectionItemRef>[])
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final PublishedCollectionItemRef ref in unsectioned) {
      widgets.add(_itemTile(ref, resolved[ref.stableKey], context));
    }
    return widgets;
  }

  /// `DTL-LINK-01` §3.2: navigation into a Collection item's own Details,
  /// via `CatalogObjectRef` wherever [ref]'s `objectType` string parses —
  /// which it always does for data this class itself produced
  /// (`CollectionPublicationDiscoveryAdapter` sets `objectType` from
  /// `CreateObjectType.name`, and `catalogObjectTypeFromTaxonomyId`
  /// accepts that form too). The untyped fallback exists only for
  /// defensive robustness against a malformed/legacy stored record — it is
  /// not expected to be exercised by any producer in this codebase today.
  String _detailsLocationFor(PublishedCollectionItemRef ref) {
    final CatalogObjectType? objectType = catalogObjectTypeFromTaxonomyId(
      ref.objectType,
    );
    if (objectType == null) {
      return '${RouteNames.discoverDetails}/${ref.objectId}';
    }
    return RouteNames.discoverDetailsCanonicalFor(
      CatalogObjectRef(objectType: objectType, objectId: ref.objectId),
    );
  }

  Widget _itemTile(
    PublishedCollectionItemRef ref,
    CollectionResolvedItem? resolved,
    BuildContext context,
  ) {
    if (resolved == null ||
        resolved.status == PublishedCollectionItemStatus.unavailable) {
      // Publicly hidden without an error — the author still sees the gap
      // in the Create block's own editor (§3.6, §13).
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        title: Text(resolved.card?.title ?? ''),
        subtitle: ref.curatorNote.isEmpty ? null : Text(ref.curatorNote),
        trailing: ref.highlight ? const Icon(Icons.star, color: Colors.amber) : null,
        onTap: () => context.go(_detailsLocationFor(ref)),
      ),
    );
  }
}
