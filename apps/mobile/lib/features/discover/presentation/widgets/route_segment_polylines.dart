import 'package:design_system/design_system.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/primitives/geo/geo_point.dart';
import '../../domain/entities/route_catalog_facts.dart';

/// DTL-RTE-02 RD-03: one [Polyline] per published segment. Explicit gaps are
/// never joined — the next segment simply starts a new line — and direct
/// segments (known only for the full track in Details) are dashed, so a
/// straight connection is never mistaken for a walked path.
///
/// The existing single-line builder for the local RTE-08 projection
/// (`published_route_polyline_builder.dart`) stays as it is.
Set<Polyline> buildRouteSegmentPolylines(
  List<RouteCatalogSegment> segments, {
  required String idPrefix,
  int width = 6,
}) {
  final Set<Polyline> lines = <Polyline>{};
  for (int index = 0; index < segments.length; index += 1) {
    final RouteCatalogSegment segment = segments[index];
    if (segment.points.length < 2) continue;
    lines.add(
      Polyline(
        polylineId: PolylineId('${idPrefix}_$index'),
        points: segment.points
            .map((GeoPoint point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        color: segment.direct
            ? RechargeTheme.travelGreenDark
            : RechargeTheme.travelGreen,
        width: width,
        patterns: segment.direct
            ? <PatternItem>[PatternItem.dash(18), PatternItem.gap(10)]
            : const <PatternItem>[],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    );
  }
  return lines;
}

/// Camera fit for the drawn segments, computed on the device from public
/// points for display only — never a published or stored bounds value (RD-04).
LatLngBounds? routeSegmentsCameraBounds(List<RouteCatalogSegment> segments) {
  double? south, west, north, east;
  for (final RouteCatalogSegment segment in segments) {
    for (final GeoPoint point in segment.points) {
      south = south == null || point.latitude < south ? point.latitude : south;
      north = north == null || point.latitude > north ? point.latitude : north;
      west = west == null || point.longitude < west ? point.longitude : west;
      east = east == null || point.longitude > east ? point.longitude : east;
    }
  }
  if (south == null || west == null || north == null || east == null) {
    return null;
  }
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}
