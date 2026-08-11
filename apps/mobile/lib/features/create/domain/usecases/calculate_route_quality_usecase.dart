import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../../core/geo/geo_distance.dart';
import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_quality_data.dart';
import '../repositories/route_quality_calculator.dart';

class RouteQualityCalculationPolicy {
  const RouteQualityCalculationPolicy({
    this.modelId = 'recharge.route.quality',
    this.modelVersion = 1,
    this.elevationNoiseThresholdMeters = 1,
    this.elevationSpikeThresholdMeters = 40,
    this.easyScoreUpperBound = 1.5,
    this.moderateScoreUpperBound = 3.5,
  });

  final String modelId;
  final int modelVersion;
  final double elevationNoiseThresholdMeters;
  final double elevationSpikeThresholdMeters;
  final double easyScoreUpperBound;
  final double moderateScoreUpperBound;

  bool get isValid =>
      modelId.trim().isNotEmpty &&
      modelVersion > 0 &&
      elevationNoiseThresholdMeters.isFinite &&
      elevationNoiseThresholdMeters >= 0 &&
      elevationSpikeThresholdMeters.isFinite &&
      elevationSpikeThresholdMeters > elevationNoiseThresholdMeters &&
      easyScoreUpperBound.isFinite &&
      easyScoreUpperBound > 0 &&
      moderateScoreUpperBound.isFinite &&
      moderateScoreUpperBound > easyScoreUpperBound;
}

class CalculateRouteQualityUseCase implements RouteQualityCalculator {
  const CalculateRouteQualityUseCase({
    this.policy = const RouteQualityCalculationPolicy(),
  });

  final RouteQualityCalculationPolicy policy;

  @override
  RouteQualityDraft calculate({
    required RouteDraftData route,
    required DateTime calculatedAtUtc,
  }) {
    if (!policy.isValid) {
      throw StateError('Route quality calculation policy is invalid.');
    }
    if (!calculatedAtUtc.isUtc) {
      throw ArgumentError.value(
        calculatedAtUtc,
        'calculatedAtUtc',
        'Must be UTC.',
      );
    }

    final trackPoints = _trackPoints(route);
    final elevation = _elevationProfile(route, trackPoints);
    final surfaces = route.metrics.surfaceDistanceMeters.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => RouteSurfaceMetricDraft(
            surfaceId: entry.key,
            distanceMeters: entry.value,
            source: RouteQualitySource.derived,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.surfaceId.compareTo(right.surfaceId));
    final knownSurfaceDistance = surfaces.fold<double>(
      0,
      (total, surface) => total + surface.distanceMeters,
    );
    final double unknownSurfaceDistance = math.max(
      0.0,
      route.metrics.distanceMeters - knownSurfaceDistance,
    );
    final difficulty = _difficulty(
      route: route,
      elevation: elevation,
      unknownSurfaceDistance: unknownSurfaceDistance,
    );
    final fingerprint = _fingerprint(
      route,
      surfaces,
      elevation,
      unknownSurfaceDistance,
    );

    return RouteQualityDraft(
      geometryRevision: route.geometryRevision,
      calculationModelId: policy.modelId,
      calculationModelVersion: policy.modelVersion,
      inputFingerprint: fingerprint,
      calculatedAtUtc: calculatedAtUtc,
      elevation: elevation,
      surfaces: surfaces,
      unknownSurfaceDistanceMeters: unknownSurfaceDistance,
      difficulty: difficulty,
      verifications:
          route.quality?.verifications ??
          const <RouteVerificationRecordDraft>[],
    );
  }

  RouteElevationProfileDraft _elevationProfile(
    RouteDraftData route,
    List<_TrackPoint> trackPoints,
  ) {
    final available = trackPoints
        .where((point) => point.point.elevationMeters != null)
        .toList(growable: false);
    if (available.isEmpty) {
      return RouteElevationProfileDraft(
        availability: RouteElevationAvailability.unavailable,
        source: RouteQualitySource.unavailable,
        samples: const <RouteElevationSampleDraft>[],
      );
    }

    final source = switch (route.creationMethod) {
      RouteCreationMethod.recordedGps => RouteQualitySource.recorded,
      RouteCreationMethod.importedGpx => RouteQualitySource.provider,
      _ => RouteQualitySource.derived,
    };
    if (available.length != trackPoints.length || available.length < 2) {
      return RouteElevationProfileDraft(
        availability: RouteElevationAvailability.partial,
        source: source,
        samples: available
            .map(
              (point) => RouteElevationSampleDraft(
                distanceFromStartMeters: point.distanceFromStartMeters,
                elevationMeters: point.point.elevationMeters!,
              ),
            )
            .toList(growable: false),
      );
    }

    final normalizedElevations = _filterElevationSpikes(
      available.map((point) => point.point.elevationMeters!).toList(),
    );
    var ascent = 0.0;
    var descent = 0.0;
    for (var index = 1; index < normalizedElevations.length; index += 1) {
      final delta = normalizedElevations[index] - normalizedElevations[index - 1];
      if (delta.abs() < policy.elevationNoiseThresholdMeters) continue;
      if (delta > 0) {
        ascent += delta;
      } else {
        descent += -delta;
      }
    }

    return RouteElevationProfileDraft(
      availability: RouteElevationAvailability.complete,
      source: source,
      samples: <RouteElevationSampleDraft>[
        for (var index = 0; index < available.length; index += 1)
          RouteElevationSampleDraft(
            distanceFromStartMeters:
                available[index].distanceFromStartMeters,
            elevationMeters: normalizedElevations[index],
          ),
      ],
      ascentMeters: ascent,
      descentMeters: descent,
      minimumElevationMeters: normalizedElevations.reduce(
        (left, right) => left < right ? left : right,
      ),
      maximumElevationMeters: normalizedElevations.reduce(
        (left, right) => left > right ? left : right,
      ),
      attribution: _elevationAttribution(route),
    );
  }

  List<double> _filterElevationSpikes(List<double> elevations) {
    if (elevations.length < 3) return List<double>.of(elevations);
    final result = List<double>.of(elevations);
    for (var index = 1; index < elevations.length - 1; index += 1) {
      final previous = elevations[index - 1];
      final current = elevations[index];
      final next = elevations[index + 1];
      final isolatedSpike =
          (current - previous).abs() >= policy.elevationSpikeThresholdMeters &&
          (current - next).abs() >= policy.elevationSpikeThresholdMeters &&
          (previous - next).abs() <
              policy.elevationSpikeThresholdMeters / 2;
      if (isolatedSpike) result[index] = (previous + next) / 2;
    }
    return result;
  }

  RouteDifficultyAssessmentDraft _difficulty({
    required RouteDraftData route,
    required RouteElevationProfileDraft elevation,
    required double unknownSurfaceDistance,
  }) {
    final distanceKm = route.metrics.distanceMeters / 1000;
    final ascent = elevation.ascentMeters;
    final directDistance =
        route.metrics.directDistanceMeters +
        route.metrics.fallbackDistanceMeters;
    final directShare = route.metrics.distanceMeters <= 0
        ? 0.0
        : directDistance / route.metrics.distanceMeters;
    final unknownSurfaceShare = route.metrics.distanceMeters <= 0
        ? 0.0
        : unknownSurfaceDistance / route.metrics.distanceMeters;
    final technicalAttributeCount = route.waypoints.fold<int>(
      0,
      (total, waypoint) => total + waypoint.technicalAttributeIds.length,
    );
    final score =
        distanceKm / 5 +
        (ascent ?? 0) / 200 +
        directShare * 2 +
        unknownSurfaceShare * 0.5 +
        technicalAttributeCount * 0.25;
    final recommended = score < policy.easyScoreUpperBound
        ? 'easy.v1'
        : score < policy.moderateScoreUpperBound
        ? 'moderate.v1'
        : 'hard.v1';
    final authorSelection = route.conditions.difficultyId;

    return RouteDifficultyAssessmentDraft(
      recommendedDifficultyId: recommended,
      modelId: '${policy.modelId}.difficulty',
      modelVersion: policy.modelVersion,
      score: score,
      missingElevation:
          elevation.availability != RouteElevationAvailability.complete,
      unknownSurfaceDistanceMeters: unknownSurfaceDistance,
      differsFromAuthorSelection:
          authorSelection != null && authorSelection != recommended,
    );
  }

  List<_TrackPoint> _trackPoints(RouteDraftData route) {
    final result = <_TrackPoint>[];
    var distance = 0.0;
    GeoPoint? previous;
    for (final segment in route.orderedSegments) {
      for (final point in segment.geometry.points) {
        if (previous != null && previous == point) continue;
        if (previous != null) {
          distance += GeoDistance.haversineMeters(previous, point);
        }
        result.add(
          _TrackPoint(point: point, distanceFromStartMeters: distance),
        );
        previous = point;
      }
    }
    return result;
  }

  String _fingerprint(
    RouteDraftData route,
    List<RouteSurfaceMetricDraft> surfaces,
    RouteElevationProfileDraft elevation,
    double unknownSurfaceDistance,
  ) {
    final buffer = StringBuffer()
      ..write('${policy.modelId}:${policy.modelVersion}|')
      ..write('${route.geometryRevision}|${route.profile.id}|')
      ..write('${route.conditions.difficultyId ?? ''}|')
      ..write('${unknownSurfaceDistance.toStringAsFixed(3)}|');
    for (final segment in route.orderedSegments) {
      buffer.write('${segment.id}:${segment.geometry.geometryHash}|');
    }
    for (final surface in surfaces) {
      buffer.write(
        '${surface.surfaceId}:${surface.distanceMeters.toStringAsFixed(3)}|',
      );
    }
    for (final sample in elevation.samples) {
      buffer.write(
        '${sample.distanceFromStartMeters.toStringAsFixed(3)}:'
        '${sample.elevationMeters.toStringAsFixed(3)}|',
      );
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  String? _elevationAttribution(RouteDraftData route) {
    final attributions = route.segments
        .map((segment) => segment.provenance.provider?.attribution)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return attributions.isEmpty ? null : attributions.join(' · ');
  }
}

class _TrackPoint {
  const _TrackPoint({
    required this.point,
    required this.distanceFromStartMeters,
  });

  final GeoPoint point;
  final double distanceFromStartMeters;
}
