import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../discover/application/discover_providers.dart';
import '../../../discover/domain/entities/discover_query.dart';
import '../../../discover/application/smart_search_parser.dart';
import '../../../discover/application/state/discover_feed_state.dart';
import '../../../discover/domain/entities/discover_item_entity.dart';
import '../../../discover/domain/entities/saved_search_entity.dart';
import '../../../discover/domain/entities/smart_search_history_entity.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/application/state/favorites_state.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/auth_providers.dart';

class DiscoverHubPage extends ConsumerStatefulWidget {
  const DiscoverHubPage({super.key, required this.favoriteApplied});

  final bool favoriteApplied;

  @override
  ConsumerState<DiscoverHubPage> createState() => _DiscoverHubPageState();
}

class _DiscoverHubPageState extends ConsumerState<DiscoverHubPage> {
  bool _snackShown = false;
  bool _favoritesRequested = false;

  static const List<_HomeCategory> _categories = <_HomeCategory>[
    _HomeCategory(id: null, label: 'All', icon: Icons.grid_view_rounded),
    _HomeCategory(
      id: 'sport',
      label: 'Sport',
      icon: Icons.sports_tennis_outlined,
    ),
    _HomeCategory(
      id: 'outdoor_nature_walking',
      label: 'Walks',
      icon: Icons.directions_walk,
    ),
    _HomeCategory(
      id: 'games_indoor',
      label: 'Games',
      icon: Icons.sports_esports_outlined,
    ),
    _HomeCategory(
      id: 'music_nightlife',
      label: 'Music',
      icon: Icons.music_note_outlined,
    ),
    _HomeCategory(
      id: 'art_culture_museums',
      label: 'Art',
      icon: Icons.palette_outlined,
    ),
    _HomeCategory(
      id: 'food_drinks',
      label: 'Food',
      icon: Icons.local_cafe_outlined,
    ),
    _HomeCategory(
      id: 'wellness_recharge',
      label: 'Wellness',
      icon: Icons.self_improvement_rounded,
    ),
  ];

  static const List<_ScenarioCardData> _scenarios = <_ScenarioCardData>[
    _ScenarioCardData(
      title: 'Free today',
      subtitle: 'Activities nearby without tickets',
      icon: Icons.bolt_outlined,
      freeOnly: true,
    ),
    _ScenarioCardData(
      title: 'Near me',
      subtitle: 'Use the map radius and quick list',
      icon: Icons.near_me_outlined,
      opensMap: true,
    ),
    _ScenarioCardData(
      title: 'Evening plans',
      subtitle: 'Find something after work',
      icon: Icons.nightlight_outlined,
      queryText: 'evening',
    ),
  ];

  static const List<_HomeRouteTemplate> _routeTemplates = <_HomeRouteTemplate>[
    _HomeRouteTemplate(
      title: 'Coffee reset',
      subtitle: 'A calm cafe start with an easy city walk.',
      icon: Icons.local_cafe_outlined,
      mood: 'calm',
      durationMinutes: 90,
      freeOnly: false,
      walkingOnly: true,
      prompt: 'coffee reset walk',
      steps: <String>['food_drinks.coffee', 'wellness_recharge.calm_walk'],
    ),
    _HomeRouteTemplate(
      title: 'Free city reset',
      subtitle: 'A free low-pressure route for a quick recharge.',
      icon: Icons.self_improvement,
      mood: 'calm',
      durationMinutes: 90,
      freeOnly: true,
      walkingOnly: true,
      prompt: 'free calm city walk',
      steps: <String>['wellness_recharge.calm_walk'],
    ),
    _HomeRouteTemplate(
      title: 'Social evening',
      subtitle: 'Start social, then keep the night nearby.',
      icon: Icons.groups_outlined,
      mood: 'social',
      durationMinutes: 150,
      freeOnly: false,
      walkingOnly: true,
      prompt: 'social evening near me',
      steps: <String>[
        'games_indoor.board_games',
        'music_nightlife.afterwork_drinks',
      ],
    ),
    _HomeRouteTemplate(
      title: 'Active boost',
      subtitle: 'Move first, then cool down on a walk.',
      icon: Icons.directions_run,
      mood: 'active',
      durationMinutes: 120,
      freeOnly: false,
      walkingOnly: true,
      prompt: 'active tennis and walk',
      steps: <String>['sport.tennis', 'outdoor_nature_walking.city_walk'],
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_favoritesRequested) {
      _favoritesRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(discoverFeedControllerProvider).ensureLoaded();
        ref.read(favoritesControllerProvider).ensureLoaded();
        ref.read(discoverFeedControllerProvider).ensureSavedSearchesLoaded();
        ref
            .read(discoverFeedControllerProvider)
            .ensureSmartSearchHistoryLoaded();
      });
    }
    if (widget.favoriteApplied && !_snackShown) {
      _snackShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Сохранено в избранное')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final authState = authController.state;
    final FavoritesState favoritesState = ref
        .watch(favoritesControllerProvider)
        .state;
    final discoverState = ref.watch(discoverFeedControllerProvider).state;
    final savedSearches = discoverState.savedSearches;
    final smartSearchHistory = discoverState.smartSearchHistory;
    final FavoriteItemEntity? savedScenario = _latestSavedScenario(
      favoritesState.items,
    );
    final SavedSearchEntity? savedSearch = savedSearches.isEmpty
        ? null
        : savedSearches.first;
    final SmartSearchHistoryEntity? smartSearch = _latestSmartSearch(
      smartSearchHistory,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF003F32),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF064936),
              Color(0xFF003F32),
              Color(0xFF002C25),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            children: <Widget>[
              _HomeHero(
                onSearch: () => context.go(RouteNames.search),
                onMap: () => context.go(RouteNames.discoverMap),
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Categories',
                actionLabel: 'View all',
                onAction: () => context.go(RouteNames.search),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    final _HomeCategory category = _categories[index];
                    return _CategoryPill(
                      category: category,
                      selected: index == 0,
                      onTap: () => _openCategory(category.id),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemCount: _categories.length,
                ),
              ),
              const SizedBox(height: 16),
              _HomeActivitySections(
                state: discoverState,
                onViewAll: () => context.go(RouteNames.search),
                onOpenDetails: (DiscoverItemEntity item) {
                  context.push('${RouteNames.discoverDetails}/${item.id}');
                },
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Quick scenarios',
                actionLabel: 'Smart search',
                onAction: () => context.go(RouteNames.search),
              ),
              const SizedBox(height: 10),
              Column(
                children: _scenarios
                    .map(
                      (_ScenarioCardData scenario) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScenarioCard(
                          scenario: scenario,
                          onTap: () => _openScenario(scenario),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Route ideas',
                actionLabel: 'Builder',
                onAction: () => context.go(RouteNames.scenarioBuilder),
              ),
              const SizedBox(height: 10),
              _HomeRouteTemplateRail(
                templates: _routeTemplates,
                onBuild: _openRouteTemplate,
                onMap: _openRouteTemplateMap,
                onCreate: _openRouteTemplateCreate,
              ),
              if (savedScenario != null) ...<Widget>[
                const SizedBox(height: 12),
                _SavedScenarioPanel(
                  scenario: savedScenario,
                  onEdit: () => _openSavedScenario(savedScenario),
                  onRoute: () => _openSavedScenarioMap(savedScenario),
                ),
              ],
              if (smartSearch != null) ...<Widget>[
                const SizedBox(height: 12),
                _SmartSearchPanel(
                  item: smartSearch,
                  onResume: () => _openSmartSearch(smartSearch),
                  onMap: () => _openSmartSearchMap(smartSearch),
                  onRoute: () => _openSmartSearchRoute(smartSearch),
                  onCreate: () => _openSmartSearchCreate(smartSearch),
                ),
              ],
              if (savedSearch != null) ...<Widget>[
                const SizedBox(height: 12),
                _SavedSearchPanel(
                  search: savedSearch,
                  onResume: () => _openSavedSearch(savedSearch),
                  onMap: () => _openSavedSearchMap(savedSearch),
                  onRoute: () => _openSavedSearchRoute(savedSearch),
                  onCreate: () => _openSavedSearchCreate(savedSearch),
                ),
              ],
              const SizedBox(height: 14),
              _ForYouStrip(
                onPopular: () => context.go(RouteNames.search),
                onScenario: () => context.go(RouteNames.scenarioBuilder),
                onCreate: () => context.push(RouteNames.create),
              ),
              if (authState.message != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  authState.message!,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCategory(String? categoryId) async {
    await ref
        .read(discoverFeedControllerProvider)
        .setCategoryFilter(categoryId);
    if (!mounted) return;
    context.go(RouteNames.search);
  }

  void _openSavedScenario(FavoriteItemEntity scenario) {
    final String? targetRoute = scenario.targetRoute;
    if (targetRoute == null || targetRoute.trim().isEmpty) {
      context.go(RouteNames.scenarioBuilder);
      return;
    }
    context.go(targetRoute);
  }

  void _openSavedScenarioMap(FavoriteItemEntity scenario) {
    context.go(_mapRouteForSavedScenario(scenario));
  }

  void _openSavedSearch(SavedSearchEntity search) {
    context.go(_searchRouteForSavedSearch(search));
  }

  void _openSavedSearchMap(SavedSearchEntity search) {
    context.go(_mapRouteForSavedSearch(search));
  }

  void _openSavedSearchRoute(SavedSearchEntity search) {
    context.go(_scenarioBuilderRouteForSavedSearch(search));
  }

  void _openSavedSearchCreate(SavedSearchEntity search) {
    context.go(_createRouteForSavedSearch(search));
  }

  void _openSmartSearch(SmartSearchHistoryEntity item) {
    context.go(_searchRouteForSmartSearch(item));
  }

  void _openSmartSearchMap(SmartSearchHistoryEntity item) {
    context.go(_mapRouteForSmartSearch(item));
  }

  void _openSmartSearchRoute(SmartSearchHistoryEntity item) {
    context.go(_scenarioBuilderRouteForSmartSearch(item));
  }

  void _openSmartSearchCreate(SmartSearchHistoryEntity item) {
    context.go(_createRouteForSmartSearch(item));
  }

  Future<void> _openScenario(_ScenarioCardData scenario) async {
    if (scenario.opensMap) {
      context.go(RouteNames.discoverMap);
      return;
    }

    final controller = ref.read(discoverFeedControllerProvider);
    if (scenario.freeOnly) {
      await controller.setFreeOnly(true);
    }
    if (scenario.queryText != null) {
      await controller.updateSearchText(scenario.queryText!);
    }
    if (!mounted) return;
    context.go(RouteNames.search);
  }

  void _openRouteTemplate(_HomeRouteTemplate template) {
    context.go(_scenarioBuilderRouteForTemplate(template));
  }

  void _openRouteTemplateMap(_HomeRouteTemplate template) {
    context.go(_mapRouteForTemplate(template));
  }

  void _openRouteTemplateCreate(_HomeRouteTemplate template) {
    context.go(_createRouteForTemplate(template));
  }
}

class _SavedScenarioPanel extends StatelessWidget {
  const _SavedScenarioPanel({
    required this.scenario,
    required this.onEdit,
    required this.onRoute,
  });

  final FavoriteItemEntity scenario;
  final VoidCallback onEdit;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(Icons.route, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Continue your route',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        scenario.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              scenario.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SavedScenarioChip(icon: Icons.flag, label: 'Saved route'),
                _SavedScenarioChip(icon: Icons.place, label: scenario.city),
                _SavedScenarioChip(
                  icon: Icons.near_me,
                  label: '${scenario.distanceKm.toStringAsFixed(1)} km',
                ),
                _SavedScenarioChip(
                  icon: Icons.payments,
                  label: scenario.isFree
                      ? 'Free'
                      : '${scenario.priceAmount.toStringAsFixed(0)} EUR',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('home-saved-scenario-edit'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-saved-scenario-route'),
                    onPressed: onRoute,
                    icon: const Icon(Icons.route),
                    label: const Text('Route'),
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

class _SavedScenarioChip extends StatelessWidget {
  const _SavedScenarioChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSearchPanel extends StatelessWidget {
  const _SavedSearchPanel({
    required this.search,
    required this.onResume,
    required this.onMap,
    required this.onRoute,
    required this.onCreate,
  });

  final SavedSearchEntity search;
  final VoidCallback onResume;
  final VoidCallback onMap;
  final VoidCallback onRoute;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
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
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(Icons.tune, color: colorScheme.secondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Continue saved search',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        search.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(search.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SavedScenarioChip(icon: Icons.search, label: 'Conditions'),
                if (search.query.selectedCategoryIds.isNotEmpty)
                  _SavedScenarioChip(
                    icon: Icons.category_outlined,
                    label: search.query.selectedCategoryIds.first,
                  ),
                _SavedScenarioChip(
                  icon: Icons.near_me_outlined,
                  label: search.query.unlimitedRadius
                      ? 'Any area'
                      : '${(search.query.radiusMeters / 1000).round()} km',
                ),
                if (search.query.freeOnly)
                  const _SavedScenarioChip(
                    icon: Icons.payments_outlined,
                    label: 'Free',
                  ),
              ],
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
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-saved-search-map'),
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Build route from saved search',
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Create listing from saved search',
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

class _SmartSearchPanel extends StatelessWidget {
  const _SmartSearchPanel({
    required this.item,
    required this.onResume,
    required this.onMap,
    required this.onRoute,
    required this.onCreate,
  });

  final SmartSearchHistoryEntity item;
  final VoidCallback onResume;
  final VoidCallback onMap;
  final VoidCallback onRoute;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final SmartRouteIntent? routeIntent = parseSmartSearch(
      item.prompt,
    ).routeIntent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
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
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Continue smart search',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SavedScenarioChip(icon: Icons.psychology, label: 'Smart'),
                if (routeIntent != null) ...<Widget>[
                  const _SavedScenarioChip(
                    icon: Icons.route_outlined,
                    label: 'Smart route',
                  ),
                  _SavedScenarioChip(
                    icon: Icons.timer_outlined,
                    label: '${routeIntent.durationMinutes} min',
                  ),
                  _SavedScenarioChip(
                    icon: Icons.flag_outlined,
                    label: '${routeIntent.stepCategories.length} stops',
                  ),
                ],
                if (item.query.selectedCategoryIds.isNotEmpty)
                  _SavedScenarioChip(
                    icon: Icons.category_outlined,
                    label: item.query.selectedCategoryIds.first,
                  ),
                _SavedScenarioChip(
                  icon: Icons.near_me_outlined,
                  label: item.query.unlimitedRadius
                      ? 'Any area'
                      : '${(item.query.radiusMeters / 1000).round()} km',
                ),
                if (item.query.budgetMax != null)
                  _SavedScenarioChip(
                    icon: Icons.payments_outlined,
                    label: 'Under ${item.query.budgetMax!.toStringAsFixed(0)}',
                  ),
              ],
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
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-smart-search-map'),
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Build route from smart search',
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Create listing from smart search',
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

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onSearch, required this.onMap});

  final VoidCallback onSearch;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Text(
          'RECHARGE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'VACATION APP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _HomeActionPill(
                icon: Icons.search_rounded,
                label: 'Search',
                onPressed: onSearch,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeActionPill(
                icon: Icons.map_outlined,
                label: 'Map',
                onPressed: onMap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeActionPill extends StatelessWidget {
  const _HomeActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: const Color(0xFF064936)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF073F35),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _HomeCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.13),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                category.icon,
                color: selected ? const Color(0xFF064936) : Colors.white,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActivitySections extends StatelessWidget {
  const _HomeActivitySections({
    required this.state,
    required this.onViewAll,
    required this.onOpenDetails,
  });

  final DiscoverFeedState state;
  final VoidCallback onViewAll;
  final ValueChanged<DiscoverItemEntity> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    if (state.status == DiscoverFeedStatus.initial ||
        state.status == DiscoverFeedStatus.loading ||
        state.status == DiscoverFeedStatus.selectingArea) {
      return const _HomeLoadingCard();
    }

    final List<DiscoverItemEntity> items = state.items;
    if (items.isEmpty) {
      return _HomeEmptyCard(onViewAll: onViewAll);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _homeChoiceSections(items)
          .map(
            (_HomeChoiceSectionData section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _HomeContentSection(
                title: section.title,
                items: section.items,
                onViewAll: onViewAll,
                onOpenDetails: onOpenDetails,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  List<_HomeChoiceSectionData> _homeChoiceSections(
    List<DiscoverItemEntity> items,
  ) {
    return <_HomeChoiceSectionData>[
      _HomeChoiceSectionData(
        title: 'Categories',
        items: _categoryMixItems(items),
      ),
      _HomeChoiceSectionData(title: 'New', items: _newItems(items)),
      _HomeChoiceSectionData(title: 'For you', items: _forYouItems(items)),
      _HomeChoiceSectionData(
        title: 'Quick events',
        items: _quickEventItems(items),
      ),
      _HomeChoiceSectionData(title: 'Nearby', items: _nearbyItems(items)),
      _HomeChoiceSectionData(title: 'Popular', items: _popularItems(items)),
    ];
  }

  List<DiscoverItemEntity> _categoryMixItems(List<DiscoverItemEntity> items) {
    final Set<String> seenCategories = <String>{};
    final List<DiscoverItemEntity> mixed = <DiscoverItemEntity>[];
    for (final DiscoverItemEntity item in items) {
      if (seenCategories.add(item.category)) {
        mixed.add(item);
      }
      if (mixed.length == 6) break;
    }
    if (mixed.length >= 4 || mixed.length == items.length) {
      return mixed;
    }
    for (final DiscoverItemEntity item in items) {
      if (!mixed.contains(item)) mixed.add(item);
      if (mixed.length == 6) break;
    }
    return mixed;
  }

  List<DiscoverItemEntity> _newItems(List<DiscoverItemEntity> items) {
    final List<DiscoverItemEntity> sorted = List<DiscoverItemEntity>.from(items)
      ..sort(
        (DiscoverItemEntity a, DiscoverItemEntity b) =>
            a.startsAtUtc.compareTo(b.startsAtUtc),
      );
    return sorted.take(6).toList(growable: false);
  }

  List<DiscoverItemEntity> _popularItems(List<DiscoverItemEntity> items) {
    final List<DiscoverItemEntity> sorted = List<DiscoverItemEntity>.from(items)
      ..sort(
        (DiscoverItemEntity a, DiscoverItemEntity b) =>
            b.relevanceScore.compareTo(a.relevanceScore),
      );
    return sorted.take(6).toList(growable: false);
  }

  List<DiscoverItemEntity> _forYouItems(List<DiscoverItemEntity> items) {
    if (items.length <= 2) return items;
    return items.skip(2).take(6).toList(growable: false);
  }

  List<DiscoverItemEntity> _quickEventItems(List<DiscoverItemEntity> items) {
    final List<DiscoverItemEntity> sorted = List<DiscoverItemEntity>.from(items)
      ..sort((DiscoverItemEntity a, DiscoverItemEntity b) {
        final int freeCompare = _freeRank(b).compareTo(_freeRank(a));
        if (freeCompare != 0) return freeCompare;
        final int durationCompare = _quickDurationRank(
          b,
        ).compareTo(_quickDurationRank(a));
        if (durationCompare != 0) return durationCompare;
        return a.startsAtUtc.compareTo(b.startsAtUtc);
      });
    return sorted.take(6).toList(growable: false);
  }

  List<DiscoverItemEntity> _nearbyItems(List<DiscoverItemEntity> items) {
    final List<DiscoverItemEntity> sorted = List<DiscoverItemEntity>.from(items)
      ..sort(
        (DiscoverItemEntity a, DiscoverItemEntity b) =>
            a.distanceKm.compareTo(b.distanceKm),
      );
    return sorted.take(6).toList(growable: false);
  }

  int _freeRank(DiscoverItemEntity item) => item.isFree ? 1 : 0;

  int _quickDurationRank(DiscoverItemEntity item) {
    final int duration = item.durationMinutes ?? 0;
    return duration > 0 && duration <= 90 ? 1 : 0;
  }
}

class _HomeChoiceSectionData {
  const _HomeChoiceSectionData({required this.title, required this.items});

  final String title;
  final List<DiscoverItemEntity> items;
}

class _HomeContentSection extends StatelessWidget {
  const _HomeContentSection({
    required this.title,
    required this.items,
    required this.onViewAll,
    required this.onOpenDetails,
  });

  final String title;
  final List<DiscoverItemEntity> items;
  final VoidCallback onViewAll;
  final ValueChanged<DiscoverItemEntity> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          title: title,
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              final DiscoverItemEntity item = items[index];
              return _HomeFeatureCard(
                item: item,
                onTap: () => onOpenDetails(item),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({required this.item, required this.onTap});

  final DiscoverItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _HomeFeatureImage(item: item),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x22FFFFFF),
                      Color(0x22000000),
                      Color(0xBB000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _HomeFeatureTag(label: item.category),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _homeCardMeta(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

class _HomeFeatureImage extends StatelessWidget {
  const _HomeFeatureImage({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    if (item.coverImageUrl.isEmpty) return _HomeFeatureFallback(item: item);
    return Image.network(
      item.coverImageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _HomeFeatureFallback(item: item),
    );
  }
}

class _HomeFeatureFallback extends StatelessWidget {
  const _HomeFeatureFallback({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE9F0EC),
            Color(0xFFB8C9C2),
            Color(0xFF31564C),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIconForHome(item.category),
          color: const Color(0xFF31564C),
          size: 38,
        ),
      ),
    );
  }
}

class _HomeFeatureTag extends StatelessWidget {
  const _HomeFeatureTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF60736D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

class _HomeEmptyCard extends StatelessWidget {
  const _HomeEmptyCard({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onViewAll,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No activities yet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.onTap});

  final _ScenarioCardData scenario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RechargeTheme.travelPanel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RechargeTheme.travelLine),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4EF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(scenario.icon, color: RechargeTheme.travelGreenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    scenario.title,
                    style: const TextStyle(
                      color: Color(0xFF073F35),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scenario.subtitle,
                    style: const TextStyle(color: Color(0xFF62756F)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF5F7770)),
          ],
        ),
      ),
    );
  }
}

class _HomeRouteTemplateRail extends StatelessWidget {
  const _HomeRouteTemplateRail({
    required this.templates,
    required this.onBuild,
    required this.onMap,
    required this.onCreate,
  });

  final List<_HomeRouteTemplate> templates;
  final ValueChanged<_HomeRouteTemplate> onBuild;
  final ValueChanged<_HomeRouteTemplate> onMap;
  final ValueChanged<_HomeRouteTemplate> onCreate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final _HomeRouteTemplate template in templates) ...<Widget>[
            _HomeRouteTemplateCard(
              template: template,
              onBuild: () => onBuild(template),
              onMap: () => onMap(template),
              onCreate: () => onCreate(template),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _HomeRouteTemplateCard extends StatelessWidget {
  const _HomeRouteTemplateCard({
    required this.template,
    required this.onBuild,
    required this.onMap,
    required this.onCreate,
  });

  final _HomeRouteTemplate template;
  final VoidCallback onBuild;
  final VoidCallback onMap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RechargeTheme.travelPanel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RechargeTheme.travelLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4EF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    template.icon,
                    color: RechargeTheme.travelGreenDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF073F35),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              template.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF62756F)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SavedScenarioChip(
                  icon: Icons.schedule,
                  label: '${template.durationMinutes} min',
                ),
                _SavedScenarioChip(
                  icon: Icons.directions_walk,
                  label: template.walkingOnly ? 'Walkable' : 'Flexible',
                ),
                _SavedScenarioChip(
                  icon: Icons.payments,
                  label: template.freeOnly ? 'Free' : 'Mixed',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onBuild,
                    icon: const Icon(Icons.route),
                    label: const Text('Build'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Map ${template.title} route',
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Create ${template.title} route',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_business_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForYouStrip extends StatelessWidget {
  const _ForYouStrip({
    required this.onPopular,
    required this.onScenario,
    required this.onCreate,
  });

  final VoidCallback onPopular;
  final VoidCallback onScenario;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RechargeTheme.travelGreenDark,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'For you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personal picks, saved ideas and creator tools stay one tap away.',
            style: TextStyle(color: Color(0xFFD5EEE5)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double buttonWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _ForYouButton(
                    width: buttonWidth,
                    onPressed: onPopular,
                    icon: Icons.star_outline_rounded,
                    label: 'Popular',
                  ),
                  _ForYouButton(
                    width: buttonWidth,
                    onPressed: onScenario,
                    icon: Icons.route,
                    label: 'Builder',
                  ),
                  _ForYouButton(
                    width: buttonWidth,
                    onPressed: onCreate,
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Create',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ForYouButton extends StatelessWidget {
  const _ForYouButton({
    required this.width,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final double width;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFB8DCD1)),
        ),
      ),
    );
  }
}

IconData _homeCategoryIcon(String categoryId) {
  return switch (normalizeRechargeContentGroupId(categoryId)) {
    'music_nightlife' => Icons.music_note,
    'comedy_theatre_performance' => Icons.theater_comedy,
    'cinema_screenings' => Icons.movie_outlined,
    'art_culture_museums' => Icons.palette_outlined,
    'education_talks' => Icons.school_outlined,
    'business_networking' => Icons.handshake_outlined,
    'workshops_masterclasses' => Icons.build_outlined,
    'language_social_learning' => Icons.translate,
    'food_drinks' => Icons.restaurant_outlined,
    'games_indoor' => Icons.casino_outlined,
    'sport' => Icons.sports_tennis,
    'dance' => Icons.nightlife_outlined,
    'outdoor_nature_walking' => Icons.park_outlined,
    'water_activities' => Icons.kayaking_outlined,
    'winter_seasonal' => Icons.ac_unit,
    'travel_tours' => Icons.tour_outlined,
    'family_kids' => Icons.family_restroom,
    'pets_animals' => Icons.pets_outlined,
    'community_charity' => Icons.volunteer_activism_outlined,
    'markets_fairs' => Icons.storefront_outlined,
    'holidays_seasonal' => Icons.celebration_outlined,
    'wellness_recharge' => Icons.self_improvement_rounded,
    _ => Icons.category_outlined,
  };
}

class _HomeCategory {
  const _HomeCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String? id;
  final String label;
  final IconData icon;
}

class _ScenarioCardData {
  const _ScenarioCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.freeOnly = false,
    this.opensMap = false,
    this.queryText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool freeOnly;
  final bool opensMap;
  final String? queryText;
}

class _HomeRouteTemplate {
  const _HomeRouteTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.prompt,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String mood;
  final int durationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String prompt;
  final List<String> steps;
}

String _homeCardMeta(DiscoverItemEntity item) {
  final DateTime local = item.startsAtUtc.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  final String price = item.isFree
      ? 'Free'
      : '${item.priceAmount.toStringAsFixed(0)} EUR';
  final String venue = item.venueName.isEmpty ? item.city : item.venueName;
  return '$price · $hour:$minute · $venue';
}

IconData _categoryIconForHome(String category) {
  return _homeCategoryIcon(category);
}

FavoriteItemEntity? _latestSavedScenario(List<FavoriteItemEntity> items) {
  final Iterable<FavoriteItemEntity> scenarios = items.where(
    (FavoriteItemEntity item) => item.category == 'scenario',
  );
  if (scenarios.isEmpty) return null;

  FavoriteItemEntity latest = scenarios.first;
  for (final FavoriteItemEntity item in scenarios.skip(1)) {
    if (item.savedAtUtc.isAfter(latest.savedAtUtc)) {
      latest = item;
    }
  }
  return latest;
}

SmartSearchHistoryEntity? _latestSmartSearch(
  List<SmartSearchHistoryEntity> items,
) {
  SmartSearchHistoryEntity? latest;
  for (final SmartSearchHistoryEntity item in items) {
    if (latest == null || item.createdAtUtc.isAfter(latest.createdAtUtc)) {
      latest = item;
    }
  }
  return latest;
}

String _mapRouteForSavedScenario(FavoriteItemEntity scenario) {
  final String? targetRoute = scenario.targetRoute;
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
  return _discoverRouteForSavedSearch(RouteNames.search, search.query);
}

String _mapRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForSavedSearch(RouteNames.discoverMap, search.query);
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
  return _discoverRouteForSavedSearch(RouteNames.discoverMap, item.query);
}

String _createRouteForSavedSearch(SavedSearchEntity search) {
  final Map<String, String> params = <String, String>{
    ..._queryParametersForSavedSearch(search.query),
    'source': 'saved_search',
    'type': 'event',
    'title': search.title,
    'subtitle': search.subtitle,
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
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
    ..._queryParametersForSavedSearch(item.query),
    'source': 'smart_search',
    'type': 'event',
    'title': _titleForSmartSearch(item.query),
    'subtitle': item.prompt,
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _scenarioBuilderRouteForTemplate(_HomeRouteTemplate template) {
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: _scenarioTemplateParameters(template),
  ).toString();
}

String _mapRouteForTemplate(_HomeRouteTemplate template) {
  final Map<String, String> params = <String, String>{
    ..._scenarioTemplateParameters(template),
    'mode': 'scenario',
  };
  return Uri(path: RouteNames.discoverMap, queryParameters: params).toString();
}

String _createRouteForTemplate(_HomeRouteTemplate template) {
  final Map<String, String> params = <String, String>{
    ..._scenarioTemplateParameters(template),
    'source': 'scenario',
    'type': 'event',
    'title': '${template.title} route',
    'subtitle': template.subtitle,
    'q': template.prompt,
    'category': 'scenario',
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

Map<String, String> _scenarioTemplateParameters(_HomeRouteTemplate template) {
  return <String, String>{
    'mood': template.mood,
    'duration': template.durationMinutes.toString(),
    'free': template.freeOnly ? '1' : '0',
    'walking': template.walkingOnly ? '1' : '0',
    'prompt': template.prompt,
    'steps': template.steps.join(','),
  };
}

String _discoverRouteForSavedSearch(String path, DiscoverQuery query) {
  return Uri(
    path: path,
    queryParameters: _queryParametersForSavedSearch(query),
  ).toString();
}

Map<String, String> _queryParametersForSavedSearch(DiscoverQuery query) {
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

String _scenarioBuilderRouteForSavedSearch(SavedSearchEntity search) {
  final DiscoverQuery query = search.query;
  final String prompt = _promptForSavedSearch(query);
  return _scenarioBuilderRouteForQuery(query, prompt: prompt);
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
      ? _promptForSavedSearch(item.query)
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

String _scenarioBuilderRouteForQuery(
  DiscoverQuery query, {
  required String prompt,
}) {
  final Map<String, String> params = <String, String>{
    'mood': _scenarioMoodForSavedSearch(query),
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

String _titleForSmartSearch(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return 'Smart search idea';
}

String _capitalized(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _scenarioMoodForSavedSearch(DiscoverQuery query) {
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

String _promptForSavedSearch(DiscoverQuery query) {
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
