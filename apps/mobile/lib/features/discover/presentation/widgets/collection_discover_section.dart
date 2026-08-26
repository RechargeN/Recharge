import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/application/collection_discover_providers.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';

/// A separate "Guides" section listing published Collections
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §13). Deliberately not merged
/// into the point-object feed/ranking pipeline built around
/// `DiscoverItemEntity` — Collection has no coordinate or start time to
/// rank by, and forcing it through that entity would mean either fabricated
/// values (forbidden, CLG-AC-13) or a breaking change to fields every other
/// Create type already depends on as non-null. Renders nothing when there
/// are no active Collections, so it never disturbs an otherwise-empty page.
class CollectionDiscoverSection extends ConsumerWidget {
  const CollectionDiscoverSection({super.key, required this.onOpenCollection});

  final ValueChanged<String> onOpenCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PublishedCollectionDiscoveryEntity>> collections =
        ref.watch(activeCollectionsProvider);
    return collections.when(
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace _) => const SizedBox.shrink(),
      data: (List<PublishedCollectionDiscoveryEntity> items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Guides',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final PublishedCollectionDiscoveryEntity entity in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CollectionCard(
                  entity: entity,
                  onTap: () => onOpenCollection(entity.collectionId),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.entity, required this.onTap});

  final PublishedCollectionDiscoveryEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.collections_bookmark,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entity.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entity.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${entity.areaLabel} · ${entity.itemCount} items',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
