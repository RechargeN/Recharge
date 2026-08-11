import 'dart:math' as math;

import '../../../../core/config/recharge_taxonomy.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/published_route_discovery_entity.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/repositories/published_route_discovery_port.dart';
import '../datasources/discover_remote_datasource.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl({
    required DiscoverRemoteDataSource remoteDataSource,
    PublishedRouteDiscoveryPort? publishedRoutes,
  }) : _remoteDataSource = remoteDataSource,
       _publishedRoutes = publishedRoutes;

  final DiscoverRemoteDataSource _remoteDataSource;
  final PublishedRouteDiscoveryPort? _publishedRoutes;

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    final remote = await _remoteDataSource.getFeedCandidates();
    final published = query.requestsPublishedRoutes
        ? await _publishedRoutes?.loadActiveRoutes() ??
              const <PublishedRouteDiscoveryEntity>[]
        : const <PublishedRouteDiscoveryEntity>[];
    final List<DiscoverItemEntity> source = <DiscoverItemEntity>[
      ...remote,
      ...published.where((route) => route.isCoherent).map(_routeItem),
    ];
    final List<DiscoverItemEntity> globallyFiltered = source
        .where((DiscoverItemEntity item) => _passGlobalFilters(item, query))
        .toList(growable: false);

    final List<DiscoverItemEntity> geoFiltered = globallyFiltered
        .map((DiscoverItemEntity item) {
          final double distanceKm = _distanceKm(
            lat1: query.centerLat,
            lng1: query.centerLng,
            lat2: item.latitude,
            lng2: item.longitude,
          );
          return item.copyWith(distanceKm: distanceKm);
        })
        .where(
          (DiscoverItemEntity item) =>
              query.unlimitedRadius ||
              item.distanceKm * 1000 <= query.radiusMeters,
        )
        .toList(growable: false);

    final DateTime now = DateTime.now().toUtc();
    final List<DiscoverItemEntity> scored = geoFiltered
        .map(
          (DiscoverItemEntity item) =>
              item.copyWith(relevanceScore: _score(item, now)),
        )
        .toList(growable: false);

    scored.sort((DiscoverItemEntity a, DiscoverItemEntity b) {
      final int scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.startsAtUtc.compareTo(b.startsAtUtc);
    });

    return scored;
  }

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    final route = await _publishedRoutes?.getActiveRoute(itemId);
    if (route != null && route.isCoherent) return _routeItem(route);
    return _remoteDataSource.getDetails(itemId);
  }

  bool _passGlobalFilters(DiscoverItemEntity item, DiscoverQuery query) {
    final String text = query.queryText.trim().toLowerCase();
    if (text.isNotEmpty) {
      final String routeTokens =
          item.publishedRoute?.searchTokens.join(' ') ?? '';
      final String haystack =
          '${item.title} ${item.subtitle} ${item.category} '
                  '${item.subcategory} ${item.city} $routeTokens'
              .toLowerCase();
      if (!haystack.contains(text)) return false;
    }

    if (query.selectedCategoryIds.isNotEmpty) {
      final String itemCategory = normalizeRechargeContentGroupId(
        item.category,
      );
      final bool categoryMatches = query.selectedCategoryIds.any(
        (String selectedCategory) =>
            normalizeRechargeContentGroupId(selectedCategory) == itemCategory,
      );
      if (!categoryMatches) return false;
    }

    if (query.selectedSubcategoryIds.isNotEmpty) {
      final String itemSubcategory = normalizeRechargeLegacySubcategoryId(
        item.subcategory,
      );
      final bool subcategoryMatches = query.selectedSubcategoryIds.any(
        (String selectedSubcategory) =>
            normalizeRechargeLegacySubcategoryId(selectedSubcategory) ==
            itemSubcategory,
      );
      if (!subcategoryMatches) return false;
    }

    if (query.freeOnly && !item.isFree) return false;

    if (query.budgetMin != null && item.priceAmount < query.budgetMin!) {
      return false;
    }
    if (query.budgetMax != null && item.priceAmount > query.budgetMax!) {
      return false;
    }

    if (!item.isPublishedRoute &&
        query.timeWindow == null &&
        query.dateFrom != null &&
        item.startsAtUtc.isBefore(query.dateFrom!)) {
      return false;
    }
    if (!item.isPublishedRoute &&
        query.timeWindow == null &&
        query.dateTo != null &&
        item.startsAtUtc.isAfter(query.dateTo!)) {
      return false;
    }

    if (query.marketCityId.isNotEmpty &&
        item.marketCityId.isNotEmpty &&
        item.marketCityId != query.marketCityId) {
      return false;
    }

    if (query.peopleCount != null &&
        item.capacity != null &&
        item.participantsCount != null) {
      final int remainingCapacity = item.capacity! - item.participantsCount!;
      if (remainingCapacity < query.peopleCount!) return false;
    }

    if (query.availableDurationMinutes != null &&
        item.durationMinutes != null &&
        item.durationMinutes! > query.availableDurationMinutes!) {
      return false;
    }

    if (query.timeWindow == null && query.onlyAvailable) {
      if (item.capacity == null ||
          item.participantsCount == null ||
          item.participantsCount! >= item.capacity!) {
        return false;
      }
    }

    return true;
  }

  double _score(DiscoverItemEntity item, DateTime nowUtc) {
    final double distanceScore = (1 - (item.distanceKm / 30)).clamp(0, 1);
    final double hoursAhead =
        item.startsAtUtc.difference(nowUtc).inMinutes / 60;
    final double freshnessScore = (1 - (hoursAhead.abs() / 48)).clamp(0, 1);
    return distanceScore * 0.65 + freshnessScore * 0.35;
  }

  double _distanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  static DiscoverItemEntity _routeItem(PublishedRouteDiscoveryEntity route) =>
      DiscoverItemEntity(
        id: route.routeId,
        title: route.title,
        subtitle: route.subtitle,
        city: route.city,
        category: route.categoryId,
        subcategory: route.subcategoryId,
        startsAtUtc: route.publishedAtUtc,
        latitude: route.startPoint.latitude,
        longitude: route.startPoint.longitude,
        priceAmount: 0,
        distanceKm: 0,
        isFree: true,
        coverImageUrl: route.coverImage,
        organizerName: route.publisherName,
        venueName: 'Route start',
        marketCityId: route.marketCityId,
        timezoneId: route.timezoneId,
        durationMinutes: (route.durationSeconds / 60).ceil(),
        durationConfidence: DurationConfidence.exact,
        ctaLabel: 'Open Route',
        highlights: <String>[
          '${(route.distanceMeters / 1000).toStringAsFixed(1)} km',
          route.routingProfileId,
          route.difficultyId,
        ],
        publishedRoute: route,
      );
}
