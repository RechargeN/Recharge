import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';

class PublishedRouteDiscoveryEntity {
  PublishedRouteDiscoveryEntity({
    required this.routeId,
    required this.versionId,
    required this.geometryHash,
    required this.contentHash,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.marketCityId,
    required this.timezoneId,
    required this.categoryId,
    required this.subcategoryId,
    required this.coverImage,
    required this.publisherName,
    required this.startPoint,
    required this.bounds,
    required this.overviewEncodedPolyline,
    required this.fullEncodedPolyline,
    required this.encodingPrecision,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.routingProfileId,
    required this.difficultyId,
    this.elevationAvailability = 'unavailable',
    this.ascentMeters,
    this.descentMeters,
    this.unknownSurfaceDistanceMeters = 0,
    Iterable<String> surfaceIds = const <String>[],
    this.recommendedDifficultyId = '',
    this.fieldVerifiedAtUtc,
    this.waypointCount = 0,
    required this.demoOnly,
    required Iterable<String> searchTokens,
    required Iterable<String> attributions,
    required this.publishedAtUtc,
  }) : surfaceIds = List<String>.unmodifiable(surfaceIds),
       searchTokens = List<String>.unmodifiable(searchTokens),
       attributions = List<String>.unmodifiable(attributions);

  final String routeId;
  final String versionId;
  final String geometryHash;
  final String contentHash;
  final String title;
  final String subtitle;
  final String city;
  final String marketCityId;
  final String timezoneId;
  final String categoryId;
  final String subcategoryId;
  final String coverImage;
  final String publisherName;
  final GeoPoint startPoint;
  final GeoBounds bounds;
  final String overviewEncodedPolyline;
  final String fullEncodedPolyline;
  final int encodingPrecision;
  final double distanceMeters;
  final int durationSeconds;
  final String routingProfileId;
  final String difficultyId;
  final String elevationAvailability;
  final double? ascentMeters;
  final double? descentMeters;
  final double unknownSurfaceDistanceMeters;
  final List<String> surfaceIds;
  final String recommendedDifficultyId;
  final DateTime? fieldVerifiedAtUtc;
  final int waypointCount;
  final bool demoOnly;
  final List<String> searchTokens;
  final List<String> attributions;
  final DateTime publishedAtUtc;

  bool get isCoherent =>
      routeId.trim().isNotEmpty &&
      versionId.trim().isNotEmpty &&
      geometryHash.trim().isNotEmpty &&
      contentHash.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      startPoint.isValid &&
      bounds.isValid &&
      overviewEncodedPolyline.isNotEmpty &&
      fullEncodedPolyline.isNotEmpty &&
      encodingPrecision >= 0 &&
      encodingPrecision <= 8 &&
      distanceMeters.isFinite &&
      distanceMeters > 0 &&
      durationSeconds > 0 &&
      elevationAvailability.trim().isNotEmpty &&
      (ascentMeters == null ||
          (ascentMeters!.isFinite && ascentMeters! >= 0)) &&
      (descentMeters == null ||
          (descentMeters!.isFinite && descentMeters! >= 0)) &&
      unknownSurfaceDistanceMeters.isFinite &&
      unknownSurfaceDistanceMeters >= 0 &&
      surfaceIds.every((id) => id.trim().isNotEmpty) &&
      (fieldVerifiedAtUtc == null || fieldVerifiedAtUtc!.isUtc) &&
      waypointCount >= 0 &&
      publishedAtUtc.isUtc;
}
