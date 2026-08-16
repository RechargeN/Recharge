import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/application/scenario_object_intake_providers.dart';
import '../../../../app/presentation/scenario_object_intake_sheet.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/geo/geometry_encoding.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/application/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate_sheet.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../../favorites/application/controllers/favorites_controller.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../../scenarios/application/state/scenario_builder_state.dart';
import '../../../scenarios/domain/entities/scenario_draft_entity.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/controllers/scenario_intake_selection_controller.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_query.dart';
import '../../application/smart_search_parser.dart';
import '../../application/state/discover_feed_state.dart';
import '../../application/state/scenario_intake_selection_state.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';
import '../../domain/entities/time_window.dart';
import '../widgets/scenario_intake_marker_icon_factory.dart';
import '../widgets/scenario_intake_selection_tray.dart';
import '../widgets/map_marker_utils.dart';
import '../widgets/map_style.dart';

class DiscoverMapPage extends ConsumerStatefulWidget {
  const DiscoverMapPage({
    super.key,
    this.seedParameters = const <String, String>{},
  });

  final Map<String, String> seedParameters;

  @override
  ConsumerState<DiscoverMapPage> createState() => _DiscoverMapPageState();
}

class _DiscoverMapPageState extends ConsumerState<DiscoverMapPage> {
  late final TextEditingController _searchController;
  late final ScenarioIntakeSelectionController _scenarioSelectionController;
  GoogleMapController? _mapController;
  Map<int, BitmapDescriptor> _scenarioSelectionMarkerIcons =
      const <int, BitmapDescriptor>{};
  bool _selectionMarkerIconsLoading = false;
  int? _selectedScenarioStopIndex;
  bool _scenarioRouteActive = false;
  bool _scenarioRouteComplete = false;
  bool _radiusControlExpanded = false;
  final Map<String, BitmapDescriptor> _customMarkers =
      <String, BitmapDescriptor>{};
  final Set<String> _loadingMarkers = <String>{};

  static final List<_MapFilterOption> _categoryFilters = <_MapFilterOption>[
    const _MapFilterOption(
      id: null,
      label: 'All',
      icon: Icons.grid_view_rounded,
    ),
    for (final RechargeContentGroup group in rechargeVisibleContentGroups)
      _MapFilterOption(
        id: group.id,
        label: group.title,
        icon: _mapCategoryIcon(group.id),
      ),
  ];

  @override
  void initState() {
    super.initState();
    _scenarioSelectionController = ScenarioIntakeSelectionController(
      supportIssue: ref
          .read(discoverScenarioIntakeAdapterProvider)
          .supportIssue,
      maxSelection: ref.read(scenarioObjectIntakeConfigProvider).maxBatchSize,
    )..addListener(_onScenarioSelectionChanged);
    final DiscoverFeedState state = ref
        .read(discoverFeedControllerProvider)
        .state;
    _searchController = TextEditingController(
      text: state.appliedQuery.queryText,
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
      ref.read(favoritesControllerProvider).ensureLoaded();
      controller.ensureSavedSearchesLoaded();
      controller.ensureSmartSearchHistoryLoaded();
    });
  }

  @override
  void dispose() {
    _scenarioSelectionController
      ..removeListener(_onScenarioSelectionChanged)
      ..dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller = ref.watch(
      discoverFeedControllerProvider,
    );
    final DiscoverFeedState state = controller.state;
    final ScenarioIntakeSelectionState selection =
        _scenarioSelectionController.state;
    final authController = ref.watch(authControllerProvider);
    final FavoritesController favoritesController = ref.watch(
      favoritesControllerProvider,
    );
    final bool isAuthenticated = authController.state.isAuthenticated;
    final intakeEnabled = isScenarioObjectIntakeSurfaceEnabled(
      ref,
      ScenarioObjectIntakeSurface.map,
    );
    final multiSelectEnabled = isScenarioObjectIntakeSurfaceEnabled(
      ref,
      ScenarioObjectIntakeSurface.map,
      multiSelect: true,
    );
    final _ScenarioMapRoute? scenarioRoute = _ScenarioMapRoute.fromSeed(
      widget.seedParameters,
    );
    final int? selectedScenarioStopIndex = _validScenarioStopIndex(
      scenarioRoute,
    );
    final LatLng center = LatLng(
      scenarioRoute?.centerLatitude ?? state.draftQuery.centerLat,
      scenarioRoute?.centerLongitude ?? state.draftQuery.centerLng,
    );
    final bool showSavedIntents =
        scenarioRoute == null &&
        (state.savedSearches.isNotEmpty || state.smartSearchHistory.isNotEmpty);

    _syncSearchController(state.appliedQuery.queryText);
    _maybeLoadCustomMarkers(state.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(selection.active ? 'Select for Scenario' : 'Map'),
        actions: <Widget>[
          if (scenarioRoute == null && multiSelectEnabled)
            IconButton(
              tooltip: selection.active
                  ? 'Cancel Scenario selection'
                  : 'Select for Scenario',
              onPressed: selection.active
                  ? _scenarioSelectionController.cancel
                  : () => _startScenarioSelection(authController),
              icon: Icon(
                selection.active ? Icons.close : Icons.playlist_add_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go(RouteNames.search),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      bottomNavigationBar: selection.active
          ? ScenarioIntakeSelectionTray(
              selectedItems: selection.selectedItems,
              message: selection.message,
              onRemove: _scenarioSelectionController.remove,
              onCancel: _scenarioSelectionController.cancel,
              onReview: selection.canReview
                  ? () => _openScenarioIntake(selection.selectedItems)
                  : null,
            )
          : null,
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 12),
            style: rechargeMapStyle,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController mapController) {
              _mapController = mapController;
            },
            clusterManagers: <ClusterManager>{
              ClusterManager(
                clusterManagerId: const ClusterManagerId('items'),
                onClusterTap: (Cluster cluster) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(cluster.position, 14),
                  );
                },
              ),
            },
            circles: <Circle>{
              if (!state.draftQuery.unlimitedRadius)
                Circle(
                  circleId: const CircleId('search_area'),
                  center: center,
                  radius: state.draftQuery.radiusMeters,
                  strokeWidth: 2,
                  strokeColor: RechargeTheme.travelGreen,
                  fillColor: RechargeTheme.travelGreen.withValues(alpha: 0.14),
                ),
            },
            markers: _buildMarkers(
              state: state,
              scenarioRoute: scenarioRoute,
              selectedScenarioStopIndex: selectedScenarioStopIndex,
              selectedItemId: state.selectedItemId,
              scenarioSelection: selection,
              scenarioSelectionIcons: _scenarioSelectionMarkerIcons,
              onTap: selection.active
                  ? (itemId) {
                      if (itemId == null) return;
                      final matches = state.items.where(
                        (item) => item.id == itemId,
                      );
                      if (matches.length == 1) {
                        _scenarioSelectionController.toggle(matches.single);
                      }
                    }
                  : controller.selectItem,
              onScenarioStopTap: scenarioRoute == null
                  ? null
                  : (int index) => _selectScenarioStop(scenarioRoute, index),
            ),
            polylines: _buildPolylines(
              context,
              scenarioRoute,
              state.selectedItem,
            ),
            onCameraMove: (CameraPosition position) {
              controller.stageMapCenter(
                lat: position.target.latitude,
                lng: position.target.longitude,
              );
            },
          ),
          // 1. Radius Control (Floating Pill)
          if (scenarioRoute == null && !selection.active)
            Positioned(
              left: 12,
              top: showSavedIntents ? 318 : 188,
              child: _CompactRadiusControl(
                radiusMeters: state.draftQuery.radiusMeters,
                unlimited: state.draftQuery.unlimitedRadius,
                expanded: _radiusControlExpanded,
                onToggle: () => setState(
                  () => _radiusControlExpanded = !_radiusControlExpanded,
                ),
                onRadiusChanged: (double value) {
                  controller.stageRadius(radiusMeters: value, unlimited: false);
                },
                onUnlimitedChanged: (bool value) {
                  controller.stageRadius(
                    radiusMeters: state.draftQuery.radiusMeters,
                    unlimited: value,
                  );
                },
              ),
            ),
          if (state.searchAreaDirty &&
              scenarioRoute == null &&
              !selection.active)
            Positioned(
              top: showSavedIntents ? 342 : 212,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: FilledButton.icon(
                      onPressed: controller.applySearchArea,
                      style: FilledButton.styleFrom(
                        backgroundColor: RechargeTheme.emerald900.withValues(
                          alpha: 0.88,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Search this area'),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: _MapFilterPanel(
              controller: _searchController,
              filters: _categoryFilters,
              selectedCategoryId: state.appliedQuery.selectedCategoryIds.isEmpty
                  ? null
                  : normalizeRechargeContentGroupId(
                      state.appliedQuery.selectedCategoryIds.first,
                    ),
              freeOnly: state.appliedQuery.freeOnly,
              resultCount: state.resultCount,
              onSubmitSearch: () {
                controller.applySearchConditions(
                  queryText: _searchController.text,
                  sourceScreen: 'map_search',
                );
              },
              onClearSearch: () {
                _searchController.clear();
                controller.applySearchConditions(
                  queryText: '',
                  sourceScreen: 'map_search',
                );
              },
              onCategorySelected: (String? value) {
                controller.applySearchConditions(
                  selectedCategoryIds: value == null
                      ? const <String>[]
                      : <String>[value],
                  sourceScreen: 'map_search',
                );
              },
              onFreeOnlyChanged: (bool value) {
                controller.applySearchConditions(
                  freeOnly: value,
                  sourceScreen: 'map_search',
                );
              },
              onCreateHere: () {
                final DiscoverQuery query = state.draftQuery.copyWith(
                  queryText: _searchController.text,
                );
                context.go(mapCreateLocationForQuery(query));
              },
              savedSearches: showSavedIntents
                  ? state.savedSearches
                  : const <SavedSearchEntity>[],
              smartSearchHistory: showSavedIntents
                  ? state.smartSearchHistory
                  : const <SmartSearchHistoryEntity>[],
              onApplySavedSearch: (SavedSearchEntity search) {
                _searchController.text = search.query.queryText;
                controller.applySavedSearch(search);
              },
              onCreateSavedSearch: (SavedSearchEntity search) {
                context.go(mapCreateLocationForSavedSearch(search));
              },
              onRouteSavedSearch: (SavedSearchEntity search) {
                context.go(mapScenarioBuilderLocationForQuery(search.query));
              },
              onApplySmartSearch: (SmartSearchHistoryEntity item) {
                _searchController.text = item.query.queryText;
                controller.applySmartSearchHistory(item);
              },
              onCreateSmartSearch: (SmartSearchHistoryEntity item) {
                context.go(mapCreateLocationForSmartSearch(item));
              },
              onRouteSmartSearch: (SmartSearchHistoryEntity item) {
                context.go(mapScenarioBuilderLocationForSmartSearch(item));
              },
            ),
          ),
          Positioned(
            right: 12,
            top: showSavedIntents ? 318 : 188,
            child: Column(
              children: <Widget>[
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  tooltip: 'Use current location',
                  onPressed: controller.useCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: RechargeTheme.travelGreenDark,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  tooltip: 'Recenter',
                  onPressed: () {
                    controller.recenterToAppliedArea();
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(
                          state.appliedQuery.centerLat,
                          state.appliedQuery.centerLng,
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: RechargeTheme.travelGreenDark,
                  child: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
          _MapResultsSheet(
            state: state,
            favoritesController: favoritesController,
            onRadiusChanged: (double value) {
              controller.stageRadius(radiusMeters: value, unlimited: false);
            },
            onUnlimitedChanged: (bool value) {
              controller.stageRadius(
                radiusMeters: state.draftQuery.radiusMeters,
                unlimited: value,
              );
            },
            onApplyArea: controller.applySearchArea,
            onRetry: controller.loadFeed,
            onSelectItem: (DiscoverItemEntity item) {
              if (selection.active) {
                _scenarioSelectionController.toggle(item);
              } else {
                controller.selectItem(item.id);
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(LatLng(item.latitude, item.longitude)),
                );
              }
            },
            onOpenDetails: (DiscoverItemEntity item) {
              context.push('${RouteNames.discoverDetails}/${item.id}');
            },
            onToggleSave: (DiscoverItemEntity item) => _onMapSaveTap(
              item: item,
              isAuthenticated: isAuthenticated,
              authController: authController,
              favoritesController: favoritesController,
            ),
            scenarioSelection: selection,
            onToggleScenarioSelection: _scenarioSelectionController.toggle,
            onAddToScenario: intakeEnabled
                ? (item) => _openScenarioIntake(<DiscoverItemEntity>[item])
                : null,
            scenarioRoute: scenarioRoute,
            selectedScenarioStopIndex: selectedScenarioStopIndex,
            routeActive: scenarioRoute != null && _scenarioRouteActive,
            routeComplete: scenarioRoute != null && _scenarioRouteComplete,
            onScenarioStopSelected: scenarioRoute == null
                ? null
                : (int index) => _selectScenarioStop(scenarioRoute, index),
            onStartRoute: scenarioRoute == null
                ? null
                : () => _startScenarioRoute(scenarioRoute),
            onNextStop: scenarioRoute == null
                ? null
                : () => _advanceScenarioRoute(scenarioRoute),
            onResetRoute: scenarioRoute == null ? null : _resetScenarioRoute,
            onSaveCompletedRoute: scenarioRoute == null
                ? null
                : () => _onScenarioRouteSaveTap(
                    route: scenarioRoute,
                    isAuthenticated: isAuthenticated,
                    authController: authController,
                    favoritesController: favoritesController,
                  ),
            onCopyCompletedRoute: scenarioRoute == null
                ? null
                : () => _copyScenarioRoute(scenarioRoute),
            onOpenBuilder: scenarioRoute == null
                ? null
                : () => context.go(scenarioRoute.builderLocation),
            onSearchScenarioRoute: scenarioRoute == null
                ? null
                : () => context.go(scenarioRoute.searchLocation),
            onCreateScenarioRoute: scenarioRoute == null
                ? null
                : () => context.go(scenarioRoute.createLocation),
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

  void _onScenarioSelectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadScenarioSelectionMarkerIcons() async {
    try {
      final icons = await buildScenarioIntakeMarkerIcons(
        color: RechargeTheme.travelGreenDark,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      if (!mounted) return;
      setState(() => _scenarioSelectionMarkerIcons = icons);
    } on Object {
      // Default orange markers and numbered tray remain a safe fallback.
    }
  }

  Future<void> _startScenarioSelection(AuthController authController) async {
    if (!await _requireScenarioAuth(authController)) return;
    _scenarioSelectionController.start();
    if (!_selectionMarkerIconsLoading &&
        _scenarioSelectionMarkerIcons.isEmpty) {
      _selectionMarkerIconsLoading = true;
      unawaited(_loadScenarioSelectionMarkerIcons());
    }
  }

  Future<bool> _requireScenarioAuth(AuthController authController) async {
    if (authController.state.user != null) return true;
    authController.trackAuthGateViewed(
      sourceScreen: 'discover_map',
      sourceAction: 'add_to_scenario',
    );
    await showAuthGateSheet(
      context,
      action: ProtectedAction.create,
      sourceScreen: 'discover_map',
      sourceAction: 'add_to_scenario',
      originRoute: RouteNames.discoverMap,
      allowGuest: false,
      onContinueAsGuest: () {},
    );
    return false;
  }

  Future<void> _openScenarioIntake(List<DiscoverItemEntity> items) async {
    final result = await launchScenarioObjectIntake(
      context: context,
      ref: ref,
      items: items,
      sourceSurface: ScenarioObjectIntakeSurface.map,
      sourceScreen: 'discover_map',
      sourceAction: 'add_to_scenario',
      originRoute: RouteNames.discoverMap,
    );
    if (result == null || !mounted) return;
    _scenarioSelectionController.cancel();
    if (result.openScenario) {
      final uri = Uri(
        path: '${RouteNames.createObject}/scenario',
        queryParameters: <String, String>{
          'scenarioDraftId': result.targetDraftId,
        },
      );
      await context.push(uri.toString());
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${result.itemCount} to Scenario')),
    );
  }

  Future<void> _applySearchSeed(
    DiscoverFeedController controller,
    Map<String, String> seedParameters,
  ) async {
    final double? budgetMax = _doubleFromSeed(seedParameters['budgetMax']);
    final DateTime? dateFrom = _dateFromSeed(seedParameters['dateFrom']);
    final DateTime? dateTo = _dateFromSeed(seedParameters['dateTo']);
    final double? itemLat = _doubleFromSeed(seedParameters['itemLat']);
    final double? itemLng = _doubleFromSeed(seedParameters['itemLng']);
    final TimeWindow? timeWindow = _mapTimeWindowFromSeed(seedParameters);
    final TravelContext? travelContext = _mapTravelContextFromSeed(
      seedParameters,
    );
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
      openNow: seedParameters['openNow'] == '1',
      onlyAvailable: seedParameters['onlyAvailable'] == '1',
      centerLat: itemLat,
      centerLng: itemLng,
      manualAreaSelected: itemLat != null && itemLng != null,
      selectedItemId: _itemIdFromSeed(seedParameters),
      timeWindow: timeWindow,
      clearTimeWindow: timeWindow == null,
      travelContext: travelContext,
      clearTravelContext: travelContext == null,
      sourceScreen: 'map_search',
    );
  }

  void _maybeLoadCustomMarkers(List<DiscoverItemEntity> items) {
    final List<DiscoverItemEntity> candidates = items
        .where(
          (DiscoverItemEntity item) =>
              item.coverImageUrl.isNotEmpty &&
              !_customMarkers.containsKey(item.id) &&
              !_loadingMarkers.contains(item.id),
        )
        .take(20)
        .toList();

    if (candidates.isEmpty) return;

    for (final DiscoverItemEntity item in candidates) {
      _loadingMarkers.add(item.id);
      createCustomMarkerFromUrl(item.coverImageUrl)
          .then((BitmapDescriptor descriptor) {
            if (mounted) {
              setState(() {
                _customMarkers[item.id] = descriptor;
                _loadingMarkers.remove(item.id);
              });
            }
          })
          .catchError((Object e) {
            if (mounted) {
              setState(() {
                _loadingMarkers.remove(item.id);
              });
            }
          });
    }
  }

  Set<Marker> _buildMarkers({
    required DiscoverFeedState state,
    required _ScenarioMapRoute? scenarioRoute,
    required int? selectedScenarioStopIndex,
    required String? selectedItemId,
    required ScenarioIntakeSelectionState scenarioSelection,
    required Map<int, BitmapDescriptor> scenarioSelectionIcons,
    required ValueChanged<String?> onTap,
    required ValueChanged<int>? onScenarioStopTap,
  }) {
    final List<DiscoverItemEntity> items = state.items;

    final Set<Marker> markers = items.map((DiscoverItemEntity item) {
      final bool selected = item.id == selectedItemId;
      final int? scenarioOrder = scenarioSelection.orderOf(item.id);
      final BitmapDescriptor? customIcon = _customMarkers[item.id];
      return Marker(
        markerId: MarkerId(item.id),
        clusterManagerId: const ClusterManagerId('items'),
        position: LatLng(item.latitude, item.longitude),
        icon:
            scenarioSelectionIcons[scenarioOrder] ??
            (scenarioOrder == null ? customIcon : null) ??
            BitmapDescriptor.defaultMarkerWithHue(
              scenarioOrder != null
                  ? BitmapDescriptor.hueOrange
                  : selected
                  ? BitmapDescriptor.hueYellow
                  : item.isPublishedRoute
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueGreen,
            ),
        onTap: () => onTap(item.id),
        infoWindow: InfoWindow(
          title: scenarioOrder == null
              ? item.title
              : '$scenarioOrder. ${item.title}',
          snippet: item.isPublishedRoute
              ? _publishedRouteMapMetric(item)
              : item.isFree
              ? 'Free'
              : '${item.priceAmount.toStringAsFixed(0)} €',
        ),
      );
    }).toSet();
    if (scenarioRoute == null) return markers;

    markers.addAll(
      scenarioRoute.stops.asMap().entries.map(
        (MapEntry<int, ScenarioStepEntity> entry) => Marker(
          markerId: MarkerId('scenario_${entry.key}_${entry.value.category}'),
          position: LatLng(entry.value.latitude, entry.value.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            selectedScenarioStopIndex == entry.key
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueAzure,
          ),
          onTap: () => onScenarioStopTap?.call(entry.key),
          infoWindow: InfoWindow(
            title: '${entry.key + 1}. ${entry.value.title}',
            snippet: '${entry.value.durationMinutes} min',
          ),
        ),
      ),
    );
    return markers;
  }

  Set<Polyline> _buildPolylines(
    BuildContext context,
    _ScenarioMapRoute? scenarioRoute,
    DiscoverItemEntity? selectedItem,
  ) {
    final Set<Polyline> polylines = <Polyline>{};
    final publishedRoute = selectedItem?.publishedRoute;
    if (publishedRoute != null && publishedRoute.isCoherent) {
      try {
        final points = GeometryEncoding.decode(
          publishedRoute.fullEncodedPolyline,
          policy: GeometryEncodingPolicy(
            precision: publishedRoute.encodingPrecision,
          ),
        );
        if (points.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: PolylineId(
                'published_route_${publishedRoute.routeId}_'
                '${publishedRoute.versionId}',
              ),
              points: points
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              color: RechargeTheme.travelGreen,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
        }
      } on FormatException {
        // A malformed snapshot is ignored instead of triggering rerouting.
      } on RangeError {
        // Unsupported precision is treated as an unreadable snapshot.
      }
    }
    if (scenarioRoute != null && scenarioRoute.stops.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('scenario_route'),
          points: scenarioRoute.stops
              .map(
                (ScenarioStepEntity step) =>
                    LatLng(step.latitude, step.longitude),
              )
              .toList(growable: false),
          color: Theme.of(context).colorScheme.primary,
          width: 5,
        ),
      );
    }
    return polylines;
  }

  int? _validScenarioStopIndex(_ScenarioMapRoute? scenarioRoute) {
    if (scenarioRoute == null || _selectedScenarioStopIndex == null) {
      return null;
    }
    if (_selectedScenarioStopIndex! < 0 ||
        _selectedScenarioStopIndex! >= scenarioRoute.stops.length) {
      return null;
    }
    return _selectedScenarioStopIndex;
  }

  void _selectScenarioStop(_ScenarioMapRoute route, int index) {
    if (index < 0 || index >= route.stops.length) return;
    setState(() {
      _selectedScenarioStopIndex = index;
      _scenarioRouteComplete = false;
    });
    _focusScenarioStop(route.stops[index]);
  }

  void _startScenarioRoute(_ScenarioMapRoute route) {
    _selectScenarioStop(route, 0);
    setState(() => _scenarioRouteActive = true);
  }

  void _advanceScenarioRoute(_ScenarioMapRoute route) {
    final int currentIndex = _validScenarioStopIndex(route) ?? -1;
    final int nextIndex = currentIndex + 1;
    if (nextIndex >= route.stops.length) {
      setState(() {
        _scenarioRouteActive = false;
        _scenarioRouteComplete = true;
      });
      return;
    }
    _selectScenarioStop(route, nextIndex);
    setState(() => _scenarioRouteActive = true);
  }

  void _resetScenarioRoute() {
    setState(() {
      _selectedScenarioStopIndex = null;
      _scenarioRouteActive = false;
      _scenarioRouteComplete = false;
    });
  }

  void _focusScenarioStop(ScenarioStepEntity step) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(step.latitude, step.longitude), 14),
    );
  }

  Future<void> _onMapSaveTap({
    required DiscoverItemEntity item,
    required bool isAuthenticated,
    required AuthController authController,
    required FavoritesController favoritesController,
  }) async {
    if (!isAuthenticated) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_map',
        sourceAction: 'favorite_tap',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.favorite,
        sourceScreen: 'discover_map',
        sourceAction: 'favorite_tap',
        originRoute: '${RouteNames.discoverDetails}/${item.id}',
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_map',
            sourceAction: 'favorite_tap',
          );
        },
      );
      return;
    }

    await favoritesController.toggleFavorite(
      _toFavorite(item),
      sourceScreen: 'discover_map',
    );
  }

  Future<void> _onScenarioRouteSaveTap({
    required _ScenarioMapRoute route,
    required bool isAuthenticated,
    required AuthController authController,
    required FavoritesController favoritesController,
  }) async {
    if (!isAuthenticated) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_map',
        sourceAction: 'save_completed_scenario',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.favorite,
        sourceScreen: 'discover_map',
        sourceAction: 'save_completed_scenario',
        originRoute: route.builderLocation,
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_map',
            sourceAction: 'save_completed_scenario',
          );
        },
      );
      return;
    }

    await favoritesController.addFavorite(
      _toScenarioFavorite(route),
      sourceScreen: 'discover_map',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scenario saved')));
  }

  Future<void> _copyScenarioRoute(_ScenarioMapRoute route) async {
    await Clipboard.setData(ClipboardData(text: _scenarioRouteSummary(route)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scenario copied')));
  }

  FavoriteItemEntity _toFavorite(DiscoverItemEntity item) {
    return FavoriteItemEntity(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      city: item.city,
      category: item.category,
      startsAtUtc: item.startsAtUtc,
      distanceKm: item.distanceKm,
      priceAmount: item.priceAmount,
      isFree: item.isFree,
      savedAtUtc: DateTime.now().toUtc(),
      targetRoute: null,
      coverImageUrl: item.coverImageUrl,
    );
  }

  FavoriteItemEntity _toScenarioFavorite(_ScenarioMapRoute route) {
    final DateTime now = DateTime.now().toUtc();
    final String categoryKey = route.stops
        .map((ScenarioStepEntity step) => step.category.replaceAll('.', '_'))
        .join('_');
    return FavoriteItemEntity(
      id: 'scenario_map_${route.moodKey}_$categoryKey',
      title: '${route.moodLabel} recharge scenario',
      subtitle:
          '${route.stops.length} stops · '
          '${route.totalDurationMinutes} min',
      city: 'Riga',
      category: 'scenario',
      startsAtUtc: now,
      distanceKm: route.totalDistanceKm,
      priceAmount: route.totalPriceAmount,
      isFree: route.totalPriceAmount == 0,
      savedAtUtc: now,
      targetRoute: route.builderLocation,
    );
  }
}

String _publishedRouteMapMetric(DiscoverItemEntity item) {
  final route = item.publishedRoute;
  if (route == null) return 'Route';
  final String distance =
      '${(route.distanceMeters / 1000).toStringAsFixed(1)} км';
  final int minutes = (route.durationSeconds / 60).round();
  return '$distance · $minutes min';
}

bool _hasSearchSeed(Map<String, String> seedParameters) {
  if (seedParameters['mode'] == 'scenario') return false;
  const List<String> supportedKeys = <String>[
    'q',
    'category',
    'free',
    'budgetMax',
    'dateFrom',
    'dateTo',
    'radius',
    'unlimited',
    'itemLat',
    'itemLng',
    'itemId',
    'timeMode',
    'openNow',
    'onlyAvailable',
  ];
  return supportedKeys.any(seedParameters.containsKey);
}

String? _queryTextFromSeed(Map<String, String> seedParameters) {
  if (!seedParameters.containsKey('q')) return null;
  return seedParameters['q']?.trim() ?? '';
}

String? _itemIdFromSeed(Map<String, String> seedParameters) {
  final String? raw = seedParameters['itemId'];
  if (raw == null) return null;
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
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

String mapCreateLocationForQuery(DiscoverQuery query) {
  final Map<String, String> params = <String, String>{
    'source': 'map',
    'type': 'event',
    'title': _mapCreateTitleForQuery(query),
    'subtitle': _mapCreateSubtitleForQuery(query),
    'q': query.queryText.trim(),
    'category': query.selectedCategoryIds.join(','),
    'free': query.freeOnly ? '1' : '0',
    if (query.budgetMax != null)
      'budgetMax': query.budgetMax!.toStringAsFixed(0),
    if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
    if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
    'radius': query.radiusMeters.round().toString(),
    'unlimited': query.unlimitedRadius ? '1' : '0',
    'city': _mapMarketCityLabel(query.marketCityId),
    'itemLat': query.centerLat.toStringAsFixed(6),
    'itemLng': query.centerLng.toStringAsFixed(6),
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String mapCreateLocationForSavedSearch(SavedSearchEntity search) {
  return _mapCreateLocationForQuery(
    search.query,
    source: 'saved_search',
    title: search.title,
    subtitle: search.subtitle,
  );
}

String mapCreateLocationForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _mapSmartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._mapSmartRouteParameters(parseResult, includeMode: false),
        'source': 'smart_route_seed',
        'type': 'route',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle':
            '${routeIntent.stepCategories.length} stops · '
            '${routeIntent.durationMinutes} min · smart route',
        'q': parseResult.originalText.trim(),
        'category': 'route',
      },
    ).toString();
  }
  return _mapCreateLocationForQuery(
    item.query,
    source: 'smart_search',
    title: _mapTitleForQuery(item.query),
    subtitle: item.prompt,
  );
}

String mapScenarioBuilderLocationForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _mapSmartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._mapSmartRouteParameters(parseResult, includeMode: false),
        'source': 'smart_route_seed',
        'type': 'route',
        'category': 'route',
      },
    ).toString();
  }
  return mapScenarioBuilderLocationForQuery(item.query, prompt: item.prompt);
}

String _mapCreateLocationForQuery(
  DiscoverQuery query, {
  required String source,
  required String title,
  required String subtitle,
}) {
  final Map<String, String> params = <String, String>{
    'source': source,
    'type': 'event',
    'title': title,
    if (subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
    ..._mapQueryParameters(query),
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String mapScenarioBuilderLocationForQuery(
  DiscoverQuery query, {
  String? prompt,
}) {
  final String routePrompt = prompt?.trim().isNotEmpty == true
      ? prompt!.trim()
      : _mapPromptForQuery(query);
  final Map<String, String> params = <String, String>{
    'mood': _mapScenarioMoodForQuery(query),
    'duration': query.radiusMeters <= 5000 ? '120' : '180',
    'walking': query.unlimitedRadius ? '0' : '1',
    if (query.freeOnly) 'free': '1',
    if (routePrompt.isNotEmpty) 'prompt': routePrompt,
  };
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      ...params,
      'source': 'saved_search_route_seed',
      'type': 'route',
      'category': 'route',
    },
  ).toString();
}

SmartSearchParseResult? _mapSmartRouteParseForSmartSearch(
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent == null) return null;
  return parseResult;
}

Map<String, String> _mapSmartRouteParameters(
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

String? mapScenarioBuilderLocationForSeed(Map<String, String> seedParameters) {
  return _ScenarioMapRoute.fromSeed(seedParameters)?.builderLocation;
}

String? mapScenarioCreateLocationForSeed(Map<String, String> seedParameters) {
  return _ScenarioMapRoute.fromSeed(seedParameters)?.createLocation;
}

String? mapScenarioSearchLocationForSeed(Map<String, String> seedParameters) {
  return _ScenarioMapRoute.fromSeed(seedParameters)?.searchLocation;
}

Map<String, String> _mapQueryParameters(DiscoverQuery query) {
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
    ..._mapTimeRouteParameters(query),
  };
}

TimeWindow? _mapTimeWindowFromSeed(Map<String, String> values) {
  final String? mode = values['timeMode'];
  final String? start = values['timeStart'];
  final String? end = values['timeEnd'];
  final String? timezone = values['timezone'];
  final String? resolvedAt = values['resolvedAt'];
  if (mode == null ||
      start == null ||
      end == null ||
      timezone == null ||
      resolvedAt == null) {
    return null;
  }
  try {
    return TimeWindow(
      startAtUtc: DateTime.parse(start).toUtc(),
      endAtUtc: DateTime.parse(end).toUtc(),
      timezoneId: timezone,
      mode: TimeWindowMode.values.firstWhere(
        (TimeWindowMode value) => value.name == mode,
      ),
      flexibilityMinutes: int.tryParse(values['flexibility'] ?? '') ?? 0,
      resolvedAtUtc: DateTime.parse(resolvedAt).toUtc(),
    );
  } on Exception {
    return null;
  }
}

TravelContext? _mapTravelContextFromSeed(Map<String, String> values) {
  if (!values.containsKey('originLat') || !values.containsKey('originLng')) {
    return null;
  }
  try {
    return TravelContext(
      originType: TravelOriginType.values.firstWhere(
        (TravelOriginType value) => value.name == values['originType'],
      ),
      origin: GeoPoint(
        latitude: double.parse(values['originLat']!),
        longitude: double.parse(values['originLng']!),
      ),
      transportMode: TransportMode.values.firstWhere(
        (TransportMode value) => value.name == values['transport'],
      ),
      includeReturnTrip: values['returnTrip'] == '1',
    );
  } on Exception {
    return null;
  }
}

Map<String, String> _mapTimeRouteParameters(DiscoverQuery query) {
  final TimeWindow? window = query.timeWindow;
  final TravelContext? travel = query.travelContext;
  if (window == null || travel == null) return const <String, String>{};
  return <String, String>{
    'timeMode': window.mode.name,
    'timeStart': window.startAtUtc.toIso8601String(),
    'timeEnd': window.endAtUtc.toIso8601String(),
    'timezone': window.timezoneId,
    'flexibility': '${window.flexibilityMinutes}',
    'resolvedAt': window.resolvedAtUtc.toIso8601String(),
    'originType': travel.originType.name,
    'originLat': '${travel.origin.latitude}',
    'originLng': '${travel.origin.longitude}',
    'transport': travel.transportMode.name,
    'returnTrip': travel.includeReturnTrip ? '1' : '0',
  };
}

String _mapCreateTitleForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return '${queryText[0].toUpperCase()}${queryText.substring(1)} idea';
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return 'Map area idea';
}

String _mapTitleForQuery(DiscoverQuery query) {
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

String _mapCreateSubtitleForQuery(DiscoverQuery query) {
  final List<String> parts = <String>[
    'Map area',
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null) 'under ${query.budgetMax!.toStringAsFixed(0)}',
    query.unlimitedRadius
        ? 'any area'
        : '${(query.radiusMeters / 1000).round()} km',
  ];
  return parts.join(' · ');
}

String _mapPromptForQuery(DiscoverQuery query) {
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

String _mapIntentRadiusLabel(DiscoverQuery query) {
  return query.unlimitedRadius
      ? 'Any area'
      : '${(query.radiusMeters / 1000).round()} km';
}

String _mapSmartSearchSubtitle(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _mapSmartRouteParseForSmartSearch(
    item,
  );
  if (parseResult == null) return _mapPromptForQuery(item.query);
  return parseResult.routeIntent!.stepCategories
      .map(createTaxonomyLabelForPath)
      .join(' · ');
}

String _mapSmartSearchTrailingLabel(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _mapSmartRouteParseForSmartSearch(
    item,
  );
  if (parseResult == null) return _mapIntentRadiusLabel(item.query);
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return '${routeIntent.durationMinutes} min · '
      '${routeIntent.stepCategories.length} stops';
}

String _mapScenarioMoodForQuery(DiscoverQuery query) {
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

String _mapMarketCityLabel(String marketCityId) {
  switch (marketCityId.toLowerCase()) {
    case 'riga':
      return 'Riga';
    case 'rezekne':
      return 'Rezekne';
  }
  return marketCityId.trim().isEmpty ? 'Riga' : _capitalized(marketCityId);
}

class _MapFilterPanel extends StatelessWidget {
  const _MapFilterPanel({
    required this.controller,
    required this.filters,
    required this.selectedCategoryId,
    required this.freeOnly,
    required this.resultCount,
    required this.onSubmitSearch,
    required this.onClearSearch,
    required this.onCategorySelected,
    required this.onFreeOnlyChanged,
    required this.onCreateHere,
    required this.savedSearches,
    required this.smartSearchHistory,
    required this.onApplySavedSearch,
    required this.onCreateSavedSearch,
    required this.onRouteSavedSearch,
    required this.onApplySmartSearch,
    required this.onCreateSmartSearch,
    required this.onRouteSmartSearch,
  });

  final TextEditingController controller;
  final List<_MapFilterOption> filters;
  final String? selectedCategoryId;
  final bool freeOnly;
  final int resultCount;
  final VoidCallback onSubmitSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<bool> onFreeOnlyChanged;
  final VoidCallback onCreateHere;
  final List<SavedSearchEntity> savedSearches;
  final List<SmartSearchHistoryEntity> smartSearchHistory;
  final ValueChanged<SavedSearchEntity> onApplySavedSearch;
  final ValueChanged<SavedSearchEntity> onCreateSavedSearch;
  final ValueChanged<SavedSearchEntity> onRouteSavedSearch;
  final ValueChanged<SmartSearchHistoryEntity> onApplySmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onCreateSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onRouteSmartSearch;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmitSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search on map',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          IconButton(
                            tooltip: 'Search',
                            onPressed: onSubmitSearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (BuildContext context, int index) {
                            final _MapFilterOption filter = filters[index];
                            return ChoiceChip(
                              selected: selectedCategoryId == filter.id,
                              avatar: Icon(filter.icon, size: 18),
                              label: Text(filter.label),
                              onSelected: (_) => onCategorySelected(filter.id),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: filters.length,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: freeOnly,
                      avatar: const Icon(Icons.bolt_outlined, size: 18),
                      label: const Text('Free'),
                      onSelected: onFreeOnlyChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '$resultCount places and activities in area',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onCreateHere,
                      tooltip: 'Create here',
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                if (savedSearches.isNotEmpty ||
                    smartSearchHistory.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _MapSavedIntentShelf(
                    savedSearches: savedSearches,
                    smartSearchHistory: smartSearchHistory,
                    onApplySavedSearch: onApplySavedSearch,
                    onCreateSavedSearch: onCreateSavedSearch,
                    onRouteSavedSearch: onRouteSavedSearch,
                    onApplySmartSearch: onApplySmartSearch,
                    onCreateSmartSearch: onCreateSmartSearch,
                    onRouteSmartSearch: onRouteSmartSearch,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSavedIntentShelf extends StatelessWidget {
  const _MapSavedIntentShelf({
    required this.savedSearches,
    required this.smartSearchHistory,
    required this.onApplySavedSearch,
    required this.onCreateSavedSearch,
    required this.onRouteSavedSearch,
    required this.onApplySmartSearch,
    required this.onCreateSmartSearch,
    required this.onRouteSmartSearch,
  });

  final List<SavedSearchEntity> savedSearches;
  final List<SmartSearchHistoryEntity> smartSearchHistory;
  final ValueChanged<SavedSearchEntity> onApplySavedSearch;
  final ValueChanged<SavedSearchEntity> onCreateSavedSearch;
  final ValueChanged<SavedSearchEntity> onRouteSavedSearch;
  final ValueChanged<SmartSearchHistoryEntity> onApplySmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onCreateSmartSearch;
  final ValueChanged<SmartSearchHistoryEntity> onRouteSmartSearch;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      ...savedSearches.map(
        (SavedSearchEntity search) => _MapSavedIntentCard(
          icon: Icons.tune,
          label: 'Saved',
          title: search.title,
          subtitle: search.subtitle,
          query: search.query,
          trailingLabel: _mapIntentRadiusLabel(search.query),
          applyTooltip: 'Apply saved conditions to map',
          createTooltip: 'Create listing from saved conditions',
          routeTooltip: 'Build route from saved conditions',
          onApply: () => onApplySavedSearch(search),
          onCreate: () => onCreateSavedSearch(search),
          onRoute: () => onRouteSavedSearch(search),
        ),
      ),
      ...smartSearchHistory.map(
        (SmartSearchHistoryEntity item) => _MapSavedIntentCard(
          icon: Icons.psychology_alt_outlined,
          label: 'Smart',
          title: item.prompt,
          subtitle: _mapSmartSearchSubtitle(item),
          query: item.query,
          trailingLabel: _mapSmartSearchTrailingLabel(item),
          applyTooltip: 'Apply smart search to map',
          createTooltip: 'Create listing from smart search',
          routeTooltip: 'Build route from smart search',
          onApply: () => onApplySmartSearch(item),
          onCreate: () => onCreateSmartSearch(item),
          onRoute: () => onRouteSmartSearch(item),
        ),
      ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.bookmarks_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Saved on map',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) => cards[index],
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: cards.length,
          ),
        ),
      ],
    );
  }
}

class _MapSavedIntentCard extends StatelessWidget {
  const _MapSavedIntentCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.trailingLabel,
    required this.applyTooltip,
    required this.createTooltip,
    required this.routeTooltip,
    required this.onApply,
    required this.onCreate,
    required this.onRoute,
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final DiscoverQuery query;
  final String trailingLabel;
  final String applyTooltip;
  final String createTooltip;
  final String routeTooltip;
  final VoidCallback onApply;
  final VoidCallback onCreate;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 238,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: RechargeTheme.travelPanel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RechargeTheme.travelLine),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: RechargeTheme.travelGreenDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: RechargeTheme.travelGreenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    trailingLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Tooltip(
                      message: applyTooltip,
                      child: FilledButton.icon(
                        onPressed: onApply,
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Apply'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: routeTooltip,
                    onPressed: onRoute,
                    icon: const Icon(Icons.route_outlined),
                  ),
                  const SizedBox(width: 4),
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
      ),
    );
  }
}

class _MapResultsSheet extends StatelessWidget {
  const _MapResultsSheet({
    required this.state,
    required this.favoritesController,
    required this.onRadiusChanged,
    required this.onUnlimitedChanged,
    required this.onApplyArea,
    required this.onRetry,
    required this.onSelectItem,
    required this.onOpenDetails,
    required this.onToggleSave,
    required this.scenarioSelection,
    required this.onToggleScenarioSelection,
    required this.onAddToScenario,
    required this.scenarioRoute,
    required this.selectedScenarioStopIndex,
    required this.routeActive,
    required this.routeComplete,
    required this.onScenarioStopSelected,
    required this.onStartRoute,
    required this.onNextStop,
    required this.onResetRoute,
    required this.onSaveCompletedRoute,
    required this.onCopyCompletedRoute,
    required this.onOpenBuilder,
    required this.onSearchScenarioRoute,
    required this.onCreateScenarioRoute,
  });

  final DiscoverFeedState state;
  final FavoritesController favoritesController;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onUnlimitedChanged;
  final Future<void> Function() onApplyArea;
  final Future<void> Function() onRetry;
  final ValueChanged<DiscoverItemEntity> onSelectItem;
  final ValueChanged<DiscoverItemEntity> onOpenDetails;
  final ValueChanged<DiscoverItemEntity> onToggleSave;
  final ScenarioIntakeSelectionState scenarioSelection;
  final ValueChanged<DiscoverItemEntity> onToggleScenarioSelection;
  final ValueChanged<DiscoverItemEntity>? onAddToScenario;
  final _ScenarioMapRoute? scenarioRoute;
  final int? selectedScenarioStopIndex;
  final bool routeActive;
  final bool routeComplete;
  final ValueChanged<int>? onScenarioStopSelected;
  final VoidCallback? onStartRoute;
  final VoidCallback? onNextStop;
  final VoidCallback? onResetRoute;
  final Future<void> Function()? onSaveCompletedRoute;
  final Future<void> Function()? onCopyCompletedRoute;
  final VoidCallback? onOpenBuilder;
  final VoidCallback? onSearchScenarioRoute;
  final VoidCallback? onCreateScenarioRoute;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.18,
      maxChildSize: 0.72,
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            border: Border(top: BorderSide(color: RechargeTheme.travelLine)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x16003F32),
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              const Center(
                child: SizedBox(
                  width: 42,
                  child: Divider(color: RechargeTheme.travelLine, thickness: 4),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Map results',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${state.resultCount}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: RechargeTheme.travelGreenDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RadiusControl(
                radiusMeters: state.draftQuery.radiusMeters,
                unlimited: state.draftQuery.unlimitedRadius,
                dirty: state.searchAreaDirty,
                onRadiusChanged: onRadiusChanged,
                onUnlimitedChanged: onUnlimitedChanged,
                onApplyArea: onApplyArea,
              ),
              if (scenarioRoute != null) ...<Widget>[
                const SizedBox(height: 12),
                _ScenarioRouteCard(
                  route: scenarioRoute!,
                  selectedStopIndex: selectedScenarioStopIndex,
                  routeActive: routeActive,
                  routeComplete: routeComplete,
                  onStopSelected: onScenarioStopSelected,
                  onStartRoute: onStartRoute,
                  onNextStop: onNextStop,
                  onResetRoute: onResetRoute,
                  onSaveCompletedRoute: onSaveCompletedRoute,
                  onCopyCompletedRoute: onCopyCompletedRoute,
                  onOpenBuilder: onOpenBuilder,
                  onSearchSimilar: onSearchScenarioRoute,
                  onCreateRoute: onCreateScenarioRoute,
                ),
              ],
              const SizedBox(height: 12),
              if (_shouldShowLoading(state))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.status == DiscoverFeedStatus.error)
                _SheetStateMessage(
                  message: state.message ?? 'Map search failed',
                  actionLabel: 'Retry',
                  onAction: onRetry,
                )
              else if (state.items.isEmpty)
                _SheetStateMessage(
                  message: state.message ?? 'No activities in this area',
                  actionLabel: 'Search this area',
                  onAction: onApplyArea,
                )
              else ...<Widget>[
                if (state.selectedItem != null) ...<Widget>[
                  _SelectedMapItem(
                    item: state.selectedItem!,
                    selectionMode: scenarioSelection.active,
                    selectionOrder: scenarioSelection.orderOf(
                      state.selectedItem!.id,
                    ),
                    isSaved: favoritesController.isFavorite(
                      state.selectedItem!.id,
                    ),
                    onToggleScenarioSelection: () =>
                        onToggleScenarioSelection(state.selectedItem!),
                    onAddToScenario: onAddToScenario == null
                        ? null
                        : () => onAddToScenario!(state.selectedItem!),
                    onToggleSave: () => onToggleSave(state.selectedItem!),
                    onOpenDetails: () => onOpenDetails(state.selectedItem!),
                  ),
                  const SizedBox(height: 10),
                ],
                ...state.items
                    .take(30)
                    .map(
                      (DiscoverItemEntity item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MapListItem(
                          item: item,
                          selected: item.id == state.selectedItemId,
                          selectionMode: scenarioSelection.active,
                          selectionOrder: scenarioSelection.orderOf(item.id),
                          isSaved: favoritesController.isFavorite(item.id),
                          onTap: () => onSelectItem(item),
                          onOpenDetails: () => onOpenDetails(item),
                          onToggleSave: () => onToggleSave(item),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowLoading(DiscoverFeedState state) {
    return state.items.isEmpty &&
        (state.status == DiscoverFeedStatus.initial ||
            state.status == DiscoverFeedStatus.loading);
  }
}

class _ScenarioRouteCard extends StatelessWidget {
  const _ScenarioRouteCard({
    required this.route,
    required this.selectedStopIndex,
    required this.routeActive,
    required this.routeComplete,
    required this.onStopSelected,
    required this.onStartRoute,
    required this.onNextStop,
    required this.onResetRoute,
    required this.onSaveCompletedRoute,
    required this.onCopyCompletedRoute,
    required this.onOpenBuilder,
    required this.onSearchSimilar,
    required this.onCreateRoute,
  });

  final _ScenarioMapRoute route;
  final int? selectedStopIndex;
  final bool routeActive;
  final bool routeComplete;
  final ValueChanged<int>? onStopSelected;
  final VoidCallback? onStartRoute;
  final VoidCallback? onNextStop;
  final VoidCallback? onResetRoute;
  final Future<void> Function()? onSaveCompletedRoute;
  final Future<void> Function()? onCopyCompletedRoute;
  final VoidCallback? onOpenBuilder;
  final VoidCallback? onSearchSimilar;
  final VoidCallback? onCreateRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int completedStopCount = _completedStopCount(
      stopCount: route.stops.length,
      selectedStopIndex: selectedStopIndex,
      routeActive: routeActive,
      routeComplete: routeComplete,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.travelPanel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.route, color: RechargeTheme.travelGreenDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scenario route',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: RechargeTheme.travelGreenDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${route.stops.length} stops',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: RechargeTheme.travelGreenDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${route.moodLabel} · ${route.totalDurationMinutes} min · '
              '${route.totalDistanceKm.toStringAsFixed(1)} km · '
              '${route.priceLabel}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (route.promptLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _ScenarioIntentBanner(label: route.promptLabel),
            ],
            if (selectedStopIndex != null) ...<Widget>[
              const SizedBox(height: 8),
              _FocusedStopBanner(
                step: route.stops[selectedStopIndex!],
                index: selectedStopIndex!,
                routeActive: routeActive,
                routeComplete: routeComplete,
              ),
            ],
            const SizedBox(height: 12),
            _RouteProgressControls(
              route: route,
              selectedStopIndex: selectedStopIndex,
              routeActive: routeActive,
              routeComplete: routeComplete,
              completedStopCount: completedStopCount,
              onStartRoute: onStartRoute,
              onNextStop: onNextStop,
              onResetRoute: onResetRoute,
            ),
            const SizedBox(height: 12),
            ...List<Widget>.generate(route.stops.length, (int index) {
              final ScenarioStepEntity step = route.stops[index];
              final bool selected = selectedStopIndex == index;
              final bool completed = index < completedStopCount;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == route.stops.length - 1 ? 0 : 8,
                ),
                child: Material(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onStopSelected == null
                        ? null
                        : () => onStopSelected!(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: completed
                                ? colorScheme.tertiary
                                : selected
                                ? colorScheme.secondary
                                : colorScheme.primary,
                            child: completed
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: colorScheme.onTertiary,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: selected
                                          ? colorScheme.onSecondary
                                          : colorScheme.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  step.title,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: completed
                                            ? colorScheme.tertiary
                                            : null,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  completed
                                      ? 'Completed · ${step.durationMinutes} min'
                                      : '${createTaxonomyLabelForPath(step.category)} · '
                                            '${step.durationMinutes} min',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            completed
                                ? Icons.check_circle
                                : selected
                                ? Icons.my_location
                                : Icons.location_searching,
                            color: completed
                                ? colorScheme.tertiary
                                : selected
                                ? colorScheme.secondary
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (routeComplete) ...<Widget>[
              const SizedBox(height: 10),
              _RouteCompleteBanner(
                route: route,
                onSave: onSaveCompletedRoute,
                onCopy: onCopyCompletedRoute,
              ),
            ],
            if (onOpenBuilder != null ||
                onSearchSimilar != null ||
                onCreateRoute != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpenBuilder,
                      icon: const Icon(Icons.edit_location_alt),
                      label: const Text('Edit route'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Search similar route',
                    onPressed: onSearchSimilar,
                    icon: const Icon(Icons.search),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Create route listing',
                    onPressed: onCreateRoute,
                    icon: const Icon(Icons.add_business_outlined),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioIntentBanner extends StatelessWidget {
  const _ScenarioIntentBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Intent: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedStopBanner extends StatelessWidget {
  const _FocusedStopBanner({
    required this.step,
    required this.index,
    required this.routeActive,
    required this.routeComplete,
  });

  final ScenarioStepEntity step;
  final int index;
  final bool routeActive;
  final bool routeComplete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.my_location, color: colorScheme.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                routeComplete
                    ? 'Completed at stop ${index + 1}: ${step.title}'
                    : routeActive
                    ? 'Now: stop ${index + 1} · ${step.title}'
                    : 'Focused stop ${index + 1}: ${step.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCompleteBanner extends StatelessWidget {
  const _RouteCompleteBanner({
    required this.route,
    required this.onSave,
    required this.onCopy,
  });

  final _ScenarioMapRoute route;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.celebration, color: colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route complete · ${route.stops.length} stops · '
                    '${route.totalDurationMinutes} min',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSave == null
                        ? null
                        : () async {
                            await onSave!();
                          },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy == null
                        ? null
                        : () async {
                            await onCopy!();
                          },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
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

class _RouteProgressControls extends StatelessWidget {
  const _RouteProgressControls({
    required this.route,
    required this.selectedStopIndex,
    required this.routeActive,
    required this.routeComplete,
    required this.completedStopCount,
    required this.onStartRoute,
    required this.onNextStop,
    required this.onResetRoute,
  });

  final _ScenarioMapRoute route;
  final int? selectedStopIndex;
  final bool routeActive;
  final bool routeComplete;
  final int completedStopCount;
  final VoidCallback? onStartRoute;
  final VoidCallback? onNextStop;
  final VoidCallback? onResetRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int currentStop = selectedStopIndex == null
        ? 0
        : selectedStopIndex! + 1;
    final bool atLastStop =
        selectedStopIndex != null &&
        selectedStopIndex == route.stops.length - 1;
    final String status = routeComplete
        ? 'Route complete'
        : routeActive
        ? 'Stop $currentStop of ${route.stops.length}'
        : 'Ready to start';
    final double progressValue = route.stops.isEmpty
        ? 0
        : completedStopCount / route.stops.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  routeComplete
                      ? Icons.check_circle
                      : routeActive
                      ? Icons.navigation
                      : Icons.flag,
                  color: colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${route.totalDurationMinutes} min',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue.clamp(0, 1).toDouble(),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: routeComplete
                        ? onStartRoute
                        : routeActive
                        ? onNextStop
                        : onStartRoute,
                    icon: Icon(
                      routeComplete
                          ? Icons.replay
                          : routeActive
                          ? atLastStop
                                ? Icons.check
                                : Icons.skip_next
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      routeComplete
                          ? 'Restart'
                          : routeActive
                          ? atLastStop
                                ? 'Finish'
                                : 'Next stop'
                          : 'Start route',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Reset route progress',
                  onPressed: routeActive || selectedStopIndex != null
                      ? onResetRoute
                      : null,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int _completedStopCount({
  required int stopCount,
  required int? selectedStopIndex,
  required bool routeActive,
  required bool routeComplete,
}) {
  if (routeComplete) return stopCount;
  if (!routeActive || selectedStopIndex == null) return 0;
  if (selectedStopIndex < 0) return 0;
  if (selectedStopIndex > stopCount) return stopCount;
  return selectedStopIndex;
}

class _RadiusControl extends StatelessWidget {
  const _RadiusControl({
    required this.radiusMeters,
    required this.unlimited,
    required this.dirty,
    required this.onRadiusChanged,
    required this.onUnlimitedChanged,
    required this.onApplyArea,
  });

  final double radiusMeters;
  final bool unlimited;
  final bool dirty;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onUnlimitedChanged;
  final Future<void> Function() onApplyArea;

  @override
  Widget build(BuildContext context) {
    final int radiusKm = (radiusMeters / 1000).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    unlimited ? 'Radius: any area' : 'Radius: $radiusKm km',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Any'),
                    Checkbox(
                      value: unlimited,
                      onChanged: (bool? value) {
                        onUnlimitedChanged(value ?? false);
                      },
                    ),
                  ],
                ),
              ],
            ),
            Slider(
              min: 1000,
              max: 200000,
              divisions: 40,
              value: radiusMeters.clamp(1000, 200000).toDouble(),
              onChanged: unlimited ? null : onRadiusChanged,
            ),
            if (dirty)
              FilledButton.icon(
                onPressed: onApplyArea,
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Search this area'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactRadiusControl extends StatelessWidget {
  const _CompactRadiusControl({
    required this.radiusMeters,
    required this.unlimited,
    required this.expanded,
    required this.onToggle,
    required this.onRadiusChanged,
    required this.onUnlimitedChanged,
  });

  final double radiusMeters;
  final bool unlimited;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onUnlimitedChanged;

  @override
  Widget build(BuildContext context) {
    final int radiusKm = (radiusMeters / 1000).round();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.white.withValues(alpha: 0.82),
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.radar_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        unlimited ? 'Any distance' : '$radiusKm km',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Search radius',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Checkbox(
                          value: unlimited,
                          onChanged: (bool? v) =>
                              onUnlimitedChanged(v ?? false),
                        ),
                        const Text('Any'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      min: 1000,
                      max: 100000,
                      divisions: 20,
                      value: radiusMeters.clamp(1000, 100000).toDouble(),
                      onChanged: unlimited ? null : onRadiusChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedMapItem extends StatelessWidget {
  const _SelectedMapItem({
    required this.item,
    required this.selectionMode,
    required this.selectionOrder,
    required this.isSaved,
    required this.onToggleScenarioSelection,
    required this.onAddToScenario,
    required this.onToggleSave,
    required this.onOpenDetails,
  });

  final DiscoverItemEntity item;
  final bool selectionMode;
  final int? selectionOrder;
  final bool isSaved;
  final VoidCallback onToggleScenarioSelection;
  final VoidCallback? onAddToScenario;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.travelPanel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RechargeTheme.travelGreenDark,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _metaLabel(item),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenDetails,
                    child: const Text('Open details'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save',
                  onPressed: onToggleSave,
                  icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectionMode || onAddToScenario != null)
              OutlinedButton.icon(
                onPressed: selectionMode
                    ? onToggleScenarioSelection
                    : onAddToScenario,
                icon: Icon(
                  selectionMode && selectionOrder != null
                      ? Icons.remove_circle_outline
                      : Icons.playlist_add_outlined,
                ),
                label: Text(
                  selectionMode
                      ? selectionOrder == null
                            ? 'Select for Scenario'
                            : 'Remove #$selectionOrder from selection'
                      : 'Add to Scenario',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapListItem extends StatelessWidget {
  const _MapListItem({
    required this.item,
    required this.selected,
    required this.selectionMode,
    required this.selectionOrder,
    required this.isSaved,
    required this.onTap,
    required this.onOpenDetails,
    required this.onToggleSave,
  });

  final DiscoverItemEntity item;
  final bool selected;
  final bool selectionMode;
  final int? selectionOrder;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? RechargeTheme.travelPanel : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: RechargeTheme.travelPanel,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: RechargeTheme.travelLine),
                ),
                alignment: Alignment.center,
                child: selectionOrder == null
                    ? Icon(
                        item.isPublishedRoute
                            ? Icons.route_outlined
                            : Icons.place_outlined,
                        color: RechargeTheme.travelGreenDark,
                      )
                    : CircleAvatar(
                        backgroundColor: RechargeTheme.travelGreenDark,
                        foregroundColor: Colors.white,
                        child: Text('$selectionOrder'),
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
                      _metaLabel(item),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectionMode)
                Checkbox(
                  value: selectionOrder != null,
                  onChanged: (_) => onTap(),
                )
              else ...<Widget>[
                IconButton(
                  tooltip: 'Save',
                  onPressed: onToggleSave,
                  icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
                ),
                IconButton(
                  tooltip: 'Open details',
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetStateMessage extends StatelessWidget {
  const _SheetStateMessage({
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

class _MapFilterOption {
  const _MapFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String? id;
  final String label;
  final IconData icon;
}

class _ScenarioMapRoute {
  const _ScenarioMapRoute({required this.seedParameters, required this.stops});

  final Map<String, String> seedParameters;
  final List<ScenarioStepEntity> stops;

  static _ScenarioMapRoute? fromSeed(Map<String, String> seedParameters) {
    if (seedParameters['mode'] != 'scenario') return null;
    final List<String> categories = _stepsFromParam(seedParameters['steps']);
    if (categories.isEmpty) return null;
    final List<ScenarioStepEntity> stops = scenarioStepsByCategories(
      categories,
    );
    if (stops.isEmpty) return null;
    return _ScenarioMapRoute(
      seedParameters: Map<String, String>.unmodifiable(seedParameters),
      stops: stops,
    );
  }

  int get totalDurationMinutes {
    return stops.fold<int>(
      0,
      (int total, ScenarioStepEntity step) => total + step.durationMinutes,
    );
  }

  double get totalDistanceKm {
    return stops.fold<double>(
      0,
      (double total, ScenarioStepEntity step) => total + step.distanceKm,
    );
  }

  double get totalPriceAmount {
    return stops.fold<double>(
      0,
      (double total, ScenarioStepEntity step) => total + step.priceAmount,
    );
  }

  double get centerLatitude {
    return stops.fold<double>(
          0,
          (double total, ScenarioStepEntity step) => total + step.latitude,
        ) /
        stops.length;
  }

  double get centerLongitude {
    return stops.fold<double>(
          0,
          (double total, ScenarioStepEntity step) => total + step.longitude,
        ) /
        stops.length;
  }

  String get priceLabel {
    if (totalPriceAmount == 0) return 'Free';
    return '${totalPriceAmount.toStringAsFixed(0)} €';
  }

  String get moodLabel {
    return switch (seedParameters['mood']) {
      'calm' => 'Calm',
      'social' => 'Social',
      'active' => 'Active',
      _ => 'Custom',
    };
  }

  String get moodKey {
    final String? value = seedParameters['mood']?.trim();
    if (value == null || value.isEmpty) return 'custom';
    return value;
  }

  String get promptLabel {
    final String? value = seedParameters['prompt']?.trim();
    if (value != null && value.isNotEmpty) return value;
    return '$moodLabel route with ${stops.length} stops';
  }

  String get builderLocation {
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ...scenarioParameters,
        'source': 'map_route_seed',
        'type': 'route',
        'category': 'route',
      },
    ).toString();
  }

  String get createLocation {
    final Map<String, String> params = <String, String>{
      ...scenarioParameters,
      'source': 'map_route_seed',
      'type': 'route',
      'title': '$moodLabel recharge route',
      'subtitle':
          '${stops.length} stops · '
          '$totalDurationMinutes min · '
          '${totalDistanceKm.toStringAsFixed(1)} km',
      'q': promptLabel,
      'category': 'route',
    };
    return Uri(path: RouteNames.create, queryParameters: params).toString();
  }

  String get searchLocation {
    final String? category = _searchCategoryForScenarioRoute(this);
    final Map<String, String> params = <String, String>{
      'q': promptLabel,
      if (category != null) 'category': category,
      'free': totalPriceAmount == 0 ? '1' : '0',
      'radius': '5000',
      'unlimited': '0',
    };
    return Uri(path: RouteNames.search, queryParameters: params).toString();
  }

  Map<String, String> get scenarioParameters {
    final Map<String, String> params = <String, String>{};
    for (final String key in <String>[
      'mood',
      'duration',
      'free',
      'walking',
      'prompt',
    ]) {
      final String? value = seedParameters[key];
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }
    params['steps'] = stops
        .map((ScenarioStepEntity step) => step.category)
        .join(',');
    return params;
  }
}

String? _searchCategoryForScenarioRoute(_ScenarioMapRoute route) {
  final List<String> categories = route.stops
      .map((ScenarioStepEntity step) => step.category)
      .toList(growable: false);
  if (categories.any(
    (String category) =>
        category.startsWith('sport') ||
        category.startsWith('outdoor_nature_walking'),
  )) {
    return 'outdoor_nature_walking';
  }
  if (categories.any(
    (String category) => category.startsWith('wellness_recharge'),
  )) {
    return 'wellness_recharge';
  }
  if (categories.any(
    (String category) => category.startsWith('art_culture_museums'),
  )) {
    return 'art_culture_museums';
  }
  if (categories.any(
    (String category) => category.startsWith('music_nightlife'),
  )) {
    return 'music_nightlife';
  }
  return null;
}

String _metaLabel(DiscoverItemEntity item) {
  final route = item.publishedRoute;
  if (route != null) {
    return '${item.city} · Route · '
        '${(route.distanceMeters / 1000).toStringAsFixed(1)} км · '
        '${(route.durationSeconds / 60).round()} min';
  }
  final String price = item.isFree
      ? 'Free'
      : '${item.priceAmount.toStringAsFixed(0)} €';
  return '${item.city} · ${rechargeTaxonomyLabel(item.category)} · '
      '${item.distanceKm.toStringAsFixed(1)} км · $price';
}

String _scenarioRouteSummary(_ScenarioMapRoute route) {
  final List<String> lines = <String>[
    '${route.moodLabel} recharge scenario',
    '${route.stops.length} stops · ${route.totalDurationMinutes} min · '
        '${route.totalDistanceKm.toStringAsFixed(1)} km',
    route.priceLabel,
    '',
    ...List<String>.generate(route.stops.length, (int index) {
      final ScenarioStepEntity step = route.stops[index];
      return '${index + 1}. ${step.title} - '
          '${createTaxonomyLabelForPath(step.category)}, '
          '${step.durationMinutes} min';
    }),
  ];
  return lines.join('\n');
}

List<String> _stepsFromParam(String? value) {
  if (value == null || value.trim().isEmpty) return const <String>[];
  return value
      .split(',')
      .map((String step) => step.trim())
      .where((String step) => step.isNotEmpty)
      .toList(growable: false);
}

IconData _mapCategoryIcon(String categoryId) {
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
