import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../shared/primitives/geo/geo_point.dart';
import '../../../../shared/primitives/geo/geometry_encoding.dart';
import '../entities/create_draft_entity.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_publication_data.dart';
import '../entities/route_validation_issue.dart';
import 'validate_route_draft_usecase.dart';

class RoutePublicationBuildException implements Exception {
  RoutePublicationBuildException(Iterable<String> codes)
    : codes = List<String>.unmodifiable(codes);

  final List<String> codes;
}

class RoutePublicationBuildPolicy {
  RoutePublicationBuildPolicy({
    required this.validationPolicy,
    required Iterable<String> locallyAllowedProviderCodes,
    this.maximumOverviewPoints = 128,
    this.configVersion = 1,
    this.taxonomyVersion = '1.4.2',
  }) : locallyAllowedProviderCodes = Set<String>.unmodifiable(
         locallyAllowedProviderCodes,
       );

  final RouteValidationPolicy validationPolicy;
  final Set<String> locallyAllowedProviderCodes;
  final int maximumOverviewPoints;
  final int configVersion;
  final String taxonomyVersion;
}

class BuildRoutePublicationBundleUseCase {
  const BuildRoutePublicationBundleUseCase({
    this.validateRoute = const ValidateRouteDraftUseCase(),
  });

  final ValidateRouteDraftUseCase validateRoute;

  RoutePublicationBundle call({
    required CreateDraftEntity draft,
    required RoutePublicationAggregate? current,
    required RoutePublisherRef publisher,
    required RoutePublicationMode mode,
    required RoutePublicationBuildPolicy policy,
    required String routeId,
    required String versionId,
    required String auditEventId,
    required String attemptId,
    required String actorId,
    required DateTime nowUtc,
    required String Function() generateId,
  }) {
    final sourceRoute = draft.routeData;
    final commonErrors = <String>[
      if (draft.objectType != CreateObjectType.route || sourceRoute == null)
        'route_draft_required',
      if (draft.title.trim().isEmpty) 'title_required',
      if (draft.shortDescription.trim().isEmpty) 'short_description_required',
      if (draft.mainCategory.trim().isEmpty) 'category_required',
      if (draft.city.trim().isEmpty) 'city_required',
      if (draft.media.coverImage.trim().isEmpty) 'cover_required',
      if (!publisher.isValid) 'publisher_invalid',
      if (!nowUtc.isUtc) 'utc_timestamp_required',
    ];
    if (commonErrors.isNotEmpty || sourceRoute == null) {
      throw RoutePublicationBuildException(commonErrors);
    }

    final route = sourceRoute.replaceLocalIds(generateId);
    final readiness = validateRoute.evaluate(
      route,
      policy: _permanentPolicy(policy.validationPolicy),
    );
    final blockingCodes = readiness.blockingIssues
        .where(
          (issue) => !_isAllowedLocalProviderIssue(
            issue,
            route,
            policy.locallyAllowedProviderCodes,
          ),
        )
        .map((issue) => issue.code)
        .toSet()
        .toList(growable: false);
    if (blockingCodes.isNotEmpty) {
      throw RoutePublicationBuildException(blockingCodes);
    }

    final fullPoints = _fullPoints(route);
    final fullGeometry = RouteGeometryDraft.fromPoints(
      fullPoints,
      encodingPolicy: route.encodingPolicy,
    );
    final providers = _providers(route);
    final demoOnly = providers.any((provider) => !provider.allowsPublication);
    final overview = _overviewPoints(
      fullPoints,
      maximumPoints: policy.maximumOverviewPoints,
    );
    final publishedDraft = draft.copyWith(
      id: routeId,
      routeData: route,
      draftStatus: DraftStatus.published,
      moderationStatus: ModerationStatus.approved,
      publishStatus: PublishStatus.published,
      updatedAtUtc: nowUtc,
      publishedAtUtc: nowUtc,
    );
    final geometry = PublishedRouteGeometry(
      routeId: routeId,
      versionId: versionId,
      geometryHash: fullGeometry.geometryHash,
      fullEncodedPolyline: fullGeometry.encodedPolyline,
      segments: route.orderedSegments.map(
        (segment) => PublishedRouteSegment(
          id: segment.id,
          order: segment.order,
          fromAnchorId: segment.fromAnchorId,
          toAnchorId: segment.toAnchorId,
          source: segment.source,
          encodedPolyline: segment.geometry.encodedPolyline,
          geometryHash: segment.geometry.geometryHash,
          distanceMeters: segment.distanceMeters,
          providerCode: segment.provenance.provider?.code,
        ),
      ),
      waypoints: route.waypoints.map(
        (waypoint) => PublishedRouteWaypoint(
          id: waypoint.id,
          position: waypoint.position,
          typeId: waypoint.typeId,
          distanceFromStartMeters: waypoint.distanceFromStartMeters ?? 0,
          anchorId: waypoint.anchorId,
          segmentId: waypoint.segmentId,
          catalogVersion: waypoint.catalogVersion,
          title: waypoint.title,
          description: waypoint.description,
          note: waypoint.note,
          safetyNote: waypoint.safetyNote,
          technicalAttributeIds: waypoint.technicalAttributeIds,
          photoIds: waypoint.photoIds,
          verifiedAtUtc: waypoint.verifiedAtUtc,
        ),
      ),
      providers: providers,
      encodingPolicyId: route.encodingPolicy.id,
      encodingPolicyVersion: route.encodingPolicy.version,
      quality: route.quality,
    );
    final projection = RouteSearchProjection(
      routeId: routeId,
      versionId: versionId,
      geometryHash: fullGeometry.geometryHash,
      marketId: draft.marketCityId,
      startPoint: fullPoints.first,
      bounds: fullGeometry.bounds,
      overviewEncodedPolyline: GeometryEncoding.encode(
        overview,
        policy: route.encodingPolicy.corePolicy,
      ),
      distanceMeters: route.metrics.distanceMeters,
      effectiveDurationSeconds: route.metrics.effectiveDurationSeconds,
      routingProfileId: route.profile.id,
      difficultyId:
          route.conditions.difficultyId ??
          route.quality?.difficulty.recommendedDifficultyId ??
          route.metrics.difficultyId ??
          'unknown',
      categoryIds: <String>[
        draft.mainCategory,
        if (draft.subcategory.trim().isNotEmpty) draft.subcategory,
      ],
      searchTokens: _searchTokens(draft),
    );
    final contentHash = _contentHash(
      draft: publishedDraft,
      route: route,
      geometryHash: fullGeometry.geometryHash,
      policy: policy,
    );
    final previous = current?.activeVersion;
    final version = PublishedRouteVersion(
      routeId: routeId,
      versionId: versionId,
      versionNumber: (previous?.versionNumber ?? 0) + 1,
      previousVersionId: previous?.versionId,
      publisher: publisher,
      authorId: actorId,
      contentHash: contentHash,
      geometryHash: fullGeometry.geometryHash,
      mode: mode,
      demoOnly: demoOnly,
      contentSnapshot: publishedDraft,
      geometry: geometry,
      projection: projection,
      createdAtUtc: nowUtc,
      publishedAtUtc: nowUtc,
    );
    return RoutePublicationBundle(
      attemptId: attemptId,
      version: version,
      auditEvent: RoutePublicationAuditEvent(
        id: auditEventId,
        action: mode == RoutePublicationMode.trustedDirect
            ? 'route_published_trusted'
            : 'route_submitted',
        actorId: actorId,
        publisher: publisher,
        routeId: routeId,
        versionId: versionId,
        attemptId: attemptId,
        occurredAtUtc: nowUtc,
      ),
    );
  }

  static RouteValidationPolicy _permanentPolicy(RouteValidationPolicy source) =>
      RouteValidationPolicy(
        profileRules: source.profileRules.values,
        encodingPolicyId: source.encodingPolicyId,
        encodingPolicyVersion: source.encodingPolicyVersion,
        minimumAnchors: source.minimumAnchors,
        maximumAnchors: source.maximumAnchors,
        maximumSegments: source.maximumSegments,
        maximumWaypoints: source.maximumWaypoints,
        maximumGeometryPoints: source.maximumGeometryPoints,
        endpointToleranceMeters: source.endpointToleranceMeters,
        distanceToleranceMeters: source.distanceToleranceMeters,
        waypointTrackToleranceMeters: source.waypointTrackToleranceMeters,
        maximumDirectShare: source.maximumDirectShare,
        manualDurationReasonDeviationRatio:
            source.manualDurationReasonDeviationRatio,
        requirePermanentIds: true,
      );

  static bool _isAllowedLocalProviderIssue(
    RouteValidationIssue issue,
    RouteDraftData route,
    Set<String> allowedCodes,
  ) {
    if (issue.code != 'provider_license_disallows_publish') return false;
    final segmentId = issue.location.segmentId;
    final provider = segmentId == null
        ? null
        : route.segmentById(segmentId)?.provenance.provider;
    return provider != null && allowedCodes.contains(provider.code);
  }

  static List<GeoPoint> _fullPoints(RouteDraftData route) {
    final points = <GeoPoint>[];
    for (final segment in route.orderedSegments) {
      final segmentPoints = segment.geometry.points;
      if (points.isEmpty) {
        points.addAll(segmentPoints);
      } else if (points.last == segmentPoints.first) {
        points.addAll(segmentPoints.skip(1));
      } else {
        throw RoutePublicationBuildException(<String>[
          'published_geometry_disconnected',
        ]);
      }
    }
    if (points.length < 2) {
      throw RoutePublicationBuildException(<String>[
        'published_geometry_too_short',
      ]);
    }
    return List<GeoPoint>.unmodifiable(points);
  }

  static List<GeoPoint> _overviewPoints(
    List<GeoPoint> points, {
    required int maximumPoints,
  }) {
    if (maximumPoints < 2) {
      throw ArgumentError.value(maximumPoints, 'maximumPoints');
    }
    if (points.length <= maximumPoints) return points;
    final result = <GeoPoint>[points.first];
    for (var index = 1; index < maximumPoints - 1; index += 1) {
      final sourceIndex = (index * (points.length - 1) / (maximumPoints - 1))
          .round();
      result.add(points[sourceIndex]);
    }
    result.add(points.last);
    return List<GeoPoint>.unmodifiable(result);
  }

  static List<RouteProviderReference> _providers(RouteDraftData route) {
    final providers = <String, RouteProviderReference>{};
    for (final segment in route.orderedSegments) {
      final provider = segment.provenance.provider;
      if (provider != null) {
        providers.putIfAbsent(
          '${provider.code}:${provider.dataVersion}',
          () => provider,
        );
      }
    }
    final values = providers.values.toList(growable: false)
      ..sort((left, right) => left.code.compareTo(right.code));
    return values;
  }

  static List<String> _searchTokens(CreateDraftEntity draft) {
    final source = <String>[
      draft.title,
      draft.shortDescription,
      draft.mainCategory,
      draft.subcategory,
      draft.city,
      ...draft.tags,
    ].join(' ').toLowerCase();
    final tokens = RegExp(
      r'[\p{L}\p{N}_]+',
      unicode: true,
    ).allMatches(source).map((match) => match.group(0)!).toSet().toList();
    tokens.sort();
    return tokens;
  }

  static String _contentHash({
    required CreateDraftEntity draft,
    required RouteDraftData route,
    required String geometryHash,
    required RoutePublicationBuildPolicy policy,
  }) {
    final tags = List<String>.of(draft.tags)..sort();
    final payload = <String, Object?>{
      'schema': 'route-published-content-v2',
      'configVersion': policy.configVersion,
      'taxonomyVersion': policy.taxonomyVersion,
      'title': draft.title.trim(),
      'shortDescription': draft.shortDescription.trim(),
      'fullDescription': draft.fullDescription.trim(),
      'category': draft.mainCategory,
      'subcategory': draft.subcategory,
      'tags': tags,
      'market': draft.marketCityId,
      'city': draft.city,
      'cover': draft.media.coverImage,
      'gallery': draft.media.gallery,
      'visibility': draft.visibility.name,
      'geometryHash': geometryHash,
      'shape': route.shape.name,
      'profile': '${route.profile.id}@${route.profile.version}',
      'difficulty':
          route.conditions.difficultyId ??
          route.quality?.difficulty.recommendedDifficultyId ??
          route.metrics.difficultyId,
      'duration': route.metrics.effectiveDurationSeconds,
      'qualityFingerprint': route.quality?.inputFingerprint,
      'verifications': route.quality?.verifications
          .map(
            (verification) => <String, Object?>{
              'id': verification.id,
              'kind': verification.kind.name,
              'actorId': verification.actorId,
              'geometryRevision': verification.geometryRevision,
              'verifiedAt': verification.verifiedAtUtc.toIso8601String(),
              'evidence': verification.evidenceMediaIds,
              'note': verification.note,
            },
          )
          .toList(growable: false),
      'waypoints': route.waypoints
          .map(
            (waypoint) => <String, Object?>{
              'id': waypoint.id,
              'type': waypoint.typeId,
              'catalogVersion': waypoint.catalogVersion,
              'title': waypoint.title,
              'description': waypoint.description,
              'note': waypoint.note,
              'safetyNote': waypoint.safetyNote,
              'technical': waypoint.technicalAttributeIds,
              'photos': waypoint.photoIds,
              'verifiedAt': waypoint.verifiedAtUtc?.toIso8601String(),
              'distance': waypoint.distanceFromStartMeters,
            },
          )
          .toList(growable: false),
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }
}
