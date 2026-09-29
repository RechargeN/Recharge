import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/repositories/collection_item_resolution_repository.dart';

/// Mini-map of a Collection's live-resolved items
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §13, Вопрос 13, CLG-AC-22). Shows
/// nothing when fewer than two distinct public points are available — a
/// single pin or an empty map is not a useful "guide by area" preview.
/// Every point comes from the live resolve result passed in; this widget
/// never falls back to a cached/authoring-time snapshot.
class CollectionDetailsMiniMap extends StatelessWidget {
  const CollectionDetailsMiniMap({super.key, required this.resolvedItems});

  final List<CollectionResolvedItem> resolvedItems;

  @override
  Widget build(BuildContext context) {
    final List<CollectionResolvedItem> withPoints = resolvedItems
        .where(
          (CollectionResolvedItem item) =>
              item.status == PublishedCollectionItemStatus.ready &&
              item.publicMapPoint != null,
        )
        .toList(growable: false);
    if (withPoints.length < 2) return const SizedBox.shrink();

    final Set<Marker> markers = withPoints
        .map(
          (CollectionResolvedItem item) => Marker(
            markerId: MarkerId(item.ref.stableKey),
            position: LatLng(
              item.publicMapPoint!.latitude,
              item.publicMapPoint!.longitude,
            ),
            infoWindow: InfoWindow(title: item.card?.title ?? ''),
          ),
        )
        .toSet();

    double minLat = withPoints.first.publicMapPoint!.latitude;
    double maxLat = minLat;
    double minLng = withPoints.first.publicMapPoint!.longitude;
    double maxLng = minLng;
    for (final CollectionResolvedItem item in withPoints) {
      final double lat = item.publicMapPoint!.latitude;
      final double lng = item.publicMapPoint!.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    final LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    return Semantics(
      label:
          'Map of ${withPoints.length} places in this Collection. '
          'Use the list below to browse them without the map.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 12),
            markers: markers,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 24),
              );
            },
          ),
        ),
      ),
    );
  }
}
