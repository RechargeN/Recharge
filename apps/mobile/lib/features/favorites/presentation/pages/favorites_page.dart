import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
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

enum _FavoritesFilter { all, events, places, routes }

const Color _favoritesBackground = Color(0xFFF8FAF7);
const Color _favoritesCard = Color(0xFFFFFFFF);
const Color _rechargeGreen = Color(0xFF0B3028);
const Color _favoriteCardGreen = Color(0xFF004532);
const Color _favoritesChip = Color(0xFFEAF0EA);
const Color _favoritesBorder = Color(0x260B3028);

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
    final FavoritesController controller = ref.watch(
      favoritesControllerProvider,
    );
    final FavoritesState state = controller.state;
    final DiscoverFeedController discoverController = ref.watch(
      discoverFeedControllerProvider,
    );

    return Scaffold(
      backgroundColor: _favoritesBackground,
      appBar: AppBar(
        backgroundColor: _favoritesBackground,
        foregroundColor: _rechargeGreen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'RECHARGE',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: <Widget>[
        if (items.isNotEmpty) ...<Widget>[
          _FavoritesFilterBar(
            selected: _filter,
            onChanged: (_FavoritesFilter next) {
              setState(() => _filter = next);
            },
          ),
          const SizedBox(height: 12),
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
        if (savedSearches.isNotEmpty ||
            smartSearchHistory.isNotEmpty) ...<Widget>[
          if (items.isNotEmpty) const SizedBox(height: 10),
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
        ],
      ],
    );
  }

  List<FavoriteItemEntity> _filteredItems(List<FavoriteItemEntity> items) {
    return switch (_filter) {
      _FavoritesFilter.all => items,
      _FavoritesFilter.events =>
        items.where(_isEventFavorite).toList(growable: false),
      _FavoritesFilter.places =>
        items.where(_isPlaceFavorite).toList(growable: false),
      _FavoritesFilter.routes =>
        items
            .where((FavoriteItemEntity item) => _favoriteKind(item).isRoute)
            .toList(growable: false),
    };
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
    return Row(
      children: <Widget>[
        Icon(icon, color: _rechargeGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _rechargeGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _rechargeGreen.withValues(alpha: 0.68),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _favoritesCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _favoritesBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F0B3028),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _favoritesChip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: _rechargeGreen, size: 19),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _rechargeGreen,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (_IntentChipData chip) =>
                        _MetaChip(icon: chip.icon, label: chip.label),
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
  const _IntentChipData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _FavoritesFilterBar extends StatelessWidget {
  const _FavoritesFilterBar({required this.selected, required this.onChanged});

  final _FavoritesFilter selected;
  final ValueChanged<_FavoritesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _FavoriteFilterChip(
            icon: Icons.grid_view_rounded,
            label: 'All',
            selected: selected == _FavoritesFilter.all,
            onTap: () => onChanged(_FavoritesFilter.all),
          ),
          const SizedBox(width: 8),
          _FavoriteFilterChip(
            icon: Icons.event_available_outlined,
            label: 'Events',
            selected: selected == _FavoritesFilter.events,
            onTap: () => onChanged(_FavoritesFilter.events),
          ),
          const SizedBox(width: 8),
          _FavoriteFilterChip(
            icon: Icons.place_outlined,
            label: 'Places',
            selected: selected == _FavoritesFilter.places,
            onTap: () => onChanged(_FavoritesFilter.places),
          ),
          const SizedBox(width: 8),
          _FavoriteFilterChip(
            icon: Icons.route_outlined,
            label: 'Routes',
            selected: selected == _FavoritesFilter.routes,
            onTap: () => onChanged(_FavoritesFilter.routes),
          ),
        ],
      ),
    );
  }
}

class _FavoriteFilterChip extends StatelessWidget {
  const _FavoriteFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected ? _rechargeGreen : _favoritesChip;
    final Color foreground = selected ? Colors.white : _rechargeGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _rechargeGreen : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
    final _FavoriteKind kind = _favoriteKind(item);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 126,
        decoration: BoxDecoration(
          color: _favoriteCardGreen,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A003F32),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              _FavoritePreview(item: item, kind: kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _FavoriteTypeBadge(kind: kind),
                        const Spacer(),
                        _FavoriteActionsMenu(
                          isRoute: kind.isRoute,
                          onOpen: onOpen,
                          onMap: onMap,
                          onRemove: onRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.04,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _favoriteSubtitle(item, kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.favorite,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Избранное',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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

class _FavoritePreview extends StatelessWidget {
  const _FavoritePreview({required this.item, required this.kind});

  final FavoriteItemEntity item;
  final _FavoriteKind kind;

  @override
  Widget build(BuildContext context) {
    final String cover = item.coverImageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 106,
        height: 110,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (cover.isNotEmpty)
              Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _FavoritePreviewFallback(kind: kind),
              )
            else
              _FavoritePreviewFallback(kind: kind),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritePreviewFallback extends StatelessWidget {
  const _FavoritePreviewFallback({required this.kind});

  final _FavoriteKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kind.previewColors,
        ),
      ),
      child: Center(
        child: Icon(
          kind.icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 34,
        ),
      ),
    );
  }
}

class _FavoriteTypeBadge extends StatelessWidget {
  const _FavoriteTypeBadge({required this.kind});

  final _FavoriteKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(kind.icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              kind.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteActionsMenu extends StatelessWidget {
  const _FavoriteActionsMenu({
    required this.isRoute,
    required this.onOpen,
    required this.onMap,
    required this.onRemove,
  });

  final bool isRoute;
  final VoidCallback onOpen;
  final VoidCallback onMap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FavoriteAction>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_horiz, color: Colors.white),
      color: Colors.white,
      onSelected: (_FavoriteAction action) {
        switch (action) {
          case _FavoriteAction.open:
            onOpen();
            break;
          case _FavoriteAction.map:
            onMap();
            break;
          case _FavoriteAction.remove:
            onRemove();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_FavoriteAction>>[
        PopupMenuItem<_FavoriteAction>(
          value: _FavoriteAction.open,
          child: Text(isRoute ? 'Edit' : 'Open'),
        ),
        PopupMenuItem<_FavoriteAction>(
          value: _FavoriteAction.map,
          child: Text(isRoute ? 'Route' : 'Map'),
        ),
        const PopupMenuItem<_FavoriteAction>(
          value: _FavoriteAction.remove,
          child: Text('Remove'),
        ),
      ],
    );
  }
}

enum _FavoriteAction { open, map, remove }

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _favoritesChip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: _rechargeGreen),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _rechargeGreen,
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
  const _FilteredEmptyState({required this.onReset});

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
          OutlinedButton(onPressed: onReset, child: const Text('Показать все')),
        ],
      ),
    );
  }
}

class _FavoriteKind {
  const _FavoriteKind({
    required this.label,
    required this.icon,
    required this.previewColors,
    required this.isRoute,
  });

  final String label;
  final IconData icon;
  final List<Color> previewColors;
  final bool isRoute;
}

const _FavoriteKind _eventFavoriteKind = _FavoriteKind(
  label: 'EVENT',
  icon: Icons.event_available_outlined,
  previewColors: <Color>[Color(0xFF24405F), Color(0xFF0B3028)],
  isRoute: false,
);

const _FavoriteKind _placeFavoriteKind = _FavoriteKind(
  label: 'PLACE',
  icon: Icons.place_outlined,
  previewColors: <Color>[Color(0xFF6F8F87), Color(0xFF0B3028)],
  isRoute: false,
);

const _FavoriteKind _routeFavoriteKind = _FavoriteKind(
  label: 'ROUTE',
  icon: Icons.route_outlined,
  previewColors: <Color>[Color(0xFF607D5B), Color(0xFF0B3028)],
  isRoute: true,
);

_FavoriteKind _favoriteKind(FavoriteItemEntity item) {
  if (_isRouteFavorite(item)) return _routeFavoriteKind;
  if (_isPlaceFavorite(item)) return _placeFavoriteKind;
  return _eventFavoriteKind;
}

bool _isRouteFavorite(FavoriteItemEntity item) {
  final String category = item.category.trim().toLowerCase();
  final String? targetRoute = item.targetRoute?.toLowerCase();
  return category == 'scenario' ||
      category.contains('route') ||
      category.contains('tour') ||
      (targetRoute?.contains(RouteNames.scenarioBuilder) ?? false);
}

bool _isPlaceFavorite(FavoriteItemEntity item) {
  if (_isRouteFavorite(item)) return false;
  final String category = item.category.trim().toLowerCase();
  return category.contains('place') ||
      category.contains('venue') ||
      category.contains('museum') ||
      category.contains('food') ||
      category.contains('drinks') ||
      category.contains('nature');
}

bool _isEventFavorite(FavoriteItemEntity item) {
  return !_isRouteFavorite(item) && !_isPlaceFavorite(item);
}

String _favoriteSubtitle(FavoriteItemEntity item, _FavoriteKind kind) {
  if (kind.isRoute) {
    final String distance = item.distanceKm >= 100
        ? '${item.distanceKm.toStringAsFixed(0)} km'
        : '${item.distanceKm.toStringAsFixed(1)} km';
    return '${item.city} · $distance';
  }
  final String date = _compactDate(item.startsAtUtc);
  return '$date · ${item.city}';
}

String _compactDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
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
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _mapRouteForFavorite(FavoriteItemEntity item) {
  if (item.category != 'scenario') return RouteNames.discoverMap;
  final String? targetRoute = item.targetRoute;
  if (targetRoute == null || targetRoute.trim().isEmpty) {
    return RouteNames.discoverMap;
  }

  final Uri targetUri = Uri.parse(targetRoute);
  final Map<String, String> params = Map<String, String>.from(
    targetUri.queryParameters,
  );
  final String? steps = params['steps'];
  if (steps == null || steps.trim().isEmpty) {
    return RouteNames.discoverMap;
  }
  params['mode'] = 'scenario';
  return Uri(path: RouteNames.discoverMap, queryParameters: params).toString();
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
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _scenarioBuilderRouteForSavedSearch(SavedSearchEntity search) {
  return _scenarioBuilderRouteForQuery(
    search.query,
    prompt: _promptForQuery(search.query),
  );
}

String _searchRouteForSmartSearch(SmartSearchHistoryEntity item) {
  return Uri(
    path: RouteNames.smartSearch,
    queryParameters: <String, String>{'prompt': item.prompt},
  ).toString();
}

String _mapRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _smartRouteParameters(parseResult, includeMode: true),
    ).toString();
  }
  return _discoverRouteForQuery(RouteNames.discoverMap, item.query);
}

String _createRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle':
            '${routeIntent.stepCategories.length} stops · '
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
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _scenarioBuilderRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _smartRouteParameters(parseResult, includeMode: false),
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
  final Set<String> normalizedCategories = query.selectedCategoryIds
      .map(normalizeRechargeContentGroupId)
      .toSet();
  if (queryText.contains('run') ||
      queryText.contains('sport') ||
      queryText.contains('tennis') ||
      normalizedCategories.contains('sport') ||
      normalizedCategories.contains('outdoor_nature_walking')) {
    return 'active';
  }
  if (normalizedCategories.contains('art_culture_museums') ||
      normalizedCategories.contains('music_nightlife') ||
      normalizedCategories.contains('family_kids')) {
    return 'social';
  }
  return 'calm';
}

String _promptForQuery(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.queryText.trim().isNotEmpty) query.queryText.trim(),
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null) 'under ${query.budgetMax!.toStringAsFixed(0)}',
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
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  final List<_IntentChipData> queryChips = _queryChips(item.query);
  if (parseResult == null) return queryChips;
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <_IntentChipData>[
    const _IntentChipData(icon: Icons.route_outlined, label: 'Smart route'),
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
