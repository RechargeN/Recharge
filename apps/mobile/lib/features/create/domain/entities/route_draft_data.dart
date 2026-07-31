import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_distance.dart';
import '../../../../core/geo/geo_point.dart';
import '../../../../core/geo/geometry_encoding.dart';
import '../../../../core/geo/geometry_hash.dart';
import 'route_quality_data.dart';

enum RouteCreationMethod {
  points,
  freehand,
  recordedGps,
  importedGpx,
  generated,
}

enum RouteShape { oneWay, loop, outAndBack }

enum RouteSegmentSource {
  routed,
  generated,
  freehand,
  recordedGps,
  importedGpx,
  intentionalDirect,
  fallbackDirect,
}

enum RouteSegmentDerivation { original, mirrored }

enum RouteSegmentOperationState { ready, routing, failed, stale }

enum RouteRoutingFailureCode {
  cancelled,
  offline,
  timeout,
  noPath,
  unsupportedProfile,
  outsideCoverage,
  providerRejected,
  unknown,
}

enum RouteWaypointTrackState { onTrack, offTrackConfirmed, unresolved }

enum RouteSourceIssueSeverity { warning, blocking }

enum RouteAsyncOperationKind { routing, generation, elevation, importGpx }

enum RouteAsyncOperationStatus { pending, failed, stale }

class RouteProfileRef {
  const RouteProfileRef({required this.id, required this.version});

  final String id;
  final int version;

  bool get isValid => id.trim().isNotEmpty && version > 0;
}

sealed class RoutePreferenceValue {
  const RoutePreferenceValue();

  Object get value;
}

class RouteBoolPreferenceValue extends RoutePreferenceValue {
  const RouteBoolPreferenceValue(this.value);

  @override
  final bool value;
}

class RouteNumberPreferenceValue extends RoutePreferenceValue {
  const RouteNumberPreferenceValue(this.value);

  @override
  final double value;

  bool get isValid => value.isFinite;
}

class RouteTextPreferenceValue extends RoutePreferenceValue {
  const RouteTextPreferenceValue(this.value);

  @override
  final String value;

  bool get isValid => value.trim().isNotEmpty;
}

class RouteRoutingPreferences {
  RouteRoutingPreferences({
    this.schemaVersion = 1,
    Map<String, RoutePreferenceValue> values =
        const <String, RoutePreferenceValue>{},
  }) : values = Map<String, RoutePreferenceValue>.unmodifiable(values);

  final int schemaVersion;
  final Map<String, RoutePreferenceValue> values;

  bool get isValid =>
      schemaVersion > 0 &&
      values.keys.every((String key) => key.trim().isNotEmpty) &&
      values.values.every(
        (RoutePreferenceValue value) => switch (value) {
          RouteNumberPreferenceValue() => value.isValid,
          RouteTextPreferenceValue() => value.isValid,
          RouteBoolPreferenceValue() => true,
        },
      );
}

class RouteGeometryEncodingPolicyDraft {
  const RouteGeometryEncodingPolicyDraft({
    required this.id,
    required this.version,
    required this.precision,
    required this.coordinateQuantizationMeters,
    required this.maxSimplificationErrorMeters,
    required this.maxPublishedPoints,
  });

  static const RouteGeometryEncodingPolicyDraft standard =
      RouteGeometryEncodingPolicyDraft(
        id: 'recharge.route.geometry',
        version: 1,
        precision: 5,
        coordinateQuantizationMeters: 1.2,
        maxSimplificationErrorMeters: 3,
        maxPublishedPoints: 10000,
      );

  final String id;
  final int version;
  final int precision;
  final double coordinateQuantizationMeters;
  final double maxSimplificationErrorMeters;
  final int maxPublishedPoints;

  bool get isValid =>
      id.trim().isNotEmpty &&
      version > 0 &&
      precision >= 0 &&
      precision <= 8 &&
      coordinateQuantizationMeters.isFinite &&
      coordinateQuantizationMeters >= 0 &&
      maxSimplificationErrorMeters.isFinite &&
      maxSimplificationErrorMeters >= 0 &&
      maxPublishedPoints >= 2;

  GeometryEncodingPolicy get corePolicy =>
      GeometryEncodingPolicy(precision: precision);

  String get canonicalId => '$id-v$version-p$precision';
}

class RouteGeometryDraft {
  RouteGeometryDraft({
    required Iterable<GeoPoint> points,
    required this.encodingPolicy,
    required this.encodedPolyline,
    required this.geometryHash,
    required this.bounds,
    required this.lengthMeters,
  }) : points = List<GeoPoint>.unmodifiable(points);

  factory RouteGeometryDraft.fromPoints(
    Iterable<GeoPoint> sourcePoints, {
    RouteGeometryEncodingPolicyDraft encodingPolicy =
        RouteGeometryEncodingPolicyDraft.standard,
  }) {
    final points = List<GeoPoint>.unmodifiable(sourcePoints);
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'sourcePoints', 'Cannot be empty.');
    }
    for (final point in points) {
      point.validated();
    }
    if (!encodingPolicy.isValid) {
      throw ArgumentError.value(
        encodingPolicy,
        'encodingPolicy',
        'Encoding policy is invalid.',
      );
    }

    return RouteGeometryDraft(
      points: points,
      encodingPolicy: encodingPolicy,
      encodedPolyline: GeometryEncoding.encode(
        points,
        policy: encodingPolicy.corePolicy,
      ),
      geometryHash: GeometryHash.fromPoints(
        points,
        policy: encodingPolicy.corePolicy,
      ).value,
      bounds: _boundsFor(points),
      lengthMeters: GeoDistance.polylineLengthMeters(points),
    );
  }

  final List<GeoPoint> points;
  final RouteGeometryEncodingPolicyDraft encodingPolicy;
  final String encodedPolyline;
  final String geometryHash;
  final GeoBounds bounds;
  final double lengthMeters;

  int get pointCount => points.length;

  bool get hasValidNumbers =>
      lengthMeters.isFinite &&
      lengthMeters >= 0 &&
      points.every((GeoPoint point) => point.isValid) &&
      bounds.isValid;

  bool get matchesCanonicalRepresentation {
    if (!encodingPolicy.isValid || points.isEmpty || !hasValidNumbers) {
      return false;
    }

    final encoded = GeometryEncoding.encode(
      points,
      policy: encodingPolicy.corePolicy,
    );
    final hash = GeometryHash.fromPoints(
      points,
      policy: encodingPolicy.corePolicy,
    ).value;
    final calculatedLength = GeoDistance.polylineLengthMeters(points);
    final calculatedBounds = _boundsFor(points);

    return encodedPolyline == encoded &&
        geometryHash == hash &&
        bounds == calculatedBounds &&
        (lengthMeters - calculatedLength).abs() <= 0.01;
  }

  static GeoBounds _boundsFor(List<GeoPoint> points) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    final longitudes = <double>[];

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      longitudes.add(point.longitude);
    }
    longitudes.sort();

    var west = longitudes.first;
    var east = longitudes.last;
    var largestGap = (longitudes.first + 360) - longitudes.last;
    for (var index = 1; index < longitudes.length; index += 1) {
      final gap = longitudes[index] - longitudes[index - 1];
      if (gap > largestGap) {
        largestGap = gap;
        west = longitudes[index];
        east = longitudes[index - 1];
      }
    }

    return GeoBounds(
      southwest: GeoPoint(latitude: south, longitude: west),
      northeast: GeoPoint(latitude: north, longitude: east),
    );
  }
}

class RouteAnchorDraft {
  const RouteAnchorDraft({
    required this.id,
    required this.position,
    this.authorIntentId,
  });

  final String id;
  final GeoPoint position;
  final String? authorIntentId;

  RouteAnchorDraft copyWith({
    String? id,
    GeoPoint? position,
    String? authorIntentId,
    bool clearAuthorIntentId = false,
  }) => RouteAnchorDraft(
    id: id ?? this.id,
    position: position ?? this.position,
    authorIntentId: clearAuthorIntentId
        ? null
        : (authorIntentId ?? this.authorIntentId),
  );
}

class RouteProviderReference {
  const RouteProviderReference({
    required this.code,
    required this.attribution,
    required this.licenseId,
    required this.dataVersion,
    required this.allowsPublication,
  });

  final String code;
  final String attribution;
  final String licenseId;
  final String dataVersion;
  final bool allowsPublication;

  bool get isValid =>
      code.trim().isNotEmpty &&
      attribution.trim().isNotEmpty &&
      licenseId.trim().isNotEmpty &&
      dataVersion.trim().isNotEmpty;
}

class RouteProvenanceDraft {
  const RouteProvenanceDraft({
    required this.sourceId,
    required this.sourceRevision,
    required this.createdAtUtc,
    this.parentSegmentId,
    this.algorithmVersion,
    this.provider,
  });

  final String sourceId;
  final int sourceRevision;
  final DateTime createdAtUtc;
  final String? parentSegmentId;
  final String? algorithmVersion;
  final RouteProviderReference? provider;

  bool get isValid =>
      sourceId.trim().isNotEmpty &&
      sourceRevision >= 0 &&
      createdAtUtc.isUtc &&
      (parentSegmentId == null || parentSegmentId!.trim().isNotEmpty) &&
      (algorithmVersion == null || algorithmVersion!.trim().isNotEmpty) &&
      (provider == null || provider!.isValid);
}

class RouteSegmentRawStats {
  const RouteSegmentRawStats({
    required this.distanceMeters,
    this.ascentMeters,
    this.descentMeters,
    this.minimumElevationMeters,
    this.maximumElevationMeters,
    this.recordedDurationSeconds,
  });

  final double distanceMeters;
  final double? ascentMeters;
  final double? descentMeters;
  final double? minimumElevationMeters;
  final double? maximumElevationMeters;
  final int? recordedDurationSeconds;

  bool get isValid =>
      distanceMeters.isFinite &&
      distanceMeters >= 0 &&
      _finiteNonNegative(ascentMeters) &&
      _finiteNonNegative(descentMeters) &&
      _finite(minimumElevationMeters) &&
      _finite(maximumElevationMeters) &&
      (recordedDurationSeconds == null || recordedDurationSeconds! >= 0);

  static bool _finite(double? value) => value == null || value.isFinite;

  static bool _finiteNonNegative(double? value) =>
      value == null || (value.isFinite && value >= 0);
}

class RouteSegmentDraft {
  RouteSegmentDraft({
    required this.id,
    required this.fromAnchorId,
    required this.toAnchorId,
    required this.order,
    required this.source,
    required this.derivation,
    required this.geometry,
    required this.provenance,
    required this.geometryRevision,
    this.operationState = RouteSegmentOperationState.ready,
    this.profileOverride,
    this.preferencesOverride,
    this.rawStats,
    this.providerDurationSeconds,
    this.needsReview = false,
    this.fallbackReason,
  });

  final String id;
  final String fromAnchorId;
  final String toAnchorId;
  final int order;
  final RouteSegmentSource source;
  final RouteSegmentDerivation derivation;
  final RouteGeometryDraft geometry;
  final RouteProvenanceDraft provenance;
  final int geometryRevision;
  final RouteSegmentOperationState operationState;
  final RouteProfileRef? profileOverride;
  final RouteRoutingPreferences? preferencesOverride;
  final RouteSegmentRawStats? rawStats;
  final int? providerDurationSeconds;
  final bool needsReview;
  final RouteRoutingFailureCode? fallbackReason;

  double get distanceMeters => geometry.lengthMeters;

  RouteSegmentDraft copyWith({
    String? id,
    String? fromAnchorId,
    String? toAnchorId,
    int? order,
    RouteSegmentSource? source,
    RouteSegmentDerivation? derivation,
    RouteGeometryDraft? geometry,
    RouteProvenanceDraft? provenance,
    int? geometryRevision,
    RouteSegmentOperationState? operationState,
    RouteProfileRef? profileOverride,
    bool clearProfileOverride = false,
    RouteRoutingPreferences? preferencesOverride,
    bool clearPreferencesOverride = false,
    RouteSegmentRawStats? rawStats,
    bool clearRawStats = false,
    int? providerDurationSeconds,
    bool clearProviderDurationSeconds = false,
    bool? needsReview,
    RouteRoutingFailureCode? fallbackReason,
    bool clearFallbackReason = false,
  }) => RouteSegmentDraft(
    id: id ?? this.id,
    fromAnchorId: fromAnchorId ?? this.fromAnchorId,
    toAnchorId: toAnchorId ?? this.toAnchorId,
    order: order ?? this.order,
    source: source ?? this.source,
    derivation: derivation ?? this.derivation,
    geometry: geometry ?? this.geometry,
    provenance: provenance ?? this.provenance,
    geometryRevision: geometryRevision ?? this.geometryRevision,
    operationState: operationState ?? this.operationState,
    profileOverride: clearProfileOverride
        ? null
        : (profileOverride ?? this.profileOverride),
    preferencesOverride: clearPreferencesOverride
        ? null
        : (preferencesOverride ?? this.preferencesOverride),
    rawStats: clearRawStats ? null : (rawStats ?? this.rawStats),
    providerDurationSeconds: clearProviderDurationSeconds
        ? null
        : (providerDurationSeconds ?? this.providerDurationSeconds),
    needsReview: needsReview ?? this.needsReview,
    fallbackReason: clearFallbackReason
        ? null
        : (fallbackReason ?? this.fallbackReason),
  );
}

class RouteAccessInfoDraft {
  RouteAccessInfoDraft({
    this.instructions,
    List<String> restrictionIds = const <String>[],
    this.openingNote,
  }) : restrictionIds = List<String>.unmodifiable(restrictionIds);

  final String? instructions;
  final List<String> restrictionIds;
  final String? openingNote;
}

class RouteWaypointDraft {
  RouteWaypointDraft({
    required this.id,
    required this.position,
    required this.typeId,
    required this.trackState,
    this.anchorId,
    this.segmentId,
    this.distanceFromStartMeters,
    this.distanceFromTrackMeters,
    this.catalogVersion = 1,
    this.title,
    this.description,
    this.note,
    this.safetyNote,
    List<String> technicalAttributeIds = const <String>[],
    List<String> photoIds = const <String>[],
    this.verifiedAtUtc,
    this.access,
  }) : technicalAttributeIds = List<String>.unmodifiable(
         technicalAttributeIds,
       ),
       photoIds = List<String>.unmodifiable(photoIds);

  final String id;
  final String? anchorId;
  final String? segmentId;
  final GeoPoint position;
  final String typeId;
  final RouteWaypointTrackState trackState;
  final double? distanceFromStartMeters;
  final double? distanceFromTrackMeters;
  final int catalogVersion;
  final String? title;
  final String? description;
  final String? note;
  final String? safetyNote;
  final List<String> technicalAttributeIds;
  final List<String> photoIds;
  final DateTime? verifiedAtUtc;
  final RouteAccessInfoDraft? access;

  RouteWaypointDraft copyWith({
    String? id,
    String? anchorId,
    bool clearAnchorId = false,
    String? segmentId,
    bool clearSegmentId = false,
    GeoPoint? position,
    String? typeId,
    RouteWaypointTrackState? trackState,
    double? distanceFromStartMeters,
    bool clearDistanceFromStartMeters = false,
    double? distanceFromTrackMeters,
    bool clearDistanceFromTrackMeters = false,
    int? catalogVersion,
    String? title,
    bool clearTitle = false,
    String? description,
    bool clearDescription = false,
    String? note,
    bool clearNote = false,
    String? safetyNote,
    bool clearSafetyNote = false,
    Iterable<String>? technicalAttributeIds,
    Iterable<String>? photoIds,
    DateTime? verifiedAtUtc,
    bool clearVerifiedAtUtc = false,
    RouteAccessInfoDraft? access,
    bool clearAccess = false,
  }) => RouteWaypointDraft(
    id: id ?? this.id,
    anchorId: clearAnchorId ? null : (anchorId ?? this.anchorId),
    segmentId: clearSegmentId ? null : (segmentId ?? this.segmentId),
    position: position ?? this.position,
    typeId: typeId ?? this.typeId,
    trackState: trackState ?? this.trackState,
    distanceFromStartMeters: clearDistanceFromStartMeters
        ? null
        : (distanceFromStartMeters ?? this.distanceFromStartMeters),
    distanceFromTrackMeters: clearDistanceFromTrackMeters
        ? null
        : (distanceFromTrackMeters ?? this.distanceFromTrackMeters),
    catalogVersion: catalogVersion ?? this.catalogVersion,
    title: clearTitle ? null : (title ?? this.title),
    description: clearDescription ? null : (description ?? this.description),
    note: clearNote ? null : (note ?? this.note),
    safetyNote: clearSafetyNote ? null : (safetyNote ?? this.safetyNote),
    technicalAttributeIds:
        technicalAttributeIds?.toList(growable: false) ??
        this.technicalAttributeIds,
    photoIds: photoIds?.toList(growable: false) ?? this.photoIds,
    verifiedAtUtc: clearVerifiedAtUtc
        ? null
        : (verifiedAtUtc ?? this.verifiedAtUtc),
    access: clearAccess ? null : (access ?? this.access),
  );
}

class RouteManualDurationDraft {
  const RouteManualDurationDraft({required this.seconds, this.reason});

  final int seconds;
  final String? reason;
}

class RouteConditionsDraft {
  RouteConditionsDraft({
    this.difficultyId,
    List<String> surfaceIds = const <String>[],
    this.isMarked,
    this.bestTimeId,
    List<String> goodToKnowIds = const <String>[],
    this.verifiedAtUtc,
    this.manualDuration,
  }) : surfaceIds = List<String>.unmodifiable(surfaceIds),
       goodToKnowIds = List<String>.unmodifiable(goodToKnowIds);

  final String? difficultyId;
  final List<String> surfaceIds;
  final bool? isMarked;
  final String? bestTimeId;
  final List<String> goodToKnowIds;
  final DateTime? verifiedAtUtc;
  final RouteManualDurationDraft? manualDuration;
}

class RouteSourceIssueDraft {
  RouteSourceIssueDraft({
    required this.id,
    required this.code,
    required this.severity,
    this.segmentId,
    Map<String, num> safeMetrics = const <String, num>{},
  }) : safeMetrics = Map<String, num>.unmodifiable(safeMetrics);

  final String id;
  final String code;
  final String? segmentId;
  final RouteSourceIssueSeverity severity;
  final Map<String, num> safeMetrics;
}

class RouteMetricsDraft {
  RouteMetricsDraft({
    required this.geometryRevision,
    required this.calculationModelId,
    required this.calculationModelVersion,
    required this.distanceMeters,
    required this.autoDurationSeconds,
    required this.effectiveDurationSeconds,
    required this.directDistanceMeters,
    required this.fallbackDistanceMeters,
    this.ascentMeters,
    this.descentMeters,
    this.minimumElevationMeters,
    this.maximumElevationMeters,
    Map<String, double> surfaceDistanceMeters = const <String, double>{},
    this.difficultyId,
  }) : surfaceDistanceMeters = Map<String, double>.unmodifiable(
         surfaceDistanceMeters,
       );

  final int geometryRevision;
  final String calculationModelId;
  final int calculationModelVersion;
  final double distanceMeters;
  final double? ascentMeters;
  final double? descentMeters;
  final double? minimumElevationMeters;
  final double? maximumElevationMeters;
  final int autoDurationSeconds;
  final int effectiveDurationSeconds;
  final double directDistanceMeters;
  final double fallbackDistanceMeters;
  final Map<String, double> surfaceDistanceMeters;
  final String? difficultyId;

  bool get hasValidNumbers =>
      geometryRevision >= 0 &&
      calculationModelId.trim().isNotEmpty &&
      calculationModelVersion > 0 &&
      distanceMeters.isFinite &&
      distanceMeters >= 0 &&
      _finiteNonNegative(ascentMeters) &&
      _finiteNonNegative(descentMeters) &&
      _finite(minimumElevationMeters) &&
      _finite(maximumElevationMeters) &&
      autoDurationSeconds >= 0 &&
      effectiveDurationSeconds >= 0 &&
      directDistanceMeters.isFinite &&
      directDistanceMeters >= 0 &&
      fallbackDistanceMeters.isFinite &&
      fallbackDistanceMeters >= 0 &&
      surfaceDistanceMeters.values.every(
        (double value) => value.isFinite && value >= 0,
      );

  static bool _finite(double? value) => value == null || value.isFinite;

  static bool _finiteNonNegative(double? value) =>
      value == null || (value.isFinite && value >= 0);
}

class RouteAsyncOperationDraft {
  const RouteAsyncOperationDraft({
    required this.operationId,
    required this.kind,
    required this.status,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    this.segmentId,
    this.failureCode,
  });

  final String operationId;
  final RouteAsyncOperationKind kind;
  final RouteAsyncOperationStatus status;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final String? segmentId;
  final String? failureCode;
}

class RouteDraftData {
  RouteDraftData({
    this.schemaVersion = 2,
    this.revision = 0,
    required this.geometryRevision,
    required this.creationMethod,
    required this.shape,
    required this.profile,
    required this.preferences,
    required Iterable<RouteAnchorDraft> anchors,
    required Iterable<RouteSegmentDraft> segments,
    required Iterable<RouteWaypointDraft> waypoints,
    required this.conditions,
    required Iterable<RouteSourceIssueDraft> sourceIssues,
    required this.metrics,
    required this.encodingPolicy,
    this.quality,
    Iterable<RouteAsyncOperationDraft> operations =
        const <RouteAsyncOperationDraft>[],
    Map<String, Object?> unknownFields = const <String, Object?>{},
    this.turningAnchorId,
  }) : anchors = List<RouteAnchorDraft>.unmodifiable(anchors),
       segments = List<RouteSegmentDraft>.unmodifiable(segments),
       waypoints = List<RouteWaypointDraft>.unmodifiable(waypoints),
       sourceIssues = List<RouteSourceIssueDraft>.unmodifiable(sourceIssues),
       operations = List<RouteAsyncOperationDraft>.unmodifiable(operations),
       unknownFields = Map<String, Object?>.unmodifiable(unknownFields);

  static const int currentSchemaVersion = 2;
  final int schemaVersion;
  final int revision;
  final int geometryRevision;
  final RouteCreationMethod creationMethod;
  final RouteShape shape;
  final String? turningAnchorId;
  final RouteProfileRef profile;
  final RouteRoutingPreferences preferences;
  final List<RouteAnchorDraft> anchors;
  final List<RouteSegmentDraft> segments;
  final List<RouteWaypointDraft> waypoints;
  final RouteConditionsDraft conditions;
  final List<RouteSourceIssueDraft> sourceIssues;
  final RouteMetricsDraft metrics;
  final RouteGeometryEncodingPolicyDraft encodingPolicy;
  final RouteQualityDraft? quality;
  final List<RouteAsyncOperationDraft> operations;
  final Map<String, Object?> unknownFields;

  List<RouteSegmentDraft> get orderedSegments {
    final ordered = List<RouteSegmentDraft>.of(segments)
      ..sort(
        (RouteSegmentDraft left, RouteSegmentDraft right) =>
            left.order.compareTo(right.order),
      );
    return List<RouteSegmentDraft>.unmodifiable(ordered);
  }

  RouteAnchorDraft? anchorById(String id) {
    for (final anchor in anchors) {
      if (anchor.id == id) return anchor;
    }
    return null;
  }

  RouteSegmentDraft? segmentById(String id) {
    for (final segment in segments) {
      if (segment.id == id) return segment;
    }
    return null;
  }

  int get geometryPointCount => segments.fold<int>(
    0,
    (int total, RouteSegmentDraft segment) =>
        total + segment.geometry.pointCount,
  );

  double get calculatedDistanceMeters => segments.fold<double>(
    0,
    (double total, RouteSegmentDraft segment) => total + segment.distanceMeters,
  );

  Iterable<String> get nestedIds sync* {
    for (final anchor in anchors) {
      yield anchor.id;
    }
    for (final segment in segments) {
      yield segment.id;
    }
    for (final waypoint in waypoints) {
      yield waypoint.id;
    }
    for (final issue in sourceIssues) {
      yield issue.id;
    }
    for (final verification
        in quality?.verifications ?? const <RouteVerificationRecordDraft>[]) {
      yield verification.id;
    }
  }

  RouteDraftData nextRevision() => copyWith(revision: revision + 1);

  RouteDraftData copyWith({
    int? schemaVersion,
    int? revision,
    int? geometryRevision,
    RouteCreationMethod? creationMethod,
    RouteShape? shape,
    String? turningAnchorId,
    bool clearTurningAnchorId = false,
    RouteProfileRef? profile,
    RouteRoutingPreferences? preferences,
    Iterable<RouteAnchorDraft>? anchors,
    Iterable<RouteSegmentDraft>? segments,
    Iterable<RouteWaypointDraft>? waypoints,
    RouteConditionsDraft? conditions,
    Iterable<RouteSourceIssueDraft>? sourceIssues,
    RouteMetricsDraft? metrics,
    RouteGeometryEncodingPolicyDraft? encodingPolicy,
    RouteQualityDraft? quality,
    bool clearQuality = false,
    Iterable<RouteAsyncOperationDraft>? operations,
    Map<String, Object?>? unknownFields,
  }) => RouteDraftData(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    revision: revision ?? this.revision,
    geometryRevision: geometryRevision ?? this.geometryRevision,
    creationMethod: creationMethod ?? this.creationMethod,
    shape: shape ?? this.shape,
    turningAnchorId: clearTurningAnchorId
        ? null
        : (turningAnchorId ?? this.turningAnchorId),
    profile: profile ?? this.profile,
    preferences: preferences ?? this.preferences,
    anchors: anchors ?? this.anchors,
    segments: segments ?? this.segments,
    waypoints: waypoints ?? this.waypoints,
    conditions: conditions ?? this.conditions,
    sourceIssues: sourceIssues ?? this.sourceIssues,
    metrics: metrics ?? this.metrics,
    encodingPolicy: encodingPolicy ?? this.encodingPolicy,
    quality: clearQuality ? null : (quality ?? this.quality),
    operations: operations ?? this.operations,
    unknownFields: unknownFields ?? this.unknownFields,
  );

  RouteDraftData replaceLocalIds(String Function() generateId) {
    final replacements = <String, String>{};
    String permanent(String id) {
      if (!id.startsWith('loc_')) return id;
      return replacements.putIfAbsent(id, generateId);
    }

    for (final id in nestedIds) {
      permanent(id);
    }

    return copyWith(
      anchors: anchors
          .map(
            (RouteAnchorDraft anchor) => RouteAnchorDraft(
              id: permanent(anchor.id),
              position: anchor.position,
              authorIntentId: anchor.authorIntentId,
            ),
          )
          .toList(growable: false),
      segments: segments
          .map(
            (RouteSegmentDraft segment) => RouteSegmentDraft(
              id: permanent(segment.id),
              fromAnchorId: permanent(segment.fromAnchorId),
              toAnchorId: permanent(segment.toAnchorId),
              order: segment.order,
              source: segment.source,
              derivation: segment.derivation,
              geometry: segment.geometry,
              provenance: RouteProvenanceDraft(
                sourceId: segment.provenance.sourceId,
                sourceRevision: segment.provenance.sourceRevision,
                createdAtUtc: segment.provenance.createdAtUtc,
                parentSegmentId: segment.provenance.parentSegmentId == null
                    ? null
                    : permanent(segment.provenance.parentSegmentId!),
                algorithmVersion: segment.provenance.algorithmVersion,
                provider: segment.provenance.provider,
              ),
              geometryRevision: segment.geometryRevision,
              operationState: segment.operationState,
              profileOverride: segment.profileOverride,
              preferencesOverride: segment.preferencesOverride,
              rawStats: segment.rawStats,
              providerDurationSeconds: segment.providerDurationSeconds,
              needsReview: segment.needsReview,
              fallbackReason: segment.fallbackReason,
            ),
          )
          .toList(growable: false),
      waypoints: waypoints
          .map(
            (RouteWaypointDraft waypoint) => RouteWaypointDraft(
              id: permanent(waypoint.id),
              anchorId: waypoint.anchorId == null
                  ? null
                  : permanent(waypoint.anchorId!),
              segmentId: waypoint.segmentId == null
                  ? null
                  : permanent(waypoint.segmentId!),
              position: waypoint.position,
              typeId: waypoint.typeId,
              trackState: waypoint.trackState,
              distanceFromStartMeters: waypoint.distanceFromStartMeters,
              distanceFromTrackMeters: waypoint.distanceFromTrackMeters,
              catalogVersion: waypoint.catalogVersion,
              title: waypoint.title,
              description: waypoint.description,
              note: waypoint.note,
              safetyNote: waypoint.safetyNote,
              technicalAttributeIds: waypoint.technicalAttributeIds,
              photoIds: waypoint.photoIds,
              verifiedAtUtc: waypoint.verifiedAtUtc,
              access: waypoint.access,
            ),
          )
          .toList(growable: false),
      sourceIssues: sourceIssues
          .map(
            (RouteSourceIssueDraft issue) => RouteSourceIssueDraft(
              id: permanent(issue.id),
              code: issue.code,
              severity: issue.severity,
              segmentId: issue.segmentId == null
                  ? null
                  : permanent(issue.segmentId!),
              safeMetrics: issue.safeMetrics,
            ),
          )
          .toList(growable: false),
      quality: quality?.copyWith(
        verifications: quality!.verifications
            .map(
              (verification) => RouteVerificationRecordDraft(
                id: permanent(verification.id),
                kind: verification.kind,
                actorId: verification.actorId,
                geometryRevision: verification.geometryRevision,
                verifiedAtUtc: verification.verifiedAtUtc,
                evidenceMediaIds: verification.evidenceMediaIds,
                note: verification.note,
              ),
            )
            .toList(growable: false),
      ),
      operations: operations
          .map(
            (RouteAsyncOperationDraft operation) => RouteAsyncOperationDraft(
              operationId: permanent(operation.operationId),
              kind: operation.kind,
              status: operation.status,
              expectedGeometryRevision: operation.expectedGeometryRevision,
              requestFingerprint: operation.requestFingerprint,
              segmentId: operation.segmentId == null
                  ? null
                  : permanent(operation.segmentId!),
              failureCode: operation.failureCode,
            ),
          )
          .toList(growable: false),
      turningAnchorId: turningAnchorId == null
          ? null
          : permanent(turningAnchorId!),
    );
  }
}
