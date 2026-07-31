import '../../features/create/domain/entities/route_publication_data.dart';
import '../../features/create/domain/repositories/route_publication_index_sink.dart';
import '../../features/discover/data/datasources/published_route_discovery_local_datasource.dart';
import '../../features/discover/domain/entities/published_route_discovery_entity.dart';
import '../../features/discover/domain/repositories/published_route_discovery_port.dart';

class RoutePublicationDiscoveryAdapter
    implements RoutePublicationIndexSink, PublishedRouteDiscoveryPort {
  const RoutePublicationDiscoveryAdapter(this._localDataSource);

  final PublishedRouteDiscoveryLocalDataSource _localDataSource;

  @override
  Future<void> activate(PublishedRouteVersion version) {
    final projection = version.projection;
    final geometry = version.geometry;
    if (projection.routeId != version.routeId ||
        projection.versionId != version.versionId ||
        projection.geometryHash != version.geometryHash ||
        geometry.routeId != version.routeId ||
        geometry.versionId != version.versionId ||
        geometry.geometryHash != version.geometryHash) {
      throw StateError('Published Route version/hash mismatch.');
    }
    final draft = version.contentSnapshot;
    final quality = geometry.quality ?? draft.routeData?.quality;
    final fieldVerifications = quality?.verifications
        .where((record) => record.kind.name == 'field')
        .toList(growable: false);
    fieldVerifications?.sort(
      (left, right) => right.verifiedAtUtc.compareTo(left.verifiedAtUtc),
    );
    final fieldVerifiedAtUtc =
        fieldVerifications == null || fieldVerifications.isEmpty
        ? null
        : fieldVerifications.first.verifiedAtUtc;
    return _localDataSource.upsert(
      PublishedRouteDiscoveryEntity(
        routeId: version.routeId,
        versionId: version.versionId,
        geometryHash: version.geometryHash,
        contentHash: version.contentHash,
        title: draft.title,
        subtitle: draft.shortDescription,
        city: draft.city,
        marketCityId: projection.marketId,
        timezoneId: draft.timezone,
        categoryId: projection.categoryIds.isEmpty
            ? draft.mainCategory
            : projection.categoryIds.first,
        subcategoryId: draft.subcategory,
        coverImage: draft.media.coverImage,
        publisherName: draft.organizerName,
        startPoint: projection.startPoint,
        bounds: projection.bounds,
        overviewEncodedPolyline: projection.overviewEncodedPolyline,
        fullEncodedPolyline: geometry.fullEncodedPolyline,
        encodingPrecision: draft.routeData?.encodingPolicy.precision ?? 5,
        distanceMeters: projection.distanceMeters,
        durationSeconds: projection.effectiveDurationSeconds,
        routingProfileId: projection.routingProfileId,
        difficultyId: projection.difficultyId,
        elevationAvailability:
            quality?.elevation.availability.name ?? 'unavailable',
        ascentMeters: quality?.elevation.ascentMeters,
        descentMeters: quality?.elevation.descentMeters,
        unknownSurfaceDistanceMeters:
            quality?.unknownSurfaceDistanceMeters ?? 0,
        surfaceIds:
            quality?.surfaces.map((surface) => surface.surfaceId) ??
            const <String>[],
        recommendedDifficultyId:
            quality?.difficulty.recommendedDifficultyId ?? '',
        fieldVerifiedAtUtc: fieldVerifiedAtUtc,
        waypointCount: geometry.waypoints.length,
        demoOnly: version.demoOnly,
        searchTokens: projection.searchTokens,
        attributions: <String>{
          ...geometry.providers
              .map((provider) => provider.attribution)
              .where((value) => value.trim().isNotEmpty),
          if (quality?.elevation.attribution case final attribution?)
            attribution,
        },
        publishedAtUtc: version.publishedAtUtc,
      ),
    );
  }

  @override
  Future<void> archive(String routeId) => _localDataSource.remove(routeId);

  @override
  Future<PublishedRouteDiscoveryEntity?> getActiveRoute(String routeId) async {
    final routes = await _localDataSource.loadAll();
    for (final route in routes) {
      if (route.routeId == routeId) return route;
    }
    return null;
  }

  @override
  Future<List<PublishedRouteDiscoveryEntity>> loadActiveRoutes() =>
      _localDataSource.loadAll();
}
