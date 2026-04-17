import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/application/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate_sheet.dart';
import '../../../favorites/application/controllers/favorites_controller.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';

class DiscoverMapPage extends ConsumerStatefulWidget {
  const DiscoverMapPage({super.key});

  @override
  ConsumerState<DiscoverMapPage> createState() => _DiscoverMapPageState();
}

class _DiscoverMapPageState extends ConsumerState<DiscoverMapPage> {
  late final TextEditingController _searchController;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final DiscoverFeedState state = ref.read(discoverFeedControllerProvider).state;
    _searchController = TextEditingController(text: state.appliedQuery.queryText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoverFeedControllerProvider).ensureLoaded();
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller =
        ref.watch(discoverFeedControllerProvider);
    final DiscoverFeedState state = controller.state;
    final authController = ref.watch(authControllerProvider);
    final isAuthenticated = authController.state.isAuthenticated;
    final favoritesController = ref.watch(favoritesControllerProvider);
    final LatLng center = LatLng(
      state.draftQuery.centerLat,
      state.draftQuery.centerLng,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Список',
            onPressed: () => context.push(RouteNames.discoverResults),
            icon: const Icon(Icons.view_list_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по карте',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (String value) {
                      controller.updateSearchText(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Применить',
                  onPressed: () {
                    controller.updateSearchText(_searchController.text);
                  },
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: state.appliedQuery.selectedCategoryIds.isEmpty
                        ? null
                        : state.appliedQuery.selectedCategoryIds.first,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'outdoor',
                        child: Text('Outdoor'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'wellness',
                        child: Text('Wellness'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'art',
                        child: Text('Art'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'music',
                        child: Text('Music'),
                      ),
                    ],
                    onChanged: (String? value) {
                      controller.setCategoryFilter(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Free'),
                    value: state.appliedQuery.freeOnly,
                    onChanged: controller.setFreeOnly,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: 12,
                  ),
                  myLocationButtonEnabled: false,
                  onMapCreated: (GoogleMapController mapController) {
                    _mapController = mapController;
                  },
                  circles: <Circle>{
                    if (!state.draftQuery.unlimitedRadius)
                      Circle(
                        circleId: const CircleId('search_area'),
                        center: center,
                        radius: state.draftQuery.radiusMeters,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF1C9C74),
                        fillColor: const Color(0x221C9C74),
                      ),
                  },
                  markers: _buildMarkers(
                    state: state,
                    onTap: controller.selectItem,
                  ),
                  onCameraMove: (CameraPosition position) {
                    controller.stageMapCenter(
                      lat: position.target.latitude,
                      lng: position.target.longitude,
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: <Widget>[
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        onPressed: controller.useCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'recenter',
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
                        child: const Icon(Icons.center_focus_strong),
                      ),
                    ],
                  ),
                ),
                if (state.searchAreaDirty)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 72,
                    child: FilledButton(
                      onPressed: controller.applySearchArea,
                      child: const Text('Search this area'),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 140,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: <Widget>[
                          const Text('Радиус'),
                          Expanded(
                            child: Slider(
                              min: 1000,
                              max: 200000,
                              divisions: 40,
                              value: state.draftQuery.radiusMeters
                                  .clamp(1000, 200000)
                                  .toDouble(),
                              onChanged: state.draftQuery.unlimitedRadius
                                  ? null
                                  : (double value) {
                                      controller.stageRadius(
                                        radiusMeters: value,
                                        unlimited: false,
                                      );
                                    },
                            ),
                          ),
                          Text(
                            state.draftQuery.unlimitedRadius
                                ? '∞'
                                : '${(state.draftQuery.radiusMeters / 1000).round()}км',
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: state.draftQuery.unlimitedRadius,
                            onChanged: (bool? value) {
                              controller.stageRadius(
                                radiusMeters: state.draftQuery.radiusMeters,
                                unlimited: value ?? false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 78,
                  child: FilledButton.tonal(
                    onPressed: () => context.push(RouteNames.discoverResults),
                    child: Text('Show results (${state.resultCount})'),
                  ),
                ),
                if (state.selectedItem != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _PreviewCard(
                      item: state.selectedItem!,
                      isSaved: favoritesController.isFavorite(state.selectedItem!.id),
                      onToggleSave: () => _onMapSaveTap(
                        item: state.selectedItem!,
                        isAuthenticated: isAuthenticated,
                        authController: authController,
                        favoritesController: favoritesController,
                      ),
                      onOpenDetails: () =>
                          context.push('${RouteNames.discoverDetails}/${state.selectedItem!.id}'),
                      onOpenList: () => context.push(RouteNames.discoverResults),
                    ),
                  ),
                if (state.status == DiscoverFeedStatus.empty)
                  const _OverlayState(
                    title: 'В зоне нет результатов',
                    message: 'Увеличьте радиус, измените бюджет или время',
                  ),
                if (state.status == DiscoverFeedStatus.error)
                  _OverlayState(
                    title: 'Ошибка загрузки',
                    message: state.message ?? 'Попробуйте снова',
                    actionLabel: 'Retry',
                    onAction: controller.loadFeed,
                  ),
                if (state.isDenseCluster)
                  const Positioned(
                    bottom: 46,
                    right: 12,
                    child: Chip(label: Text('Cluster mode')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers({
    required DiscoverFeedState state,
    required ValueChanged<String?> onTap,
  }) {
    final List<DiscoverItemEntity> items = state.canShowRawMarkers
        ? state.items
        : state.items.take(120).toList(growable: false);

    return items
        .map(
          (DiscoverItemEntity item) => Marker(
            markerId: MarkerId(item.id),
            position: LatLng(item.latitude, item.longitude),
            onTap: () => onTap(item.id),
            infoWindow: InfoWindow(
              title: item.title,
              snippet: item.isFree ? 'Free' : '${item.priceAmount.toStringAsFixed(0)} €',
            ),
          ),
        )
        .toSet();
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
    );
  }
}

class _OverlayState extends StatelessWidget {
  const _OverlayState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: const Color(0xCCFFFFFF),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(message),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.item,
    required this.isSaved,
    required this.onToggleSave,
    required this.onOpenDetails,
    required this.onOpenList,
  });

  final DiscoverItemEntity item;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.city} · ${item.distanceKm.toStringAsFixed(1)} км · ${item.isFree ? 'Free' : '${item.priceAmount.toStringAsFixed(0)} €'}',
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
                  icon: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
                IconButton(
                  tooltip: 'Open list',
                  onPressed: onOpenList,
                  icon: const Icon(Icons.view_list),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
