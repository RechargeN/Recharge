import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../shared/primitives/money/money.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/time_window.dart';
import '../../domain/usecases/build_time_window_usecase.dart';
import '../discover_formats.dart';

abstract final class _SearchLandingStyle {
  static const Color ink = Color(0xFF10231F);
  static const Color mutedInk = Color(0xFF687771);
  static const Color accent = Color(0xFF0B4A3C);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color softSurface = Color(0xFFF5F8F5);
  static const Color chipSurface = Color(0xFFEDF4EF);
  static const Color line = Color(0xFFE1E8E3);
}

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
      backgroundColor: _SearchLandingStyle.canvas,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: _SearchLandingStyle.canvas,
        foregroundColor: _SearchLandingStyle.ink,
        centerTitle: false,
        titleSpacing: 16,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.discoverSearchRecharge,
          style: TextStyle(
            color: _SearchLandingStyle.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        key: const Key('search-landing-body'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: <Widget>[
          SizedBox(
            height: 42,
            child: TextField(
              key: const Key('regular-search-field'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _openResults(controller),
              style: const TextStyle(
                color: _SearchLandingStyle.ink,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.discoverSearchHint,
                hintStyle: const TextStyle(
                  color: _SearchLandingStyle.mutedInk,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _SearchLandingStyle.mutedInk,
                  size: 18,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: IconButton(
                  key: const Key('regular-search-filters'),
                  tooltip: context.l10n.discoverSearchFilters,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openFilters(controller, query),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: _SearchLandingStyle.mutedInk,
                    size: 18,
                  ),
                ),
                filled: true,
                fillColor: _SearchLandingStyle.canvas,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: _SearchLandingStyle.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: _SearchLandingStyle.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: _SearchLandingStyle.accent,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SearchConditionChips(
            query: query,
            onDate: () => _openDatePicker(controller, query),
            onPeople: () => _openPeoplePicker(controller, query),
            onBudget: () => _openBudgetPicker(controller, query),
            onRadius: () => _openRadiusPicker(controller, query),
          ),
          const SizedBox(height: 12),
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
            onLowBudget: () => controller.stageSearchConditions(
              budgetMax: Money(
                minorUnits: 1000,
                currencyCode: controller.marketCurrencyCode,
              ),
            ),
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
          const SizedBox(height: 16),
          _SectionHeader(
            title: context.l10n.discoverRecentSearches,
            action: recent.length > 3 ? context.l10n.discoverSeeAll : null,
            onAction: recent.length > 3
                ? () => _showAllRecent(controller, recent)
                : null,
          ),
          const SizedBox(height: 6),
          _RecentSearches(
            searches: recent.take(3).toList(growable: false),
            onOpen: (SavedSearchEntity search) =>
                context.go(_resultsLocation(search.query, source: 'recent')),
            onDelete: (SavedSearchEntity search) =>
                controller.deleteSavedSearch(search.id),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: context.l10n.discoverQuickPlans,
            action: null,
            onAction: null,
          ),
          const SizedBox(height: 6),
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

  Future<void> _openDatePicker(
    DiscoverFeedController controller,
    DiscoverQuery query,
  ) async {
    final _QuickDateSelection? selection =
        await showModalBottomSheet<_QuickDateSelection>(
          context: context,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) => _QuickDateSheet(query: query),
        );
    if (selection == null) return;
    controller.stageSearchConditions(
      dateFrom: selection.window?.from,
      clearDateFrom: selection.window == null,
      dateTo: selection.window?.to,
      clearDateTo: selection.window == null,
      clearTimeWindow: true,
      clearTravelContext: true,
    );
  }

  Future<void> _openPeoplePicker(
    DiscoverFeedController controller,
    DiscoverQuery query,
  ) async {
    final _QuickPeopleSelection? selection =
        await showModalBottomSheet<_QuickPeopleSelection>(
          context: context,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) =>
              _QuickPeopleSheet(selected: query.peopleCount),
        );
    if (selection == null) return;
    controller.stageSearchConditions(
      peopleCount: selection.peopleCount,
      clearPeopleCount: selection.peopleCount == null,
    );
  }

  Future<void> _openBudgetPicker(
    DiscoverFeedController controller,
    DiscoverQuery query,
  ) async {
    final _QuickBudgetSelection? selection =
        await showModalBottomSheet<_QuickBudgetSelection>(
          context: context,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) =>
              _QuickBudgetSheet(selected: query.budgetMax?.round()),
        );
    if (selection == null) return;
    controller.stageSearchConditions(
      budgetMax: selection.budgetMax == null
          ? null
          : Money(
              minorUnits: selection.budgetMax! * 100,
              currencyCode: controller.marketCurrencyCode,
            ),
      clearBudgetMax: selection.budgetMax == null,
    );
  }

  Future<void> _openRadiusPicker(
    DiscoverFeedController controller,
    DiscoverQuery query,
  ) async {
    final _QuickRadiusSelection? selection =
        await showModalBottomSheet<_QuickRadiusSelection>(
          context: context,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) => _QuickRadiusSheet(query: query),
        );
    if (selection == null) return;
    controller.stageSearchConditions(
      radiusMeters: selection.radiusMeters,
      unlimitedRadius: selection.unlimited,
    );
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
      budgetMax: selection.budgetMax == null
          ? null
          : Money(
              minorUnits: selection.budgetMax! * 100,
              currencyCode: controller.marketCurrencyCode,
            ),
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
      final TimeWindowIssue? error = controller.stageTimeWindowSelection(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoverTimeWindowIssue(error.name)),
          ),
        );
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
              context.l10n.discoverRecentSearches,
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
  const _SearchConditionChips({
    required this.query,
    required this.onDate,
    required this.onPeople,
    required this.onBudget,
    required this.onRadius,
  });

  final DiscoverQuery query;
  final VoidCallback onDate;
  final VoidCallback onPeople;
  final VoidCallback onBudget;
  final VoidCallback onRadius;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      if (query.timeWindow != null)
        _SearchConditionChip(
          icon: Icons.schedule_outlined,
          label: query.timeWindow!.mode == TimeWindowMode.flexible
              ? context.l10n.discoverFlexibleWindow(
                  query.timeWindow!.flexibilityMinutes,
                )
              : query.timeWindow!.mode == TimeWindowMode.anytimeToday
              ? context.l10n.discoverUntilEndOfDay
              : context.l10n.discoverExactTime,
        ),
      _SearchConditionChip(
        key: const Key('search-date-chip'),
        icon: Icons.calendar_today_outlined,
        label: _dateLabel(context.l10n, query),
        onTap: onDate,
      ),
      _SearchConditionChip(
        key: const Key('search-people-chip'),
        icon: Icons.group_outlined,
        label: query.peopleCount == null
            ? context.l10n.discoverAnyGroup
            : context.l10n.discoverPeopleCount(query.peopleCount!),
        onTap: onPeople,
      ),
      _SearchConditionChip(
        key: const Key('search-budget-chip'),
        icon: Icons.payments_outlined,
        label: query.budgetMax == null
            ? context.l10n.discoverAnyBudget
            : query.budgetMax!.minorUnits == 0
            ? context.l10n.discoverFree
            : RechargeFormats.money(query.budgetMax!, context.l10n.localeName),
        onTap: onBudget,
      ),
      _SearchConditionChip(
        key: const Key('search-radius-chip'),
        icon: Icons.location_on_outlined,
        label: query.unlimitedRadius
            ? context.l10n.discoverAnyArea
            : context.l10n.discoverDistanceKm(
                '${(query.radiusMeters / 1000).round()}',
              ),
        onTap: onRadius,
      ),
      if (query.availableDurationMinutes != null)
        _SearchConditionChip(
          icon: Icons.schedule_outlined,
          label: context.l10n.discoverMinutes(query.availableDurationMinutes!),
        ),
      if (query.mood != null)
        _SearchConditionChip(
          icon: Icons.nightlight_outlined,
          label: context.l10n.discoverMood(query.mood!),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 6, children: chips),
    );
  }
}

class _SearchConditionChip extends StatelessWidget {
  const _SearchConditionChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _SearchLandingStyle.chipSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 14, color: _SearchLandingStyle.accent),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: _SearchLandingStyle.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _QuickDateSelection {
  const _QuickDateSelection(this.window);

  final _DateWindow? window;
}

class _QuickPeopleSelection {
  const _QuickPeopleSelection(this.peopleCount);

  final int? peopleCount;
}

class _QuickBudgetSelection {
  const _QuickBudgetSelection(this.budgetMax);

  final int? budgetMax;
}

class _QuickRadiusSelection {
  const _QuickRadiusSelection({
    required this.radiusMeters,
    required this.unlimited,
  });

  final double radiusMeters;
  final bool unlimited;
}

class _QuickDateSheet extends StatelessWidget {
  const _QuickDateSheet({required this.query});

  final DiscoverQuery query;

  @override
  Widget build(BuildContext context) {
    final _DateWindow today = _todayWindow();
    final _DateWindow tomorrow = _tomorrowWindow();
    final _DateWindow weekend = _weekendWindow();
    return _QuickPickerSurface(
      key: const Key('search-date-sheet'),
      title: context.l10n.discoverChooseDate,
      onReset: () => Navigator.of(context).pop(const _QuickDateSelection(null)),
      child: _FilterPillWrap(
        children: <Widget>[
          _FilterPill(
            label: context.l10n.discoverAnyDate,
            selected: query.dateFrom == null && query.dateTo == null,
            onTap: () =>
                Navigator.of(context).pop(const _QuickDateSelection(null)),
          ),
          _FilterPill(
            key: const Key('quick-date-today'),
            label: context.l10n.discoverToday,
            selected: _sameLocalDay(query.dateFrom, today.from),
            onTap: () => Navigator.of(context).pop(_QuickDateSelection(today)),
          ),
          _FilterPill(
            key: const Key('quick-date-tomorrow'),
            label: context.l10n.discoverTomorrow,
            selected: _sameLocalDay(query.dateFrom, tomorrow.from),
            onTap: () =>
                Navigator.of(context).pop(_QuickDateSelection(tomorrow)),
          ),
          _FilterPill(
            key: const Key('quick-date-weekend'),
            label: context.l10n.discoverThisWeekend,
            selected:
                _sameLocalDay(query.dateFrom, weekend.from) &&
                _sameLocalDay(query.dateTo, weekend.to),
            onTap: () =>
                Navigator.of(context).pop(_QuickDateSelection(weekend)),
          ),
          _FilterPill(
            key: const Key('quick-date-custom'),
            label: context.l10n.discoverChooseDates,
            selected: false,
            onTap: () => _pickCustomRange(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year, now.month, now.day);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
      helpText: context.l10n.discoverChooseSearchDates,
    );
    if (picked == null || !context.mounted) return;
    final DateTime from = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    );
    final DateTime to = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
    );
    Navigator.of(context).pop(_QuickDateSelection(_DateWindow(from, to)));
  }
}

class _QuickPeopleSheet extends StatelessWidget {
  const _QuickPeopleSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) => _QuickPickerSurface(
    key: const Key('search-people-sheet'),
    title: context.l10n.discoverGroupSize,
    onReset: () => Navigator.of(context).pop(const _QuickPeopleSelection(null)),
    child: _FilterPillWrap(
      children: <Widget>[
        for (final int? value in <int?>[null, 1, 2, 3, 4, 5])
          _FilterPill(
            key: value == null ? null : Key('quick-people-$value'),
            label: value == null
                ? context.l10n.discoverAnyGroup
                : value == 1
                ? context.l10n.discoverJustMe
                : value == 5
                ? '5+'
                : context.l10n.discoverPeopleCount(value),
            selected: selected == value,
            onTap: () =>
                Navigator.of(context).pop(_QuickPeopleSelection(value)),
          ),
        _FilterPill(
          key: const Key('quick-people-custom'),
          label: selected != null && selected! > 5
              ? context.l10n.discoverCustomValue('$selected')
              : context.l10n.discoverCustom,
          selected: selected != null && selected! > 5,
          onTap: () => _editCustom(context),
        ),
      ],
    ),
  );

  Future<void> _editCustom(BuildContext context) async {
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _NumberInputDialog<int>(
        title: context.l10n.discoverNumberOfPeople,
        hint: context.l10n.discoverExampleEight,
        initialValue: selected != null && selected! > 5 ? '$selected' : '',
        parser: (String value) => int.tryParse(value),
        isValid: (int value) => value >= 1 && value <= 99,
        errorMessage: context.l10n.discoverEnterPeople,
      ),
    );
    if (result == null || !context.mounted) return;
    Navigator.of(context).pop(_QuickPeopleSelection(result));
  }
}

class _QuickBudgetSheet extends StatelessWidget {
  const _QuickBudgetSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) => _QuickPickerSurface(
    key: const Key('search-budget-sheet'),
    title: context.l10n.discoverBudgetPerPerson,
    onReset: () => Navigator.of(context).pop(const _QuickBudgetSelection(null)),
    child: _FilterPillWrap(
      children: <Widget>[
        for (final int? value in <int?>[null, 0, 10, 20, 50])
          _FilterPill(
            key: value == null ? null : Key('quick-budget-$value'),
            label: value == null
                ? context.l10n.discoverAnyBudget
                : value == 0
                ? context.l10n.discoverFree
                : context.l10n.discoverUpToBudget(_euros(context, value)),
            selected: selected == value,
            onTap: () =>
                Navigator.of(context).pop(_QuickBudgetSelection(value)),
          ),
        _FilterPill(
          key: const Key('quick-budget-custom'),
          label: _isCustom
              ? context.l10n.discoverCustomValue(_euros(context, selected!))
              : context.l10n.discoverCustom,
          selected: _isCustom,
          onTap: () => _editCustom(context),
        ),
      ],
    ),
  );

  bool get _isCustom =>
      selected != null && !<int>[0, 10, 20, 50].contains(selected);

  Future<void> _editCustom(BuildContext context) async {
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _NumberInputDialog<int>(
        title: context.l10n.discoverBudgetPerPerson,
        hint: context.l10n.discoverAmountInEur,
        initialValue: _isCustom ? '$selected' : '',
        parser: (String value) => int.tryParse(value),
        isValid: (int value) => value >= 0 && value <= 10000,
        errorMessage: context.l10n.discoverEnterBudget,
      ),
    );
    if (result == null || !context.mounted) return;
    Navigator.of(context).pop(_QuickBudgetSelection(result));
  }
}

class _QuickRadiusSheet extends StatefulWidget {
  const _QuickRadiusSheet({required this.query});

  final DiscoverQuery query;

  @override
  State<_QuickRadiusSheet> createState() => _QuickRadiusSheetState();
}

class _QuickRadiusSheetState extends State<_QuickRadiusSheet> {
  late double _radiusKm = (widget.query.radiusMeters / 1000).clamp(1, 50);
  late bool _unlimited = widget.query.unlimitedRadius;

  @override
  Widget build(BuildContext context) => _QuickPickerSurface(
    key: const Key('search-radius-sheet'),
    title: context.l10n.discoverSearchRadius,
    onReset: () => Navigator.of(
      context,
    ).pop(const _QuickRadiusSelection(radiusMeters: 5000, unlimited: false)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FilterPillWrap(
          children: <Widget>[
            for (final int value in <int>[1, 3, 5, 10, 20, 50])
              _FilterPill(
                key: Key('quick-radius-$value'),
                label: context.l10n.discoverDistanceKm('$value'),
                selected: !_unlimited && _radiusKm.round() == value,
                onTap: () => setState(() {
                  _radiusKm = value.toDouble();
                  _unlimited = false;
                }),
              ),
            _FilterPill(
              key: const Key('quick-radius-any'),
              label: context.l10n.discoverAnyDistance,
              selected: _unlimited,
              onTap: () => setState(() => _unlimited = true),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Text(context.l10n.discoverCustomRadius),
            const Spacer(),
            Text(
              _unlimited
                  ? context.l10n.discoverAnyDistance
                  : context.l10n.discoverDistanceKm('${_radiusKm.round()}'),
            ),
          ],
        ),
        Slider(
          key: const Key('quick-radius-slider'),
          min: 1,
          max: 50,
          divisions: 49,
          value: _radiusKm,
          onChanged: (double value) => setState(() {
            _radiusKm = value;
            _unlimited = false;
          }),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('quick-radius-apply'),
          onPressed: () => Navigator.of(context).pop(
            _QuickRadiusSelection(
              radiusMeters: _radiusKm * 1000,
              unlimited: _unlimited,
            ),
          ),
          child: Text(context.l10n.discoverApplyRadius),
        ),
      ],
    ),
  );
}

class _QuickPickerSurface extends StatelessWidget {
  const _QuickPickerSurface({
    super.key,
    required this.title,
    required this.onReset,
    required this.child,
  });

  final String title;
  final VoidCallback onReset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _SheetDragHandle(),
              _SheetHeader(
                title: title,
                actionLabel: context.l10n.discoverReset,
                onAction: onReset,
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
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
      _QuickActionData(
        Icons.navigation_outlined,
        context.l10n.discoverNearMeNow,
        onNearNow,
      ),
      _QuickActionData(
        Icons.group_outlined,
        context.l10n.discoverForTwo,
        onForTwo,
      ),
      _QuickActionData(
        Icons.sell_outlined,
        context.l10n.discoverLowBudget,
        onLowBudget,
      ),
      _QuickActionData(
        Icons.schedule_outlined,
        context.l10n.discoverHoursLong(1),
        onOneHour,
      ),
      _QuickActionData(
        Icons.nightlight_outlined,
        context.l10n.discoverCalmEvening,
        onCalmEvening,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actions
          .map(
            (_QuickActionData action) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: action.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 3,
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _SearchLandingStyle.canvas,
                          shape: BoxShape.circle,
                          border: Border.all(color: _SearchLandingStyle.line),
                        ),
                        child: Icon(
                          action.icon,
                          size: 18,
                          color: _SearchLandingStyle.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        action.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _SearchLandingStyle.ink,
                          fontSize: 9.5,
                          height: 1.05,
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
            style: const TextStyle(
              color: _SearchLandingStyle.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _SearchLandingStyle.accent,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(action!),
          ),
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
        key: const Key('recent-searches-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: _SearchLandingStyle.softSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.discoverRegularSearchesHint,
          style: TextStyle(color: _SearchLandingStyle.mutedInk, fontSize: 12),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (int index = 0; index < searches.length; index++) ...<Widget>[
          _RecentSearchTile(
            search: searches[index],
            tone: index,
            onOpen: () => onOpen(searches[index]),
            onDelete: () => onDelete(searches[index]),
          ),
          if (index < searches.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.search,
    required this.tone,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedSearchEntity search;
  final int tone;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // The stored subtitle is legacy English; the reader sees the conditions
    // of the saved query in their own language.
    final List<String> details = discoverQueryConditionTexts(
      context.l10n,
      search.query,
    ).take(3).toList(growable: false);
    final Color iconSurface = switch (tone % 3) {
      1 => const Color(0xFFF0E8FF),
      2 => const Color(0xFFE8F5E9),
      _ => const Color(0xFFE5F2E8),
    };
    final Color iconColor = switch (tone % 3) {
      1 => const Color(0xFF7250A6),
      2 => const Color(0xFF4E7D4B),
      _ => _SearchLandingStyle.accent,
    };

    return Material(
      color: _SearchLandingStyle.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _SearchLandingStyle.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(_recentIcon(search), size: 18, color: iconColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      search.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _SearchLandingStyle.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (details.isEmpty)
                      Text(
                        search.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _SearchLandingStyle.mutedInk,
                          fontSize: 9.5,
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (
                              int index = 0;
                              index < details.length;
                              index++
                            ) ...<Widget>[
                              _RecentDetailPill(label: details[index]),
                              if (index < details.length - 1)
                                const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: _SearchLandingStyle.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDetailPill extends StatelessWidget {
  const _RecentDetailPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _SearchLandingStyle.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _SearchLandingStyle.mutedInk,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickPlanRail extends StatelessWidget {
  const _QuickPlanRail({required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    List<_QuickPlanData> plans = <_QuickPlanData>[
      _QuickPlanData(
        context.l10n.discoverAfterWork,
        context.l10n.discoverAboutOneHour,
        Icons.local_cafe_outlined,
        0,
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085'
            '?auto=format&fit=crop&w=600&q=80',
        'calm',
        60,
        'food_drinks.coffee,wellness_recharge.calm_walk',
      ),
      _QuickPlanData(
        context.l10n.discoverSunsetBreak,
        context.l10n.discoverHoursRange(1, 2),
        Icons.wb_twilight_outlined,
        1,
        'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429'
            '?auto=format&fit=crop&w=600&q=80',
        'calm',
        120,
        'wellness_recharge.calm_walk,art_culture_museums.museum',
      ),
      _QuickPlanData(
        context.l10n.discoverActiveMorning,
        context.l10n.discoverHoursRange(2, 3),
        Icons.directions_run_outlined,
        2,
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
            '?auto=format&fit=crop&w=600&q=80',
        'active',
        150,
        'outdoor_nature_walking.city_walk,sport.tennis',
      ),
      _QuickPlanData(
        context.l10n.discoverSocialEvening,
        context.l10n.discoverHoursRange(2, 3),
        Icons.celebration_outlined,
        3,
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a'
            '?auto=format&fit=crop&w=600&q=80',
        'social',
        180,
        'games_indoor.board_games,music_nightlife.afterwork_drinks',
      ),
    ];
    return SizedBox(
      key: const Key('quick-plan-rail'),
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final _QuickPlanData plan = plans[index];
          final Color planColor = _quickPlanColor(
            Theme.of(context).colorScheme,
            plan.tone,
          );
          return SizedBox(
            width: 112,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpen(plan.location),
              child: Material(
                color: _SearchLandingStyle.canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: _SearchLandingStyle.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: 76,
                      child: _QuickPlanImage(plan: plan, fallback: planColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _SearchLandingStyle.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            plan.duration,
                            style: const TextStyle(
                              color: _SearchLandingStyle.mutedInk,
                              fontSize: 9,
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
    this.imageUrl,
    this.mood,
    this.minutes,
    this.steps,
  );
  final String title;
  final String duration;
  final IconData icon;
  final int tone;
  final String imageUrl;
  final String mood;
  final int minutes;
  final String steps;

  String get location => Uri(
    path: RouteNames.quickPlanFor('quick-template-$mood-$minutes'),
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

class _QuickPlanImage extends StatelessWidget {
  const _QuickPlanImage({required this.plan, required this.fallback});

  final _QuickPlanData plan;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[fallback.withValues(alpha: 0.58), fallback],
        ),
      ),
      child: Center(child: Icon(plan.icon, color: Colors.white, size: 28)),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          plan.imageUrl,
          fit: BoxFit.cover,
          frameBuilder:
              (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return placeholder;
              },
          errorBuilder: (_, __, ___) => placeholder,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Color(0x33000000)],
            ),
          ),
        ),
      ],
    );
  }
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
  late int? _budgetMax = widget.query.budgetMax?.round();
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
                title: context.l10n.discoverSearchFilters,
                actionLabel: context.l10n.discoverReset,
                onAction: _reset,
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: <Widget>[
                    _FilterTitle(context.l10n.discoverWhen),
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
                    _FilterTitle(context.l10n.discoverTimeAvailable),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final int? value in <int?>[null, 60, 120, 180])
                          _FilterPill(
                            label: value == null
                                ? context.l10n.discoverAny
                                : context.l10n.discoverHoursLong(value ~/ 60),
                            selected: _duration == value,
                            onTap: () => setState(() => _duration = value),
                          ),
                      ],
                    ),
                    const _FilterSectionDivider(),
                    _TimeFilterBlock(
                      mode: _timeWindowMode,
                      start: _startLocal,
                      end: _endLocal,
                      flexibilityMinutes: _flexibilityMinutes,
                      onModeChanged: (TimeWindowMode? value) =>
                          setState(() => _timeWindowMode = value),
                      onStartTap: () => _pickFilterTime(isStart: true),
                      onEndTap: () => _pickFilterTime(isStart: false),
                      onFlexibilityChanged: (int value) =>
                          setState(() => _flexibilityMinutes = value),
                    ),
                    const _FilterSectionDivider(),
                    _TravelFilterBlock(
                      originType: _originType,
                      transportMode: _transportMode,
                      includeReturnTrip: _includeReturnTrip,
                      onOriginChanged: (TravelOriginType value) =>
                          setState(() => _originType = value),
                      onTransportChanged: (TransportMode value) =>
                          setState(() => _transportMode = value),
                      onReturnTripChanged: (bool value) =>
                          setState(() => _includeReturnTrip = value),
                    ),
                    const _FilterSectionDivider(),
                    _FilterTitle(context.l10n.discoverAvailability),
                    const SizedBox(height: 2),
                    _CompactSwitchRow(
                      label: context.l10n.discoverOpenNow,
                      value: _openNow,
                      onChanged: (bool value) =>
                          setState(() => _openNow = value),
                    ),
                    _CompactSwitchRow(
                      label: context.l10n.discoverOnlyAvailable,
                      value: _onlyAvailable,
                      onChanged: (bool value) =>
                          setState(() => _onlyAvailable = value),
                    ),
                    const _FilterSectionDivider(),
                    _FilterTitle(context.l10n.discoverPeople),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final int? value in <int?>[null, 1, 2, 4])
                          _FilterPill(
                            label: value == null
                                ? context.l10n.discoverAny
                                : '$value',
                            selected: _peopleCount == value,
                            onTap: () => setState(() => _peopleCount = value),
                          ),
                        _FilterPill(
                          key: const Key('people-custom'),
                          label: _isCustomPeople
                              ? context.l10n.discoverCustomValue(
                                  '$_peopleCount',
                                )
                              : context.l10n.discoverCustom,
                          selected: _isCustomPeople,
                          onTap: _editPeopleCount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FilterTitle(context.l10n.discoverBudgetPerPerson),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final int? value in <int?>[null, 0, 10, 20, 40])
                          _FilterPill(
                            label: value == null
                                ? context.l10n.discoverAny
                                : _euros(context, value),
                            selected: _budgetMax == value,
                            onTap: () => setState(() => _budgetMax = value),
                          ),
                        _FilterPill(
                          key: const Key('budget-custom'),
                          label: _isCustomBudget
                              ? context.l10n.discoverCustomValue(
                                  _euros(context, _budgetMax!),
                                )
                              : context.l10n.discoverCustom,
                          selected: _isCustomBudget,
                          onTap: _editBudget,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FilterTitle(context.l10n.discoverMoodTitle),
                    const SizedBox(height: 8),
                    _FilterPillWrap(
                      children: <Widget>[
                        for (final (String?, String) option
                            in <(String?, String)>[
                              (null, context.l10n.discoverAny),
                              ('calm', context.l10n.discoverMood('calm')),
                              ('social', context.l10n.discoverMood('social')),
                              ('active', context.l10n.discoverMood('active')),
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
                        _FilterTitle(context.l10n.discoverDistance),
                        const Spacer(),
                        Text(
                          _unlimited
                              ? context.l10n.discoverAnyArea
                              : context.l10n.discoverDistanceKm(
                                  '${(_radiusMeters / 1000).round()}',
                                ),
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
                      label: context.l10n.discoverAnyDistance,
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
      'today' => context.l10n.discoverToday,
      'tonight' => context.l10n.discoverTonight,
      _ => context.l10n.discoverAnyDate,
    };
    final String duration = _duration == null
        ? context.l10n.discoverAnyDuration
        : _duration == 60
        ? '1 hour'
        : '${_duration! ~/ 60} hours';
    final String radius = _unlimited
        ? context.l10n.discoverAnyArea
        : '${(_radiusMeters / 1000).round()} km';
    return <String>[
      date,
      duration,
      if (_timeWindowMode != null) _transportMode.name,
      radius,
    ].join(' · ');
  }

  bool get _isCustomPeople =>
      _peopleCount != null && !<int>[1, 2, 4].contains(_peopleCount);

  bool get _isCustomBudget =>
      _budgetMax != null && !<int>[0, 10, 20, 40].contains(_budgetMax);

  Future<void> _pickFilterTime({required bool isStart}) async {
    final DateTime initial = isStart ? _startLocal : _endLocal;
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
        _startLocal = value;
        if (!_endLocal.isAfter(_startLocal)) {
          _endLocal = _startLocal.add(const Duration(hours: 1));
        }
      } else {
        _endLocal = value.isAfter(_startLocal)
            ? value
            : value.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _editPeopleCount() async {
    final int? result = await _showNumberDialog<int>(
      title: context.l10n.discoverNumberOfPeople,
      hint: context.l10n.discoverExampleSix,
      initialValue: _isCustomPeople ? '$_peopleCount' : '',
      parser: (String value) => int.tryParse(value),
      isValid: (int value) => value >= 1 && value <= 99,
      errorMessage: context.l10n.discoverEnterPeople,
    );
    if (result != null && mounted) setState(() => _peopleCount = result);
  }

  Future<void> _editBudget() async {
    final int? result = await _showNumberDialog<int>(
      title: context.l10n.discoverBudgetPerPerson,
      hint: context.l10n.discoverAmountInEur,
      initialValue: _isCustomBudget ? '$_budgetMax' : '',
      parser: (String value) => int.tryParse(value),
      isValid: (int value) => value >= 0 && value <= 10000,
      errorMessage: context.l10n.discoverEnterBudget,
    );
    if (result != null && mounted) setState(() => _budgetMax = result);
  }

  Future<T?> _showNumberDialog<T extends num>({
    required String title,
    required String hint,
    required String initialValue,
    required T? Function(String value) parser,
    required bool Function(T value) isValid,
    required String errorMessage,
  }) => showDialog<T>(
    context: context,
    builder: (BuildContext context) => _NumberInputDialog<T>(
      title: title,
      hint: hint,
      initialValue: initialValue,
      parser: parser,
      isValid: isValid,
      errorMessage: errorMessage,
    ),
  );

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

class _NumberInputDialog<T extends num> extends StatefulWidget {
  const _NumberInputDialog({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.parser,
    required this.isValid,
    required this.errorMessage,
  });

  final String title;
  final String hint;
  final String initialValue;
  final T? Function(String value) parser;
  final bool Function(T value) isValid;
  final String errorMessage;

  @override
  State<_NumberInputDialog<T>> createState() => _NumberInputDialogState<T>();
}

class _NumberInputDialogState<T extends num>
    extends State<_NumberInputDialog<T>> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('custom-number-input'),
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: _error,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.discoverCancel),
      ),
      FilledButton(
        key: const Key('custom-number-save'),
        onPressed: _submit,
        child: Text(context.l10n.discoverSave),
      ),
    ],
  );

  void _submit() {
    final T? value = widget.parser(_controller.text.trim());
    if (value == null || !widget.isValid(value)) {
      setState(() => _error = widget.errorMessage);
      return;
    }
    Navigator.of(context).pop(value);
  }
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
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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

class _TimeFilterBlock extends StatelessWidget {
  const _TimeFilterBlock({
    required this.mode,
    required this.start,
    required this.end,
    required this.flexibilityMinutes,
    required this.onModeChanged,
    required this.onStartTap,
    required this.onEndTap,
    required this.onFlexibilityChanged,
  });

  final TimeWindowMode? mode;
  final DateTime start;
  final DateTime end;
  final int flexibilityMinutes;
  final ValueChanged<TimeWindowMode?> onModeChanged;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final ValueChanged<int> onFlexibilityChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool showsWindow =
        mode == TimeWindowMode.exact || mode == TimeWindowMode.flexible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ReferenceBlockTitle(
          icon: Icons.schedule_outlined,
          label: context.l10n.discoverWhen,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _ReferencePill(
              label: context.l10n.discoverExact,
              selected: mode == TimeWindowMode.exact,
              onTap: () => onModeChanged(
                mode == TimeWindowMode.exact ? null : TimeWindowMode.exact,
              ),
            ),
            _ReferencePill(
              label: context.l10n.discoverFlexibleTime,
              selected: mode == TimeWindowMode.flexible,
              onTap: () => onModeChanged(
                mode == TimeWindowMode.flexible
                    ? null
                    : TimeWindowMode.flexible,
              ),
            ),
            _ReferencePill(
              label: context.l10n.discoverToday,
              selected: mode == TimeWindowMode.anytimeToday,
              onTap: () => onModeChanged(
                mode == TimeWindowMode.anytimeToday
                    ? null
                    : TimeWindowMode.anytimeToday,
              ),
            ),
          ],
        ),
        if (showsWindow) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _InlineTimeField(
                  key: const Key('filter-start-time'),
                  value: _formatClock(start),
                  onTap: onStartTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Text(
                  '–',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _InlineTimeField(
                  key: const Key('filter-end-time'),
                  value: _formatClock(end),
                  onTap: onEndTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.discoverWindowEdgeBuffer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (mode == TimeWindowMode.flexible)
                PopupMenuButton<int>(
                  tooltip: context.l10n.discoverChangeFlexibility,
                  initialValue: flexibilityMinutes,
                  onSelected: onFlexibilityChanged,
                  itemBuilder: (BuildContext context) => <int>[15, 30, 45, 60]
                      .map(
                        (int value) => PopupMenuItem<int>(
                          value: value,
                          child: Text(
                            context.l10n.discoverFlexibilityMinutes(value),
                          ),
                        ),
                      )
                      .toList(),
                  child: Text(
                    context.l10n.discoverFlexibilityMinutes(flexibilityMinutes),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  context.l10n.discoverNoBuffer,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TravelFilterBlock extends StatelessWidget {
  const _TravelFilterBlock({
    required this.originType,
    required this.transportMode,
    required this.includeReturnTrip,
    required this.onOriginChanged,
    required this.onTransportChanged,
    required this.onReturnTripChanged,
  });

  final TravelOriginType originType;
  final TransportMode transportMode;
  final bool includeReturnTrip;
  final ValueChanged<TravelOriginType> onOriginChanged;
  final ValueChanged<TransportMode> onTransportChanged;
  final ValueChanged<bool> onReturnTripChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _ReferenceBlockTitle(
        icon: Icons.location_on_outlined,
        label: context.l10n.discoverTravel,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _ReferencePill(
            icon: Icons.my_location_rounded,
            label: "I'm here",
            selected: originType == TravelOriginType.currentLocation,
            onTap: () => onOriginChanged(TravelOriginType.currentLocation),
          ),
          _ReferencePill(
            icon: Icons.location_on_outlined,
            label: context.l10n.discoverMapPoint,
            selected: originType == TravelOriginType.manualPin,
            onTap: () => onOriginChanged(TravelOriginType.manualPin),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          _TransportButton(
            tooltip: context.l10n.discoverWalking,
            icon: Icons.directions_walk_rounded,
            selected: transportMode == TransportMode.walking,
            onTap: () => onTransportChanged(TransportMode.walking),
          ),
          const SizedBox(width: 10),
          _TransportButton(
            tooltip: context.l10n.discoverDriving,
            icon: Icons.directions_car_outlined,
            selected: transportMode == TransportMode.driving,
            onTap: () => onTransportChanged(TransportMode.driving),
          ),
          const SizedBox(width: 10),
          _TransportButton(
            tooltip: context.l10n.discoverTransit,
            icon: Icons.directions_transit_outlined,
            selected: transportMode == TransportMode.transit,
            onTap: () => onTransportChanged(TransportMode.transit),
          ),
        ],
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => onReturnTripChanged(!includeReturnTrip),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  key: const Key('include-return-trip'),
                  value: includeReturnTrip,
                  onChanged: (bool? value) =>
                      onReturnTripChanged(value ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_return_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.discoverIncludeReturnTrip,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ReferenceBlockTitle extends StatelessWidget {
  const _ReferenceBlockTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 7),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ReferencePill extends StatelessWidget {
  const _ReferencePill({
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
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 17, color: colors.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? colors.primary : colors.onSurface,
                    fontWeight: FontWeight.w600,
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

class _InlineTimeField extends StatelessWidget {
  const _InlineTimeField({super.key, required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.schedule_outlined, size: 19, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: selected ? colors.primaryContainer : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 46,
            height: 44,
            child: Icon(icon, size: 21, color: colors.primary),
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
                child: Text(context.l10n.discoverApplyFilters),
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
                title: context.l10n.discoverExactTime,
                actionLabel: context.l10n.discoverReset,
                leading: IconButton(
                  tooltip: context.l10n.discoverBackToFilters,
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
                          label: context.l10n.discoverExact,
                          selected: _mode == TimeWindowMode.exact,
                          onTap: () =>
                              setState(() => _mode = TimeWindowMode.exact),
                        ),
                        _FilterPill(
                          label: context.l10n.discoverFlexibleTime,
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
                            _formatLocalDate(context.l10n, _start),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDate,
                          child: Text(context.l10n.discoverChangeDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CompactTimeInput(
                            label: context.l10n.discoverStart,
                            value: _formatClock(_start),
                            onTap: () => _pickTime(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactTimeInput(
                            label: context.l10n.discoverEnd,
                            value: _formatClock(_end),
                            onTap: () => _pickTime(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    if (_mode == TimeWindowMode.flexible) ...<Widget>[
                      const _FilterSectionDivider(),
                      _FilterTitle(context.l10n.discoverBufferEachSide),
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
                                context.l10n.discoverEffectiveWindow,
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
                                ? context.l10n.discoverWindowAsEntered
                                : context.l10n.discoverUsedInsteadOf(
                                    _formatClock(_start),
                                    _formatClock(_end),
                                  ),
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
                      child: Text(context.l10n.discoverDone),
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
  final int? budgetMax;
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

/// A date the reader picked (their own moment, so the device zone).
String _formatLocalDate(AppLocalizations l10n, DateTime value) {
  final DateTime now = DateTime.now();
  final bool today =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  final String date = RechargeFormats.wallMonthDay(value, l10n.localeName);
  return today ? l10n.discoverTodayDate(date) : date;
}

_DateWindow _todayWindow() {
  final DateTime now = DateTime.now();
  return _DateWindow(now, DateTime(now.year, now.month, now.day, 23, 59, 59));
}

_DateWindow _tomorrowWindow() {
  final DateTime now = DateTime.now();
  final DateTime tomorrow = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  return _DateWindow(
    tomorrow,
    DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59),
  );
}

_DateWindow _weekendWindow() {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int daysUntilSaturday = (DateTime.saturday - today.weekday) % 7;
  final DateTime saturday = today.add(Duration(days: daysUntilSaturday));
  final DateTime sunday = saturday.add(const Duration(days: 1));
  return _DateWindow(
    saturday,
    DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
  );
}

_DateWindow _tonightWindow() {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month, now.day, 18);
  return _DateWindow(
    now.isAfter(from) ? now : from,
    DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
}

String _dateLabel(AppLocalizations l10n, DiscoverQuery query) {
  if (query.dateFrom == null && query.dateTo == null) {
    return l10n.discoverAnyDate;
  }
  final DateTime now = DateTime.now();
  final DateTime? from = query.dateFrom?.toLocal();
  final DateTime? to = query.dateTo?.toLocal();
  if (_sameLocalDay(from, now)) {
    return l10n.discoverToday;
  }
  if (_sameLocalDay(from, now.add(const Duration(days: 1)))) {
    return l10n.discoverTomorrow;
  }
  if (from == null) return l10n.discoverDateSet;
  final String fromLabel = _numericDate(from);
  if (to == null || _sameLocalDay(from, to)) return fromLabel;
  return '$fromLabel–${_numericDate(to)}';
}

bool _sameLocalDay(DateTime? first, DateTime? second) {
  if (first == null || second == null) return false;
  final DateTime firstLocal = first.toLocal();
  final DateTime secondLocal = second.toLocal();
  return firstLocal.year == secondLocal.year &&
      firstLocal.month == secondLocal.month &&
      firstLocal.day == secondLocal.day;
}

String _numericDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}';

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

/// Whole euros of the EUR-only budget pickers (their stored value is EUR).
String _euros(BuildContext context, int value) => RechargeFormats.money(
  Money(minorUnits: value * 100, currencyCode: 'EUR'),
  context.l10n.localeName,
);
