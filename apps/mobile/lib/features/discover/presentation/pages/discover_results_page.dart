import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/queries/discover_query.dart';
import '../../application/smart_search_parser.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';

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
  SmartSearchParseResult? _lastSmartParse;

  static const List<_CategoryOption> _categories = <_CategoryOption>[
    _CategoryOption(id: null, label: 'All', icon: Icons.grid_view_rounded),
    _CategoryOption(id: 'outdoor', label: 'Outdoor', icon: Icons.park_outlined),
    _CategoryOption(
      id: 'wellness',
      label: 'Wellness',
      icon: Icons.self_improvement_rounded,
    ),
    _CategoryOption(id: 'art', label: 'Art', icon: Icons.palette_outlined),
    _CategoryOption(id: 'music', label: 'Music', icon: Icons.music_note),
    _CategoryOption(id: 'family', label: 'Family', icon: Icons.family_restroom),
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
      controller.ensureSmartSearchHistoryLoaded();
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
            onVoicePrompt: () => _showVoicePromptSheet(controller),
            onClear: () {
              _searchController.clear();
              setState(() => _lastSmartParse = null);
              controller.applySearchConditions(queryText: '');
            },
          ),
          const SizedBox(height: 12),
          _SmartSearchPanel(
            parseResult: _lastSmartParse,
            onApply: () => _applySmartSearch(controller),
            onVoicePrompt: () => _showVoicePromptSheet(controller),
            onBuildScenario: _lastSmartParse == null
                ? null
                : () => context.go(_scenarioBuilderLocation(_lastSmartParse!)),
            onMapSmartRoute: _lastSmartParse?.routeIntent == null
                ? null
                : () => context.go(_mapLocationForSmartRoute(_lastSmartParse!)),
            onCreateSmartRoute: _lastSmartParse?.routeIntent == null
                ? null
                : () => context.go(
                    _createLocationForSmartRoute(_lastSmartParse!),
                  ),
            onExample: (String value) {
              _searchController.text = value;
              _applySmartSearch(controller);
            },
          ),
          if (state.smartSearchHistory.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _SmartSearchHistoryPanel(
              history: state.smartSearchHistory,
              onApply: (SmartSearchHistoryEntity item) {
                _searchController.text = item.prompt;
                setState(() => _lastSmartParse = parseSmartSearch(item.prompt));
                controller.applySmartSearchHistory(item);
              },
              onOpenMap: (SmartSearchHistoryEntity item) {
                context.go(_mapLocationForSmartSearch(item));
              },
              onBuildScenario: (SmartSearchHistoryEntity item) {
                context.go(_scenarioBuilderLocationForSmartSearch(item));
              },
              onCreateListing: (SmartSearchHistoryEntity item) {
                context.go(_createLocationForSmartSearch(item));
              },
              onDelete: (SmartSearchHistoryEntity item) {
                controller.deleteSmartSearchPrompt(item.id);
              },
            ),
          ],
          const SizedBox(height: 14),
          _SavedSearchesPanel(
            savedSearches: state.savedSearches,
            onSaveCurrent: controller.saveCurrentSearch,
            onCreateCurrent: () => context.go(_createLocationForQuery(query)),
            onApply: (SavedSearchEntity search) {
              _searchController.text = search.query.queryText;
              setState(() => _lastSmartParse = null);
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
                selectedCategoryIds: const <String>['outdoor'],
                freeOnly: false,
                clearBudgetMin: true,
                clearBudgetMax: true,
                clearDateFrom: true,
                clearDateTo: true,
              );
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
                : query.selectedCategoryIds.first,
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

  Future<void> _applySmartSearch(DiscoverFeedController controller) async {
    final SmartSearchParseResult parsed = parseSmartSearch(
      _searchController.text,
    );
    final _DateWindow? window = switch (parsed.datePreset) {
      SmartSearchDatePreset.today => _todayWindow(),
      SmartSearchDatePreset.tonight => _tonightWindow(),
      null => null,
    };

    setState(() => _lastSmartParse = parsed);
    await controller.applySearchConditions(
      queryText: parsed.queryText,
      selectedCategoryIds: parsed.selectedCategoryIds,
      freeOnly: parsed.freeOnly ?? false,
      budgetMax: parsed.budgetMax,
      clearBudgetMin: true,
      clearBudgetMax: parsed.budgetMax == null,
      dateFrom: window?.from,
      clearDateFrom: window == null,
      dateTo: window?.to,
      clearDateTo: window == null,
      radiusMeters: parsed.radiusMeters,
      unlimitedRadius: parsed.unlimitedRadius,
    );
    await controller.saveSmartSearchPrompt(
      prompt: parsed.originalText,
      query: controller.state.appliedQuery,
    );
  }

  Future<void> _showVoicePromptSheet(DiscoverFeedController controller) async {
    final String? prompt = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.mic_none_outlined),
                  title: const Text('Voice prompt'),
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                for (final String value in const <String>[
                  'free yoga tonight near 5 km',
                  'museum today under 10',
                  'free calm walking route for 2 hours with coffee',
                  'quiet walk near 3 km',
                ])
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(value),
                    onTap: () => Navigator.of(context).pop(value),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    _searchController.text = prompt;
    await _applySmartSearch(controller);
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

class _SmartSearchPanel extends StatelessWidget {
  const _SmartSearchPanel({
    required this.parseResult,
    required this.onApply,
    required this.onVoicePrompt,
    required this.onBuildScenario,
    required this.onMapSmartRoute,
    required this.onCreateSmartRoute,
    required this.onExample,
  });

  final SmartSearchParseResult? parseResult;
  final Future<void> Function() onApply;
  final VoidCallback onVoicePrompt;
  final VoidCallback? onBuildScenario;
  final VoidCallback? onMapSmartRoute;
  final VoidCallback? onCreateSmartRoute;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart Search',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Voice prompt',
                  onPressed: onVoicePrompt,
                  icon: const Icon(Icons.mic_none_outlined),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.psychology),
                  label: const Text('Parse'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Try a phrase like free yoga tonight near 5 km under 10.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  avatar: const Icon(Icons.self_improvement),
                  label: const Text('free yoga tonight near 5 km'),
                  onPressed: () => onExample('free yoga tonight near 5 km'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.museum),
                  label: const Text('museum today under 10'),
                  onPressed: () => onExample('museum today under 10'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.route_outlined),
                  label: const Text('free calm walking route'),
                  onPressed: () => onExample(
                    'free calm walking route for 2 hours with coffee',
                  ),
                ),
              ],
            ),
            if (parseResult != null) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: parseResult!.explanationChips
                    .map(
                      (String chip) => Chip(
                        avatar: const Icon(Icons.check, size: 16),
                        label: Text(chip),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              if (parseResult!.routeIntent == null)
                OutlinedButton.icon(
                  onPressed: onBuildScenario,
                  icon: const Icon(Icons.route),
                  label: const Text('Build scenario'),
                )
              else
                _SmartRouteIntentPanel(
                  parseResult: parseResult!,
                  onBuildRoute: onBuildScenario,
                  onMapRoute: onMapSmartRoute,
                  onCreateRoute: onCreateSmartRoute,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmartRouteIntentPanel extends StatelessWidget {
  const _SmartRouteIntentPanel({
    required this.parseResult,
    required this.onBuildRoute,
    required this.onMapRoute,
    required this.onCreateRoute,
  });

  final SmartSearchParseResult parseResult;
  final VoidCallback? onBuildRoute;
  final VoidCallback? onMapRoute;
  final VoidCallback? onCreateRoute;

  @override
  Widget build(BuildContext context) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Divider(color: colorScheme.primary.withValues(alpha: 0.22)),
        Row(
          children: <Widget>[
            Icon(Icons.route_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Smart route',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${routeIntent.stepCategories.length} stops',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: routeIntent.explanationChips
              .map(
                (String chip) => Chip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(chip),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          routeIntent.stepCategories
              .map(createTaxonomyLabelForPath)
              .join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: onBuildRoute,
                icon: const Icon(Icons.route),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Build route'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMapRoute,
                icon: const Icon(Icons.map_outlined),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Map route'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Create smart route listing',
              onPressed: onCreateRoute,
              icon: const Icon(Icons.add_business_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmartSearchHistoryPanel extends StatelessWidget {
  const _SmartSearchHistoryPanel({
    required this.history,
    required this.onApply,
    required this.onOpenMap,
    required this.onBuildScenario,
    required this.onCreateListing,
    required this.onDelete,
  });

  final List<SmartSearchHistoryEntity> history;
  final ValueChanged<SmartSearchHistoryEntity> onApply;
  final ValueChanged<SmartSearchHistoryEntity> onOpenMap;
  final ValueChanged<SmartSearchHistoryEntity> onBuildScenario;
  final ValueChanged<SmartSearchHistoryEntity> onCreateListing;
  final ValueChanged<SmartSearchHistoryEntity> onDelete;

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.history_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent Smart Searches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: history
                  .map(
                    (SmartSearchHistoryEntity item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SmartSearchHistoryTile(
                        item: item,
                        onApply: () => onApply(item),
                        onOpenMap: () => onOpenMap(item),
                        onBuildScenario: () => onBuildScenario(item),
                        onCreateListing: () => onCreateListing(item),
                        onDelete: () => onDelete(item),
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

class _SmartSearchHistoryTile extends StatelessWidget {
  const _SmartSearchHistoryTile({
    required this.item,
    required this.onApply,
    required this.onOpenMap,
    required this.onBuildScenario,
    required this.onCreateListing,
    required this.onDelete,
  });

  final SmartSearchHistoryEntity item;
  final VoidCallback onApply;
  final VoidCallback onOpenMap;
  final VoidCallback onBuildScenario;
  final VoidCallback onCreateListing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final SmartRouteIntent? routeIntent = parseSmartSearch(
      item.prompt,
    ).routeIntent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
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
                        item.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _promptForQuery(item.query),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete smart search',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (routeIntent != null) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  const Chip(
                    avatar: Icon(Icons.route_outlined, size: 16),
                    label: Text('Smart route'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('${routeIntent.durationMinutes} min'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.flag_outlined, size: 16),
                    label: Text('${routeIntent.stepCategories.length} stops'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Use'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Open smart search on map',
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Build route from smart search',
                  onPressed: onBuildScenario,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Create listing from smart search',
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
                    'Saved conditions',
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
                'No saved conditions yet',
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

String _scenarioBuilderLocation(SmartSearchParseResult parseResult) {
  final SmartRouteIntent? routeIntent = parseResult.routeIntent;
  final Map<String, String> params = <String, String>{
    'mood': routeIntent?.mood ?? _scenarioMoodForSmartParse(parseResult),
    'duration': (routeIntent?.durationMinutes ?? 150).toString(),
    'walking': routeIntent == null
        ? (parseResult.unlimitedRadius == true ? '0' : '1')
        : (routeIntent.walkingOnly ? '1' : '0'),
    if (parseResult.freeOnly == true || routeIntent?.freeOnly == true)
      'free': '1',
    if (parseResult.originalText.trim().isNotEmpty)
      'prompt': parseResult.originalText.trim(),
    if (routeIntent != null && routeIntent.stepCategories.isNotEmpty)
      'steps': routeIntent.stepCategories.join(','),
  };
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: params,
  ).toString();
}

String _mapLocationForSmartRoute(SmartSearchParseResult parseResult) {
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: _smartRouteParameters(
      parseResult,
      routeIntent,
      includeMode: true,
    ),
  ).toString();
}

String _mapLocationForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent != null) {
    return _mapLocationForSmartRoute(parseResult);
  }
  return _mapLocationForQuery(item.query);
}

String _createLocationForSmartRoute(SmartSearchParseResult parseResult) {
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  final String mood = routeIntent.mood;
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      ..._smartRouteParameters(parseResult, routeIntent, includeMode: false),
      'source': 'scenario',
      'type': 'event',
      'title': '${_capitalized(mood)} recharge route',
      'subtitle':
          '${routeIntent.stepCategories.length} stops · '
          '${routeIntent.durationMinutes} min · smart route',
      'q': parseResult.originalText.trim(),
      'category': 'scenario',
    },
  ).toString();
}

Map<String, String> _smartRouteParameters(
  SmartSearchParseResult parseResult,
  SmartRouteIntent routeIntent, {
  required bool includeMode,
}) {
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

String _scenarioBuilderLocationForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent != null) {
    return _scenarioBuilderLocation(parseResult);
  }
  return _scenarioBuilderLocationForQuery(item.query);
}

String _scenarioMoodForSmartParse(SmartSearchParseResult parseResult) {
  return _scenarioMoodForSignals(
    parseResult.queryText,
    parseResult.selectedCategoryIds,
  );
}

String _scenarioMoodForQuery(DiscoverQuery query) {
  return _scenarioMoodForSignals(query.queryText, query.selectedCategoryIds);
}

String _scenarioMoodForSignals(String queryText, List<String> categories) {
  final String normalized = queryText.toLowerCase();
  if (normalized.contains('tennis') ||
      normalized.contains('run') ||
      normalized.contains('sport')) {
    return 'active';
  }
  if (categories.any((String category) {
    return category == 'music' || category == 'art' || category == 'family';
  })) {
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

String _createLocationForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent != null) {
    return _createLocationForSmartRoute(parseResult);
  }
  return _createLocationForQuery(
    item.query,
    source: 'smart_search',
    title: _createTitleForQuery(item.query),
    subtitle: item.prompt,
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
      .map((String value) => value.trim())
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
    required this.onVoicePrompt,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onVoicePrompt;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'Describe what you want',
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
                tooltip: 'Voice prompt',
                onPressed: onVoicePrompt,
                icon: const Icon(Icons.mic_none_outlined),
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
                      '${item.city} · ${item.category} · '
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
