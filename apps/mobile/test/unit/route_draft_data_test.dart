import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/geo/geometry_encoding.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  group('RouteGeometryDraft', () {
    test('uses a stable canonical encoded geometry and hash fixture', () {
      const points = <GeoPoint>[
        GeoPoint(latitude: 38.5, longitude: -120.2),
        GeoPoint(latitude: 40.7, longitude: -120.95),
        GeoPoint(latitude: 43.252, longitude: -126.453),
      ];

      final geometry = RouteGeometryDraft.fromPoints(points);

      expect(geometry.encodedPolyline, '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(
        geometry.geometryHash,
        '2305f42b979655135bb52e1ca72219b3800c13c52d0186a7173ad6e636e38a5b',
      );
      expect(GeometryEncoding.decode(geometry.encodedPolyline), points);
      expect(geometry.matchesCanonicalRepresentation, isTrue);
    });

    test('builds minimal antimeridian-aware bounds', () {
      final geometry = RouteGeometryDraft.fromPoints(const <GeoPoint>[
        GeoPoint(latitude: -5, longitude: 179),
        GeoPoint(latitude: 5, longitude: -179),
      ]);

      expect(geometry.bounds.crossesAntimeridian, isTrue);
      expect(
        geometry.bounds.contains(const GeoPoint(latitude: 0, longitude: 180)),
        isTrue,
      );
      expect(
        geometry.bounds.contains(const GeoPoint(latitude: 0, longitude: 0)),
        isFalse,
      );
    });

    test('keeps elevation independent from the two-dimensional line hash', () {
      final withoutElevation = RouteGeometryDraft.fromPoints(const <GeoPoint>[
        GeoPoint(latitude: 56.94, longitude: 24.10),
        GeoPoint(latitude: 56.95, longitude: 24.11),
      ]);
      final withElevation = RouteGeometryDraft.fromPoints(const <GeoPoint>[
        GeoPoint(latitude: 56.94, longitude: 24.10, elevationMeters: 12),
        GeoPoint(latitude: 56.95, longitude: 24.11, elevationMeters: 18),
      ]);

      expect(withElevation.geometryHash, withoutElevation.geometryHash);
      expect(withElevation.encodedPolyline, withoutElevation.encodedPolyline);
    });

    test('rejects empty and invalid source geometry', () {
      expect(
        () => RouteGeometryDraft.fromPoints(const <GeoPoint>[]),
        throwsArgumentError,
      );
      expect(
        () => RouteGeometryDraft.fromPoints(const <GeoPoint>[
          GeoPoint(latitude: 100, longitude: 0),
        ]),
        throwsArgumentError,
      );
    });

    test('detects bounds that do not describe the canonical points', () {
      final canonical = RouteGeometryDraft.fromPoints(const <GeoPoint>[
        GeoPoint(latitude: 56.94, longitude: 24.10),
        GeoPoint(latitude: 56.95, longitude: 24.11),
      ]);
      final corrupt = RouteGeometryDraft(
        points: canonical.points,
        encodingPolicy: canonical.encodingPolicy,
        encodedPolyline: canonical.encodedPolyline,
        geometryHash: canonical.geometryHash,
        bounds: const GeoBounds(
          southwest: GeoPoint(latitude: 0, longitude: 0),
          northeast: GeoPoint(latitude: 1, longitude: 1),
        ),
        lengthMeters: canonical.lengthMeters,
      );

      expect(corrupt.matchesCanonicalRepresentation, isFalse);
    });
  });

  group('RouteDraftData', () {
    test('defensively freezes collections and derives ordered values', () {
      final anchors = <RouteAnchorDraft>[
        routeAnchor('01ANCHOR000000000000000001', 56.94, 24.10),
        routeAnchor('01ANCHOR000000000000000002', 56.95, 24.11),
      ];
      final segment = routeSegment(
        id: '01SEGMENT00000000000000001',
        order: 0,
        from: anchors[0],
        to: anchors[1],
      );
      final route = routeFixture(
        anchors: anchors,
        segments: <RouteSegmentDraft>[segment],
        waypoints: const <RouteWaypointDraft>[],
      );

      anchors.clear();

      expect(route.anchors, hasLength(2));
      expect(
        () => route.anchors.add(route.anchors.first),
        throwsUnsupportedError,
      );
      expect(route.orderedSegments.single, same(segment));
      expect(route.geometryPointCount, segment.geometry.pointCount);
      expect(route.calculatedDistanceMeters, segment.distanceMeters);
    });

    test('preference values are typed and immutable', () {
      final source = <String, RoutePreferenceValue>{
        'avoid_stairs': const RouteBoolPreferenceValue(true),
        'maximum_slope': const RouteNumberPreferenceValue(8),
        'surface': const RouteTextPreferenceValue('unpaved'),
      };
      final preferences = RouteRoutingPreferences(values: source);

      source.clear();

      expect(preferences.isValid, isTrue);
      expect(preferences.values, hasLength(3));
      expect(
        () => preferences.values['new'] = const RouteBoolPreferenceValue(false),
        throwsUnsupportedError,
      );
      expect(
        RouteRoutingPreferences(
          values: const <String, RoutePreferenceValue>{
            'slope': RouteNumberPreferenceValue(double.nan),
          },
        ).isValid,
        isFalse,
      );
    });
  });
}
