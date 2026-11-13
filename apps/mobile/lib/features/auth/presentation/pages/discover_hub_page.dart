import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/localization/taxonomy_labels.dart';
import '../../../../shared/models/catalog_object_ref.dart';
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

// Kept as a non-constant compatibility gate until the M10 code deletion.
// Main intentionally exposes neither Scenario nor legacy Quick Plan.
bool _legacyPlanningOnMainEnabled() => false;

class DiscoverHubPage extends ConsumerStatefulWidget {
  const DiscoverHubPage({super.key, required this.favoriteApplied});

  final bool favoriteApplied;

  @override
  ConsumerState<DiscoverHubPage> createState() => _DiscoverHubPageState();
}

class _DiscoverHubPageState extends ConsumerState<DiscoverHubPage> {
  bool _snackShown = false;
  bool _favoritesRequested = false;

  static const List<String> _homeCategoryPriority = <String>[
    'sport',
    'outdoor_nature_walking',
    'games_indoor',
    'dance',
    'music_nightlife',
    'art_culture_museums',
    'food_drinks',
    'wellness_recharge',
  ];

  static final List<_HomeCategory> _categories = <_HomeCategory>[
    // The "All" chip; its text comes from l10n when shown.
    const _HomeCategory(id: null, label: '', icon: Icons.grid_view_rounded),
    for (final String categoryId in _homeCategoryPriority)
      if (rechargeContentGroupById(categoryId) case final group?)
        _HomeCategory(
          id: group.id,
          label: group.id,
          icon: _homeCategoryIcon(group.id),
        ),
    for (final RechargeContentGroup group in rechargeVisibleContentGroups)
      if (!_homeCategoryPriority.contains(group.id))
        _HomeCategory(
          id: group.id,
          label: group.id,
          icon: _homeCategoryIcon(group.id),
        ),
  ];

  static const List<_ScenarioCardData> _scenarios = <_ScenarioCardData>[
    _ScenarioCardData(
      id: 'freeToday',
      icon: Icons.bolt_outlined,
      freeOnly: true,
    ),
    _ScenarioCardData(
      id: 'nearMe',
      icon: Icons.near_me_outlined,
      opensMap: true,
    ),
    _ScenarioCardData(
      id: 'eveningPlans',
      icon: Icons.nightlight_outlined,
      queryText: 'evening',
    ),
  ];

  static const List<_HomeRouteTemplate> _routeTemplates = <_HomeRouteTemplate>[
    _HomeRouteTemplate(
      id: 'coffeeReset',
      icon: Icons.local_cafe_outlined,
      mood: 'calm',
      durationMinutes: 90,
      freeOnly: false,
      walkingOnly: true,
      prompt:
          'coffee reset walk', // l10n-ignore: search prompt text, not UI copy
      steps: <String>['food_drinks.coffee', 'wellness_recharge.calm_walk'],
    ),
    _HomeRouteTemplate(
      id: 'freeCityReset',
      icon: Icons.self_improvement,
      mood: 'calm',
      durationMinutes: 90,
      freeOnly: true,
      walkingOnly: true,
      prompt:
          'free calm city walk', // l10n-ignore: search prompt text, not UI copy
      steps: <String>['wellness_recharge.calm_walk'],
    ),
    _HomeRouteTemplate(
      id: 'socialEvening',
      icon: Icons.groups_outlined,
      mood: 'social',
      durationMinutes: 150,
      freeOnly: false,
      walkingOnly: true,
      prompt:
          'social evening near me', // l10n-ignore: search prompt text, not UI copy
      steps: <String>[
        'games_indoor.board_games',
        'music_nightlife.afterwork_drinks',
      ],
    ),
    _HomeRouteTemplate(
      id: 'activeBoost',
      icon: Icons.directions_run,
      mood: 'active',
      durationMinutes: 120,
      freeOnly: false,
      walkingOnly: true,
      prompt:
          'active tennis and walk', // l10n-ignore: search prompt text, not UI copy
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.detailsSavedToFavorites)),
        );
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
      backgroundColor: RechargeTheme.homeBackground,
      body: DecoratedBox(
        key: const Key('home-screen'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              RechargeTheme.homeBackgroundTop,
              RechargeTheme.homeBackground,
              RechargeTheme.homeBackgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
            children: <Widget>[
              _HomeHero(
                onSearch: () => context.go(RouteNames.search),
                onMap: () => context.go(RouteNames.discoverMap),
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: context.l10n.discoverCategories,
                actionLabel: context.l10n.homeViewAll,
                onAction: () => context.push(RouteNames.categories),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    final _HomeCategory category = _categories[index];
                    return _CategoryPill(
                      key: Key('home-category-${category.id ?? 'all'}'),
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
                  context.push(
                    RouteNames.discoverDetailsCanonicalFor(
                      CatalogObjectRef(
                        objectType: item.catalogObjectType,
                        objectId: item.id,
                      ),
                    ),
                  );
                },
              ),
              if (_legacyPlanningOnMainEnabled()) ...<Widget>[
                const SizedBox(height: 18),
                _SectionHeader(
                  title: context.l10n.discoverQuickScenarios,
                  actionLabel: context.l10n.discoverSmartSearch,
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
                  title: context.l10n.discoverRouteIdeas,
                  actionLabel: context.l10n.discoverBuilder,
                  onAction: () => context.go(
                    Uri(
                      path: RouteNames.create,
                      queryParameters: const <String, String>{'type': 'route'},
                    ).toString(),
                  ),
                ),
                const SizedBox(height: 10),
                _HomeRouteTemplateRail(
                  templates: _routeTemplates,
                  onBuild: _openRouteTemplate,
                  onMap: _openRouteTemplateMap,
                  onCreate: _openRouteTemplateCreate,
                ),
              ],
              if (_legacyPlanningOnMainEnabled() &&
                  savedScenario != null) ...<Widget>[
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
                  onCreate: () => _openSmartSearchCreate(smartSearch),
                ),
              ],
              if (savedSearch != null) ...<Widget>[
                const SizedBox(height: 12),
                _SavedSearchPanel(
                  search: savedSearch,
                  onResume: () => _openSavedSearch(savedSearch),
                  onMap: () => _openSavedSearchMap(savedSearch),
                  onCreate: () => _openSavedSearchCreate(savedSearch),
                ),
              ],
              if (_legacyPlanningOnMainEnabled()) ...<Widget>[
                const SizedBox(height: 14),
                _ForYouStrip(
                  onPopular: () => context.go(RouteNames.search),
                  onScenario: () => context.go(
                    Uri(
                      path: RouteNames.create,
                      queryParameters: const <String, String>{
                        'type': 'scenario',
                      },
                    ).toString(),
                  ),
                  onCreate: () => context.push(RouteNames.create),
                ),
              ],
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

  void _openCategory(String? categoryId) {
    if (categoryId == null) {
      context.push(RouteNames.categories);
      return;
    }
    context.push('${RouteNames.categories}/$categoryId');
  }

  void _openSavedScenario(FavoriteItemEntity scenario) {
    final String? targetRoute = scenario.targetRoute;
    if (targetRoute == null || targetRoute.trim().isEmpty) {
      context.go(
        Uri(
          path: RouteNames.create,
          queryParameters: const <String, String>{'type': 'scenario'},
        ).toString(),
      );
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

  void _openSavedSearchCreate(SavedSearchEntity search) {
    context.go(_createRouteForSavedSearch(search));
  }

  void _openSmartSearch(SmartSearchHistoryEntity item) {
    context.go(_searchRouteForSmartSearch(item));
  }

  void _openSmartSearchMap(SmartSearchHistoryEntity item) {
    context.go(_mapRouteForSmartSearch(item));
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
    context.go(_createRouteForTemplate(context.l10n, template));
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
                        context.l10n.homeContinueRoute,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        homeScenarioTitle(context.l10n, scenario.id),
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
              homeScenarioSubtitle(context.l10n, scenario.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SavedScenarioChip(
                  icon: Icons.flag,
                  label: context.l10n.homeSavedRoute,
                ),
                _SavedScenarioChip(icon: Icons.place, label: scenario.city),
                if (scenario.distanceKm case final double distanceKm)
                  _SavedScenarioChip(
                    icon: Icons.near_me,
                    label: '${distanceKm.toStringAsFixed(1)} km',
                  ),
                _SavedScenarioChip(
                  icon: Icons.payments,
                  // L4: the price keeps its own currency.
                  label: scenario.isFree || scenario.priceAmount == null
                      ? (scenario.isFree ? context.l10n.homeFree : '—')
                      : RechargeFormats.money(
                          scenario.priceAmount!,
                          context.l10n.localeName,
                        ),
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
                    label: Text(context.l10n.createScenarioEdit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-saved-scenario-route'),
                    onPressed: onRoute,
                    icon: const Icon(Icons.route),
                    label: Text(context.l10n.discoverRouteLabel),
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
    required this.onCreate,
  });

  final SavedSearchEntity search;
  final VoidCallback onResume;
  final VoidCallback onMap;
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
                        context.l10n.homeContinueSavedSearch,
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
                _SavedScenarioChip(
                  icon: Icons.search,
                  label: context.l10n.discoverConditions,
                ),
                if (search.query.selectedCategoryIds.isNotEmpty)
                  _SavedScenarioChip(
                    icon: Icons.category_outlined,
                    label: taxonomyLabel(
                      context.l10n,
                      search.query.selectedCategoryIds.first,
                    ),
                  ),
                _SavedScenarioChip(
                  icon: Icons.near_me_outlined,
                  label: search.query.unlimitedRadius
                      ? context.l10n.homeAnyArea
                      : context.l10n.homeRadiusKm(
                          RechargeFormats.decimal(
                            (search.query.radiusMeters / 1000).round(),
                            context.l10n.localeName,
                          ),
                        ),
                ),
                if (search.query.freeOnly)
                  _SavedScenarioChip(
                    icon: Icons.payments_outlined,
                    label: context.l10n.discoverFree,
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
                    label: Text(context.l10n.discoverResume),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-saved-search-map'),
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(context.l10n.discoverMap),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: context.l10n.homeCreateFromSavedSearch,
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
    required this.onCreate,
  });

  final SmartSearchHistoryEntity item;
  final VoidCallback onResume;
  final VoidCallback onMap;
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
                        context.l10n.homeContinueSmartSearch,
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
                _SavedScenarioChip(
                  icon: Icons.psychology,
                  label: context.l10n.discoverSmart,
                ),
                if (routeIntent != null) ...<Widget>[
                  _SavedScenarioChip(
                    icon: Icons.route_outlined,
                    label: context.l10n.homeSmartRoute,
                  ),
                  _SavedScenarioChip(
                    icon: Icons.timer_outlined,
                    label: context.l10n.discoverMinutes(
                      routeIntent.durationMinutes,
                    ),
                  ),
                  _SavedScenarioChip(
                    icon: Icons.flag_outlined,
                    label: context.l10n.discoverStops(
                      routeIntent.stepCategories.length,
                    ),
                  ),
                ],
                if (item.query.selectedCategoryIds.isNotEmpty)
                  _SavedScenarioChip(
                    icon: Icons.category_outlined,
                    label: taxonomyLabel(
                      context.l10n,
                      item.query.selectedCategoryIds.first,
                    ),
                  ),
                _SavedScenarioChip(
                  icon: Icons.near_me_outlined,
                  label: item.query.unlimitedRadius
                      ? context.l10n.homeAnyArea
                      : context.l10n.homeRadiusKm(
                          RechargeFormats.decimal(
                            (item.query.radiusMeters / 1000).round(),
                            context.l10n.localeName,
                          ),
                        ),
                ),
                if (item.query.budgetMax != null)
                  _SavedScenarioChip(
                    icon: Icons.payments_outlined,
                    label: context.l10n.discoverUpToBudget(
                      RechargeFormats.money(
                        item.query.budgetMax!,
                        context.l10n.localeName,
                      ),
                    ),
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
                    label: Text(context.l10n.discoverResume),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('home-smart-search-map'),
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(context.l10n.discoverMap),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: context.l10n.homeCreateFromSmartSearch,
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
          'RECHARGE', // l10n-ignore: brand wordmark
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.l10n.discoverHomeTagline,
          style: TextStyle(
            color: RechargeTheme.homeMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _HomeActionPill(
                key: const Key('home-search-action'),
                icon: Icons.search_rounded,
                label: context.l10n.discoverSearch,
                onPressed: onSearch,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeActionPill(
                key: const Key('home-map-action'),
                icon: Icons.map_outlined,
                label: context.l10n.discoverMap,
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
    super.key,
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
      borderRadius: BorderRadius.circular(RechargeTheme.homePillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(RechargeTheme.homePillRadius),
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: RechargeTheme.homeBackground),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF073F35),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
            foregroundColor: RechargeTheme.homeMuted,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    super.key,
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
        borderRadius: BorderRadius.circular(RechargeTheme.homePillRadius),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : RechargeTheme.homeCategorySurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : RechargeTheme.homeMuted.withValues(alpha: 0.32),
                ),
              ),
              child: Icon(
                category.icon,
                color: selected ? const Color(0xFF064936) : Colors.white,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.id == null
                  ? context.l10n.discoverAll
                  : _homeCategoryLabel(context.l10n, category.id!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : RechargeTheme.homeMuted,
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
                key: ValueKey<String>('home-feed-${section.id}'),
                title: _homeSectionTitle(context.l10n, section.id),
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
      // Section ids are stable widget keys, not copy; the title comes from
      // _homeSectionTitle.
      _HomeChoiceSectionData(
        id: 'Categories', // l10n-ignore: section id
        items: _categoryMixItems(items),
      ),
      _HomeChoiceSectionData(
        id: 'New', // l10n-ignore: section id
        items: _newItems(items),
      ),
      _HomeChoiceSectionData(
        id: 'For you', // l10n-ignore: section id
        items: _forYouItems(items),
      ),
      _HomeChoiceSectionData(
        id: 'Quick events', // l10n-ignore: section id
        items: _quickEventItems(items),
      ),
      _HomeChoiceSectionData(
        id: 'Nearby', // l10n-ignore: section id
        items: _nearbyItems(items),
      ),
      _HomeChoiceSectionData(
        id: 'Popular', // l10n-ignore: section id
        items: _popularItems(items),
      ),
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
      ..sort((DiscoverItemEntity a, DiscoverItemEntity b) => a.compareStart(b));
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
        return a.compareStart(b);
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
  const _HomeChoiceSectionData({required this.id, required this.items});

  /// Stable section id (also the widget key); the title comes from l10n.
  final String id;
  final List<DiscoverItemEntity> items;
}

class _HomeContentSection extends StatelessWidget {
  const _HomeContentSection({
    super.key,
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
          actionLabel: context.l10n.homeViewAll,
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
                key: ValueKey<String>('home-card-$title-${item.id}'),
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
  const _HomeFeatureCard({super.key, required this.item, required this.onTap});

  final DiscoverItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RechargeTheme.homeCardRadius),
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
                      _homeCardMeta(context.l10n, item),
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
        color: RechargeTheme.homeTag.withValues(alpha: 0.88),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.homeNoActivities,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
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
                    homeScenarioTitle(context.l10n, scenario.id),
                    style: const TextStyle(
                      color: Color(0xFF073F35),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    homeScenarioSubtitle(context.l10n, scenario.id),
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
                    homeScenarioTitle(context.l10n, template.id),
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
              homeScenarioSubtitle(context.l10n, template.id),
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
                  label: template.walkingOnly
                      ? context.l10n.discoverWalkable
                      : context.l10n.discoverFlexibleTime,
                ),
                _SavedScenarioChip(
                  icon: Icons.payments,
                  label: template.freeOnly
                      ? context.l10n.discoverFree
                      : context.l10n.discoverMixedPrice,
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
                    label: Text(context.l10n.discoverBuild),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: context.l10n.discoverMapTemplateRoute(
                    homeScenarioTitle(context.l10n, template.id),
                  ),
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: context.l10n.discoverCreateTemplateRoute(
                    homeScenarioTitle(context.l10n, template.id),
                  ),
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
          Text(
            _homeSectionTitle(
              context.l10n,
              'For you', // l10n-ignore: stable section id (widget key)
            ), // l10n-ignore: stable section id (widget key)
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.discoverForYouHint,
            style: const TextStyle(color: Color(0xFFD5EEE5)),
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
                    label: _homeSectionTitle(
                      context.l10n,
                      'Popular', // l10n-ignore: section id
                    ),
                  ),
                  _ForYouButton(
                    width: buttonWidth,
                    onPressed: onScenario,
                    icon: Icons.route,
                    label: context.l10n.discoverBuilder,
                  ),
                  _ForYouButton(
                    width: buttonWidth,
                    onPressed: onCreate,
                    icon: Icons.add_circle_outline_rounded,
                    label: context.l10n.discoverCreate,
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

/// L4.9.5: the short home chip name; other categories use their full name.
String _homeCategoryLabel(AppLocalizations l10n, String categoryId) {
  return switch (normalizeRechargeContentGroupId(categoryId)) {
    'sport' => l10n.discoverHomeShortSport,
    'outdoor_nature_walking' => l10n.discoverHomeShortWalks,
    'games_indoor' => l10n.discoverHomeShortGames,
    'dance' => l10n.discoverHomeShortDance,
    'music_nightlife' => l10n.discoverHomeShortMusic,
    'art_culture_museums' => l10n.discoverHomeShortArt,
    'food_drinks' => l10n.discoverHomeShortFood,
    'wellness_recharge' => l10n.discoverHomeShortWellness,
    final String id => taxonomyLabel(l10n, id),
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
    required this.id,
    required this.icon,
    this.freeOnly = false,
    this.opensMap = false,
    this.queryText,
  });

  /// Stable card id; title and subtitle come from l10n.
  final String id;
  final IconData icon;
  final bool freeOnly;
  final bool opensMap;
  final String? queryText;
}

class _HomeRouteTemplate {
  const _HomeRouteTemplate({
    required this.id,
    required this.icon,
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.prompt,
    required this.steps,
  });

  /// Stable template id; title and subtitle come from l10n.
  final String id;
  final IconData icon;
  final String mood;
  final int durationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String prompt;
  final List<String> steps;
}

/// L4: price in the item's own currency and start time in the item's own
/// zone (the device zone only when the item carries none).
String _homeCardMeta(AppLocalizations l10n, DiscoverItemEntity item) {
  final DateTime? start = item.startsAtUtc;
  final String price = item.isFree
      ? l10n.homeFree
      : item.priceAmount == null
      ? '—'
      : RechargeFormats.money(item.priceAmount!, l10n.localeName);
  final String time = start == null
      ? (item.activityCatalog == null
            ? l10n.homeAnyTime
            : _activityDuration(
                l10n,
                item.activityCatalog!.durationMinMinutes,
                item.activityCatalog!.durationMaxMinutes,
              ))
      : item.timezoneId.isEmpty
      ? RechargeFormats.deviceTime(start, l10n.localeName)
      : RechargeFormats.time(start, item.timezoneId, l10n.localeName);
  final String venue = item.venueName.isEmpty ? item.city : item.venueName;
  return l10n.homeCardMeta(price, time, venue);
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
        'source': 'smart_route_seed',
        'type': 'route',
        'title':
            '${_capitalized(routeIntent.mood)} recharge route', // l10n-ignore: Create seed prefill data
        'subtitle':
            '${routeIntent.stepCategories.length} stops · ' // l10n-ignore: Create seed prefill data
            '${routeIntent.durationMinutes} min · smart route', // l10n-ignore: Create seed prefill data
        'q': parseResult.originalText.trim(),
        'category': 'route',
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
    path: RouteNames.create,
    queryParameters: <String, String>{
      ..._scenarioTemplateParameters(template),
      'source': 'route_template_seed',
      'type': 'route',
      'category': 'route',
    },
  ).toString();
}

String _mapRouteForTemplate(_HomeRouteTemplate template) {
  final Map<String, String> params = <String, String>{
    ..._scenarioTemplateParameters(template),
    'mode': 'route',
  };
  return Uri(path: RouteNames.discoverMap, queryParameters: params).toString();
}

/// The Create seed is prefilled in the reader's language.
String _createRouteForTemplate(
  AppLocalizations l10n,
  _HomeRouteTemplate template,
) {
  final Map<String, String> params = <String, String>{
    ..._scenarioTemplateParameters(template),
    'source': 'route_template_seed',
    'type': 'route',
    'title': l10n.discoverHomeIdeaTitle(template.id),
    'subtitle': l10n.discoverHomeIdeaSubtitle(template.id),
    'q': template.prompt,
    'category': 'route',
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
    if (includeMode) 'mode': 'route',
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

String _titleForSmartSearch(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea'; // l10n-ignore: Create seed prefill data
  }
  return 'Smart search idea'; // l10n-ignore: Create seed prefill data
}

String _capitalized(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

// The cases are the stable section ids of _homeChoiceSections.
String _homeSectionTitle(AppLocalizations l10n, String id) => switch (id) {
  'Categories' => l10n.discoverCategories, // l10n-ignore: section id
  'New' => l10n.discoverHomeNew, // l10n-ignore: section id
  'For you' => l10n.discoverHomeForYou, // l10n-ignore: section id
  'Quick events' => l10n.discoverHomeQuickEvents, // l10n-ignore: section id
  'Nearby' => l10n.discoverHomeNearby, // l10n-ignore: section id
  _ => l10n.discoverHomePopular,
};

String homeScenarioTitle(AppLocalizations l10n, String id) =>
    l10n.discoverHomeIdeaTitle(id);

String homeScenarioSubtitle(AppLocalizations l10n, String id) =>
    l10n.discoverHomeIdeaSubtitle(id);

/// The declared duration of a catalog Activity: one value or a range.
String _activityDuration(AppLocalizations l10n, int min, int max) => min == max
    ? l10n.discoverMinutes(min)
    : l10n.discoverMinutesRange(min, max);
