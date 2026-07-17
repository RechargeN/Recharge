import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/queries/discover_query.dart';
import '../../domain/entities/saved_search_entity.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final DiscoverFeedController controller = ref.read(
      discoverFeedControllerProvider,
    );
    _searchController = TextEditingController(
      text: controller.state.appliedQuery.queryText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.ensureLoaded();
      if (!mounted) return;
      controller.beginSearchDraft();
      await controller.ensureSavedSearchesLoaded();
      if (!mounted || _searchController.text.isNotEmpty) return;
      _searchController.text = controller.state.draftQuery.queryText;
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
    final DiscoverQuery query = controller.state.draftQuery;
    final List<SavedSearchEntity> recent = controller.state.savedSearches;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Recharge')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          TextField(
            key: const Key('regular-search-field'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _openResults(controller),
            decoration: InputDecoration(
              hintText: 'Search activity, place or plan',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                key: const Key('regular-search-filters'),
                tooltip: 'Search filters',
                onPressed: () => _openFilters(controller, query),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SearchConditionChips(query: query),
          const SizedBox(height: 18),
          _QuickSearchActions(
            onNearNow: () {
              final _DateWindow today = _todayWindow();
              controller.stageSearchConditions(
                dateFrom: today.from,
                dateTo: today.to,
                radiusMeters: 2000,
                unlimitedRadius: false,
              );
            },
            onForTwo: () => controller.stageSearchConditions(peopleCount: 2),
            onLowBudget: () => controller.stageSearchConditions(budgetMax: 10),
            onOneHour: () =>
                controller.stageSearchConditions(availableDurationMinutes: 60),
            onCalmEvening: () {
              final _DateWindow tonight = _tonightWindow();
              controller.stageSearchConditions(
                mood: 'calm',
                dateFrom: tonight.from,
                dateTo: tonight.to,
              );
            },
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Recent searches',
            action: recent.length > 3 ? 'See all' : null,
            onAction: recent.length > 3
                ? () => _showAllRecent(controller, recent)
                : null,
          ),
          const SizedBox(height: 8),
          _RecentSearches(
            searches: recent.take(3).toList(growable: false),
            onOpen: (SavedSearchEntity search) =>
                context.go(_resultsLocation(search.query, source: 'recent')),
            onDelete: (SavedSearchEntity search) =>
                controller.deleteSavedSearch(search.id),
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Quick plans',
            action: 'See all',
            onAction: () =>
                context.go('${RouteNames.scenarioBuilder}?preview=1'),
          ),
          const SizedBox(height: 10),
          _QuickPlanRail(onOpen: (String location) => context.go(location)),
        ],
      ),
    );
  }

  void _openResults(DiscoverFeedController controller) {
    FocusScope.of(context).unfocus();
    controller.stageSearchConditions(queryText: _searchController.text);
    context.go(_resultsLocation(controller.state.draftQuery));
  }

  Future<void> _openFilters(
    DiscoverFeedController controller,
    DiscoverQuery query,
  ) async {
    final _SearchFilterSelection? selection =
        await showModalBottomSheet<_SearchFilterSelection>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => _SearchFiltersSheet(query: query),
        );
    if (selection == null) return;
    controller.stageSearchConditions(
      peopleCount: selection.peopleCount,
      clearPeopleCount: selection.peopleCount == null,
      budgetMax: selection.budgetMax,
      clearBudgetMax: selection.budgetMax == null,
      dateFrom: selection.dateWindow?.from,
      clearDateFrom: selection.dateWindow == null,
      dateTo: selection.dateWindow?.to,
      clearDateTo: selection.dateWindow == null,
      radiusMeters: selection.radiusMeters,
      unlimitedRadius: selection.unlimitedRadius,
      availableDurationMinutes: selection.durationMinutes,
      clearAvailableDurationMinutes: selection.durationMinutes == null,
      mood: selection.mood,
      clearMood: selection.mood == null,
    );
  }

  void _showAllRecent(
    DiscoverFeedController controller,
    List<SavedSearchEntity> recent,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListView(
          children: <Widget>[
            Text(
              'Recent searches',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _RecentSearches(
              searches: recent,
              onOpen: (SavedSearchEntity search) {
                Navigator.of(sheetContext).pop();
                context.go(_resultsLocation(search.query, source: 'recent'));
              },
              onDelete: (SavedSearchEntity search) =>
                  controller.deleteSavedSearch(search.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchConditionChips extends StatelessWidget {
  const _SearchConditionChips({required this.query});

  final DiscoverQuery query;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      Chip(
        avatar: const Icon(Icons.calendar_today_outlined, size: 15),
        label: Text(_dateLabel(query)),
      ),
      Chip(
        avatar: const Icon(Icons.group_outlined, size: 15),
        label: Text(
          query.peopleCount == null
              ? 'Any group'
              : '${query.peopleCount} people',
        ),
      ),
      Chip(
        avatar: const Icon(Icons.payments_outlined, size: 15),
        label: Text(
          query.budgetMax == null
              ? 'Any budget'
              : '€${query.budgetMax!.round()}',
        ),
      ),
      Chip(
        avatar: const Icon(Icons.near_me_outlined, size: 15),
        label: Text(
          query.unlimitedRadius
              ? 'Any area'
              : '${(query.radiusMeters / 1000).round()} km',
        ),
      ),
      if (query.availableDurationMinutes != null)
        Chip(
          avatar: const Icon(Icons.schedule_outlined, size: 15),
          label: Text('${query.availableDurationMinutes} min'),
        ),
      if (query.mood != null)
        Chip(
          avatar: const Icon(Icons.nightlight_outlined, size: 15),
          label: Text(
            '${query.mood![0].toUpperCase()}${query.mood!.substring(1)}',
          ),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 6, children: chips),
    );
  }
}

class _QuickSearchActions extends StatelessWidget {
  const _QuickSearchActions({
    required this.onNearNow,
    required this.onForTwo,
    required this.onLowBudget,
    required this.onOneHour,
    required this.onCalmEvening,
  });

  final VoidCallback onNearNow;
  final VoidCallback onForTwo;
  final VoidCallback onLowBudget;
  final VoidCallback onOneHour;
  final VoidCallback onCalmEvening;

  @override
  Widget build(BuildContext context) {
    final List<_QuickActionData> actions = <_QuickActionData>[
      _QuickActionData(Icons.navigation_outlined, 'Near me now', onNearNow),
      _QuickActionData(Icons.group_outlined, 'For two', onForTwo),
      _QuickActionData(Icons.sell_outlined, 'Low budget', onLowBudget),
      _QuickActionData(Icons.schedule_outlined, '1 hour', onOneHour),
      _QuickActionData(
        Icons.nightlight_outlined,
        'Calm evening',
        onCalmEvening,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actions
          .map(
            (_QuickActionData action) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: action.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Icon(action.icon, size: 20),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        action.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onOpen,
    required this.onDelete,
  });
  final List<SavedSearchEntity> searches;
  final ValueChanged<SavedSearchEntity> onOpen;
  final ValueChanged<SavedSearchEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Your regular searches will appear here automatically.',
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < searches.length; index++) ...<Widget>[
            ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(_recentIcon(searches[index]), size: 19),
              ),
              title: Text(
                searches[index].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                searches[index].subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpen(searches[index]),
              onLongPress: () => onDelete(searches[index]),
            ),
            if (index < searches.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}

class _QuickPlanRail extends StatelessWidget {
  const _QuickPlanRail({required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    const List<_QuickPlanData> plans = <_QuickPlanData>[
      _QuickPlanData(
        'After work',
        '~ 1 hour',
        Icons.local_cafe_outlined,
        0,
        'calm',
        60,
        'food_drinks.coffee,wellness_recharge.calm_walk',
      ),
      _QuickPlanData(
        'Sunset break',
        '1–2 hours',
        Icons.wb_twilight_outlined,
        1,
        'calm',
        120,
        'wellness_recharge.calm_walk,art_culture_museums.museum',
      ),
      _QuickPlanData(
        'Active morning',
        '2–3 hours',
        Icons.directions_run_outlined,
        2,
        'active',
        150,
        'outdoor_nature_walking.city_walk,sport.tennis',
      ),
      _QuickPlanData(
        'Social evening',
        '2–3 hours',
        Icons.celebration_outlined,
        3,
        'social',
        180,
        'games_indoor.board_games,music_nightlife.afterwork_drinks',
      ),
    ];
    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final _QuickPlanData plan = plans[index];
          final Color planColor = _quickPlanColor(
            Theme.of(context).colorScheme,
            plan.tone,
          );
          return SizedBox(
            width: 132,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onOpen(plan.location),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              planColor.withValues(alpha: 0.62),
                              planColor,
                            ],
                          ),
                        ),
                        child: Icon(plan.icon, color: Colors.white, size: 34),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            plan.duration,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickPlanData {
  const _QuickPlanData(
    this.title,
    this.duration,
    this.icon,
    this.tone,
    this.mood,
    this.minutes,
    this.steps,
  );
  final String title;
  final String duration;
  final IconData icon;
  final int tone;
  final String mood;
  final int minutes;
  final String steps;

  String get location => Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: <String, String>{
      'preview': '1',
      'title': title,
      'mood': mood,
      'duration': '$minutes',
      'walking': '1',
      'steps': steps,
    },
  ).toString();
}

Color _quickPlanColor(ColorScheme colors, int tone) => switch (tone) {
  1 => colors.tertiary,
  2 => colors.primary,
  3 => colors.secondary,
  _ => colors.onSurfaceVariant,
};

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({required this.query});
  final DiscoverQuery query;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late int? _peopleCount = widget.query.peopleCount;
  late double? _budgetMax = widget.query.budgetMax;
  late double _radiusMeters = widget.query.radiusMeters;
  late bool _unlimited = widget.query.unlimitedRadius;
  late int? _duration = widget.query.availableDurationMinutes;
  late String? _mood = widget.query.mood;
  late String _date = _dateChoice(widget.query);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.76,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController scrollController) =>
          ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Search filters',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 14),
              _FilterTitle('When'),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment(value: 'any', label: Text('Any')),
                  ButtonSegment(value: 'today', label: Text('Today')),
                  ButtonSegment(value: 'tonight', label: Text('Tonight')),
                ],
                selected: <String>{_date},
                onSelectionChanged: (Set<String> value) =>
                    setState(() => _date = value.first),
              ),
              const SizedBox(height: 18),
              _FilterTitle('People'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final int? value in <int?>[null, 1, 2, 4])
                    ChoiceChip(
                      label: Text(value == null ? 'Any' : '$value'),
                      selected: _peopleCount == value,
                      onSelected: (_) => setState(() => _peopleCount = value),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _FilterTitle('Budget per person'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final double? value in <double?>[null, 10, 20, 40])
                    ChoiceChip(
                      label: Text(value == null ? 'Any' : '€${value.round()}'),
                      selected: _budgetMax == value,
                      onSelected: (_) => setState(() => _budgetMax = value),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _FilterTitle('Time available'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final int? value in <int?>[null, 60, 120, 180])
                    ChoiceChip(
                      label: Text(
                        value == null
                            ? 'Any'
                            : value == 60
                            ? '1 hour'
                            : '${value ~/ 60} hours',
                      ),
                      selected: _duration == value,
                      onSelected: (_) => setState(() => _duration = value),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _FilterTitle('Mood'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final String? value in <String?>[
                    null,
                    'calm',
                    'social',
                    'active',
                  ])
                    ChoiceChip(
                      label: Text(
                        value == null
                            ? 'Any'
                            : '${value[0].toUpperCase()}${value.substring(1)}',
                      ),
                      selected: _mood == value,
                      onSelected: (_) => setState(() => _mood = value),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const _FilterTitle('Distance'),
                  const Spacer(),
                  Text(
                    _unlimited
                        ? 'Any area'
                        : '${(_radiusMeters / 1000).round()} km',
                  ),
                ],
              ),
              Slider(
                min: 1,
                max: 30,
                divisions: 29,
                value: (_radiusMeters / 1000).clamp(1, 30),
                onChanged: _unlimited
                    ? null
                    : (double value) =>
                          setState(() => _radiusMeters = value * 1000),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Any distance'),
                value: _unlimited,
                onChanged: (bool value) => setState(() => _unlimited = value),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selection),
                child: const Text('Apply filters'),
              ),
            ],
          ),
    );
  }

  _SearchFilterSelection get _selection {
    final _DateWindow? window = switch (_date) {
      'today' => _todayWindow(),
      'tonight' => _tonightWindow(),
      _ => null,
    };
    return _SearchFilterSelection(
      peopleCount: _peopleCount,
      budgetMax: _budgetMax,
      dateWindow: window,
      radiusMeters: _radiusMeters,
      unlimitedRadius: _unlimited,
      durationMinutes: _duration,
      mood: _mood,
    );
  }

  void _reset() => setState(() {
    _peopleCount = null;
    _budgetMax = null;
    _date = 'any';
    _radiusMeters = 5000;
    _unlimited = false;
    _duration = null;
    _mood = null;
  });
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _SearchFilterSelection {
  const _SearchFilterSelection({
    required this.peopleCount,
    required this.budgetMax,
    required this.dateWindow,
    required this.radiusMeters,
    required this.unlimitedRadius,
    required this.durationMinutes,
    required this.mood,
  });
  final int? peopleCount;
  final double? budgetMax;
  final _DateWindow? dateWindow;
  final double radiusMeters;
  final bool unlimitedRadius;
  final int? durationMinutes;
  final String? mood;
}

class _DateWindow {
  const _DateWindow(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

_DateWindow _todayWindow() {
  final DateTime now = DateTime.now();
  return _DateWindow(now, DateTime(now.year, now.month, now.day, 23, 59, 59));
}

_DateWindow _tonightWindow() {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month, now.day, 18);
  return _DateWindow(
    now.isAfter(from) ? now : from,
    DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
}

String _dateLabel(DiscoverQuery query) {
  if (query.dateFrom == null && query.dateTo == null) return 'Any date';
  final DateTime now = DateTime.now();
  final DateTime? from = query.dateFrom?.toLocal();
  if (from?.year == now.year &&
      from?.month == now.month &&
      from?.day == now.day) {
    return 'Today';
  }
  return 'Date set';
}

String _dateChoice(DiscoverQuery query) {
  if (query.dateFrom == null && query.dateTo == null) return 'any';
  final int hour = query.dateFrom?.toLocal().hour ?? 0;
  return hour >= 17 ? 'tonight' : 'today';
}

IconData _recentIcon(SavedSearchEntity search) {
  final String value = '${search.title} ${search.subtitle}'.toLowerCase();
  if (value.contains('music')) return Icons.music_note_outlined;
  if (value.contains('coffee')) return Icons.coffee_outlined;
  if (value.contains('park') || value.contains('walk')) {
    return Icons.eco_outlined;
  }
  return Icons.search_rounded;
}

String _resultsLocation(
  DiscoverQuery query, {
  String source = 'regular_search',
}) {
  return Uri(
    path: RouteNames.discoverResults,
    queryParameters: <String, String>{
      'source': source,
      'q': query.queryText.trim(),
      'category': query.selectedCategoryIds.join(','),
      'free': query.freeOnly ? '1' : '0',
      if (query.peopleCount != null) 'people': '${query.peopleCount}',
      if (query.budgetMax != null)
        'budgetMax': query.budgetMax!.toStringAsFixed(0),
      if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
      if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
      'radius': query.radiusMeters.round().toString(),
      'unlimited': query.unlimitedRadius ? '1' : '0',
      if (query.availableDurationMinutes != null)
        'duration': '${query.availableDurationMinutes}',
      if (query.mood != null) 'mood': query.mood!,
    },
  ).toString();
}
