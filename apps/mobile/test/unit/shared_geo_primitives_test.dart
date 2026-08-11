import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart' as compatibility;
import 'package:recharge/shared/primitives/geo/geo_bounds.dart';
import 'package:recharge/shared/primitives/geo/geo_distance.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';
import 'package:recharge/shared/primitives/geo/geometry_encoding.dart';
import 'package:recharge/shared/primitives/geo/geometry_hash.dart';

void main() {
  test('core compatibility export resolves to the shared GeoPoint type', () {
    const GeoPoint shared = GeoPoint(latitude: 56.9496, longitude: 24.1052);
    const compatibility.GeoPoint legacy = compatibility.GeoPoint(
      latitude: 56.9496,
      longitude: 24.1052,
    );

    expect(legacy, shared);
  });

  test('shared geo primitives preserve validation and calculations', () {
    const GeoPoint origin = GeoPoint(latitude: 0, longitude: 0);
    const GeoPoint east = GeoPoint(latitude: 0, longitude: 1);
    const GeoBounds bounds = GeoBounds(
      southwest: GeoPoint(latitude: -1, longitude: -1),
      northeast: GeoPoint(latitude: 1, longitude: 1),
    );

    expect(origin.isValid, isTrue);
    expect(bounds.contains(east), isTrue);
    expect(GeoDistance.haversineMeters(origin, east), closeTo(111195.08, 0.1));
  });

  test('shared encoding and hash remain deterministic', () {
    const List<GeoPoint> points = <GeoPoint>[
      GeoPoint(latitude: 38.5, longitude: -120.2),
      GeoPoint(latitude: 40.7, longitude: -120.95),
      GeoPoint(latitude: 43.252, longitude: -126.453),
    ];

    final String encoded = GeometryEncoding.encode(points);
    final GeometryHash first = GeometryHash.fromPoints(points);
    final GeometryHash second = GeometryHash.fromPoints(
      GeometryEncoding.decode(encoded),
    );

    expect(encoded, '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(first, second);
  });
}
