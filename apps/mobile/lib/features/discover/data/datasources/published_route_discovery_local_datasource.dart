import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/published_route_discovery_entity.dart';

class PublishedRouteDiscoveryLocalDataSource {
  PublishedRouteDiscoveryLocalDataSource(this._storage);

  static const String storageKey = 'recharge.route.discovery.index.v1';

  final FlutterSecureStorage _storage;

  Future<List<PublishedRouteDiscoveryEntity>> loadAll() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PublishedRouteDiscoveryEntity>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] is! int ||
          (decoded['schemaVersion'] as int) < 1 ||
          (decoded['schemaVersion'] as int) > 2) {
        return const <PublishedRouteDiscoveryEntity>[];
      }
      final routes = decoded['routes'];
      if (routes is! List<dynamic>) {
        return const <PublishedRouteDiscoveryEntity>[];
      }
      return routes
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (map) => _fromMap(
              map.map(
                (key, value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              ),
            ),
          )
          .where((route) => route.isCoherent)
          .toList(growable: false);
    } on FormatException {
      return const <PublishedRouteDiscoveryEntity>[];
    } on TypeError {
      return const <PublishedRouteDiscoveryEntity>[];
    }
  }

  Future<void> upsert(PublishedRouteDiscoveryEntity route) async {
    if (!route.isCoherent) {
      throw ArgumentError.value(route, 'route', 'Route index is incoherent.');
    }
    final current = await loadAll();
    final next = <PublishedRouteDiscoveryEntity>[
      for (final value in current)
        if (value.routeId != route.routeId) value,
      route,
    ]..sort((left, right) => left.routeId.compareTo(right.routeId));
    await _write(next);
  }

  Future<void> remove(String routeId) async {
    final current = await loadAll();
    final next = current
        .where((route) => route.routeId != routeId)
        .toList(growable: false);
    await _write(next);
  }

  Future<void> clear() => _storage.delete(key: storageKey);

  Future<void> _write(List<PublishedRouteDiscoveryEntity> routes) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'routes': routes.map(_toMap).toList(growable: false),
      }),
    );
  }

  static Map<String, Object?> _toMap(PublishedRouteDiscoveryEntity value) =>
      <String, Object?>{
        'routeId': value.routeId,
        'versionId': value.versionId,
        'geometryHash': value.geometryHash,
        'contentHash': value.contentHash,
        'title': value.title,
        'subtitle': value.subtitle,
        'city': value.city,
        'marketCityId': value.marketCityId,
        'timezoneId': value.timezoneId,
        'categoryId': value.categoryId,
        'subcategoryId': value.subcategoryId,
        'coverImage': value.coverImage,
        'publisherName': value.publisherName,
        'startPoint': value.startPoint.toMap(),
        'bounds': value.bounds.toMap(),
        'overviewEncodedPolyline': value.overviewEncodedPolyline,
        'fullEncodedPolyline': value.fullEncodedPolyline,
        'encodingPrecision': value.encodingPrecision,
        'distanceMeters': value.distanceMeters,
        'durationSeconds': value.durationSeconds,
        'routingProfileId': value.routingProfileId,
        'difficultyId': value.difficultyId,
        'elevationAvailability': value.elevationAvailability,
        'ascentMeters': value.ascentMeters,
        'descentMeters': value.descentMeters,
        'unknownSurfaceDistanceMeters': value.unknownSurfaceDistanceMeters,
        'surfaceIds': value.surfaceIds,
        'recommendedDifficultyId': value.recommendedDifficultyId,
        'fieldVerifiedAtUtc': value.fieldVerifiedAtUtc?.toIso8601String(),
        'waypointCount': value.waypointCount,
        'demoOnly': value.demoOnly,
        'searchTokens': value.searchTokens,
        'attributions': value.attributions,
        'publishedAtUtc': value.publishedAtUtc.toIso8601String(),
      };

  static PublishedRouteDiscoveryEntity _fromMap(
    Map<String, Object?> map,
  ) => PublishedRouteDiscoveryEntity(
    routeId: map['routeId']! as String,
    versionId: map['versionId']! as String,
    geometryHash: map['geometryHash']! as String,
    contentHash: map['contentHash']! as String,
    title: map['title']! as String,
    subtitle: map['subtitle'] as String? ?? '',
    city: map['city'] as String? ?? '',
    marketCityId: map['marketCityId'] as String? ?? '',
    timezoneId: map['timezoneId'] as String? ?? 'UTC',
    categoryId: map['categoryId'] as String? ?? '',
    subcategoryId: map['subcategoryId'] as String? ?? '',
    coverImage: map['coverImage'] as String? ?? '',
    publisherName: map['publisherName'] as String? ?? '',
    startPoint: GeoPoint.fromMap(
      Map<String, Object?>.from(map['startPoint']! as Map),
    ),
    bounds: GeoBounds.fromMap(Map<String, Object?>.from(map['bounds']! as Map)),
    overviewEncodedPolyline: map['overviewEncodedPolyline']! as String,
    fullEncodedPolyline: map['fullEncodedPolyline']! as String,
    encodingPrecision: (map['encodingPrecision']! as num).toInt(),
    distanceMeters: (map['distanceMeters']! as num).toDouble(),
    durationSeconds: (map['durationSeconds']! as num).toInt(),
    routingProfileId: map['routingProfileId'] as String? ?? '',
    difficultyId: map['difficultyId'] as String? ?? '',
    elevationAvailability:
        map['elevationAvailability'] as String? ?? 'unavailable',
    ascentMeters: (map['ascentMeters'] as num?)?.toDouble(),
    descentMeters: (map['descentMeters'] as num?)?.toDouble(),
    unknownSurfaceDistanceMeters:
        (map['unknownSurfaceDistanceMeters'] as num?)?.toDouble() ?? 0,
    surfaceIds: (map['surfaceIds'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .toList(growable: false),
    recommendedDifficultyId:
        map['recommendedDifficultyId'] as String? ?? '',
    fieldVerifiedAtUtc: map['fieldVerifiedAtUtc'] == null
        ? null
        : DateTime.parse(map['fieldVerifiedAtUtc']! as String).toUtc(),
    waypointCount: (map['waypointCount'] as num?)?.toInt() ?? 0,
    demoOnly: map['demoOnly'] as bool? ?? false,
    searchTokens: (map['searchTokens'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .toList(growable: false),
    attributions: (map['attributions'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .toList(growable: false),
    publishedAtUtc: DateTime.parse(map['publishedAtUtc']! as String).toUtc(),
  );
}
