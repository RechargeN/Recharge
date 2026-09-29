import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:recharge/features/discover/domain/entities/published_route_discovery_entity.dart';
import 'package:recharge/features/discover/presentation/widgets/published_route_polyline_builder.dart';
import 'package:recharge/shared/primitives/geo/geo_bounds.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';

/// `docs/product/DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md` §2: the pure
/// function extracted verbatim from `discover_map_page.dart`'s
/// `_buildPolylines` Published-Route branch — proving its behavior is
/// unchanged (same id shape, same style, same silent-degrade on a bad
/// snapshot) independent of the Map page itself.
void main() {
  test('builds a Polyline matching the pre-extraction id/style/points', () {
    final PublishedRouteDiscoveryEntity route = _route(
      // Two points, ~100m apart — encodePolyline-compatible fixture.
      encodedPolyline: '_p~iF~ps|U_ulLnnqC',
    );

    final Polyline? polyline = buildPublishedRoutePolyline(route);

    expect(polyline, isNotNull);
    expect(polyline!.polylineId.value, 'published_route_route-1_v1');
    expect(polyline.width, 6);
    expect(polyline.startCap, Cap.roundCap);
    expect(polyline.endCap, Cap.roundCap);
    expect(polyline.jointType, JointType.round);
    expect(polyline.points.length, greaterThanOrEqualTo(2));
  });

  test('an incoherent route (missing id/version) returns null', () {
    final PublishedRouteDiscoveryEntity route = _route(
      routeId: '',
      encodedPolyline: '_p~iF~ps|U_ulLnnqC',
    );

    expect(buildPublishedRoutePolyline(route), isNull);
  });

  test(
    'a malformed encoded polyline degrades to null instead of throwing',
    () {
      final PublishedRouteDiscoveryEntity route = _route(
        encodedPolyline: 'not-a-valid-polyline!!!',
      );

      expect(buildPublishedRoutePolyline(route), isNull);
    },
  );

  test('a single-point decode (no usable line) returns null', () {
    final PublishedRouteDiscoveryEntity route = _route(encodedPolyline: '');

    expect(buildPublishedRoutePolyline(route), isNull);
  });
}

PublishedRouteDiscoveryEntity _route({
  String routeId = 'route-1',
  String encodedPolyline = '_p~iF~ps|U_ulLnnqC',
}) {
  return PublishedRouteDiscoveryEntity(
    routeId: routeId,
    versionId: 'v1',
    geometryHash: 'hash',
    contentHash: 'content-v1',
    title: 'Forest walking route',
    subtitle: 'A continuous trail through the forest.',
    city: 'Riga',
    marketCityId: 'riga',
    timezoneId: 'Europe/Riga',
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'walking_route',
    coverImage: 'asset://route.jpg',
    publisherName: 'Recharge',
    startPoint: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
    bounds: const GeoBounds(
      southwest: GeoPoint(latitude: 56.9496, longitude: 24.1052),
      northeast: GeoPoint(latitude: 56.9520, longitude: 24.1150),
    ),
    overviewEncodedPolyline: encodedPolyline,
    fullEncodedPolyline: encodedPolyline,
    encodingPrecision: 5,
    distanceMeters: 4200,
    durationSeconds: 2700,
    routingProfileId: 'walking',
    difficultyId: 'easy.v1',
    demoOnly: true,
    searchTokens: const <String>['forest', 'walking'],
    attributions: const <String>['OpenStreetMap contributors'],
    publishedAtUtc: DateTime.utc(2026, 7, 25, 10),
  );
}
