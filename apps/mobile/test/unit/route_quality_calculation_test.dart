import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/create/data/models/route_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_quality_data.dart';
import 'package:recharge/features/create/domain/usecases/calculate_route_quality_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_route_draft_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  const calculator = CalculateRouteQualityUseCase();

  test('missing elevation remains unavailable and never becomes zero', () {
    final route = routeFixture();

    final quality = calculator.calculate(
      route: route,
      calculatedAtUtc: DateTime.utc(2026, 7, 25, 12),
    );

    expect(
      quality.elevation.availability,
      RouteElevationAvailability.unavailable,
    );
    expect(quality.elevation.samples, isEmpty);
    expect(quality.elevation.ascentMeters, isNull);
    expect(quality.elevation.descentMeters, isNull);
    expect(quality.difficulty.missingElevation, isTrue);
    expect(quality.isCoherent, isTrue);
  });

  test('complete elevation filters an isolated spike deterministically', () {
    final route = _elevatedRoute(<double>[10, 100, 12]);

    final first = calculator.calculate(
      route: route,
      calculatedAtUtc: DateTime.utc(2026, 7, 25, 12),
    );
    final repeated = calculator.calculate(
      route: route,
      calculatedAtUtc: DateTime.utc(2026, 7, 25, 13),
    );

    expect(
      first.elevation.availability,
      RouteElevationAvailability.complete,
    );
    expect(first.elevation.samples[1].elevationMeters, 11);
    expect(first.elevation.ascentMeters, 2);
    expect(first.elevation.descentMeters, 0);
    expect(first.inputFingerprint, repeated.inputFingerprint);
  });

  test('quality and expanded POI survive schema v2 round-trip', () {
    final base = routeFixture();
    final waypoint = base.waypoints.single.copyWith(
      catalogVersion: 2,
      title: 'Steep crossing',
      description: 'Use the marked path.',
      safetyNote: 'Slippery after rain.',
      technicalAttributeIds: const <String>['steep.v1', 'roots.v1'],
      verifiedAtUtc: DateTime.utc(2026, 7, 25, 11),
    );
    final routeWithPoi = base.copyWith(
      waypoints: <RouteWaypointDraft>[waypoint],
    );
    final quality = calculator.calculate(
      route: routeWithPoi,
      calculatedAtUtc: DateTime.utc(2026, 7, 25, 12),
    );
    final source = routeWithPoi.copyWith(quality: quality);

    final json = RouteDraftMapper.toJson(source);
    final restored = RouteDraftMapper.fromJson(json);

    expect(json['schemaVersion'], 2);
    expect(restored.quality?.inputFingerprint, quality.inputFingerprint);
    expect(
      restored.quality?.difficulty.recommendedDifficultyId,
      quality.difficulty.recommendedDifficultyId,
    );
    expect(restored.waypoints.single.catalogVersion, 2);
    expect(
      restored.waypoints.single.technicalAttributeIds,
      <String>['steep.v1', 'roots.v1'],
    );
    expect(restored.waypoints.single.safetyNote, 'Slippery after rain.');
  });

  test('legacy schema v1 restores without fabricated quality', () {
    final json = RouteDraftMapper.toJson(routeFixture())
      ..['schemaVersion'] = 1
      ..remove('quality');

    final restored = RouteDraftMapper.fromJson(json);

    expect(restored.schemaVersion, RouteDraftData.currentSchemaVersion);
    expect(restored.quality, isNull);
    expect(restored.waypoints.single.catalogVersion, 1);
  });

  test('stale quality is blocked and difficulty mismatch is reviewable', () {
    final route = routeFixture();
    final hardSelection = route.copyWith(
      conditions: RouteConditionsDraft(
        difficultyId: 'hard.v1',
        surfaceIds: route.conditions.surfaceIds,
        isMarked: route.conditions.isMarked,
      ),
    );
    final mismatched = hardSelection.copyWith(
      quality: calculator.calculate(
        route: hardSelection,
        calculatedAtUtc: DateTime.utc(2026, 7, 25, 12),
      ),
    );

    final issues = ValidateRouteDraftUseCase()(
      mismatched,
      policy: routeValidationPolicy(),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('difficulty_differs_from_recommendation'),
    );

    final stale = mismatched.copyWith(geometryRevision: 99);
    final staleIssues = ValidateRouteDraftUseCase()(
      stale,
      policy: routeValidationPolicy(),
    );
    expect(
      staleIssues.map((issue) => issue.code),
      contains('quality_revision_stale'),
    );
  });
}

RouteDraftData _elevatedRoute(List<double> elevations) {
  final anchors = <RouteAnchorDraft>[
    RouteAnchorDraft(
      id: '01ANCHOR000000000000000001',
      position: GeoPoint(
        latitude: 56.9496,
        longitude: 24.1052,
        elevationMeters: elevations.first,
      ),
    ),
    RouteAnchorDraft(
      id: '01ANCHOR000000000000000002',
      position: GeoPoint(
        latitude: 56.9520,
        longitude: 24.1150,
        elevationMeters: elevations.last,
      ),
    ),
  ];
  final geometry = RouteGeometryDraft.fromPoints(<GeoPoint>[
    anchors.first.position,
    GeoPoint(
      latitude: 56.9508,
      longitude: 24.1101,
      elevationMeters: elevations[1],
    ),
    anchors.last.position,
  ]);
  final segment = routeSegment(
    id: '01SEGMENT00000000000000001',
    order: 0,
    from: anchors.first,
    to: anchors.last,
    geometry: geometry,
  );
  return routeFixture(
    anchors: anchors,
    segments: <RouteSegmentDraft>[segment],
    metrics: RouteMetricsDraft(
      geometryRevision: routeFixtureRevision,
      calculationModelId: 'walking-duration',
      calculationModelVersion: 1,
      distanceMeters: geometry.lengthMeters,
      autoDurationSeconds: 600,
      effectiveDurationSeconds: 600,
      directDistanceMeters: 0,
      fallbackDistanceMeters: 0,
      surfaceDistanceMeters: <String, double>{
        'mixed': geometry.lengthMeters,
      },
    ),
  );
}
