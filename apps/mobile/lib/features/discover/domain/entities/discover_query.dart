import '../../../../shared/primitives/money/money.dart';
import 'time_window.dart';

enum DiscoverSortMode { geoFreshness }

class DiscoverQuery {
  DiscoverQuery({
    required this.queryText,
    required this.selectedCategoryIds,
    required this.selectedSubcategoryIds,
    required this.dateFrom,
    required this.dateTo,
    required this.peopleCount,
    this.availableDurationMinutes,
    this.mood,
    required this.budgetMin,
    required this.budgetMax,
    required this.freeOnly,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.unlimitedRadius,
    required this.sortMode,
    required this.openNow,
    required this.onlyAvailable,
    required this.marketCityId,
    required this.manualAreaSelected,
    required this.searchAreaDirty,
    required this.sourceScreen,
    required this.queryVersion,
    required this.appliedAtUtc,
    this.timeWindow,
    this.travelContext,
  }) {
    if ((budgetMin?.minorUnits ?? 0) < 0 || (budgetMax?.minorUnits ?? 0) < 0) {
      throw ArgumentError('Budget must be nonnegative');
    }
    if (budgetMin != null &&
        budgetMax != null &&
        budgetMin!.compareTo(budgetMax!) > 0) {
      throw ArgumentError('Budget minimum exceeds maximum');
    }
    if (timeWindow != null && travelContext == null) {
      throw ArgumentError('travelContext is required with timeWindow');
    }
  }

  factory DiscoverQuery.defaults({
    String marketCityId = '',
    double centerLat = 0,
    double centerLng = 0,
    DateTime? nowUtc,
  }) => DiscoverQuery(
    queryText: '',
    selectedCategoryIds: const <String>[],
    selectedSubcategoryIds: const <String>[],
    dateFrom: null,
    dateTo: null,
    peopleCount: null,
    availableDurationMinutes: null,
    mood: null,
    budgetMin: null,
    budgetMax: null,
    freeOnly: false,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusMeters: 5000,
    unlimitedRadius: false,
    sortMode: DiscoverSortMode.geoFreshness,
    openNow: false,
    onlyAvailable: false,
    marketCityId: marketCityId,
    manualAreaSelected: false,
    searchAreaDirty: false,
    sourceScreen: 'discover',
    queryVersion: 2,
    appliedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
  );

  final String queryText;
  final List<String> selectedCategoryIds;
  final List<String> selectedSubcategoryIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? peopleCount;
  final int? availableDurationMinutes;
  final String? mood;
  final Money? budgetMin;
  final Money? budgetMax;
  final bool freeOnly;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool unlimitedRadius;
  final DiscoverSortMode sortMode;
  final bool openNow;
  final bool onlyAvailable;
  final String marketCityId;
  final bool manualAreaSelected;
  final bool searchAreaDirty;
  final String sourceScreen;
  final int queryVersion;
  final DateTime appliedAtUtc;
  final TimeWindow? timeWindow;
  final TravelContext? travelContext;

  bool get requestsPublishedRoutes {
    final source = sourceScreen.trim().toLowerCase();
    return queryText.trim().isNotEmpty ||
        selectedCategoryIds.isNotEmpty ||
        selectedSubcategoryIds.isNotEmpty ||
        freeOnly ||
        budgetMin != null ||
        budgetMax != null ||
        availableDurationMinutes != null ||
        manualAreaSelected ||
        source == 'regular_search' ||
        source == 'smart_search' ||
        source == 'search_results' ||
        source == 'map_search' ||
        source == 'route_details';
  }

  DiscoverQuery copyWith({
    String? queryText,
    List<String>? selectedCategoryIds,
    List<String>? selectedSubcategoryIds,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    int? peopleCount,
    bool clearPeopleCount = false,
    int? availableDurationMinutes,
    bool clearAvailableDurationMinutes = false,
    String? mood,
    bool clearMood = false,
    Money? budgetMin,
    bool clearBudgetMin = false,
    Money? budgetMax,
    bool clearBudgetMax = false,
    bool? freeOnly,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    bool? unlimitedRadius,
    DiscoverSortMode? sortMode,
    bool? openNow,
    bool? onlyAvailable,
    String? marketCityId,
    bool? manualAreaSelected,
    bool? searchAreaDirty,
    String? sourceScreen,
    int? queryVersion,
    DateTime? appliedAtUtc,
    TimeWindow? timeWindow,
    bool clearTimeWindow = false,
    TravelContext? travelContext,
    bool clearTravelContext = false,
  }) => DiscoverQuery(
    queryText: queryText ?? this.queryText,
    selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
    selectedSubcategoryIds:
        selectedSubcategoryIds ?? this.selectedSubcategoryIds,
    dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
    dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    peopleCount: clearPeopleCount ? null : (peopleCount ?? this.peopleCount),
    availableDurationMinutes: clearAvailableDurationMinutes
        ? null
        : (availableDurationMinutes ?? this.availableDurationMinutes),
    mood: clearMood ? null : (mood ?? this.mood),
    budgetMin: clearBudgetMin ? null : (budgetMin ?? this.budgetMin),
    budgetMax: clearBudgetMax ? null : (budgetMax ?? this.budgetMax),
    freeOnly: freeOnly ?? this.freeOnly,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    unlimitedRadius: unlimitedRadius ?? this.unlimitedRadius,
    sortMode: sortMode ?? this.sortMode,
    openNow: openNow ?? this.openNow,
    onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    marketCityId: marketCityId ?? this.marketCityId,
    manualAreaSelected: manualAreaSelected ?? this.manualAreaSelected,
    searchAreaDirty: searchAreaDirty ?? this.searchAreaDirty,
    sourceScreen: sourceScreen ?? this.sourceScreen,
    queryVersion: queryVersion ?? this.queryVersion,
    appliedAtUtc: appliedAtUtc ?? this.appliedAtUtc,
    timeWindow: clearTimeWindow ? null : (timeWindow ?? this.timeWindow),
    travelContext: clearTravelContext
        ? null
        : (travelContext ?? this.travelContext),
  );
}
