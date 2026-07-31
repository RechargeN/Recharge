import '../../../../core/geo/geo_bounds.dart';
import '../../domain/entities/route_draft_data.dart';

class DemoCoverageConfig {
  DemoCoverageConfig({
    required this.id,
    required this.version,
    required this.graphId,
    required this.graphVersion,
    required this.bounds,
    required this.maximumSnapDistanceMeters,
    required Iterable<RouteProfileRef> supportedProfiles,
  }) : supportedProfiles = List<RouteProfileRef>.unmodifiable(
         supportedProfiles,
       );

  final String id;
  final int version;
  final String graphId;
  final String graphVersion;
  final GeoBounds bounds;
  final double maximumSnapDistanceMeters;
  final List<RouteProfileRef> supportedProfiles;

  bool get isValid =>
      id.trim().isNotEmpty &&
      version > 0 &&
      graphId.trim().isNotEmpty &&
      graphVersion.trim().isNotEmpty &&
      bounds.isValid &&
      maximumSnapDistanceMeters.isFinite &&
      maximumSnapDistanceMeters > 0 &&
      supportedProfiles.isNotEmpty &&
      supportedProfiles.every((RouteProfileRef profile) => profile.isValid);

  bool supports(RouteProfileRef profile) => supportedProfiles.any(
    (RouteProfileRef candidate) =>
        candidate.id == profile.id && candidate.version == profile.version,
  );
}
