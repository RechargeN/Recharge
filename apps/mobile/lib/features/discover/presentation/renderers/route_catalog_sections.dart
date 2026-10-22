import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/recharge_taxonomy.dart';
import '../../domain/entities/route_catalog_facts.dart';
import '../shell/compatibility_object_renderer.dart';
import '../widgets/route_catalog_labels.dart';
import '../widgets/route_segment_polylines.dart';

/// DTL-RTE-02: the Route Details sections for a Route read from the server
/// Catalog. They show only what the public snapshot carries: no duration, no
/// bounds, no difficulty, surface or POI count (RD-01, RD-12).

/// Map hero over the full trimmed track: one line per segment, gaps open,
/// direct segments dashed (RD-03); geometry-derived start and end pins only.
class RouteCatalogMapHero extends StatelessWidget {
  const RouteCatalogMapHero({
    super.key,
    required this.facts,
    required this.onOpenMap,
  });

  final RouteCatalogFacts facts;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final List<RouteCatalogSegment> segments = facts.track ?? facts.preview;
    final Set<Polyline> lines = buildRouteSegmentPolylines(
      segments,
      idPrefix: 'catalog_route_details',
    );
    final LatLngBounds? bounds = routeSegmentsCameraBounds(segments);
    final RouteCatalogSegment? last = segments.isEmpty ? null : segments.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.35,
          child: lines.isEmpty || bounds == null || last == null
              ? const _RouteCatalogMapUnavailable()
              : GoogleMap(
                  key: const Key('route-catalog-map'),
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (bounds.southwest.latitude + bounds.northeast.latitude) /
                          2,
                      (bounds.southwest.longitude +
                              bounds.northeast.longitude) /
                          2,
                    ),
                    zoom: 13,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(bounds, 40),
                    );
                  },
                  polylines: lines,
                  markers: <Marker>{
                    Marker(
                      markerId: const MarkerId('route_start'),
                      position: LatLng(
                        facts.start.latitude,
                        facts.start.longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                    Marker(
                      markerId: const MarkerId('route_end'),
                      position: LatLng(
                        last.points.last.latitude,
                        last.points.last.longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  },
                  liteModeEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: RechargeTheme.travelPanel),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              key: const Key('route-catalog-open-map'),
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Открыть на карте'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteCatalogMapUnavailable extends StatelessWidget {
  const _RouteCatalogMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: RechargeTheme.travelPanel),
      child: Center(
        child: Text(
          'Не удалось загрузить карту маршрута',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Distance and elevation as the snapshot has them; an absent value is not
/// shown and never becomes zero (RD-12).
class RouteCatalogSummaryCard extends StatelessWidget {
  const RouteCatalogSummaryCard({super.key, required this.facts});

  final RouteCatalogFacts facts;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('Расстояние', routeCatalogDistanceLabel(facts)),
      if (facts.ascentMeters != null)
        ('Набор высоты', '${facts.ascentMeters!.round()} м'),
      if (facts.descentMeters != null)
        ('Сброс высоты', '${facts.descentMeters!.round()} м'),
      if (facts.minElevationMeters != null && facts.maxElevationMeters != null)
        (
          'Высота',
          '${facts.minElevationMeters!.round()}–'
              '${facts.maxElevationMeters!.round()} м',
        ),
    ];
    return Card(
      key: const Key('route-catalog-summary'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (String label, String value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(label)),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shape, profile, category, publisher kind, gaps and direct segments.
class RouteCatalogFactsCard extends StatelessWidget {
  const RouteCatalogFactsCard({
    super.key,
    required this.facts,
    required this.categoryId,
  });

  final RouteCatalogFacts facts;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('route-catalog-facts'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            DetailsPill(label: routeCatalogShapeLabel(facts.shape)),
            DetailsPill(label: routeProfileLabelForDetails(facts.profileId)),
            DetailsPill(label: rechargeTaxonomyLabel(categoryId)),
            DetailsPill(
              key: const Key('route-catalog-publisher'),
              label: routeCatalogPublisherLabel(facts),
            ),
            if (facts.gapCount > 0)
              DetailsPill(
                key: const Key('route-catalog-gaps'),
                label: 'Разрывов трека: ${facts.gapCount}',
              ),
            if (facts.directSegmentCount > 0)
              DetailsPill(
                key: const Key('route-catalog-direct'),
                label: 'Прямых участков: ${facts.directSegmentCount}',
              ),
          ],
        ),
      ),
    );
  }
}

/// Public waypoints in track order (RTE-PUB-01 RP-09); no private notes exist.
class RouteCatalogWaypointsCard extends StatelessWidget {
  const RouteCatalogWaypointsCard({super.key, required this.waypoints});

  final List<RouteCatalogWaypoint> waypoints;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('route-catalog-waypoints'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Точки на маршруте',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final RouteCatalogWaypoint waypoint in waypoints)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(waypoint.title ?? waypoint.typeId),
                subtitle: Text(
                  <String>[
                    '${(waypoint.distanceFromStartMeters / 1000).toStringAsFixed(1)} км от старта',
                    ?waypoint.safetyNote,
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
