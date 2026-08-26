import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';
import '../../domain/repositories/collection_item_resolution_repository.dart';
import '../shell/details_renderer.dart';
import '../widgets/collection_details_mini_map.dart';

/// [DetailsRenderer] for `CatalogObjectType.collection`
/// (`docs/product/DTL_CLG_01_COLLECTION_SHELL_MIGRATION_SLICE_SPEC.md`).
///
/// A **pure shell migration**, not a visual redesign (§1.1/§1.2 of that
/// spec): every widget/helper here is moved verbatim from the pre-slice
/// `_CollectionDetailsBody`/`CollectionDetailsPage` — same section order
/// (title/description → chips → mini-map → grouped sections), same
/// `ListView`+`Chip`+`Card` visual execution, same unavailable-item
/// hide-without-badge policy (`COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md:919`).
/// Only the container changes: `DetailsShell` instead of a bare `Scaffold`.
class CollectionDetailsRenderer implements DetailsRenderer {
  const CollectionDetailsRenderer({
    required this.entity,
    required this.resolvedItems,
  });

  final PublishedCollectionDiscoveryEntity entity;
  final Map<String, CollectionResolvedItem> resolvedItems;

  @override
  List<Widget> buildAppBarActions(BuildContext context) => const <Widget>[];

  // Collection has no single photo/cover shape to anchor a hero on today
  // (§1.1: this slice does not add one — that is visual-polish scope).
  @override
  Widget buildHero(BuildContext context) => const SizedBox.shrink();

  @override
  Widget buildBody(BuildContext context) {
    final List<CollectionResolvedItem> ordered = entity.items
        .map(
          (PublishedCollectionItemRef ref) => resolvedItems[ref.stableKey],
        )
        .whereType<CollectionResolvedItem>()
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(entity.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(entity.shortDescription),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text(entity.areaLabel)),
              if (entity.budgetTier != null)
                Chip(label: Text(entity.budgetTier!)),
              Chip(label: Text('${entity.itemCount} items')),
              Chip(label: Text('By ${entity.publisherName}')),
            ],
          ),
          const SizedBox(height: 16),
          CollectionDetailsMiniMap(resolvedItems: ordered),
          const SizedBox(height: 16),
          ..._groupedSections(context),
        ],
      ),
    );
  }

  // Collection has no single "booking"-like primary action today, unlike
  // Object/Offer/Route — DTL-CLG-01 CLG-D-AC-10: no fabricated CTA, and
  // DetailsShell itself skips the sticky container entirely when this
  // returns null (see `details_shell.dart`'s `_buildAvailable`).
  @override
  Widget? buildStickyAction(BuildContext context) => null;

  List<Widget> _groupedSections(BuildContext context) {
    final Map<String?, List<PublishedCollectionItemRef>> bySection =
        <String?, List<PublishedCollectionItemRef>>{};
    for (final PublishedCollectionItemRef ref in entity.items) {
      bySection
          .putIfAbsent(ref.sectionId, () => <PublishedCollectionItemRef>[])
          .add(ref);
    }
    final List<Widget> widgets = <Widget>[];
    final List<PublishedCollectionSectionRef> sortedSections = entity.sections
        .toList()
      ..sort(
        (PublishedCollectionSectionRef a, PublishedCollectionSectionRef b) =>
            a.order.compareTo(b.order),
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
        widgets.add(_itemTile(ref, resolvedItems[ref.stableKey], context));
      }
    }
    final List<PublishedCollectionItemRef> unsectioned =
        (bySection[null] ?? const <PublishedCollectionItemRef>[]).toList()
          ..sort(
            (PublishedCollectionItemRef a, PublishedCollectionItemRef b) =>
                a.order.compareTo(b.order),
          );
    for (final PublishedCollectionItemRef ref in unsectioned) {
      widgets.add(_itemTile(ref, resolvedItems[ref.stableKey], context));
    }
    return widgets;
  }

  Widget _itemTile(
    PublishedCollectionItemRef ref,
    CollectionResolvedItem? resolved,
    BuildContext context,
  ) {
    if (resolved == null ||
        resolved.status == PublishedCollectionItemStatus.unavailable) {
      // Publicly hidden without an error — the author still sees the gap
      // in the Create block's own editor
      // (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §3.6/§13/:919).
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        title: Text(resolved.card?.title ?? ''),
        subtitle: ref.curatorNote.isEmpty ? null : Text(ref.curatorNote),
        trailing: ref.highlight
            ? const Icon(Icons.star, color: Colors.amber)
            : null,
        onTap: () => context.go(_detailsLocationFor(ref)),
      ),
    );
  }

  /// `DTL-LINK-01` §3.2 (unchanged by this slice, moved verbatim):
  /// navigation into a Collection item's own Details via `CatalogObjectRef`
  /// wherever [ref]'s `objectType` string parses.
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
}
