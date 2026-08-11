enum RouteQualitySource {
  recorded,
  selfHosted,
  provider,
  author,
  derived,
  unavailable,
}

enum RouteElevationAvailability { complete, partial, unavailable }

enum RouteVerificationKind { technical, field }

class RouteElevationSampleDraft {
  const RouteElevationSampleDraft({
    required this.distanceFromStartMeters,
    required this.elevationMeters,
  });

  final double distanceFromStartMeters;
  final double elevationMeters;

  bool get isValid =>
      distanceFromStartMeters.isFinite &&
      distanceFromStartMeters >= 0 &&
      elevationMeters.isFinite;
}

class RouteElevationProfileDraft {
  RouteElevationProfileDraft({
    required this.availability,
    required this.source,
    required Iterable<RouteElevationSampleDraft> samples,
    this.ascentMeters,
    this.descentMeters,
    this.minimumElevationMeters,
    this.maximumElevationMeters,
    this.attribution,
  }) : samples = List<RouteElevationSampleDraft>.unmodifiable(samples);

  final RouteElevationAvailability availability;
  final RouteQualitySource source;
  final List<RouteElevationSampleDraft> samples;
  final double? ascentMeters;
  final double? descentMeters;
  final double? minimumElevationMeters;
  final double? maximumElevationMeters;
  final String? attribution;

  bool get isCoherent {
    if (!samples.every((sample) => sample.isValid)) return false;
    for (var index = 1; index < samples.length; index += 1) {
      if (samples[index].distanceFromStartMeters <
          samples[index - 1].distanceFromStartMeters) {
        return false;
      }
    }
    final hasCompleteSummary =
        ascentMeters != null &&
        descentMeters != null &&
        minimumElevationMeters != null &&
        maximumElevationMeters != null;
    if (availability == RouteElevationAvailability.complete) {
      return samples.length >= 2 &&
          hasCompleteSummary &&
          _finiteNonNegative(ascentMeters) &&
          _finiteNonNegative(descentMeters) &&
          minimumElevationMeters!.isFinite &&
          maximumElevationMeters!.isFinite &&
          minimumElevationMeters! <= maximumElevationMeters!;
    }
    return !hasCompleteSummary &&
        ascentMeters == null &&
        descentMeters == null &&
        minimumElevationMeters == null &&
        maximumElevationMeters == null;
  }

  static bool _finiteNonNegative(double? value) =>
      value != null && value.isFinite && value >= 0;
}

class RouteSurfaceMetricDraft {
  const RouteSurfaceMetricDraft({
    required this.surfaceId,
    required this.distanceMeters,
    required this.source,
    this.attribution,
  });

  final String surfaceId;
  final double distanceMeters;
  final RouteQualitySource source;
  final String? attribution;

  bool get isValid =>
      surfaceId.trim().isNotEmpty &&
      distanceMeters.isFinite &&
      distanceMeters >= 0;
}

class RouteDifficultyAssessmentDraft {
  const RouteDifficultyAssessmentDraft({
    required this.recommendedDifficultyId,
    required this.modelId,
    required this.modelVersion,
    required this.score,
    required this.missingElevation,
    required this.unknownSurfaceDistanceMeters,
    required this.differsFromAuthorSelection,
  });

  final String recommendedDifficultyId;
  final String modelId;
  final int modelVersion;
  final double score;
  final bool missingElevation;
  final double unknownSurfaceDistanceMeters;
  final bool differsFromAuthorSelection;

  bool get isValid =>
      recommendedDifficultyId.trim().isNotEmpty &&
      modelId.trim().isNotEmpty &&
      modelVersion > 0 &&
      score.isFinite &&
      score >= 0 &&
      unknownSurfaceDistanceMeters.isFinite &&
      unknownSurfaceDistanceMeters >= 0;
}

class RouteVerificationRecordDraft {
  RouteVerificationRecordDraft({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.geometryRevision,
    required this.verifiedAtUtc,
    Iterable<String> evidenceMediaIds = const <String>[],
    this.note,
  }) : evidenceMediaIds = List<String>.unmodifiable(evidenceMediaIds);

  final String id;
  final RouteVerificationKind kind;
  final String actorId;
  final int geometryRevision;
  final DateTime verifiedAtUtc;
  final List<String> evidenceMediaIds;
  final String? note;

  bool get isValid =>
      id.trim().isNotEmpty &&
      actorId.trim().isNotEmpty &&
      geometryRevision >= 0 &&
      verifiedAtUtc.isUtc &&
      evidenceMediaIds.every((id) => id.trim().isNotEmpty) &&
      evidenceMediaIds.toSet().length == evidenceMediaIds.length;
}

class RouteQualityDraft {
  RouteQualityDraft({
    required this.geometryRevision,
    required this.calculationModelId,
    required this.calculationModelVersion,
    required this.inputFingerprint,
    required this.calculatedAtUtc,
    required this.elevation,
    required Iterable<RouteSurfaceMetricDraft> surfaces,
    required this.unknownSurfaceDistanceMeters,
    required this.difficulty,
    Iterable<RouteVerificationRecordDraft> verifications =
        const <RouteVerificationRecordDraft>[],
  }) : surfaces = List<RouteSurfaceMetricDraft>.unmodifiable(surfaces),
       verifications = List<RouteVerificationRecordDraft>.unmodifiable(
         verifications,
       );

  final int geometryRevision;
  final String calculationModelId;
  final int calculationModelVersion;
  final String inputFingerprint;
  final DateTime calculatedAtUtc;
  final RouteElevationProfileDraft elevation;
  final List<RouteSurfaceMetricDraft> surfaces;
  final double unknownSurfaceDistanceMeters;
  final RouteDifficultyAssessmentDraft difficulty;
  final List<RouteVerificationRecordDraft> verifications;

  bool get isCoherent =>
      geometryRevision >= 0 &&
      calculationModelId.trim().isNotEmpty &&
      calculationModelVersion > 0 &&
      inputFingerprint.trim().isNotEmpty &&
      calculatedAtUtc.isUtc &&
      elevation.isCoherent &&
      surfaces.every((surface) => surface.isValid) &&
      surfaces.map((surface) => surface.surfaceId).toSet().length ==
          surfaces.length &&
      unknownSurfaceDistanceMeters.isFinite &&
      unknownSurfaceDistanceMeters >= 0 &&
      difficulty.isValid &&
      verifications.every((record) => record.isValid) &&
      verifications.map((record) => record.id).toSet().length ==
          verifications.length;

  RouteQualityDraft copyWith({
    Iterable<RouteVerificationRecordDraft>? verifications,
  }) => RouteQualityDraft(
    geometryRevision: geometryRevision,
    calculationModelId: calculationModelId,
    calculationModelVersion: calculationModelVersion,
    inputFingerprint: inputFingerprint,
    calculatedAtUtc: calculatedAtUtc,
    elevation: elevation,
    surfaces: surfaces,
    unknownSurfaceDistanceMeters: unknownSurfaceDistanceMeters,
    difficulty: difficulty,
    verifications: verifications ?? this.verifications,
  );
}
