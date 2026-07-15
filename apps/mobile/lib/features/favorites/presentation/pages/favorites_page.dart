import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../discover/application/controllers/discover_feed_controller.dart';
import '../../../discover/application/discover_providers.dart';
import '../../../discover/application/queries/discover_query.dart';
import '../../../discover/application/smart_search_parser.dart';
import '../../../discover/domain/entities/saved_search_entity.dart';
import '../../../discover/domain/entities/smart_search_history_entity.dart';
import '../../application/controllers/favorites_controller.dart';
import '../../application/favorites_providers.dart';
import '../../application/state/favorites_state.dart';
import '../../domain/entities/favorite_item_entity.dart';

enum _FavoritesFilter {
  all,
  upcoming,
  free,
}

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  _FavoritesFilter _filter = _FavoritesFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
      ref.read(discoverFeedControllerProvider).ensureSavedSearchesLoaded();
      ref.read(discoverFeedControllerProvider).ensureSmartSearchHistoryLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FavoritesController controller =
        ref.watch(favoritesControllerProvider);
    final FavoritesState state = controller.state;
    final DiscoverFeedController discoverController =
        ref.watch(discoverFeedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
      ),
      body: switch (state.status) {
        FavoritesStatus.initial || FavoritesStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        FavoritesStatus.error => _StateMessage(
            message: state.message ?? 'Не удалось загрузить избранное',
            actionLabel: 'Повторить',
            onAction: controller.loadFavorites,
          ),
        FavoritesStatus.ready => _buildReadyState(
            context: context,
            controller: controller,
            discoverController: discoverController,
            items: state.items,
            savedSearches: discoverController.state.savedSearches,
            smartSearchHistory: discoverController.state.smartSearchHistory,
          ),
      },
    );
  }

  Widget _buildReadyState({
    required BuildContext context,
    required FavoritesController controller,
    required DiscoverFeedController discoverController,
    required List<FavoriteItemEntity> items,
    required List<SavedSearchEntity> savedSearches,
    required List<SmartSearchHistoryEntity> smartSearchHistory,
  }) {
    if (items.isEmpty && savedSearches.isEmpty && smartSearchHistory.isEmpty) {
      return _StateMessage(
        message: 'Пока нет сохраненных событий',
        actionLabel: 'Открыть Discover',
        onAction: () async => context.go(RouteNames.discover),
      );
    }

    final List<FavoriteItemEntity> visibleItems = _filteredItems(items);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _FavoritesHero(
          totalCount:
              items.length + savedSearches.length + smartSearchHistory.length,
          freeCount:
              items.where((FavoriteItemEntity item) => item.isFree).length,
          nextItem: _nextUpcoming(items),
          onDiscoverTap: () => context.go(RouteNames.discover),
          onMapTap: () => context.go(RouteNames.discoverMap),
        ),
        const SizedBox(height: 14),
        if (savedSearches.isNotEmpty ||
            smartSearchHistory.isNotEmpty) ...<Widget>[
          _SavedIntentSection(
            savedSearches: savedSearches,
            smartSearchHistory: smartSearchHistory,
            onResumeSavedSearch: (SavedSearchEntity search) {
              context.go(_searchRouteForSavedSearch(search));
            },
            onMapSavedSearch: (SavedSearchEntity search) {
              context.go(_mapRouteForSavedSearch(search));
            },
            onRouteSavedSearch: (SavedSearchEntity search) {
              context.go(_scenarioBuilderRouteForSavedSearch(search));
            },
            onCreateSavedSearch: (SavedSearchEntity search) {
              context.go(_createRouteForSavedSearch(search));
            },
            onDeleteSavedSearch: (SavedSearchEntity search) {
              discoverController.deleteSavedSearch(search.id);
            },
            onResumeSmartSearch: (SmartSearchHistoryEntity item) {
              context.go(_searchRouteForSmartSearch(item));
            },
            onMapSmartSearch: (SmartSearchHistoryEntity item) {
              context.go(_mapRouteForSmartSearch(item));
            },
            onRouteSmartSearch: (SmartSearchHistoryEntity item) {
              context.go(_scenarioBuilderRouteForSmartSearch(item));
            },
            onCreateSmartSearch: (SmartSearchHistoryEntity item) {
              context.go(_createRouteForSmartSearch(item));
            },
            onDeleteSmartSearch: (SmartSearchHistoryEntity item) {
              discoverController.deleteSmartSearchPrompt(item.id);
            },
          ),
          const SizedBox(height: 14),
        ],
        if (items.isNotEmpty) ...<Widget>[
          _FavoritesFilterBar(
            selected: _filter,
            onChanged: (_FavoritesFilter next) {
              setState(() => _filter = next);
            },
          ),
          const SizedBox(height: 14),
          if (visibleItems.isEmpty)
            _FilteredEmptyState(
              onReset: () => setState(() => _filter = _FavoritesFilter.all),
            )
          else
            ...visibleItems.map(
              (FavoriteItemEntity item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FavoritePlanCard(
                  item: item,
                  onOpen: () {
                    if (item.targetRoute != null &&
                        item.targetRoute!.isNotEmpty) {
                      context.go(item.targetRoute!);
                      return;
                    }
                    if (item.category == 'scenario') {
                      context.go(RouteNames.scenarioBuilder);
                      return;
                    }
                    context.push('${RouteNames.discoverDetails}/${item.id}');
                  },
                  onMap: () => context.go(_mapRouteForFavorite(item)),
                  onRemove: () {
                    controller.removeFavorite(
                      item.id,
                      sourceScreen: 'favorites',
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  List<FavoriteItemEntity> _filteredItems(List<FavoriteItemEntity> items) {
    final DateTime now = DateTime.now().toUtc();
    return switch (_filter) {
      _FavoritesFilter.all => items,
      _FavoritesFilter.upcoming => items
          .where((FavoriteItemEntity item) => item.startsAtUtc.isAfter(now))
          .toList(growable: false),
      _FavoritesFilter.free => items
          .where((FavoriteItemEntity item) => item.isFree)
          .toList(growable: false),
    };
  }

  FavoriteItemEntity? _nextUpcoming(List<FavoriteItemEntity> items) {
    final DateTime now = DateTime.now().toUtc();
    final List<FavoriteItemEntity> upcoming = items
        .where((FavoriteItemEntity item) => item.startsAtUtc.isAfter(now))
        .toList(growable: false)
      ..sort(
        (FavoriteItemEntity a, FavoriteItemEntity b) =>
            a.startsAtUtc.compareTo(b.startsAtUtc),
      );
    return upcoming.isEmpty ? null : upcoming.first;
  }
}

class _FavoritesHero extends StatelessWidget {
  const _FavoritesHero({
    required this.totalCount,
    required this.freeCount,
    required this.nextItem,
    required this.onDiscoverTap,
    required this.onMapTap,
  });

  final int totalCount;
  final int freeCount;
  final FavoriteItemEntity? nextItem;
  final VoidCallback onDiscoverTap;
  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.bookmark, color: colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Saved plans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              nextItem == null
                  ? 'Build a shortlist for your next recharge.'
                  : 'Next up: ${nextItem!.title}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HeroPill(label: '$totalCount saved'),
                _HeroPill(label: '$freeCount free'),
                if (nextItem != null)
                  _HeroPill(label: _formatDate(nextItem!.startsAtUtc)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMapTap,
                    icon: const Icon(Icons.map),
                    label: const Text('Map'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDiscoverTap,
                    icon: const Icon(Icons.explore),
                    label: const Text('Discover'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(
                        color: colorScheme.onPrimary.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SavedIntentSection extends StatelessWidget {
  const _SavedIntentSection({
    required this.savedSearches,
    required this.smartSearchHistory,
    required this.onResumeSavedSearch,
    required this.onMapSavedSearch,
    required this.onRouteSavedSearch,
    required this.onCreateSavedSearch,
    required this.onDeleteSavedSearch,
    required this.onResumeSmartSearch,
    required this.onMapSmartSearch,
    required this.onRouteSmartSearch,
    required this.onCreateSmartSearch,
    required this.onDeleteSmartSearch,
  });

  final List<SavedSearchEntity> savedSearches;
  final List<SmartSearchHistoryEntity> smartSearchHistory;
  final ValueChanged<SavedSearchEntity> onResumeSavedSearch;
  final ValueChanged<SavedSearchEntity> onMapSavedSearch;
  final ValueChanged<SavedSearchEntity> onRouteSavedSearch;
  final ValueChanged<SavedSearchEntity> onCreateSavedSearch;
  final ValueChanged<SavedSearchEntity> onDeleteSavedSearch;
  final ValueChanged<SmartSearchHistoryEntity> onResumeSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onMapSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onRouteSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onCreateSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onDeleteSmartSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          icon: Icons.auto_awesome,
          title: 'Saved intents',
          subtitle: 'Conditions and prompts ready to continue',
        ),
        const SizedBox(height: 10),
        ...savedSearches.map(
          (SavedSearchEntity search) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SavedIntentCard(
              icon: Icons.tune,
              label: 'Saved conditions',
              title: search.title,
              subtitle: search.subtitle,
              chips: _queryChips(search.query),
              deleteTooltip: 'Delete saved conditions',
              routeTooltip: 'Build route from saved conditions',
              createTooltip: 'Create listing from saved conditions',
              onResume: () => onResumeSavedSearch(search),
              onMap: () => onMapSavedSearch(search),
              onRoute: () => onRouteSavedSearch(search),
              onCreate: () => onCreateSavedSearch(search),
              onDelete: () => onDeleteSavedSearch(search),
            ),
          ),
        ),
        ...smartSearchHistory.map(
          (SmartSearchHistoryEntity item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SavedIntentCard(
              icon: Icons.psychology_alt_outlined,
              label: 'Smart search',
              title: item.prompt,
              subtitle: _promptForQuery(item.query),
              chips: _smartSearchChips(item),
              deleteTooltip: 'Delete smart search',
              routeTooltip: 'Build route from smart search',
              createTooltip: 'Create listing from smart search',
              onResume: () => onResumeSmartSearch(item),
              onMap: () => onMapSmartSearch(item),
              onRoute: () => onRouteSmartSearch(item),
              onCreate: () => onCreateSmartSearch(item),
              onDelete: () => onDeleteSmartSearch(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedIntentCard extends StatelessWidget {
  const _SavedIntentCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.deleteTooltip,
    required this.routeTooltip,
    required this.createTooltip,
    required this.onResume,
    required this.onMap,
    required this.onRoute,
    required this.onCreate,
    required this.onDelete,
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final List<_IntentChipData> chips;
  final String deleteTooltip;
  final String routeTooltip;
  final String createTooltip;
  final VoidCallback onResume;
  final VoidCallback onMap;
  final VoidCallback onRoute;
  final VoidCallback onCreate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: deleteTooltip,
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (_IntentChipData chip) => _MetaChip(
                      icon: chip.icon,
                      label: chip.label,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Resume'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: routeTooltip,
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: createTooltip,
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentChipData {
  const _IntentChipData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _FavoritesFilterBar extends StatelessWidget {
  const _FavoritesFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _FavoritesFilter selected;
  final ValueChanged<_FavoritesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_FavoritesFilter>(
      segments: const <ButtonSegment<_FavoritesFilter>>[
        ButtonSegment<_FavoritesFilter>(
          value: _FavoritesFilter.all,
          icon: Icon(Icons.dashboard),
          label: Text('All'),
        ),
        ButtonSegment<_FavoritesFilter>(
          value: _FavoritesFilter.upcoming,
          icon: Icon(Icons.event_available),
          label: Text('Soon'),
        ),
        ButtonSegment<_FavoritesFilter>(
          value: _FavoritesFilter.free,
          icon: Icon(Icons.local_offer),
          label: Text('Free'),
        ),
      ],
      selected: <_FavoritesFilter>{selected},
      onSelectionChanged: (Set<_FavoritesFilter> values) {
        onChanged(values.first);
      },
    );
  }
}

class _FavoritePlanCard extends StatelessWidget {
  const _FavoritePlanCard({
    required this.item,
    required this.onOpen,
    required this.onMap,
    required this.onRemove,
  });

  final FavoriteItemEntity item;
  final VoidCallback onOpen;
  final VoidCallback onMap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isScenario = item.category == 'scenario';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить из избранного',
                  onPressed: onRemove,
                  icon: const Icon(Icons.favorite),
                  color: colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (isScenario)
                  const _MetaChip(icon: Icons.route, label: 'Route scenario'),
                _MetaChip(icon: Icons.category, label: item.category),
                _MetaChip(icon: Icons.place, label: item.city),
                _MetaChip(
                  icon: Icons.near_me,
                  label: '${item.distanceKm.toStringAsFixed(1)} km',
                ),
                _MetaChip(
                  icon: Icons.schedule,
                  label: _formatDate(item.startsAtUtc),
                ),
                _MetaChip(
                  icon: Icons.payments,
                  label: item.isFree
                      ? 'Free'
                      : '${item.priceAmount.toStringAsFixed(0)} EUR',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: Icon(
                      isScenario ? Icons.edit_location_alt : Icons.open_in_new,
                    ),
                    label: Text(isScenario ? 'Edit' : 'Open'),
                  ),
                ),
                const SizedBox(width: 10),
                if (isScenario)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMap,
                      icon: const Icon(Icons.route),
                      label: const Text('Route'),
                    ),
                  )
                else
                  IconButton.outlined(
                    tooltip: 'Показать на карте',
                    onPressed: onMap,
                    icon: const Icon(Icons.map),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: colorScheme.secondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.onReset,
  });

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          const Icon(Icons.filter_alt_off, size: 36),
          const SizedBox(height: 10),
          const Text('В этом фильтре пока пусто'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReset,
            child: const Text('Показать все'),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month, $hour:$minute';
}

String _mapRouteForFavorite(FavoriteItemEntity item) {
  if (item.category != 'scenario') return RouteNames.discoverMap;
  final String? targetRoute = item.targetRoute;
  if (targetRoute == null || targetRoute.trim().isEmpty) {
    return RouteNames.discoverMap;
  }

  final Uri targetUri = Uri.parse(targetRoute);
  final Map<String, String> params =
      Map<String, String>.from(targetUri.queryParameters);
  final String? steps = params['steps'];
  if (steps == null || steps.trim().isEmpty) {
    return RouteNames.discoverMap;
  }
  params['mode'] = 'scenario';
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: params,
  ).toString();
}

String _searchRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForQuery(RouteNames.search, search.query);
}

String _mapRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForQuery(RouteNames.discoverMap, search.query);
}

String _createRouteForSavedSearch(SavedSearchEntity search) {
  final Map<String, String> params = <String, String>{
    ..._queryParametersForQuery(search.query),
    'source': 'saved_search',
    'type': 'event',
    'title': search.title,
    'subtitle': search.subtitle,
  };
  return Uri(
    path: RouteNames.create,
    queryParameters: params,
  ).toString();
}

String _scenarioBuilderRouteForSavedSearch(SavedSearchEntity search) {
  return _scenarioBuilderRouteForQuery(
    search.query,
    prompt: _promptForQuery(search.query),
  );
}

String _searchRouteForSmartSearch(SmartSearchHistoryEntity item) {
  return _discoverRouteForQuery(RouteNames.search, item.query);
}

String _mapRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _smartRouteParameters(
        parseResult,
        includeMode: true,
      ),
    ).toString();
  }
  return _discoverRouteForQuery(RouteNames.discoverMap, item.query);
}

String _createRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle': '${routeIntent.stepCategories.length} stops · '
            '${routeIntent.durationMinutes} min · smart route',
        'q': parseResult.originalText.trim(),
        'category': 'scenario',
      },
    ).toString();
  }
  final Map<String, String> params = <String, String>{
    ..._queryParametersForQuery(item.query),
    'source': 'smart_search',
    'type': 'event',
    'title': _titleForQuery(item.query),
    'subtitle': item.prompt,
  };
  return Uri(
    path: RouteNames.create,
    queryParameters: params,
  ).toString();
}

String _scenarioBuilderRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _smartRouteParameters(
        parseResult,
        includeMode: false,
      ),
    ).toString();
  }
  final String prompt = item.prompt.trim().isEmpty
      ? _promptForQuery(item.query)
      : item.prompt.trim();
  return _scenarioBuilderRouteForQuery(item.query, prompt: prompt);
}

SmartSearchParseResult? _smartRouteParseForSmartSearch(
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent == null) return null;
  return parseResult;
}

Map<String, String> _smartRouteParameters(
  SmartSearchParseResult parseResult, {
  required bool includeMode,
}) {
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <String, String>{
    if (includeMode) 'mode': 'scenario',
    'mood': routeIntent.mood,
    'duration': routeIntent.durationMinutes.toString(),
    'free': routeIntent.freeOnly ? '1' : '0',
    'walking': routeIntent.walkingOnly ? '1' : '0',
    if (parseResult.originalText.trim().isNotEmpty)
      'prompt': parseResult.originalText.trim(),
    if (routeIntent.stepCategories.isNotEmpty)
      'steps': routeIntent.stepCategories.join(','),
  };
}

String _discoverRouteForQuery(String path, DiscoverQuery query) {
  return Uri(
    path: path,
    queryParameters: _queryParametersForQuery(query),
  ).toString();
}

Map<String, String> _queryParametersForQuery(DiscoverQuery query) {
  return <String, String>{
    'q': query.queryText.trim(),
    'category': query.selectedCategoryIds.join(','),
    'free': query.freeOnly ? '1' : '0',
    if (query.budgetMax != null)
      'budgetMax': query.budgetMax!.toStringAsFixed(0),
    if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
    if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
    'radius': query.radiusMeters.round().toString(),
    'unlimited': query.unlimitedRadius ? '1' : '0',
  };
}

String _scenarioBuilderRouteForQuery(
  DiscoverQuery query, {
  required String prompt,
}) {
  final Map<String, String> params = <String, String>{
    'mood': _scenarioMoodForQuery(query),
    'duration': query.radiusMeters <= 5000 ? '120' : '180',
    'walking': query.unlimitedRadius ? '0' : '1',
    if (query.freeOnly) 'free': '1',
    if (prompt.isNotEmpty) 'prompt': prompt,
  };
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: params,
  ).toString();
}

String _scenarioMoodForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.toLowerCase();
  if (queryText.contains('run') ||
      queryText.contains('sport') ||
      queryText.contains('tennis') ||
      query.selectedCategoryIds.contains('outdoor')) {
    return 'active';
  }
  if (query.selectedCategoryIds.any(
    (String category) {
      return category == 'art' || category == 'music' || category == 'family';
    },
  )) {
    return 'social';
  }
  return 'calm';
}

String _promptForQuery(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.queryText.trim().isNotEmpty) query.queryText.trim(),
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null)
      'under ${query.budgetMax!.toStringAsFixed(0)}',
    query.unlimitedRadius
        ? 'any area'
        : 'near ${(query.radiusMeters / 1000).round()} km',
  ];
  return parts.join(' · ');
}

String _titleForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return 'Recharge idea';
}

String _capitalized(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

List<_IntentChipData> _smartSearchChips(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  final List<_IntentChipData> queryChips = _queryChips(item.query);
  if (parseResult == null) return queryChips;
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <_IntentChipData>[
    const _IntentChipData(
      icon: Icons.route_outlined,
      label: 'Smart route',
    ),
    _IntentChipData(
      icon: Icons.timer_outlined,
      label: '${routeIntent.durationMinutes} min',
    ),
    _IntentChipData(
      icon: Icons.flag_outlined,
      label: '${routeIntent.stepCategories.length} stops',
    ),
    ...queryChips,
  ];
}

List<_IntentChipData> _queryChips(DiscoverQuery query) {
  return <_IntentChipData>[
    _IntentChipData(
      icon: Icons.category_outlined,
      label: query.selectedCategoryIds.isEmpty
          ? 'All'
          : query.selectedCategoryIds.first,
    ),
    _IntentChipData(
      icon: Icons.near_me_outlined,
      label: query.unlimitedRadius
          ? 'Any area'
          : '${(query.radiusMeters / 1000).round()} km',
    ),
    if (query.freeOnly)
      const _IntentChipData(icon: Icons.payments_outlined, label: 'Free'),
    if (query.budgetMax != null)
      _IntentChipData(
        icon: Icons.savings_outlined,
        label: 'Under ${query.budgetMax!.toStringAsFixed(0)}',
      ),
  ];
}
