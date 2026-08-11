import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_distance.dart';
import 'package:recharge/core/geo/geo_point.dart' as core;
import 'package:recharge/core/geo/geometry_encoding.dart';
import 'package:recharge/core/geo/geometry_hash.dart';
import 'package:recharge/features/discover/domain/entities/geo_point.dart'
    as discover;

void main() {
  group('GeoPoint', () {
    test('Discover compatibility export resolves to the canonical type', () {
      final core.GeoPoint point = const discover.GeoPoint(
        latitude: 56.9496,
        longitude: 24.1052,
      );

      expect(point, const core.GeoPoint(latitude: 56.9496, longitude: 24.1052));
      expect(point.toMap(), <String, Object?>{
        'latitude': 56.9496,
        'longitude': 24.1052,
      });
      expect(core.GeoPoint.fromMap(point.toMap()), point);
    });

    test('validates finite WGS 84 coordinate ranges', () {
      expect(
        const core.GeoPoint(latitude: -90, longitude: -180).isValid,
        isTrue,
      );
      expect(const core.GeoPoint(latitude: 90, longitude: 180).isValid, isTrue);
      expect(
        const core.GeoPoint(latitude: 90.00001, longitude: 0).isValid,
        isFalse,
      );
      expect(
        const core.GeoPoint(latitude: 0, longitude: -180.00001).isValid,
        isFalse,
      );
      expect(
        core.GeoPoint(latitude: double.nan, longitude: 0).isValid,
        isFalse,
      );
      expect(
        core.GeoPoint(
          latitude: 0,
          longitude: 0,
          elevationMeters: double.infinity,
        ).isValid,
        isFalse,
      );
      expect(
        () => const core.GeoPoint(latitude: 91, longitude: 0).validated(),
        throwsArgumentError,
      );
    });

    test('preserves optional finite elevation without changing 2D maps', () {
      const elevated = core.GeoPoint(
        latitude: 56.9496,
        longitude: 24.1052,
        elevationMeters: 18.4,
      );

      expect(elevated.isValid, isTrue);
      expect(elevated.toMap(), <String, Object?>{
        'latitude': 56.9496,
        'longitude': 24.1052,
        'elevationMeters': 18.4,
      });
      expect(core.GeoPoint.fromMap(elevated.toMap()), elevated);
      expect(
        const core.GeoPoint(latitude: 56.9496, longitude: 24.1052).toMap(),
        isNot(contains('elevationMeters')),
      );
    });
  });

  group('GeoBounds', () {
    test('contains boundary points and round-trips through a map', () {
      const bounds = GeoBounds(
        southwest: core.GeoPoint(latitude: 56, longitude: 23),
        northeast: core.GeoPoint(latitude: 57, longitude: 25),
      );

      expect(bounds.isValid, isTrue);
      expect(
        bounds.contains(const core.GeoPoint(latitude: 56, longitude: 23)),
        isTrue,
      );
      expect(
        bounds.contains(const core.GeoPoint(latitude: 56.5, longitude: 24)),
        isTrue,
      );
      expect(
        bounds.contains(const core.GeoPoint(latitude: 57.1, longitude: 24)),
        isFalse,
      );
      expect(GeoBounds.fromMap(bounds.toMap()), bounds);
    });

    test('supports a box that crosses the antimeridian', () {
      const bounds = GeoBounds(
        southwest: core.GeoPoint(latitude: -10, longitude: 170),
        northeast: core.GeoPoint(latitude: 10, longitude: -170),
      );

      expect(bounds.crossesAntimeridian, isTrue);
      expect(
        bounds.contains(const core.GeoPoint(latitude: 0, longitude: 179)),
        isTrue,
      );
      expect(
        bounds.contains(const core.GeoPoint(latitude: 0, longitude: -179)),
        isTrue,
      );
      expect(
        bounds.contains(const core.GeoPoint(latitude: 0, longitude: 0)),
        isFalse,
      );
    });

    test('rejects an inverted latitude range', () {
      const bounds = GeoBounds(
        southwest: core.GeoPoint(latitude: 20, longitude: 10),
        northeast: core.GeoPoint(latitude: 10, longitude: 30),
      );

      expect(bounds.isValid, isFalse);
      expect(
        bounds.contains(const core.GeoPoint(latitude: 15, longitude: 20)),
        isFalse,
      );
      expect(bounds.validated, throwsArgumentError);
    });
  });

  group('GeoDistance', () {
    test('calculates a stable great-circle distance', () {
      const origin = core.GeoPoint(latitude: 0, longitude: 0);
      const oneDegreeEast = core.GeoPoint(latitude: 0, longitude: 1);

      expect(
        GeoDistance.haversineMeters(origin, oneDegreeEast),
        closeTo(111195.08, 0.1),
      );
      expect(GeoDistance.haversineMeters(origin, origin), 0);
    });

    test('sums adjacent polyline segments and handles empty input', () {
      const points = <core.GeoPoint>[
        core.GeoPoint(latitude: 0, longitude: 0),
        core.GeoPoint(latitude: 0, longitude: 1),
        core.GeoPoint(latitude: 0, longitude: 2),
      ];

      expect(GeoDistance.polylineLengthMeters(points), closeTo(222390.16, 0.2));
      expect(GeoDistance.polylineLengthMeters(const []), 0);
    });
  });

  group('GeometryEncoding', () {
    const canonicalPoints = <core.GeoPoint>[
      core.GeoPoint(latitude: 38.5, longitude: -120.2),
      core.GeoPoint(latitude: 40.7, longitude: -120.95),
      core.GeoPoint(latitude: 43.252, longitude: -126.453),
    ];
    const canonicalEncoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

    test('matches the canonical encoded-polyline fixture', () {
      expect(GeometryEncoding.encode(canonicalPoints), canonicalEncoded);
      expect(GeometryEncoding.decode(canonicalEncoded), canonicalPoints);
    });

    test('round-trips deterministic high-precision coordinate sets', () {
      final points = List<core.GeoPoint>.generate(
        101,
        (index) => core.GeoPoint(
          latitude: -50 + index * 0.731234,
          longitude: -170 + index * 2.931234,
        ),
      );

      final encoded = GeometryEncoding.encode(
        points,
        policy: GeometryEncodingPolicy.highPrecision,
      );
      final decoded = GeometryEncoding.decode(
        encoded,
        policy: GeometryEncodingPolicy.highPrecision,
      );

      expect(decoded, hasLength(points.length));
      for (var index = 0; index < points.length; index += 1) {
        expect(
          decoded[index].latitude,
          closeTo(points[index].latitude, 0.000001),
        );
        expect(
          decoded[index].longitude,
          closeTo(points[index].longitude, 0.000001),
        );
      }
      expect(
        GeometryEncoding.encode(
          decoded,
          policy: GeometryEncodingPolicy.highPrecision,
        ),
        encoded,
      );
    });

    test('rejects malformed, invalid, or unsupported input', () {
      expect(() => GeometryEncoding.decode('~'), throwsFormatException);
      expect(() => GeometryEncoding.decode(' '), throwsFormatException);
      expect(
        () => GeometryEncoding.encode(const [
          core.GeoPoint(latitude: 100, longitude: 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => GeometryEncoding.encode(
          const [],
          policy: const GeometryEncodingPolicy(precision: 9),
        ),
        throwsRangeError,
      );
    });
  });

  group('GeometryHash', () {
    const points = <core.GeoPoint>[
      core.GeoPoint(latitude: 56.9496, longitude: 24.1052),
      core.GeoPoint(latitude: 56.9501, longitude: 24.112),
    ];

    test('is deterministic and records its canonical policy', () {
      final first = GeometryHash.fromPoints(points);
      final second = GeometryHash.fromPoints(List.of(points));

      expect(first, second);
      expect(first.value, hasLength(64));
      expect(first.value, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(first.encodingPolicyId, GeometryEncodingPolicy.standard.id);
      expect(GeometryHash.algorithm, 'sha256');
    });

    test('changes with point order and encoding policy', () {
      final standard = GeometryHash.fromPoints(points);
      final reversed = GeometryHash.fromPoints(points.reversed);
      final highPrecision = GeometryHash.fromPoints(
        points,
        policy: GeometryEncodingPolicy.highPrecision,
      );

      expect(reversed.value, isNot(standard.value));
      expect(highPrecision.value, isNot(standard.value));
    });
  });
}
