import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/queries/discover_query.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/saved_search_entity.dart';

class DiscoverResultsPage extends ConsumerStatefulWidget {
  const DiscoverResultsPage({
    super.key,
    this.seedParameters = const <String, String>{},
  });

  final Map<String, String> seedParameters;

  @override
  ConsumerState<DiscoverResultsPage> createState() =>
      _DiscoverResultsPageState();
}

class _DiscoverResultsPageState extends ConsumerState<DiscoverResultsPage> {
  late final TextEditingController _searchController;
  final GlobalKey _conditionsKey = GlobalKey();

  static final List<_CategoryOption> _categories = <_CategoryOption>[
    const _CategoryOption(
      id: null,
      label: 'All',
      icon: Icons.grid_view_rounded,
    ),
    for (final RechargeContentGroup group in rechargeVisibleContentGroups)
      _CategoryOption(
        id: group.id,
        label: group.title,
        icon: _discoverCategoryIcon(group.id),
      ),
  ];

  @override
  void initState() {
    super.initState();
    final DiscoverQuery query = ref
        .read(discoverFeedControllerProvider)
        .state
        .appliedQuery;
    _searchController = TextEditingController(
      text: _queryTextFromSeed(widget.seedParameters) ?? query.queryText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final DiscoverFeedController controller = ref.read(
        discoverFeedControllerProvider,
      );
      if (_hasSearchSeed(widget.seedParameters)) {
        _applySearchSeed(controller, widget.seedParameters);
      } else {
        controller.ensureLoaded();
      }
      controller.ensureSavedSearchesLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller = ref.watch(
      discoverFeedControllerProvider,
    );
    final DiscoverFeedState state = controller.state;
    final DiscoverQuery query = state.appliedQuery;
    _syncSearchController(query.queryText);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Recharge'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Map',
            onPressed: () => context.go(_mapLocationForQuery(query)),
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Create from current search',
            onPressed: () => context.go(_createLocationForQuery(query)),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _SearchField(
            controller: _searchController,
            onSubmit: () => controller.applySearchConditions(
              queryText: _searchController.text,
            ),
            onClear: () {
              _searchController.clear();
              controller.applySearchConditions(queryText: '');
            },
            onFilters: _scrollToConditions,
          ),
          const SizedBox(height: 10),
          _ActiveConditionChips(query: query),
          const SizedBox(height: 14),
          _SectionTitle(
            title: 'Quick scenarios',
            actionLabel: 'Reset',
            onAction: () {
              _searchController.clear();
              controller.resetSearchConditions();
            },
          ),
          const SizedBox(height: 10),
          _ScenarioRow(
            onFreeToday: () {
              final _DateWindow today = _todayWindow();
              _searchController.clear();
              controller.applySearchConditions(
                queryText: '',
                selectedCategoryIds: const <String>[],
                freeOnly: true,
                clearBudgetMin: true,
                clearBudgetMax: true,
                dateFrom: today.from,
                dateTo: today.to,
              );
            },
            onTonight: () {
              final _DateWindow tonight = _tonightWindow();
              _searchController.text = 'music';
              controller.applySearchConditions(
                queryText: 'music',
                selectedCategoryIds: const <String>[],
                freeOnly: false,
                clearBudgetMin: true,
                clearBudgetMax: true,
                dateFrom: tonight.from,
                dateTo: tonight.to,
              );
            },
            onUnderTen: () {
              controller.applySearchConditions(
                freeOnly: false,
                clearBudgetMin: true,
                budgetMax: 10,
                clearDateFrom: true,
                clearDateTo: true,
              );
            },
            onOutdoor: () {
              controller.applySearchConditions(
                selectedCategoryIds: const <String>['outdoor_nature_walking'],
                freeOnly: false,
                clearBudgetMin: true,
                clearBudgetMax: true,
                clearDateFrom: true,
                clearDateTo: true,
              );
            },
          ),
          const SizedBox(height: 18),
          _SavedSearchesPanel(
            savedSearches: state.savedSearches,
            onSaveCurrent: controller.saveCurrentSearch,
            onCreateCurrent: () => context.go(_createLocationForQuery(query)),
            onApply: (SavedSearchEntity search) {
              _searchController.text = search.query.queryText;
              controller.applySavedSearch(search);
            },
            onOpenMap: (SavedSearchEntity search) {
              context.go(_mapLocationForQuery(search.query));
            },
            onBuildScenario: (SavedSearchEntity search) {
              context.go(_scenarioBuilderLocationForQuery(search.query));
            },
            onCreateListing: (SavedSearchEntity search) {
              context.go(_createLocationForSavedSearch(search));
            },
            onDelete: (SavedSearchEntity search) {
              controller.deleteSavedSearch(search.id);
            },
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Categories',
            actionLabel: 'View map',
            onAction: () => context.go(_mapLocationForQuery(query)),
          ),
          const SizedBox(height: 10),
          _CategoryRail(
            categories: _categories,
            selectedCategoryId: query.selectedCategoryIds.isEmpty
                ? null
                : normalizeRechargeContentGroupId(
                    query.selectedCategoryIds.first,
                  ),
            onSelected: (String? categoryId) {
              controller.applySearchConditions(
                selectedCategoryIds: categoryId == null
                    ? const <String>[]
                    : <String>[categoryId],
              );
            },
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Conditions',
            actionLabel: '${state.resultCount} found',
          ),
          const SizedBox(height: 10),
          _ConditionPanel(
            key: _conditionsKey,
            query: query,
            onFreeOnlyChanged: (bool value) {
              controller.applySearchConditions(freeOnly: value);
            },
            onBudgetSelected: (double? value) {
              controller.applySearchConditions(
                freeOnly: false,
                budgetMax: value,
                clearBudgetMin: true,
                clearBudgetMax: value == null,
              );
            },
            onDateSelected: (_DateFilter filter) {
              final _DateWindow? window = switch (filter) {
                _DateFilter.any => null,
                _DateFilter.today => _todayWindow(),
                _DateFilter.tonight => _tonightWindow(),
              };
              controller.applySearchConditions(
                dateFrom: window?.from,
                clearDateFrom: window == null,
                dateTo: window?.to,
                clearDateTo: window == null,
              );
            },
            onRadiusSelected: (_RadiusFilter filter) {
              controller.applySearchConditions(
                radiusMeters: filter.radiusMeters,
                unlimitedRadius: filter.unlimited,
              );
            },
          ),
          const SizedBox(height: 14),
          _AppliedSummary(query: query),
          const SizedBox(height: 18),
          _ResultsList(
            state: state,
            onRetry: controller.loadFeed,
            onReset: () {
              _searchController.clear();
              return controller.resetSearchConditions();
            },
            onOpenDetails: (String itemId) {
              context.push('${RouteNames.discoverDetails}/$itemId');
            },
          ),
        ],
      ),
    );
  }

  void _syncSearchController(String queryText) {
    if (_searchController.text == queryText) return;
    _searchController.value = _searchController.value.copyWith(
      text: queryText,
      selection: TextSelection.collapsed(offset: queryText.length),
      composing: TextRange.empty,
    );
  }

  void _scrollToConditions() {
    final BuildContext? targetContext = _conditionsKey.currentContext;
    if (targetContext == null) return;
    FocusScope.of(context).unfocus();
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.12,
    );
  }

  Future<void> _applySearchSeed(
    DiscoverFeedController controller,
    Map<String, String> seedParameters,
  ) async {
    final double? budgetMax = _doubleFromSeed(seedParameters['budgetMax']);
    final DateTime? dateFrom = _dateFromSeed(seedParameters['dateFrom']);
    final DateTime? dateTo = _dateFromSeed(seedParameters['dateTo']);
    await controller.applySearchConditions(
      queryText: _queryTextFromSeed(seedParameters),
      selectedCategoryIds: _categoriesFromSeed(seedParameters),
      freeOnly: seedParameters['free'] == '1',
      budgetMax: budgetMax,
      clearBudgetMin: true,
      clearBudgetMax: budgetMax == null,
      dateFrom: dateFrom,
      clearDateFrom: dateFrom == null,
      dateTo: dateTo,
      clearDateTo: dateTo == null,
      radiusMeters: _doubleFromSeed(seedParameters['radius']),
      unlimitedRadius: seedParameters['unlimited'] == '1',
    );
  }
}

class _SavedSearchesPanel extends StatelessWidget {
  const _SavedSearchesPanel({
    required this.savedSearches,
    required this.onSaveCurrent,
    required this.onCreateCurrent,
    required this.onApply,
    required this.onOpenMap,
    required this.onBuildScenario,
    required this.onCreateListing,
    required this.onDelete,
  });

  final List<SavedSearchEntity> savedSearches;
  final Future<void> Function() onSaveCurrent;
  final VoidCallback onCreateCurrent;
  final ValueChanged<SavedSearchEntity> onApply;
  final ValueChanged<SavedSearchEntity> onOpenMap;
  final ValueChanged<SavedSearchEntity> onBuildScenario;
  final ValueChanged<SavedSearchEntity> onCreateListing;
  final ValueChanged<SavedSearchEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.bookmarks_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent searches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onSaveCurrent,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Create listing from current search',
                  onPressed: onCreateCurrent,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (savedSearches.isEmpty)
              Text(
                'No recent searches yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Column(
                children: savedSearches
                    .map(
                      (SavedSearchEntity search) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SavedSearchTile(
                          search: search,
                          onApply: () => onApply(search),
                          onOpenMap: () => onOpenMap(search),
                          onBuildScenario: () => onBuildScenario(search),
                          onCreateListing: () => onCreateListing(search),
                          onDelete: () => onDelete(search),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedSearchTile extends StatelessWidget {
  const _SavedSearchTile({
    required this.search,
    required this.onApply,
    required this.onOpenMap,
    required this.onBuildScenario,
    required this.onCreateListing,
    required this.onDelete,
  });

  final SavedSearchEntity search;
  final VoidCallback onApply;
  final VoidCallback onOpenMap;
  final VoidCallback onBuildScenario;
  final VoidCallback onCreateListing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        search.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        search.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete saved conditions',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.tune),
                    label: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Open saved conditions on map',
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Build route from saved conditions',
                  onPressed: onBuildScenario,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Create listing from saved conditions',
                  onPressed: onCreateListing,
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

String _scenarioBuilderLocationForQuery(DiscoverQuery query) {
  final String prompt = _promptForQuery(query);
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
  return _scenarioMoodForSignals(query.queryText, query.selectedCategoryIds);
}

String _scenarioMoodForSignals(String queryText, List<String> categories) {
  final String normalized = queryText.toLowerCase();
  final Set<String> normalizedCategories = categories
      .map(normalizeRechargeContentGroupId)
      .toSet();
  if (normalized.contains('tennis') ||
      normalized.contains('run') ||
      normalized.contains('sport') ||
      normalizedCategories.contains('sport') ||
      normalizedCategories.contains('outdoor_nature_walking')) {
    return 'active';
  }
  if (normalizedCategories.contains('music_nightlife') ||
      normalizedCategories.contains('art_culture_museums') ||
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

String _mapLocationForQuery(DiscoverQuery query) {
  final Map<String, String> params = <String, String>{
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
  return Uri(path: RouteNames.discoverMap, queryParameters: params).toString();
}

String _createLocationForSavedSearch(SavedSearchEntity search) {
  return _createLocationForQuery(
    search.query,
    source: 'saved_search',
    title: search.title,
    subtitle: search.subtitle,
  );
}

String _createLocationForQuery(
  DiscoverQuery query, {
  String source = 'search',
  String? title,
  String? subtitle,
}) {
  final Map<String, String> params = <String, String>{
    'source': source,
    'type': 'event',
    'title': title ?? _createTitleForQuery(query),
    if (subtitle != null && subtitle.trim().isNotEmpty)
      'subtitle': subtitle.trim(),
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
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _createTitleForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return _capitalized(queryText);
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

bool _hasSearchSeed(Map<String, String> seedParameters) {
  const List<String> supportedKeys = <String>[
    'q',
    'category',
    'free',
    'budgetMax',
    'dateFrom',
    'dateTo',
    'radius',
    'unlimited',
  ];
  return supportedKeys.any(seedParameters.containsKey);
}

String? _queryTextFromSeed(Map<String, String> seedParameters) {
  if (!seedParameters.containsKey('q')) return null;
  return seedParameters['q']?.trim() ?? '';
}

List<String>? _categoriesFromSeed(Map<String, String> seedParameters) {
  final String? raw = seedParameters['category'];
  if (raw == null) return null;
  return raw
      .split(',')
      .map(normalizeRechargeContentGroupId)
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

double? _doubleFromSeed(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return double.tryParse(value.trim());
}

DateTime? _dateFromSeed(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
    required this.onFilters,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'Search activity, place or plan',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: SizedBox(
          width: 144,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
              IconButton(
                tooltip: 'Search conditions',
                onPressed: onFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveConditionChips extends StatelessWidget {
  const _ActiveConditionChips({required this.query});

  final DiscoverQuery query;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      if (query.dateFrom != null || query.dateTo != null)
        const Chip(
          avatar: Icon(Icons.calendar_today_outlined, size: 16),
          label: Text('Date set'),
        ),
      if (query.peopleCount != null)
        Chip(
          avatar: const Icon(Icons.group_outlined, size: 16),
          label: Text('${query.peopleCount} people'),
        ),
      if (query.freeOnly)
        const Chip(
          avatar: Icon(Icons.payments_outlined, size: 16),
          label: Text('Free'),
        )
      else if (query.budgetMax != null)
        Chip(
          avatar: const Icon(Icons.payments_outlined, size: 16),
          label: Text('Up to €${query.budgetMax!.toStringAsFixed(0)}'),
        ),
      Chip(
        avatar: const Icon(Icons.near_me_outlined, size: 16),
        label: Text(
          query.unlimitedRadius
              ? 'Any area'
              : '${(query.radiusMeters / 1000).round()} km',
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (Widget chip) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: chip,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onAction == null)
          Text(
            actionLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.onFreeToday,
    required this.onTonight,
    required this.onUnderTen,
    required this.onOutdoor,
  });

  final VoidCallback onFreeToday;
  final VoidCallback onTonight;
  final VoidCallback onUnderTen;
  final VoidCallback onOutdoor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ActionChip(
          avatar: const Icon(Icons.bolt_outlined),
          label: const Text('Free today'),
          onPressed: onFreeToday,
        ),
        ActionChip(
          avatar: const Icon(Icons.nightlight_outlined),
          label: const Text('Tonight'),
          onPressed: onTonight,
        ),
        ActionChip(
          avatar: const Icon(Icons.payments_outlined),
          label: const Text('Under 10'),
          onPressed: onUnderTen,
        ),
        ActionChip(
          avatar: const Icon(Icons.park_outlined),
          label: const Text('Outdoor'),
          onPressed: onOutdoor,
        ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<_CategoryOption> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const ValueKey<String>('discover-category-rail'),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final _CategoryOption category = categories[index];
          final bool selected = selectedCategoryId == category.id;
          return ChoiceChip(
            selected: selected,
            avatar: Icon(category.icon, size: 18),
            label: Text(category.label),
            onSelected: (_) => onSelected(category.id),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}

class _ConditionPanel extends StatelessWidget {
  const _ConditionPanel({
    super.key,
    required this.query,
    required this.onFreeOnlyChanged,
    required this.onBudgetSelected,
    required this.onDateSelected,
    required this.onRadiusSelected,
  });

  final DiscoverQuery query;
  final ValueChanged<bool> onFreeOnlyChanged;
  final ValueChanged<double?> onBudgetSelected;
  final ValueChanged<_DateFilter> onDateSelected;
  final ValueChanged<_RadiusFilter> onRadiusSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Free only'),
              subtitle: const Text('Show no-ticket activities'),
              value: query.freeOnly,
              onChanged: onFreeOnlyChanged,
            ),
            const Divider(height: 20),
            _FilterLine(
              label: 'Budget',
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Any'),
                  selected: query.budgetMax == null && !query.freeOnly,
                  onSelected: (_) => onBudgetSelected(null),
                ),
                ChoiceChip(
                  label: const Text('Under 10'),
                  selected: query.budgetMax == 10,
                  onSelected: (_) => onBudgetSelected(10),
                ),
                ChoiceChip(
                  label: const Text('Under 15'),
                  selected: query.budgetMax == 15,
                  onSelected: (_) => onBudgetSelected(15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterLine(
              label: 'Date',
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Any'),
                  selected: query.dateFrom == null && query.dateTo == null,
                  onSelected: (_) => onDateSelected(_DateFilter.any),
                ),
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _matchesWindow(query, _todayWindow()),
                  onSelected: (_) => onDateSelected(_DateFilter.today),
                ),
                ChoiceChip(
                  label: const Text('Tonight'),
                  selected: _matchesWindow(query, _tonightWindow()),
                  onSelected: (_) => onDateSelected(_DateFilter.tonight),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterLine(
              label: 'Radius',
              children: <Widget>[
                ChoiceChip(
                  label: const Text('5 km'),
                  selected:
                      !query.unlimitedRadius &&
                      query.radiusMeters.round() == 5000,
                  onSelected: (_) => onRadiusSelected(_RadiusFilter.fiveKm),
                ),
                ChoiceChip(
                  label: const Text('20 km'),
                  selected:
                      !query.unlimitedRadius &&
                      query.radiusMeters.round() == 20000,
                  onSelected: (_) => onRadiusSelected(_RadiusFilter.twentyKm),
                ),
                ChoiceChip(
                  label: const Text('Any area'),
                  selected: query.unlimitedRadius,
                  onSelected: (_) => onRadiusSelected(_RadiusFilter.anyArea),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterLine extends StatelessWidget {
  const _FilterLine({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _AppliedSummary extends StatelessWidget {
  const _AppliedSummary({required this.query});

  final DiscoverQuery query;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = <String>[
      if (query.queryText.isNotEmpty) '"${query.queryText}"',
      if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
      if (query.freeOnly) 'free',
      if (query.budgetMax != null)
        'up to ${query.budgetMax!.toStringAsFixed(0)}',
      if (query.dateFrom != null || query.dateTo != null) 'date set',
      query.unlimitedRadius
          ? 'any area'
          : '${(query.radiusMeters / 1000).round()} km',
    ];

    return Text(
      parts.isEmpty
          ? 'Showing nearby activities'
          : 'Applied: ${parts.join(' · ')}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.state,
    required this.onRetry,
    required this.onReset,
    required this.onOpenDetails,
  });

  final DiscoverFeedState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReset;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DiscoverFeedStatus.initial:
      case DiscoverFeedStatus.loading:
      case DiscoverFeedStatus.selectingArea:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      case DiscoverFeedStatus.empty:
        return _StateMessage(
          message: state.message ?? 'No activities match these conditions',
          actionLabel: 'Reset conditions',
          onAction: onReset,
        );
      case DiscoverFeedStatus.error:
      case DiscoverFeedStatus.permissionDenied:
        return _StateMessage(
          message: state.message ?? 'Search failed',
          actionLabel: 'Retry',
          onAction: onRetry,
        );
      case DiscoverFeedStatus.ready:
      case DiscoverFeedStatus.denseCluster:
        return Column(
          children: state.items
              .map(
                (DiscoverItemEntity item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SearchResultCard(
                    item: item,
                    onTap: () => onOpenDetails(item.id),
                  ),
                ),
              )
              .toList(growable: false),
        );
    }
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item, required this.onTap});

  final DiscoverItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String priceLabel = item.isFree
        ? 'Free'
        : '${item.priceAmount.toStringAsFixed(0)} €';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_activity_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
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
                      '${item.city} · ${rechargeTaxonomyLabel(item.category)} · '
                      '${item.distanceKm.toStringAsFixed(1)} км',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

IconData _discoverCategoryIcon(String categoryId) {
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

class _CategoryOption {
  const _CategoryOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String? id;
  final String label;
  final IconData icon;
}

class _DateWindow {
  const _DateWindow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

enum _DateFilter { any, today, tonight }

enum _RadiusFilter {
  fiveKm(5000, false),
  twentyKm(20000, false),
  anyArea(200000, true);

  const _RadiusFilter(this.radiusMeters, this.unlimited);

  final double radiusMeters;
  final bool unlimited;
}

_DateWindow _todayWindow() {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month, now.day);
  return _DateWindow(from: start, to: start.add(const Duration(days: 1)));
}

_DateWindow _tonightWindow() {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month, now.day, 18);
  final DateTime end = DateTime(now.year, now.month, now.day, 23, 59);
  if (now.isAfter(end)) {
    return _DateWindow(from: now, to: now.add(const Duration(hours: 6)));
  }
  final DateTime from = now.isAfter(start) ? now : start;
  return _DateWindow(from: from, to: end);
}

bool _matchesWindow(DiscoverQuery query, _DateWindow window) {
  return query.dateFrom?.toLocal().isAtSameMomentAs(window.from) == true &&
      query.dateTo?.toLocal().isAtSameMomentAs(window.to) == true;
}
