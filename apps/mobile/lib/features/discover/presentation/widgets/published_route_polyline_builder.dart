import 'package:design_system/design_system.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/primitives/geo/geo_point.dart';
import '../../../../shared/primitives/geo/geometry_encoding.dart';
import '../../domain/entities/published_route_discovery_entity.dart';

/// Pure function: `PublishedRouteDiscoveryEntity → Polyline?`
/// (`docs/product/DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md` §1.1.1/§2).
///
/// Extracted verbatim from the Published-Route branch of
/// `discover_map_page.dart`'s `_buildPolylines` — the **only** branch:
/// `_buildPolylines` also independently builds a Scenario-route polyline
/// from `scenarioRoute.stops`, which stays inline in that file, untouched
/// by this slice. Reused by both the Map page and `RouteDetailsRenderer`'s
/// map-hero so the two never draw the same route differently.
///
/// Returns `null` when [route] isn't coherent, decodes to fewer than 2
/// points, or the encoded polyline is malformed/uses an unsupported
/// precision — the same silent-degrade behavior `discover_map_page.dart`
/// already had (a bad snapshot is ignored, not surfaced as an error or
/// used to trigger rerouting).
Polyline? buildPublishedRoutePolyline(PublishedRouteDiscoveryEntity route) {
  if (!route.isCoherent) return null;
  try {
    final List<GeoPoint> points = GeometryEncoding.decode(
      route.fullEncodedPolyline,
      policy: GeometryEncodingPolicy(precision: route.encodingPrecision),
    );
    if (points.length < 2) return null;
    return Polyline(
      polylineId: PolylineId(
        'published_route_${route.routeId}_${route.versionId}',
      ),
      points: points
          .map((GeoPoint point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false),
      color: RechargeTheme.travelGreen,
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}
