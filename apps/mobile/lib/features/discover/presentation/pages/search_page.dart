import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/time_window.dart';

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
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
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
      openNow: selection.openNow,
      onlyAvailable: selection.onlyAvailable,
      availableDurationMinutes: selection.durationMinutes,
      clearAvailableDurationMinutes: selection.durationMinutes == null,
      mood: selection.mood,
      clearMood: selection.mood == null,
    );
    if (selection.timeWindowMode == null) {
      controller.clearTimeWindowSelection(clearLegacyDates: false);
    } else {
      final String? error = controller.stageTimeWindowSelection(
        mode: selection.timeWindowMode!,
        startLocal: selection.startLocal,
        endLocal: selection.endLocal,
        flexibilityMinutes: selection.flexibilityMinutes,
        originType: selection.originType,
        originLat: selection.originType == TravelOriginType.manualPin
            ? query.centerLat
            : null,
        originLng: selection.originType == TravelOriginType.manualPin
            ? query.centerLng
            : null,
        transportMode: selection.transportMode,
        includeReturnTrip: selection.includeReturnTrip,
      );
      if (error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
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
      if (query.timeWindow != null)
        Chip(
          avatar: const Icon(Icons.schedule_outlined, size: 15),
          label: Text(
            query.timeWindow!.mode == TimeWindowMode.flexible
                ? 'Flexible ±${query.timeWindow!.flexibilityMinutes} min'
                : query.timeWindow!.mode == TimeWindowMode.anytimeToday
                ? 'Until end of day'
                : 'Exact time',
          ),
        ),
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
  late bool _openNow = widget.query.openNow;
  late bool _onlyAvailable = widget.query.onlyAvailable;
  late int? _duration = widget.query.availableDurationMinutes;
  late String? _mood = widget.query.mood;
  late String _date = _dateChoice(widget.query);
  late TimeWindowMode? _timeWindowMode = widget.query.timeWindow?.mode;
  late DateTime _startLocal =
      widget.query.timeWindow?.startAtUtc.toLocal() ??
      DateTime.now().add(const Duration(minutes: 30));
  late DateTime _endLocal =
      widget.query.timeWindow?.endAtUtc.toLocal() ??
      DateTime.now().add(const Duration(hours: 2));
  late int _flexibilityMinutes =
      widget.query.timeWindow?.flexibilityMinutes ?? 30;
  late TravelOriginType _originType =
      widget.query.travelContext?.originType ??
      TravelOriginType.currentLocation;
  late TransportMode _transportMode =
      widget.query.travelContext?.transportMode ?? TransportMode.walking;
  late bool _includeReturnTrip =
      widget.query.travelContext?.includeReturnTrip ?? true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.68,
      maxChildSize: 0.97,
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          key: const Key('search-filters-sheet'),
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              const _SheetDragHandle(),
              _SheetHeader(
                title: 'Search filters',
                actionLabel: 'Reset',
                onAction: _reset,
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: <Widget>[
                    const _FilterTitle('When'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final (String, String) option
                            in <(String, String)>[
                              ('any', 'Any'),
                              ('today', 'Today'),
                              ('tonight', 'Tonight'),
                            ])
                          _FilterPill(
                            label: option.$2,
                            selected: _date == option.$1,
                            onTap: () => setState(() => _date = option.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FilterTitle('Time available'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final int? value in <int?>[null, 60, 120, 180])
                          _FilterPill(
                            label: value == null
                                ? 'Any'
                                : value == 60
                                ? '1 hour'
                                : '${value ~/ 60} hours',
                            selected: _duration == value,
                            onTap: () => setState(() => _duration = value),
                          ),
                      ],
                    ),
                    const _FilterSectionDivider(),
                    const _FilterTitle('Time fit'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        _FilterPill(
                          label: 'Off',
                          selected: _timeWindowMode == null,
                          onTap: () => setState(() => _timeWindowMode = null),
                        ),
                        _FilterPill(
                          label: 'Exact',
                          selected: _timeWindowMode == TimeWindowMode.exact,
                          onTap: () => _openTimeWindowEditor(
                            initialMode: TimeWindowMode.exact,
                          ),
                        ),
                        _FilterPill(
                          label: 'Flexible',
                          selected: _timeWindowMode == TimeWindowMode.flexible,
                          onTap: () => _openTimeWindowEditor(
                            initialMode: TimeWindowMode.flexible,
                          ),
                        ),
                        _FilterPill(
                          label: 'Until end of day',
                          selected:
                              _timeWindowMode == TimeWindowMode.anytimeToday,
                          onTap: () => setState(
                            () => _timeWindowMode = TimeWindowMode.anytimeToday,
                          ),
                        ),
                      ],
                    ),
                    if (_timeWindowMode == TimeWindowMode.exact ||
                        _timeWindowMode == TimeWindowMode.flexible) ...<Widget>[
                      const SizedBox(height: 10),
                      _TimeWindowNavigationRow(
                        mode: _timeWindowMode!,
                        start: _startLocal,
                        end: _endLocal,
                        flexibilityMinutes: _flexibilityMinutes,
                        onTap: () => _openTimeWindowEditor(
                          initialMode: _timeWindowMode!,
                        ),
                      ),
                    ],
                    if (_timeWindowMode != null) ...<Widget>[
                      const _FilterSectionDivider(),
                      const _FilterTitle('Travel'),
                      const SizedBox(height: 8),
                      _FilterPillWrap(
                        children: <Widget>[
                          _FilterPill(
                            label: 'Walking',
                            icon: Icons.directions_walk_rounded,
                            selected: _transportMode == TransportMode.walking,
                            onTap: () => setState(
                              () => _transportMode = TransportMode.walking,
                            ),
                          ),
                          _FilterPill(
                            label: 'Driving',
                            icon: Icons.directions_car_outlined,
                            selected: _transportMode == TransportMode.driving,
                            onTap: () => setState(
                              () => _transportMode = TransportMode.driving,
                            ),
                          ),
                          _FilterPill(
                            label: 'Transit',
                            icon: Icons.directions_transit_outlined,
                            selected: _transportMode == TransportMode.transit,
                            onTap: () => setState(
                              () => _transportMode = TransportMode.transit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _OriginSegment(
                        value: _originType,
                        onChanged: (TravelOriginType value) =>
                            setState(() => _originType = value),
                      ),
                      const SizedBox(height: 2),
                      _CompactSwitchRow(
                        label: 'Include return trip',
                        value: _includeReturnTrip,
                        onChanged: (bool value) =>
                            setState(() => _includeReturnTrip = value),
                      ),
                    ],
                    const _FilterSectionDivider(),
                    const _FilterTitle('Availability'),
                    const SizedBox(height: 2),
                    _CompactSwitchRow(
                      label: 'Open now',
                      value: _openNow,
                      onChanged: (bool value) =>
                          setState(() => _openNow = value),
                    ),
                    _CompactSwitchRow(
                      label: 'Only available',
                      value: _onlyAvailable,
                      onChanged: (bool value) =>
                          setState(() => _onlyAvailable = value),
                    ),
                    const _FilterSectionDivider(),
                    const _FilterTitle('People'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final int? value in <int?>[null, 1, 2, 4])
                          _FilterPill(
                            label: value == null ? 'Any' : '$value',
                            selected: _peopleCount == value,
                            onTap: () => setState(() => _peopleCount = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FilterTitle('Budget per person'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final double? value in <double?>[null, 10, 20, 40])
                          _FilterPill(
                            label: value == null ? 'Any' : '€${value.round()}',
                            selected: _budgetMax == value,
                            onTap: () => setState(() => _budgetMax = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FilterTitle('Mood'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final (String?, String) option
                            in <(String?, String)>[
                              (null, 'Any'),
                              ('calm', 'Calm'),
                              ('social', 'Social'),
                              ('active', 'Active'),
                            ])
                          _FilterPill(
                            label: option.$2,
                            selected: _mood == option.$1,
                            onTap: () => setState(() => _mood = option.$1),
                          ),
                      ],
                    ),
                    const _FilterSectionDivider(),
                    Row(
                      children: <Widget>[
                        const _FilterTitle('Distance'),
                        const Spacer(),
                        Text(
                          _unlimited
                              ? 'Any area'
                              : '${(_radiusMeters / 1000).round()} km',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        min: 1,
                        max: 30,
                        divisions: 29,
                        value: (_radiusMeters / 1000).clamp(1, 30),
                        onChanged: _unlimited
                            ? null
                            : (double value) =>
                                  setState(() => _radiusMeters = value * 1000),
                      ),
                    ),
                    _CompactSwitchRow(
                      label: 'Any distance',
                      value: _unlimited,
                      onChanged: (bool value) =>
                          setState(() => _unlimited = value),
                    ),
                  ],
                ),
              ),
              _FilterApplyFooter(
                summary: _summary,
                onApply: () => Navigator.of(context).pop(_selection),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _summary {
    final String date = switch (_date) {
      'today' => 'Today',
      'tonight' => 'Tonight',
      _ => 'Any date',
    };
    final String duration = _duration == null
        ? 'Any duration'
        : _duration == 60
        ? '1 hour'
        : '${_duration! ~/ 60} hours';
    final String radius = _unlimited
        ? 'Any area'
        : '${(_radiusMeters / 1000).round()} km';
    return <String>[
      date,
      duration,
      if (_timeWindowMode != null) _transportMode.name,
      radius,
    ].join(' · ');
  }

  Future<void> _openTimeWindowEditor({
    required TimeWindowMode initialMode,
  }) async {
    final _TimeWindowDraft? result =
        await showModalBottomSheet<_TimeWindowDraft>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) => _TimeWindowEditorSheet(
            initialMode: initialMode,
            initialStart: _startLocal,
            initialEnd: _endLocal,
            initialFlexibilityMinutes: _flexibilityMinutes,
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _timeWindowMode = result.mode;
      _startLocal = result.start;
      _endLocal = result.end;
      _flexibilityMinutes = result.flexibilityMinutes;
    });
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
      openNow: _openNow,
      onlyAvailable: _onlyAvailable,
      durationMinutes: _duration,
      mood: _mood,
      timeWindowMode: _timeWindowMode,
      startLocal: _startLocal,
      endLocal: _endLocal,
      flexibilityMinutes: _flexibilityMinutes,
      originType: _originType,
      transportMode: _transportMode,
      includeReturnTrip: _includeReturnTrip,
    );
  }

  void _reset() => setState(() {
    _peopleCount = null;
    _budgetMax = null;
    _date = 'any';
    _radiusMeters = 5000;
    _unlimited = false;
    _openNow = false;
    _onlyAvailable = false;
    _duration = null;
    _mood = null;
    _timeWindowMode = null;
    _startLocal = DateTime.now().add(const Duration(minutes: 30));
    _endLocal = DateTime.now().add(const Duration(hours: 2));
    _flexibilityMinutes = 30;
    _originType = TravelOriginType.currentLocation;
    _transportMode = TransportMode.walking;
    _includeReturnTrip = true;
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
    ).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.leading,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class _FilterPillWrap extends StatelessWidget {
  const _FilterPillWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primaryContainer : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  Icon(Icons.check_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 5),
                ] else if (icon != null) ...<Widget>[
                  Icon(icon, size: 15, color: colors.onSurfaceVariant),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.primary : colors.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSectionDivider extends StatelessWidget {
  const _FilterSectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        SizedBox(
          width: 44,
          child: Transform.scale(
            scale: 0.82,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ),
      ],
    ),
  );
}

class _OriginSegment extends StatelessWidget {
  const _OriginSegment({required this.value, required this.onChanged});

  final TravelOriginType value;
  final ValueChanged<TravelOriginType> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          for (final (TravelOriginType, String, IconData) option
              in <(TravelOriginType, String, IconData)>[
                (
                  TravelOriginType.currentLocation,
                  'Current location',
                  Icons.near_me_outlined,
                ),
                (
                  TravelOriginType.manualPin,
                  'Search pin',
                  Icons.location_on_outlined,
                ),
              ])
            Expanded(
              child: Material(
                color: value == option.$1
                    ? colors.primaryContainer
                    : colors.surface,
                child: InkWell(
                  onTap: () => onChanged(option.$1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(option.$3, size: 15, color: colors.primary),
                      const SizedBox(width: 5),
                      Text(
                        option.$2,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: value == option.$1
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeWindowNavigationRow extends StatelessWidget {
  const _TimeWindowNavigationRow({
    required this.mode,
    required this.start,
    required this.end,
    required this.flexibilityMinutes,
    required this.onTap,
  });

  final TimeWindowMode mode;
  final DateTime start;
  final DateTime end;
  final int flexibilityMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Set exact time',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${mode == TimeWindowMode.flexible ? 'Flexible' : 'Exact'} · '
                        '${_formatClock(start)}–${_formatClock(end)}'
                        '${mode == TimeWindowMode.flexible ? ' · ±$flexibilityMinutes min' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterApplyFooter extends StatelessWidget {
  const _FilterApplyFooter({required this.summary, required this.onApply});

  final String summary;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SizedBox(
              key: const Key('filter-apply-button'),
              height: 40,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onApply,
                child: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWindowDraft {
  const _TimeWindowDraft({
    required this.mode,
    required this.start,
    required this.end,
    required this.flexibilityMinutes,
  });

  final TimeWindowMode mode;
  final DateTime start;
  final DateTime end;
  final int flexibilityMinutes;
}

class _TimeWindowEditorSheet extends StatefulWidget {
  const _TimeWindowEditorSheet({
    required this.initialMode,
    required this.initialStart,
    required this.initialEnd,
    required this.initialFlexibilityMinutes,
  });

  final TimeWindowMode initialMode;
  final DateTime initialStart;
  final DateTime initialEnd;
  final int initialFlexibilityMinutes;

  @override
  State<_TimeWindowEditorSheet> createState() => _TimeWindowEditorSheetState();
}

class _TimeWindowEditorSheetState extends State<_TimeWindowEditorSheet> {
  late TimeWindowMode _mode = widget.initialMode == TimeWindowMode.flexible
      ? TimeWindowMode.flexible
      : TimeWindowMode.exact;
  late DateTime _start = widget.initialStart;
  late DateTime _end = widget.initialEnd;
  late int _flexibilityMinutes = widget.initialFlexibilityMinutes.clamp(15, 60);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int effectiveFlex = _mode == TimeWindowMode.flexible
        ? _flexibilityMinutes
        : 0;
    final DateTime effectiveStart = _start.subtract(
      Duration(minutes: effectiveFlex),
    );
    final DateTime effectiveEnd = _end.add(Duration(minutes: effectiveFlex));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.64,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          key: const Key('time-window-editor'),
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              const _SheetDragHandle(),
              _SheetHeader(
                title: 'Exact time',
                actionLabel: 'Reset',
                leading: IconButton(
                  tooltip: 'Back to filters',
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                onAction: _reset,
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: <Widget>[
                    const _FilterTitle('Mode'),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        _FilterPill(
                          label: 'Exact',
                          selected: _mode == TimeWindowMode.exact,
                          onTap: () =>
                              setState(() => _mode = TimeWindowMode.exact),
                        ),
                        _FilterPill(
                          label: 'Flexible',
                          selected: _mode == TimeWindowMode.flexible,
                          onTap: () =>
                              setState(() => _mode = TimeWindowMode.flexible),
                        ),
                      ],
                    ),
                    const _FilterSectionDivider(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _formatLocalDate(_start),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDate,
                          child: const Text('Change date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CompactTimeInput(
                            label: 'Start',
                            value: _formatClock(_start),
                            onTap: () => _pickTime(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactTimeInput(
                            label: 'End',
                            value: _formatClock(_end),
                            onTap: () => _pickTime(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    if (_mode == TimeWindowMode.flexible) ...<Widget>[
                      const _FilterSectionDivider(),
                      const _FilterTitle('Buffer on each side'),
                      const SizedBox(height: 8),
                      _FilterPillWrap(
                        children: <Widget>[
                          for (final int minutes in <int>[15, 30, 45, 60])
                            _FilterPill(
                              label: '$minutes min',
                              selected: _flexibilityMinutes == minutes,
                              onTap: () =>
                                  setState(() => _flexibilityMinutes = minutes),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.schedule_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Effective window',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatClock(effectiveStart)}–'
                            '${_formatClock(effectiveEnd)}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            effectiveFlex == 0
                                ? 'Used as entered for time matching.'
                                : 'Used for matching instead of '
                                      '${_formatClock(_start)}–${_formatClock(_end)}.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('time-window-done'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _submit,
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
      _end = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _end.hour,
        _end.minute,
      );
      if (!_end.isAfter(_start)) _end = _end.add(const Duration(days: 1));
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final DateTime initial = isStart ? _start : _end;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final DateTime value = DateTime(
        initial.year,
        initial.month,
        initial.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        _start = value;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = value.isAfter(_start)
            ? value
            : value.add(const Duration(days: 1));
      }
    });
  }

  void _reset() => setState(() {
    _mode = TimeWindowMode.exact;
    _start = DateTime.now().add(const Duration(minutes: 30));
    _end = DateTime.now().add(const Duration(hours: 2));
    _flexibilityMinutes = 30;
  });

  void _submit() {
    Navigator.of(context).pop(
      _TimeWindowDraft(
        mode: _mode,
        start: _start,
        end: _end,
        flexibilityMinutes: _mode == TimeWindowMode.flexible
            ? _flexibilityMinutes
            : 0,
      ),
    );
  }
}

class _CompactTimeInput extends StatelessWidget {
  const _CompactTimeInput({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: Align(
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            value,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchFilterSelection {
  const _SearchFilterSelection({
    required this.peopleCount,
    required this.budgetMax,
    required this.dateWindow,
    required this.radiusMeters,
    required this.unlimitedRadius,
    required this.openNow,
    required this.onlyAvailable,
    required this.durationMinutes,
    required this.mood,
    required this.timeWindowMode,
    required this.startLocal,
    required this.endLocal,
    required this.flexibilityMinutes,
    required this.originType,
    required this.transportMode,
    required this.includeReturnTrip,
  });
  final int? peopleCount;
  final double? budgetMax;
  final _DateWindow? dateWindow;
  final double radiusMeters;
  final bool unlimitedRadius;
  final bool openNow;
  final bool onlyAvailable;
  final int? durationMinutes;
  final String? mood;
  final TimeWindowMode? timeWindowMode;
  final DateTime startLocal;
  final DateTime endLocal;
  final int flexibilityMinutes;
  final TravelOriginType originType;
  final TransportMode transportMode;
  final bool includeReturnTrip;
}

class _DateWindow {
  const _DateWindow(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

String _formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _formatLocalDate(DateTime value) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime now = DateTime.now();
  final bool today =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  return '${today ? 'Today, ' : ''}${months[value.month - 1]} ${value.day}';
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
      'openNow': query.openNow ? '1' : '0',
      'onlyAvailable': query.onlyAvailable ? '1' : '0',
      if (query.availableDurationMinutes != null)
        'duration': '${query.availableDurationMinutes}',
      if (query.mood != null) 'mood': query.mood!,
      if (query.timeWindow != null) ...<String, String>{
        'timeMode': query.timeWindow!.mode.name,
        'timeStart': query.timeWindow!.startAtUtc.toIso8601String(),
        'timeEnd': query.timeWindow!.endAtUtc.toIso8601String(),
        'timezone': query.timeWindow!.timezoneId,
        'flexibility': '${query.timeWindow!.flexibilityMinutes}',
        'resolvedAt': query.timeWindow!.resolvedAtUtc.toIso8601String(),
      },
      if (query.travelContext != null) ...<String, String>{
        'originType': query.travelContext!.originType.name,
        'originLat': '${query.travelContext!.origin.latitude}',
        'originLng': '${query.travelContext!.origin.longitude}',
        'transport': query.travelContext!.transportMode.name,
        'returnTrip': query.travelContext!.includeReturnTrip ? '1' : '0',
      },
    },
  ).toString();
}
