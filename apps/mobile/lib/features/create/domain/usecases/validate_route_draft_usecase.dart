import '../../../../core/geo/geo_distance.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_validation_issue.dart';

class RouteProfileValidationRule {
  RouteProfileValidationRule({
    required this.profile,
    required this.minimumDistanceMeters,
    required this.maximumDistanceMeters,
    required this.maximumDurationSeconds,
    required Iterable<RouteShape> allowedShapes,
    required Iterable<String> supportedPreferenceIds,
  }) : allowedShapes = Set<RouteShape>.unmodifiable(allowedShapes),
       supportedPreferenceIds = Set<String>.unmodifiable(
         supportedPreferenceIds,
       );

  final RouteProfileRef profile;
  final double minimumDistanceMeters;
  final double maximumDistanceMeters;
  final int maximumDurationSeconds;
  final Set<RouteShape> allowedShapes;
  final Set<String> supportedPreferenceIds;

  bool get isValid =>
      profile.isValid &&
      minimumDistanceMeters.isFinite &&
      minimumDistanceMeters >= 0 &&
      maximumDistanceMeters.isFinite &&
      maximumDistanceMeters >= minimumDistanceMeters &&
      maximumDurationSeconds > 0 &&
      allowedShapes.isNotEmpty &&
      supportedPreferenceIds.every((String id) => id.trim().isNotEmpty);
}

class RouteValidationPolicy {
  RouteValidationPolicy({
    required Iterable<RouteProfileValidationRule> profileRules,
    required this.encodingPolicyId,
    required this.encodingPolicyVersion,
    required this.minimumAnchors,
    required this.maximumAnchors,
    required this.maximumSegments,
    required this.maximumWaypoints,
    required this.maximumGeometryPoints,
    required this.endpointToleranceMeters,
    required this.distanceToleranceMeters,
    required this.waypointTrackToleranceMeters,
    required this.maximumDirectShare,
    required this.manualDurationReasonDeviationRatio,
    required this.requirePermanentIds,
  }) : profileRules = Map<String, RouteProfileValidationRule>.unmodifiable({
         for (final rule in profileRules)
           _profileKey(rule.profile.id, rule.profile.version): rule,
       });

  final Map<String, RouteProfileValidationRule> profileRules;
  final String encodingPolicyId;
  final int encodingPolicyVersion;
  final int minimumAnchors;
  final int maximumAnchors;
  final int maximumSegments;
  final int maximumWaypoints;
  final int maximumGeometryPoints;
  final double endpointToleranceMeters;
  final double distanceToleranceMeters;
  final double waypointTrackToleranceMeters;
  final double maximumDirectShare;
  final double manualDurationReasonDeviationRatio;
  final bool requirePermanentIds;

  RouteProfileValidationRule? ruleFor(RouteProfileRef profile) =>
      profileRules[_profileKey(profile.id, profile.version)];

  bool get isValid =>
      profileRules.isNotEmpty &&
      profileRules.values.every(
        (RouteProfileValidationRule rule) => rule.isValid,
      ) &&
      encodingPolicyId.trim().isNotEmpty &&
      encodingPolicyVersion > 0 &&
      minimumAnchors >= 2 &&
      maximumAnchors >= minimumAnchors &&
      maximumSegments >= 1 &&
      maximumWaypoints >= 0 &&
      maximumGeometryPoints >= 2 &&
      endpointToleranceMeters.isFinite &&
      endpointToleranceMeters >= 0 &&
      distanceToleranceMeters.isFinite &&
      distanceToleranceMeters >= 0 &&
      waypointTrackToleranceMeters.isFinite &&
      waypointTrackToleranceMeters >= 0 &&
      maximumDirectShare.isFinite &&
      maximumDirectShare >= 0 &&
      maximumDirectShare <= 1 &&
      manualDurationReasonDeviationRatio.isFinite &&
      manualDurationReasonDeviationRatio >= 0;

  static String _profileKey(String id, int version) => '$id@$version';
}

class ValidateRouteDraftUseCase {
  const ValidateRouteDraftUseCase();

  List<RouteValidationIssue> call(
    RouteDraftData route, {
    required RouteValidationPolicy policy,
  }) => evaluate(route, policy: policy).issues;

  RouteReadiness evaluate(
    RouteDraftData route, {
    required RouteValidationPolicy policy,
  }) {
    if (!policy.isValid) {
      throw ArgumentError.value(policy, 'policy', 'Policy is invalid.');
    }

    final issues = <String, RouteValidationIssue>{};

    void add(
      String code,
      RouteValidationSeverity severity,
      String section, {
      String? field,
      String? segmentId,
      String? waypointId,
      RouteValidationRemediation remediation = RouteValidationRemediation.fix,
      Map<String, num> safeMetrics = const <String, num>{},
    }) {
      final issue = RouteValidationIssue(
        code: code,
        severity: severity,
        location: RouteValidationLocation(
          sectionId: section,
          fieldId: field,
          segmentId: segmentId,
          waypointId: waypointId,
        ),
        remediation: remediation,
        safeMetrics: safeMetrics,
      );
      issues.putIfAbsent(issue.stableId, () => issue);
    }

    void block(
      String code,
      String section, {
      String? field,
      String? segmentId,
      String? waypointId,
      RouteValidationRemediation? remediation,
      Map<String, num>? safeMetrics,
    }) {
      add(
        code,
        RouteValidationSeverity.blocking,
        section,
        field: field,
        segmentId: segmentId,
        waypointId: waypointId,
        remediation: remediation ?? RouteValidationRemediation.fix,
        safeMetrics: safeMetrics ?? const <String, num>{},
      );
    }

    void warn(
      String code,
      String section, {
      String? field,
      String? segmentId,
      String? waypointId,
      RouteValidationRemediation? remediation,
      Map<String, num>? safeMetrics,
    }) {
      add(
        code,
        RouteValidationSeverity.warning,
        section,
        field: field,
        segmentId: segmentId,
        waypointId: waypointId,
        remediation: remediation ?? RouteValidationRemediation.review,
        safeMetrics: safeMetrics ?? const <String, num>{},
      );
    }

    if (route.schemaVersion != RouteDraftData.currentSchemaVersion) {
      block('schema_version_unsupported', 'route', field: 'schemaVersion');
    }
    if (route.revision < 0) {
      block('revision_invalid', 'route', field: 'revision');
    }
    if (route.geometryRevision < 0) {
      block('geometry_revision_invalid', 'route', field: 'geometryRevision');
    }
    if (!route.profile.isValid) {
      block('profile_invalid', 'profile', field: 'profile');
    }
    final profileRule = policy.ruleFor(route.profile);
    if (profileRule == null) {
      block('profile_unsupported', 'profile', field: 'profile');
    } else if (!profileRule.allowedShapes.contains(route.shape)) {
      block('shape_unsupported_for_profile', 'profile', field: 'shape');
    }
    if (!route.preferences.isValid) {
      block('preferences_invalid', 'profile', field: 'preferences');
    }
    if (profileRule != null) {
      for (final preferenceId in route.preferences.values.keys) {
        if (!profileRule.supportedPreferenceIds.contains(preferenceId)) {
          block('preference_unsupported', 'profile', field: preferenceId);
        }
      }
    }

    _validateEncodingPolicy(route, policy, block);
    _validateIds(route, policy, block);
    _validateAnchors(route, policy, block);
    _validateSegments(route, policy, block, warn);
    _validateTopology(route, block);
    _validateWaypoints(route, policy, block, warn);
    _validateMetrics(route, policy, profileRule, block, warn);
    _validateQuality(route, policy, block, warn);
    _validateConditions(route, policy, block, warn);
    _validateSourceIssues(route, block, warn);
    _validateOperations(route, block);

    return RouteReadiness(issues.values);
  }

  static void _validateEncodingPolicy(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
  ) {
    if (!route.encodingPolicy.isValid) {
      block('encoding_policy_invalid', 'geometry', field: 'encodingPolicy');
      return;
    }
    if (route.encodingPolicy.id != policy.encodingPolicyId ||
        route.encodingPolicy.version != policy.encodingPolicyVersion) {
      block('encoding_policy_outdated', 'geometry', field: 'encodingPolicy');
    }
    if (route.encodingPolicy.maxPublishedPoints >
        policy.maximumGeometryPoints) {
      block(
        'encoding_policy_limit_incompatible',
        'geometry',
        field: 'maxPublishedPoints',
      );
    }
  }

  static void _validateIds(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
  ) {
    final seen = <String>{};
    for (final id in route.nestedIds) {
      final normalized = id.trim();
      if (normalized.isEmpty) {
        block('entity_id_missing', 'relations', field: 'id');
      } else if (!seen.add(normalized)) {
        block('entity_id_duplicate', 'relations', field: 'id');
      }
      if (policy.requirePermanentIds && normalized.startsWith('loc_')) {
        block('temporary_id_not_publishable', 'relations', field: 'id');
      }
    }
  }

  static void _validateAnchors(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
  ) {
    if (route.anchors.length < policy.minimumAnchors) {
      block(
        'anchors_too_few',
        'geometry',
        field: 'anchors',
        safeMetrics: <String, num>{'count': route.anchors.length},
      );
    }
    if (route.anchors.length > policy.maximumAnchors) {
      block(
        'anchors_limit_exceeded',
        'geometry',
        field: 'anchors',
        safeMetrics: <String, num>{'count': route.anchors.length},
      );
    }
    for (final anchor in route.anchors) {
      if (!anchor.position.isValid) {
        block('anchor_position_invalid', 'geometry', field: 'anchors');
      }
      if (anchor.authorIntentId != null &&
          anchor.authorIntentId!.trim().isEmpty) {
        block('anchor_intent_invalid', 'geometry', field: 'authorIntentId');
      }
    }
  }

  static void _validateSegments(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
    _AddIssue warn,
  ) {
    if (route.segments.isEmpty) {
      block('segments_missing', 'geometry', field: 'segments');
      return;
    }
    if (route.segments.length > policy.maximumSegments) {
      block(
        'segments_limit_exceeded',
        'geometry',
        field: 'segments',
        safeMetrics: <String, num>{'count': route.segments.length},
      );
    }
    if (route.geometryPointCount > policy.maximumGeometryPoints ||
        route.geometryPointCount > route.encodingPolicy.maxPublishedPoints) {
      block(
        'geometry_points_limit_exceeded',
        'geometry',
        field: 'points',
        safeMetrics: <String, num>{'count': route.geometryPointCount},
      );
    }

    final anchors = <String, RouteAnchorDraft>{
      for (final anchor in route.anchors) anchor.id: anchor,
    };
    final orders = <int>{};
    for (final segment in route.segments) {
      if (segment.order < 0 || !orders.add(segment.order)) {
        block(
          'segment_order_invalid',
          'geometry',
          segmentId: segment.id,
          field: 'order',
        );
      }
      final from = anchors[segment.fromAnchorId];
      final to = anchors[segment.toAnchorId];
      if (from == null || to == null) {
        block(
          'segment_anchor_missing',
          'geometry',
          segmentId: segment.id,
          field: from == null ? 'fromAnchorId' : 'toAnchorId',
        );
      }
      if (segment.geometryRevision != route.geometryRevision) {
        block(
          'segment_revision_stale',
          'geometry',
          segmentId: segment.id,
          field: 'geometryRevision',
        );
      }
      if (segment.operationState != RouteSegmentOperationState.ready) {
        block(
          'segment_not_ready',
          'geometry',
          segmentId: segment.id,
          field: 'operationState',
          remediation:
              segment.operationState == RouteSegmentOperationState.failed
              ? RouteValidationRemediation.retry
              : RouteValidationRemediation.fix,
        );
      }
      if (segment.geometry.pointCount < 2 ||
          !segment.geometry.hasValidNumbers) {
        block(
          'segment_geometry_invalid',
          'geometry',
          segmentId: segment.id,
          field: 'geometry',
        );
      } else {
        if (!segment.geometry.matchesCanonicalRepresentation) {
          block(
            'segment_geometry_hash_mismatch',
            'geometry',
            segmentId: segment.id,
            field: 'geometryHash',
          );
        }
        if (segment.geometry.encodingPolicy.canonicalId !=
            route.encodingPolicy.canonicalId) {
          block(
            'segment_encoding_policy_mismatch',
            'geometry',
            segmentId: segment.id,
            field: 'encodingPolicy',
          );
        }
        if (from != null &&
            GeoDistance.haversineMeters(
                  from.position,
                  segment.geometry.points.first,
                ) >
                policy.endpointToleranceMeters) {
          block(
            'segment_start_mismatch',
            'geometry',
            segmentId: segment.id,
            field: 'geometry',
          );
        }
        if (to != null &&
            GeoDistance.haversineMeters(
                  to.position,
                  segment.geometry.points.last,
                ) >
                policy.endpointToleranceMeters) {
          block(
            'segment_end_mismatch',
            'geometry',
            segmentId: segment.id,
            field: 'geometry',
          );
        }
      }
      if (!segment.provenance.isValid) {
        block(
          'segment_provenance_invalid',
          'sources',
          segmentId: segment.id,
          field: 'provenance',
        );
      }
      final provider = segment.provenance.provider;
      if ((segment.source == RouteSegmentSource.routed ||
              segment.source == RouteSegmentSource.generated) &&
          provider == null) {
        block(
          'provider_reference_required',
          'sources',
          segmentId: segment.id,
          field: 'provider',
        );
      }
      if (provider != null && !provider.allowsPublication) {
        block(
          'provider_license_disallows_publish',
          'sources',
          segmentId: segment.id,
          field: 'provider',
        );
      }
      if (segment.rawStats != null && !segment.rawStats!.isValid) {
        block(
          'segment_raw_stats_invalid',
          'metrics',
          segmentId: segment.id,
          field: 'rawStats',
        );
      }
      if (segment.providerDurationSeconds != null &&
          segment.providerDurationSeconds! < 0) {
        block(
          'provider_duration_invalid',
          'metrics',
          segmentId: segment.id,
          field: 'providerDurationSeconds',
        );
      }
      if (segment.preferencesOverride != null &&
          !segment.preferencesOverride!.isValid) {
        block(
          'segment_preferences_invalid',
          'profile',
          segmentId: segment.id,
          field: 'preferencesOverride',
        );
      }
      if (segment.source == RouteSegmentSource.fallbackDirect) {
        if (segment.fallbackReason == null) {
          block(
            'fallback_reason_missing',
            'sources',
            segmentId: segment.id,
            field: 'fallbackReason',
          );
        }
        warn(
          'fallback_direct_requires_review',
          'sources',
          segmentId: segment.id,
          remediation: RouteValidationRemediation.accept,
        );
      } else if (segment.fallbackReason != null) {
        block(
          'fallback_reason_not_allowed',
          'sources',
          segmentId: segment.id,
          field: 'fallbackReason',
        );
      }
      if (segment.source == RouteSegmentSource.intentionalDirect) {
        warn(
          'intentional_direct_requires_review',
          'sources',
          segmentId: segment.id,
          remediation: RouteValidationRemediation.accept,
        );
      }
      if (segment.needsReview) {
        warn('segment_marked_for_review', 'geometry', segmentId: segment.id);
      }
    }

    final expectedOrders = List<int>.generate(route.segments.length, (i) => i);
    final actualOrders = route.orderedSegments
        .map((RouteSegmentDraft segment) => segment.order)
        .toList(growable: false);
    if (!_sameIntList(expectedOrders, actualOrders)) {
      block('segment_order_not_contiguous', 'geometry', field: 'order');
    }
  }

  static void _validateTopology(RouteDraftData route, _AddIssue block) {
    if (route.segments.isEmpty) return;
    final ordered = route.orderedSegments;

    for (var index = 1; index < ordered.length; index += 1) {
      if (ordered[index - 1].toAnchorId != ordered[index].fromAnchorId) {
        block(
          'segment_chain_broken',
          'geometry',
          segmentId: ordered[index].id,
          field: 'fromAnchorId',
        );
      }
    }

    final startId = ordered.first.fromAnchorId;
    final finishId = ordered.last.toAnchorId;
    switch (route.shape) {
      case RouteShape.oneWay:
        if (startId == finishId) {
          block('one_way_must_not_close', 'geometry', field: 'shape');
        }
        if (route.turningAnchorId != null) {
          block(
            'turning_anchor_not_allowed',
            'geometry',
            field: 'turningAnchorId',
          );
        }
      case RouteShape.loop:
        if (startId != finishId) {
          block('loop_must_close', 'geometry', field: 'shape');
        }
        if (route.turningAnchorId != null) {
          block(
            'turning_anchor_not_allowed',
            'geometry',
            field: 'turningAnchorId',
          );
        }
      case RouteShape.outAndBack:
        if (startId != finishId) {
          block('out_and_back_must_return', 'geometry', field: 'shape');
        }
        final turningId = route.turningAnchorId;
        if (turningId == null || route.anchorById(turningId) == null) {
          block(
            'turning_anchor_required',
            'geometry',
            field: 'turningAnchorId',
          );
        } else {
          final path = <String>[
            ordered.first.fromAnchorId,
            ...ordered.map((RouteSegmentDraft segment) => segment.toAnchorId),
          ];
          final turningIndex = path.indexOf(turningId);
          if (turningIndex <= 0 || turningIndex >= path.length - 1) {
            block(
              'turning_anchor_not_traversed',
              'geometry',
              field: 'turningAnchorId',
            );
          }
        }
    }
  }

  static void _validateWaypoints(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
    _AddIssue warn,
  ) {
    if (route.waypoints.length > policy.maximumWaypoints) {
      block(
        'waypoints_limit_exceeded',
        'waypoints',
        field: 'waypoints',
        safeMetrics: <String, num>{'count': route.waypoints.length},
      );
    }
    final anchorIds = route.anchors
        .map((RouteAnchorDraft anchor) => anchor.id)
        .toSet();
    final segmentIds = route.segments
        .map((RouteSegmentDraft segment) => segment.id)
        .toSet();

    for (final waypoint in route.waypoints) {
      if (!waypoint.position.isValid) {
        block(
          'waypoint_position_invalid',
          'waypoints',
          waypointId: waypoint.id,
          field: 'position',
        );
      }
      if (waypoint.typeId.trim().isEmpty) {
        block(
          'waypoint_type_missing',
          'waypoints',
          waypointId: waypoint.id,
          field: 'typeId',
        );
      }
      if (waypoint.catalogVersion <= 0) {
        block(
          'waypoint_catalog_version_invalid',
          'waypoints',
          waypointId: waypoint.id,
          field: 'catalogVersion',
        );
      }
      if ((waypoint.title?.length ?? 0) > 120 ||
          (waypoint.description?.length ?? 0) > 2000 ||
          (waypoint.safetyNote?.length ?? 0) > 1000) {
        block(
          'waypoint_content_too_long',
          'waypoints',
          waypointId: waypoint.id,
          field: 'content',
        );
      }
      if (waypoint.technicalAttributeIds.any((id) => id.trim().isEmpty) ||
          waypoint.technicalAttributeIds.toSet().length !=
              waypoint.technicalAttributeIds.length) {
        block(
          'waypoint_technical_attributes_invalid',
          'waypoints',
          waypointId: waypoint.id,
          field: 'technicalAttributeIds',
        );
      }
      if (waypoint.verifiedAtUtc != null && !waypoint.verifiedAtUtc!.isUtc) {
        block(
          'waypoint_verified_at_not_utc',
          'waypoints',
          waypointId: waypoint.id,
          field: 'verifiedAtUtc',
        );
      }
      if (waypoint.anchorId != null && !anchorIds.contains(waypoint.anchorId)) {
        block(
          'waypoint_anchor_missing',
          'waypoints',
          waypointId: waypoint.id,
          field: 'anchorId',
        );
      }
      if (waypoint.segmentId != null &&
          !segmentIds.contains(waypoint.segmentId)) {
        block(
          'waypoint_segment_missing',
          'waypoints',
          waypointId: waypoint.id,
          field: 'segmentId',
        );
      }
      if (!_finiteNonNegative(waypoint.distanceFromStartMeters) ||
          !_finiteNonNegative(waypoint.distanceFromTrackMeters)) {
        block(
          'waypoint_distance_invalid',
          'waypoints',
          waypointId: waypoint.id,
          field: 'distance',
        );
      }
      if (waypoint.distanceFromStartMeters != null &&
          waypoint.distanceFromStartMeters! >
              route.metrics.distanceMeters + policy.distanceToleranceMeters) {
        block(
          'waypoint_distance_beyond_route',
          'waypoints',
          waypointId: waypoint.id,
          field: 'distanceFromStartMeters',
        );
      }
      switch (waypoint.trackState) {
        case RouteWaypointTrackState.onTrack:
          if (waypoint.anchorId == null && waypoint.segmentId == null) {
            block(
              'waypoint_track_reference_missing',
              'waypoints',
              waypointId: waypoint.id,
              field: 'trackState',
            );
          }
          if (waypoint.distanceFromStartMeters == null ||
              waypoint.distanceFromTrackMeters == null) {
            block(
              'waypoint_projection_missing',
              'waypoints',
              waypointId: waypoint.id,
              field: 'distanceFromStartMeters',
            );
          } else if (waypoint.distanceFromTrackMeters! >
              policy.waypointTrackToleranceMeters) {
            warn(
              'waypoint_far_from_track',
              'waypoints',
              waypointId: waypoint.id,
              field: 'distanceFromTrackMeters',
              remediation: RouteValidationRemediation.accept,
              safeMetrics: <String, num>{
                'distanceMeters': waypoint.distanceFromTrackMeters!,
              },
            );
          }
        case RouteWaypointTrackState.offTrackConfirmed:
          if (waypoint.distanceFromTrackMeters == null) {
            block(
              'off_track_distance_missing',
              'waypoints',
              waypointId: waypoint.id,
              field: 'distanceFromTrackMeters',
            );
          }
        case RouteWaypointTrackState.unresolved:
          block(
            'waypoint_unresolved',
            'waypoints',
            waypointId: waypoint.id,
            field: 'trackState',
          );
      }
      if (waypoint.note != null && waypoint.note!.length > 1000) {
        block(
          'waypoint_note_too_long',
          'waypoints',
          waypointId: waypoint.id,
          field: 'note',
        );
      }
      if (waypoint.photoIds.any((String id) => id.trim().isEmpty) ||
          waypoint.photoIds.toSet().length != waypoint.photoIds.length) {
        block(
          'waypoint_photo_ids_invalid',
          'waypoints',
          waypointId: waypoint.id,
          field: 'photoIds',
        );
      }
    }
  }

  static void _validateQuality(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
    _AddIssue warn,
  ) {
    final quality = route.quality;
    if (quality == null) return;
    if (!quality.isCoherent) {
      block('quality_invalid', 'quality', field: 'quality');
      return;
    }
    if (quality.geometryRevision != route.geometryRevision) {
      block(
        'quality_revision_stale',
        'quality',
        field: 'geometryRevision',
      );
    }
    final knownSurfaceDistance = quality.surfaces.fold<double>(
      0,
      (total, surface) => total + surface.distanceMeters,
    );
    final describedSurfaceDistance =
        knownSurfaceDistance + quality.unknownSurfaceDistanceMeters;
    if ((describedSurfaceDistance - route.metrics.distanceMeters).abs() >
        policy.distanceToleranceMeters) {
      block(
        'quality_surface_distance_mismatch',
        'quality',
        field: 'surfaces',
      );
    }
    if (quality.difficulty.differsFromAuthorSelection) {
      warn(
        'difficulty_differs_from_recommendation',
        'quality',
        field: 'difficultyId',
        remediation: RouteValidationRemediation.review,
        safeMetrics: <String, num>{
          'score': quality.difficulty.score,
        },
      );
    }
    if (quality.difficulty.missingElevation) {
      warn(
        'quality_elevation_unavailable',
        'quality',
        field: 'elevation',
        remediation: RouteValidationRemediation.accept,
      );
    }
    for (final verification in quality.verifications) {
      if (verification.geometryRevision != route.geometryRevision) {
        warn(
          'quality_verification_stale',
          'quality',
          field: 'verifications',
          remediation: RouteValidationRemediation.review,
        );
      }
    }
  }

  static void _validateMetrics(
    RouteDraftData route,
    RouteValidationPolicy policy,
    RouteProfileValidationRule? profileRule,
    _AddIssue block,
    _AddIssue warn,
  ) {
    final metrics = route.metrics;
    if (!metrics.hasValidNumbers) {
      block('metrics_invalid', 'metrics', field: 'metrics');
      return;
    }
    if (metrics.geometryRevision != route.geometryRevision) {
      block('metrics_revision_stale', 'metrics', field: 'geometryRevision');
    }
    final calculatedDistance = route.calculatedDistanceMeters;
    if ((metrics.distanceMeters - calculatedDistance).abs() >
        policy.distanceToleranceMeters) {
      block(
        'metrics_distance_mismatch',
        'metrics',
        field: 'distanceMeters',
        safeMetrics: <String, num>{
          'differenceMeters': (metrics.distanceMeters - calculatedDistance)
              .abs(),
        },
      );
    }
    final calculatedIntentionalDirect = route.segments
        .where(
          (RouteSegmentDraft segment) =>
              segment.source == RouteSegmentSource.intentionalDirect,
        )
        .fold<double>(
          0,
          (double total, RouteSegmentDraft segment) =>
              total + segment.distanceMeters,
        );
    final calculatedFallbackDirect = route.segments
        .where(
          (RouteSegmentDraft segment) =>
              segment.source == RouteSegmentSource.fallbackDirect,
        )
        .fold<double>(
          0,
          (double total, RouteSegmentDraft segment) =>
              total + segment.distanceMeters,
        );
    if ((metrics.directDistanceMeters - calculatedIntentionalDirect).abs() >
        policy.distanceToleranceMeters) {
      block(
        'metrics_direct_distance_mismatch',
        'metrics',
        field: 'directDistanceMeters',
      );
    }
    if ((metrics.fallbackDistanceMeters - calculatedFallbackDirect).abs() >
        policy.distanceToleranceMeters) {
      block(
        'metrics_fallback_distance_mismatch',
        'metrics',
        field: 'fallbackDistanceMeters',
      );
    }
    if (profileRule != null) {
      if (metrics.distanceMeters < profileRule.minimumDistanceMeters) {
        block('route_too_short', 'metrics', field: 'distanceMeters');
      }
      if (metrics.distanceMeters > profileRule.maximumDistanceMeters) {
        block('route_too_long', 'metrics', field: 'distanceMeters');
      }
      if (metrics.effectiveDurationSeconds >
          profileRule.maximumDurationSeconds) {
        block(
          'route_duration_too_long',
          'metrics',
          field: 'effectiveDurationSeconds',
        );
      }
    }
    if (metrics.minimumElevationMeters != null &&
        metrics.maximumElevationMeters != null &&
        metrics.minimumElevationMeters! > metrics.maximumElevationMeters!) {
      block('elevation_range_invalid', 'metrics', field: 'elevation');
    }
    if ((metrics.ascentMeters == null) != (metrics.descentMeters == null)) {
      warn('elevation_summary_incomplete', 'metrics', field: 'elevation');
    }

    final directDistance =
        metrics.directDistanceMeters + metrics.fallbackDistanceMeters;
    final directShare = metrics.distanceMeters <= 0
        ? 0.0
        : directDistance / metrics.distanceMeters;
    if (directShare > policy.maximumDirectShare) {
      warn(
        'direct_share_high',
        'metrics',
        field: 'directDistanceMeters',
        remediation: RouteValidationRemediation.accept,
        safeMetrics: <String, num>{'share': directShare},
      );
    }
    final surfaceDistance = metrics.surfaceDistanceMeters.values.fold<double>(
      0,
      (double total, double distance) => total + distance,
    );
    if (surfaceDistance >
        metrics.distanceMeters + policy.distanceToleranceMeters) {
      block('surface_distance_exceeds_route', 'metrics', field: 'surfaces');
    } else if (surfaceDistance + policy.distanceToleranceMeters <
        metrics.distanceMeters) {
      warn('surface_data_incomplete', 'metrics', field: 'surfaces');
    }
  }

  static void _validateConditions(
    RouteDraftData route,
    RouteValidationPolicy policy,
    _AddIssue block,
    _AddIssue warn,
  ) {
    final conditions = route.conditions;
    if (conditions.surfaceIds.any((String id) => id.trim().isEmpty) ||
        conditions.surfaceIds.toSet().length != conditions.surfaceIds.length) {
      block('condition_surface_ids_invalid', 'conditions', field: 'surfaceIds');
    }
    if (conditions.goodToKnowIds.any((String id) => id.trim().isEmpty) ||
        conditions.goodToKnowIds.toSet().length !=
            conditions.goodToKnowIds.length) {
      block(
        'condition_good_to_know_ids_invalid',
        'conditions',
        field: 'goodToKnowIds',
      );
    }
    if (conditions.verifiedAtUtc != null && !conditions.verifiedAtUtc!.isUtc) {
      block(
        'conditions_verified_at_not_utc',
        'conditions',
        field: 'verifiedAtUtc',
      );
    }
    final manual = conditions.manualDuration;
    if (manual != null) {
      if (manual.seconds <= 0) {
        block('manual_duration_invalid', 'conditions', field: 'manualDuration');
      } else {
        final auto = route.metrics.autoDurationSeconds;
        final deviation = auto <= 0
            ? 1.0
            : (manual.seconds - auto).abs() / auto;
        if (deviation > policy.manualDurationReasonDeviationRatio) {
          if (manual.reason == null || manual.reason!.trim().isEmpty) {
            block(
              'manual_duration_reason_required',
              'conditions',
              field: 'manualDuration',
            );
          } else {
            warn(
              'manual_duration_deviation',
              'conditions',
              field: 'manualDuration',
              remediation: RouteValidationRemediation.accept,
              safeMetrics: <String, num>{'ratio': deviation},
            );
          }
        }
      }
      if (route.metrics.effectiveDurationSeconds != manual.seconds) {
        block(
          'effective_duration_mismatch',
          'metrics',
          field: 'effectiveDurationSeconds',
        );
      }
    } else if (route.metrics.effectiveDurationSeconds !=
        route.metrics.autoDurationSeconds) {
      block(
        'effective_duration_mismatch',
        'metrics',
        field: 'effectiveDurationSeconds',
      );
    }
  }

  static void _validateSourceIssues(
    RouteDraftData route,
    _AddIssue block,
    _AddIssue warn,
  ) {
    final segmentIds = route.segments
        .map((RouteSegmentDraft segment) => segment.id)
        .toSet();
    for (final sourceIssue in route.sourceIssues) {
      if (sourceIssue.code.trim().isEmpty ||
          sourceIssue.safeMetrics.values.any((num value) => !value.isFinite)) {
        block(
          'source_issue_invalid',
          'sources',
          segmentId: sourceIssue.segmentId,
        );
        continue;
      }
      if (sourceIssue.segmentId != null &&
          !segmentIds.contains(sourceIssue.segmentId)) {
        block(
          'source_issue_segment_missing',
          'sources',
          segmentId: sourceIssue.segmentId,
        );
      }
      if (sourceIssue.severity == RouteSourceIssueSeverity.blocking) {
        block(
          sourceIssue.code,
          'sources',
          segmentId: sourceIssue.segmentId,
          remediation: RouteValidationRemediation.fix,
          safeMetrics: sourceIssue.safeMetrics,
        );
      } else {
        warn(
          sourceIssue.code,
          'sources',
          segmentId: sourceIssue.segmentId,
          remediation: RouteValidationRemediation.accept,
          safeMetrics: sourceIssue.safeMetrics,
        );
      }
    }
  }

  static void _validateOperations(RouteDraftData route, _AddIssue block) {
    final operationIds = <String>{};
    for (final operation in route.operations) {
      if (operation.operationId.trim().isEmpty ||
          !operationIds.add(operation.operationId) ||
          operation.expectedGeometryRevision < 0 ||
          operation.requestFingerprint.trim().isEmpty) {
        block('operation_invalid', 'operations', field: 'operations');
      }
      if (operation.segmentId != null &&
          route.segmentById(operation.segmentId!) == null) {
        block(
          'operation_segment_missing',
          'operations',
          segmentId: operation.segmentId,
        );
      }
      block(
        switch (operation.status) {
          RouteAsyncOperationStatus.pending => 'operation_pending',
          RouteAsyncOperationStatus.failed => 'operation_failed',
          RouteAsyncOperationStatus.stale => 'operation_stale',
        },
        'operations',
        segmentId: operation.segmentId,
        remediation: operation.status == RouteAsyncOperationStatus.failed
            ? RouteValidationRemediation.retry
            : RouteValidationRemediation.fix,
      );
    }
  }

  static bool _sameIntList(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _finiteNonNegative(double? value) =>
      value == null || (value.isFinite && value >= 0);
}

typedef _AddIssue =
    void Function(
      String code,
      String section, {
      String? field,
      String? segmentId,
      String? waypointId,
      RouteValidationRemediation? remediation,
      Map<String, num>? safeMetrics,
    });
