import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/route_quality_data.dart';

class UnsupportedRouteSchemaException implements Exception {
  const UnsupportedRouteSchemaException(this.version);

  final int version;

  @override
  String toString() => 'Unsupported Route schema version: $version';
}

class RouteDraftFormatException implements Exception {
  const RouteDraftFormatException(this.path);

  final String path;

  @override
  String toString() => 'Invalid Route draft payload at $path';
}

abstract final class RouteDraftMapper {
  static RouteDraftData fromJson(Map<String, Object?> json) {
    final version = _int(json['schemaVersion'], 'schemaVersion');
    if (version > RouteDraftData.currentSchemaVersion) {
      throw UnsupportedRouteSchemaException(version);
    }

    return RouteDraftData(
      schemaVersion: RouteDraftData.currentSchemaVersion,
      revision: _intOr(json['revision'], 0),
      geometryRevision: _int(json['geometryRevision'], 'geometryRevision'),
      creationMethod: _enumValue(
        RouteCreationMethod.values,
        json['creationMethod'],
        'creationMethod',
      ),
      shape: _enumValue(RouteShape.values, json['shape'], 'shape'),
      turningAnchorId: _nullableString(json['turningAnchorId']),
      profile: _profile(_map(json['profile'], 'profile')),
      preferences: _preferences(
        _map(json['preferences'], 'preferences'),
        'preferences',
      ),
      anchors: _list(json['anchors'], 'anchors')
          .asMap()
          .entries
          .map(
            (entry) => _anchor(
              _map(entry.value, 'anchors[${entry.key}]'),
              'anchors[${entry.key}]',
            ),
          )
          .toList(growable: false),
      segments: _list(json['segments'], 'segments')
          .asMap()
          .entries
          .map(
            (entry) => _segment(
              _map(entry.value, 'segments[${entry.key}]'),
              'segments[${entry.key}]',
            ),
          )
          .toList(growable: false),
      waypoints: _list(json['waypoints'], 'waypoints')
          .asMap()
          .entries
          .map(
            (entry) => _waypoint(
              _map(entry.value, 'waypoints[${entry.key}]'),
              'waypoints[${entry.key}]',
            ),
          )
          .toList(growable: false),
      conditions: _conditions(_map(json['conditions'], 'conditions')),
      sourceIssues: _list(json['sourceIssues'], 'sourceIssues')
          .asMap()
          .entries
          .map(
            (entry) => _sourceIssue(
              _map(entry.value, 'sourceIssues[${entry.key}]'),
              'sourceIssues[${entry.key}]',
            ),
          )
          .toList(growable: false),
      metrics: _metrics(_map(json['metrics'], 'metrics')),
      quality: json['quality'] is Map
          ? _quality(_map(json['quality'], 'quality'))
          : null,
      encodingPolicy: _encodingPolicy(
        _map(json['encodingPolicy'], 'encodingPolicy'),
      ),
      operations: _listOrEmpty(json['operations'])
          .asMap()
          .entries
          .map(
            (entry) => _operation(
              _map(entry.value, 'operations[${entry.key}]'),
              'operations[${entry.key}]',
            ),
          )
          .toList(growable: false),
      unknownFields: _deepCopyMap(json),
    );
  }

  static Map<String, Object?> toJson(RouteDraftData value) {
    final known = <String, Object?>{
      'schemaVersion': RouteDraftData.currentSchemaVersion,
      'revision': value.revision,
      'geometryRevision': value.geometryRevision,
      'creationMethod': value.creationMethod.name,
      'shape': value.shape.name,
      'turningAnchorId': value.turningAnchorId,
      'profile': <String, Object?>{
        'id': value.profile.id,
        'version': value.profile.version,
      },
      'preferences': _preferencesToJson(value.preferences),
      'anchors': value.anchors.map(_anchorToJson).toList(growable: false),
      'segments': value.segments.map(_segmentToJson).toList(growable: false),
      'waypoints': value.waypoints.map(_waypointToJson).toList(growable: false),
      'conditions': _conditionsToJson(value.conditions),
      'sourceIssues': value.sourceIssues
          .map(_sourceIssueToJson)
          .toList(growable: false),
      'metrics': _metricsToJson(value.metrics),
      'quality': value.quality == null ? null : _qualityToJson(value.quality!),
      'encodingPolicy': _encodingPolicyToJson(value.encodingPolicy),
      'operations': value.operations
          .map(_operationToJson)
          .toList(growable: false),
    };
    return _deepMerge(value.unknownFields, known);
  }

  static RouteProfileRef _profile(Map<String, Object?> json) => RouteProfileRef(
    id: _string(json['id'], 'profile.id'),
    version: _int(json['version'], 'profile.version'),
  );

  static Map<String, Object?> _profileToJson(RouteProfileRef value) =>
      <String, Object?>{'id': value.id, 'version': value.version};

  static RouteRoutingPreferences _preferences(
    Map<String, Object?> json,
    String path,
  ) {
    final rawValues = _map(json['values'], '$path.values');
    return RouteRoutingPreferences(
      schemaVersion: _intOr(json['schemaVersion'], 1),
      values: <String, RoutePreferenceValue>{
        for (final entry in rawValues.entries)
          entry.key: _preferenceValue(entry.value, '$path.values.${entry.key}'),
      },
    );
  }

  static RoutePreferenceValue _preferenceValue(Object? value, String path) {
    final json = _map(value, path);
    final type = _string(json['type'], '$path.type');
    return switch (type) {
      'bool' => RouteBoolPreferenceValue(_bool(json['value'], '$path.value')),
      'number' => RouteNumberPreferenceValue(
        _double(json['value'], '$path.value'),
      ),
      'text' => RouteTextPreferenceValue(_string(json['value'], '$path.value')),
      _ => throw RouteDraftFormatException('$path.type'),
    };
  }

  static Map<String, Object?> _preferencesToJson(
    RouteRoutingPreferences value,
  ) => <String, Object?>{
    'schemaVersion': value.schemaVersion,
    'values': <String, Object?>{
      for (final entry in value.values.entries)
        entry.key: switch (entry.value) {
          RouteBoolPreferenceValue() => <String, Object?>{
            'type': 'bool',
            'value': entry.value.value,
          },
          RouteNumberPreferenceValue() => <String, Object?>{
            'type': 'number',
            'value': entry.value.value,
          },
          RouteTextPreferenceValue() => <String, Object?>{
            'type': 'text',
            'value': entry.value.value,
          },
        },
    },
  };

  static RouteAnchorDraft _anchor(Map<String, Object?> json, String path) =>
      RouteAnchorDraft(
        id: _string(json['id'], '$path.id'),
        position: _point(
          _map(json['position'], '$path.position'),
          '$path.position',
        ),
        authorIntentId: _nullableString(json['authorIntentId']),
      );

  static Map<String, Object?> _anchorToJson(RouteAnchorDraft value) =>
      <String, Object?>{
        'id': value.id,
        'position': _pointToJson(value.position),
        'authorIntentId': value.authorIntentId,
      };

  static RouteSegmentDraft _segment(Map<String, Object?> json, String path) =>
      RouteSegmentDraft(
        id: _string(json['id'], '$path.id'),
        fromAnchorId: _string(json['fromAnchorId'], '$path.fromAnchorId'),
        toAnchorId: _string(json['toAnchorId'], '$path.toAnchorId'),
        order: _int(json['order'], '$path.order'),
        source: _enumValue(
          RouteSegmentSource.values,
          json['source'],
          '$path.source',
        ),
        derivation: _enumValue(
          RouteSegmentDerivation.values,
          json['derivation'],
          '$path.derivation',
        ),
        geometry: _geometry(
          _map(json['geometry'], '$path.geometry'),
          '$path.geometry',
        ),
        provenance: _provenance(
          _map(json['provenance'], '$path.provenance'),
          '$path.provenance',
        ),
        geometryRevision: _int(
          json['geometryRevision'],
          '$path.geometryRevision',
        ),
        operationState: _enumValueOr(
          RouteSegmentOperationState.values,
          json['operationState'],
          RouteSegmentOperationState.ready,
        ),
        profileOverride: json['profileOverride'] is Map
            ? _profile(_map(json['profileOverride'], '$path.profileOverride'))
            : null,
        preferencesOverride: json['preferencesOverride'] is Map
            ? _preferences(
                _map(json['preferencesOverride'], '$path.preferencesOverride'),
                '$path.preferencesOverride',
              )
            : null,
        rawStats: json['rawStats'] is Map
            ? _rawStats(_map(json['rawStats'], '$path.rawStats'))
            : null,
        providerDurationSeconds: _nullableInt(json['providerDurationSeconds']),
        needsReview: _boolOr(json['needsReview'], false),
        fallbackReason: _nullableEnumValue(
          RouteRoutingFailureCode.values,
          json['fallbackReason'],
        ),
      );

  static Map<String, Object?> _segmentToJson(RouteSegmentDraft value) =>
      <String, Object?>{
        'id': value.id,
        'fromAnchorId': value.fromAnchorId,
        'toAnchorId': value.toAnchorId,
        'order': value.order,
        'source': value.source.name,
        'derivation': value.derivation.name,
        'geometry': _geometryToJson(value.geometry),
        'provenance': _provenanceToJson(value.provenance),
        'geometryRevision': value.geometryRevision,
        'operationState': value.operationState.name,
        'profileOverride': value.profileOverride == null
            ? null
            : _profileToJson(value.profileOverride!),
        'preferencesOverride': value.preferencesOverride == null
            ? null
            : _preferencesToJson(value.preferencesOverride!),
        'rawStats': value.rawStats == null
            ? null
            : _rawStatsToJson(value.rawStats!),
        'providerDurationSeconds': value.providerDurationSeconds,
        'needsReview': value.needsReview,
        'fallbackReason': value.fallbackReason?.name,
      };

  static RouteGeometryDraft _geometry(Map<String, Object?> json, String path) =>
      RouteGeometryDraft(
        points: _list(json['points'], '$path.points')
            .asMap()
            .entries
            .map(
              (entry) => _point(
                _map(entry.value, '$path.points[${entry.key}]'),
                '$path.points[${entry.key}]',
              ),
            )
            .toList(growable: false),
        encodingPolicy: _encodingPolicy(
          _map(json['encodingPolicy'], '$path.encodingPolicy'),
        ),
        encodedPolyline: _string(
          json['encodedPolyline'],
          '$path.encodedPolyline',
        ),
        geometryHash: _string(json['geometryHash'], '$path.geometryHash'),
        bounds: _bounds(_map(json['bounds'], '$path.bounds'), '$path.bounds'),
        lengthMeters: _double(json['lengthMeters'], '$path.lengthMeters'),
      );

  static Map<String, Object?> _geometryToJson(RouteGeometryDraft value) =>
      <String, Object?>{
        'points': value.points.map(_pointToJson).toList(growable: false),
        'encodingPolicy': _encodingPolicyToJson(value.encodingPolicy),
        'encodedPolyline': value.encodedPolyline,
        'geometryHash': value.geometryHash,
        'bounds': <String, Object?>{
          'southwest': _pointToJson(value.bounds.southwest),
          'northeast': _pointToJson(value.bounds.northeast),
        },
        'lengthMeters': value.lengthMeters,
      };

  static RouteGeometryEncodingPolicyDraft _encodingPolicy(
    Map<String, Object?> json,
  ) => RouteGeometryEncodingPolicyDraft(
    id: _string(json['id'], 'encodingPolicy.id'),
    version: _int(json['version'], 'encodingPolicy.version'),
    precision: _int(json['precision'], 'encodingPolicy.precision'),
    coordinateQuantizationMeters: _double(
      json['coordinateQuantizationMeters'],
      'encodingPolicy.coordinateQuantizationMeters',
    ),
    maxSimplificationErrorMeters: _double(
      json['maxSimplificationErrorMeters'],
      'encodingPolicy.maxSimplificationErrorMeters',
    ),
    maxPublishedPoints: _int(
      json['maxPublishedPoints'],
      'encodingPolicy.maxPublishedPoints',
    ),
  );

  static Map<String, Object?> _encodingPolicyToJson(
    RouteGeometryEncodingPolicyDraft value,
  ) => <String, Object?>{
    'id': value.id,
    'version': value.version,
    'precision': value.precision,
    'coordinateQuantizationMeters': value.coordinateQuantizationMeters,
    'maxSimplificationErrorMeters': value.maxSimplificationErrorMeters,
    'maxPublishedPoints': value.maxPublishedPoints,
  };

  static RouteProvenanceDraft _provenance(
    Map<String, Object?> json,
    String path,
  ) => RouteProvenanceDraft(
    sourceId: _string(json['sourceId'], '$path.sourceId'),
    sourceRevision: _int(json['sourceRevision'], '$path.sourceRevision'),
    createdAtUtc: _dateTime(json['createdAtUtc'], '$path.createdAtUtc'),
    parentSegmentId: _nullableString(json['parentSegmentId']),
    algorithmVersion: _nullableString(json['algorithmVersion']),
    provider: json['provider'] is Map
        ? _provider(_map(json['provider'], '$path.provider'), '$path.provider')
        : null,
  );

  static Map<String, Object?> _provenanceToJson(RouteProvenanceDraft value) =>
      <String, Object?>{
        'sourceId': value.sourceId,
        'sourceRevision': value.sourceRevision,
        'createdAtUtc': value.createdAtUtc.toIso8601String(),
        'parentSegmentId': value.parentSegmentId,
        'algorithmVersion': value.algorithmVersion,
        'provider': value.provider == null
            ? null
            : _providerToJson(value.provider!),
      };

  static RouteProviderReference _provider(
    Map<String, Object?> json,
    String path,
  ) => RouteProviderReference(
    code: _string(json['code'], '$path.code'),
    attribution: _string(json['attribution'], '$path.attribution'),
    licenseId: _string(json['licenseId'], '$path.licenseId'),
    dataVersion: _string(json['dataVersion'], '$path.dataVersion'),
    allowsPublication: _bool(
      json['allowsPublication'],
      '$path.allowsPublication',
    ),
  );

  static Map<String, Object?> _providerToJson(RouteProviderReference value) =>
      <String, Object?>{
        'code': value.code,
        'attribution': value.attribution,
        'licenseId': value.licenseId,
        'dataVersion': value.dataVersion,
        'allowsPublication': value.allowsPublication,
      };

  static RouteSegmentRawStats _rawStats(Map<String, Object?> json) =>
      RouteSegmentRawStats(
        distanceMeters: _double(
          json['distanceMeters'],
          'rawStats.distanceMeters',
        ),
        ascentMeters: _nullableDouble(json['ascentMeters']),
        descentMeters: _nullableDouble(json['descentMeters']),
        minimumElevationMeters: _nullableDouble(json['minimumElevationMeters']),
        maximumElevationMeters: _nullableDouble(json['maximumElevationMeters']),
        recordedDurationSeconds: _nullableInt(json['recordedDurationSeconds']),
      );

  static Map<String, Object?> _rawStatsToJson(RouteSegmentRawStats value) =>
      <String, Object?>{
        'distanceMeters': value.distanceMeters,
        'ascentMeters': value.ascentMeters,
        'descentMeters': value.descentMeters,
        'minimumElevationMeters': value.minimumElevationMeters,
        'maximumElevationMeters': value.maximumElevationMeters,
        'recordedDurationSeconds': value.recordedDurationSeconds,
      };

  static RouteWaypointDraft _waypoint(
    Map<String, Object?> json,
    String path,
  ) => RouteWaypointDraft(
    id: _string(json['id'], '$path.id'),
    anchorId: _nullableString(json['anchorId']),
    segmentId: _nullableString(json['segmentId']),
    position: _point(
      _map(json['position'], '$path.position'),
      '$path.position',
    ),
    typeId: _string(json['typeId'], '$path.typeId'),
    trackState: _enumValue(
      RouteWaypointTrackState.values,
      json['trackState'],
      '$path.trackState',
    ),
    distanceFromStartMeters: _nullableDouble(json['distanceFromStartMeters']),
    distanceFromTrackMeters: _nullableDouble(json['distanceFromTrackMeters']),
    catalogVersion: _intOr(json['catalogVersion'], 1),
    title: _nullableString(json['title']),
    description: _nullableString(json['description']),
    note: _nullableString(json['note']),
    safetyNote: _nullableString(json['safetyNote']),
    technicalAttributeIds: _stringListOrEmpty(json['technicalAttributeIds']),
    photoIds: _stringListOrEmpty(json['photoIds']),
    verifiedAtUtc: json['verifiedAtUtc'] == null
        ? null
        : _dateTime(json['verifiedAtUtc'], '$path.verifiedAtUtc'),
    access: json['access'] is Map
        ? _access(_map(json['access'], '$path.access'))
        : null,
  );

  static Map<String, Object?> _waypointToJson(RouteWaypointDraft value) =>
      <String, Object?>{
        'id': value.id,
        'anchorId': value.anchorId,
        'segmentId': value.segmentId,
        'position': _pointToJson(value.position),
        'typeId': value.typeId,
        'trackState': value.trackState.name,
        'distanceFromStartMeters': value.distanceFromStartMeters,
        'distanceFromTrackMeters': value.distanceFromTrackMeters,
        'catalogVersion': value.catalogVersion,
        'title': value.title,
        'description': value.description,
        'note': value.note,
        'safetyNote': value.safetyNote,
        'technicalAttributeIds': value.technicalAttributeIds,
        'photoIds': value.photoIds,
        'verifiedAtUtc': value.verifiedAtUtc?.toIso8601String(),
        'access': value.access == null ? null : _accessToJson(value.access!),
      };

  static RouteAccessInfoDraft _access(Map<String, Object?> json) =>
      RouteAccessInfoDraft(
        instructions: _nullableString(json['instructions']),
        restrictionIds: _stringListOrEmpty(json['restrictionIds']),
        openingNote: _nullableString(json['openingNote']),
      );

  static Map<String, Object?> _accessToJson(RouteAccessInfoDraft value) =>
      <String, Object?>{
        'instructions': value.instructions,
        'restrictionIds': value.restrictionIds,
        'openingNote': value.openingNote,
      };

  static RouteConditionsDraft _conditions(Map<String, Object?> json) =>
      RouteConditionsDraft(
        difficultyId: _nullableString(json['difficultyId']),
        surfaceIds: _stringListOrEmpty(json['surfaceIds']),
        isMarked: json['isMarked'] as bool?,
        bestTimeId: _nullableString(json['bestTimeId']),
        goodToKnowIds: _stringListOrEmpty(json['goodToKnowIds']),
        verifiedAtUtc: json['verifiedAtUtc'] == null
            ? null
            : _dateTime(json['verifiedAtUtc'], 'conditions.verifiedAtUtc'),
        manualDuration: json['manualDuration'] is Map
            ? RouteManualDurationDraft(
                seconds: _int(
                  _map(
                    json['manualDuration'],
                    'conditions.manualDuration',
                  )['seconds'],
                  'conditions.manualDuration.seconds',
                ),
                reason: _nullableString(
                  _map(
                    json['manualDuration'],
                    'conditions.manualDuration',
                  )['reason'],
                ),
              )
            : null,
      );

  static Map<String, Object?> _conditionsToJson(RouteConditionsDraft value) =>
      <String, Object?>{
        'difficultyId': value.difficultyId,
        'surfaceIds': value.surfaceIds,
        'isMarked': value.isMarked,
        'bestTimeId': value.bestTimeId,
        'goodToKnowIds': value.goodToKnowIds,
        'verifiedAtUtc': value.verifiedAtUtc?.toIso8601String(),
        'manualDuration': value.manualDuration == null
            ? null
            : <String, Object?>{
                'seconds': value.manualDuration!.seconds,
                'reason': value.manualDuration!.reason,
              },
      };

  static RouteSourceIssueDraft _sourceIssue(
    Map<String, Object?> json,
    String path,
  ) => RouteSourceIssueDraft(
    id: _string(json['id'], '$path.id'),
    code: _string(json['code'], '$path.code'),
    segmentId: _nullableString(json['segmentId']),
    severity: _enumValue(
      RouteSourceIssueSeverity.values,
      json['severity'],
      '$path.severity',
    ),
    safeMetrics: <String, num>{
      for (final entry in _map(
        json['safeMetrics'],
        '$path.safeMetrics',
      ).entries)
        entry.key: _num(entry.value, '$path.safeMetrics.${entry.key}'),
    },
  );

  static Map<String, Object?> _sourceIssueToJson(RouteSourceIssueDraft value) =>
      <String, Object?>{
        'id': value.id,
        'code': value.code,
        'segmentId': value.segmentId,
        'severity': value.severity.name,
        'safeMetrics': value.safeMetrics,
      };

  static RouteMetricsDraft _metrics(Map<String, Object?> json) =>
      RouteMetricsDraft(
        geometryRevision: _int(
          json['geometryRevision'],
          'metrics.geometryRevision',
        ),
        calculationModelId: _string(
          json['calculationModelId'],
          'metrics.calculationModelId',
        ),
        calculationModelVersion: _int(
          json['calculationModelVersion'],
          'metrics.calculationModelVersion',
        ),
        distanceMeters: _double(
          json['distanceMeters'],
          'metrics.distanceMeters',
        ),
        ascentMeters: _nullableDouble(json['ascentMeters']),
        descentMeters: _nullableDouble(json['descentMeters']),
        minimumElevationMeters: _nullableDouble(json['minimumElevationMeters']),
        maximumElevationMeters: _nullableDouble(json['maximumElevationMeters']),
        autoDurationSeconds: _int(
          json['autoDurationSeconds'],
          'metrics.autoDurationSeconds',
        ),
        effectiveDurationSeconds: _int(
          json['effectiveDurationSeconds'],
          'metrics.effectiveDurationSeconds',
        ),
        directDistanceMeters: _double(
          json['directDistanceMeters'],
          'metrics.directDistanceMeters',
        ),
        fallbackDistanceMeters: _double(
          json['fallbackDistanceMeters'],
          'metrics.fallbackDistanceMeters',
        ),
        surfaceDistanceMeters: <String, double>{
          for (final entry in _map(
            json['surfaceDistanceMeters'],
            'metrics.surfaceDistanceMeters',
          ).entries)
            entry.key: _double(
              entry.value,
              'metrics.surfaceDistanceMeters.${entry.key}',
            ),
        },
        difficultyId: _nullableString(json['difficultyId']),
      );

  static Map<String, Object?> _metricsToJson(RouteMetricsDraft value) =>
      <String, Object?>{
        'geometryRevision': value.geometryRevision,
        'calculationModelId': value.calculationModelId,
        'calculationModelVersion': value.calculationModelVersion,
        'distanceMeters': value.distanceMeters,
        'ascentMeters': value.ascentMeters,
        'descentMeters': value.descentMeters,
        'minimumElevationMeters': value.minimumElevationMeters,
        'maximumElevationMeters': value.maximumElevationMeters,
        'autoDurationSeconds': value.autoDurationSeconds,
        'effectiveDurationSeconds': value.effectiveDurationSeconds,
        'directDistanceMeters': value.directDistanceMeters,
        'fallbackDistanceMeters': value.fallbackDistanceMeters,
        'surfaceDistanceMeters': value.surfaceDistanceMeters,
        'difficultyId': value.difficultyId,
      };

  static RouteQualityDraft _quality(Map<String, Object?> json) =>
      RouteQualityDraft(
        geometryRevision: _int(
          json['geometryRevision'],
          'quality.geometryRevision',
        ),
        calculationModelId: _string(
          json['calculationModelId'],
          'quality.calculationModelId',
        ),
        calculationModelVersion: _int(
          json['calculationModelVersion'],
          'quality.calculationModelVersion',
        ),
        inputFingerprint: _string(
          json['inputFingerprint'],
          'quality.inputFingerprint',
        ),
        calculatedAtUtc: _dateTime(
          json['calculatedAtUtc'],
          'quality.calculatedAtUtc',
        ),
        elevation: _elevation(
          _map(json['elevation'], 'quality.elevation'),
        ),
        surfaces: _listOrEmpty(json['surfaces'])
            .asMap()
            .entries
            .map(
              (entry) => _surface(
                _map(entry.value, 'quality.surfaces[${entry.key}]'),
                'quality.surfaces[${entry.key}]',
              ),
            )
            .toList(growable: false),
        unknownSurfaceDistanceMeters: _double(
          json['unknownSurfaceDistanceMeters'],
          'quality.unknownSurfaceDistanceMeters',
        ),
        difficulty: _difficulty(
          _map(json['difficulty'], 'quality.difficulty'),
        ),
        verifications: _listOrEmpty(json['verifications'])
            .asMap()
            .entries
            .map(
              (entry) => _verification(
                _map(entry.value, 'quality.verifications[${entry.key}]'),
                'quality.verifications[${entry.key}]',
              ),
            )
            .toList(growable: false),
      );

  static Map<String, Object?> _qualityToJson(RouteQualityDraft value) =>
      <String, Object?>{
        'geometryRevision': value.geometryRevision,
        'calculationModelId': value.calculationModelId,
        'calculationModelVersion': value.calculationModelVersion,
        'inputFingerprint': value.inputFingerprint,
        'calculatedAtUtc': value.calculatedAtUtc.toIso8601String(),
        'elevation': _elevationToJson(value.elevation),
        'surfaces': value.surfaces.map(_surfaceToJson).toList(growable: false),
        'unknownSurfaceDistanceMeters': value.unknownSurfaceDistanceMeters,
        'difficulty': _difficultyToJson(value.difficulty),
        'verifications': value.verifications
            .map(_verificationToJson)
            .toList(growable: false),
      };

  static RouteElevationProfileDraft _elevation(
    Map<String, Object?> json,
  ) => RouteElevationProfileDraft(
    availability: _enumValue(
      RouteElevationAvailability.values,
      json['availability'],
      'quality.elevation.availability',
    ),
    source: _enumValue(
      RouteQualitySource.values,
      json['source'],
      'quality.elevation.source',
    ),
    samples: _listOrEmpty(json['samples'])
        .asMap()
        .entries
        .map((entry) {
          final path = 'quality.elevation.samples[${entry.key}]';
          final sample = _map(entry.value, path);
          return RouteElevationSampleDraft(
            distanceFromStartMeters: _double(
              sample['distanceFromStartMeters'],
              '$path.distanceFromStartMeters',
            ),
            elevationMeters: _double(
              sample['elevationMeters'],
              '$path.elevationMeters',
            ),
          );
        })
        .toList(growable: false),
    ascentMeters: _nullableDouble(json['ascentMeters']),
    descentMeters: _nullableDouble(json['descentMeters']),
    minimumElevationMeters: _nullableDouble(json['minimumElevationMeters']),
    maximumElevationMeters: _nullableDouble(json['maximumElevationMeters']),
    attribution: _nullableString(json['attribution']),
  );

  static Map<String, Object?> _elevationToJson(
    RouteElevationProfileDraft value,
  ) => <String, Object?>{
    'availability': value.availability.name,
    'source': value.source.name,
    'samples': value.samples
        .map(
          (sample) => <String, Object?>{
            'distanceFromStartMeters': sample.distanceFromStartMeters,
            'elevationMeters': sample.elevationMeters,
          },
        )
        .toList(growable: false),
    'ascentMeters': value.ascentMeters,
    'descentMeters': value.descentMeters,
    'minimumElevationMeters': value.minimumElevationMeters,
    'maximumElevationMeters': value.maximumElevationMeters,
    'attribution': value.attribution,
  };

  static RouteSurfaceMetricDraft _surface(
    Map<String, Object?> json,
    String path,
  ) => RouteSurfaceMetricDraft(
    surfaceId: _string(json['surfaceId'], '$path.surfaceId'),
    distanceMeters: _double(json['distanceMeters'], '$path.distanceMeters'),
    source: _enumValue(
      RouteQualitySource.values,
      json['source'],
      '$path.source',
    ),
    attribution: _nullableString(json['attribution']),
  );

  static Map<String, Object?> _surfaceToJson(RouteSurfaceMetricDraft value) =>
      <String, Object?>{
        'surfaceId': value.surfaceId,
        'distanceMeters': value.distanceMeters,
        'source': value.source.name,
        'attribution': value.attribution,
      };

  static RouteDifficultyAssessmentDraft _difficulty(
    Map<String, Object?> json,
  ) => RouteDifficultyAssessmentDraft(
    recommendedDifficultyId: _string(
      json['recommendedDifficultyId'],
      'quality.difficulty.recommendedDifficultyId',
    ),
    modelId: _string(json['modelId'], 'quality.difficulty.modelId'),
    modelVersion: _int(
      json['modelVersion'],
      'quality.difficulty.modelVersion',
    ),
    score: _double(json['score'], 'quality.difficulty.score'),
    missingElevation: _bool(
      json['missingElevation'],
      'quality.difficulty.missingElevation',
    ),
    unknownSurfaceDistanceMeters: _double(
      json['unknownSurfaceDistanceMeters'],
      'quality.difficulty.unknownSurfaceDistanceMeters',
    ),
    differsFromAuthorSelection: _bool(
      json['differsFromAuthorSelection'],
      'quality.difficulty.differsFromAuthorSelection',
    ),
  );

  static Map<String, Object?> _difficultyToJson(
    RouteDifficultyAssessmentDraft value,
  ) => <String, Object?>{
    'recommendedDifficultyId': value.recommendedDifficultyId,
    'modelId': value.modelId,
    'modelVersion': value.modelVersion,
    'score': value.score,
    'missingElevation': value.missingElevation,
    'unknownSurfaceDistanceMeters': value.unknownSurfaceDistanceMeters,
    'differsFromAuthorSelection': value.differsFromAuthorSelection,
  };

  static RouteVerificationRecordDraft _verification(
    Map<String, Object?> json,
    String path,
  ) => RouteVerificationRecordDraft(
    id: _string(json['id'], '$path.id'),
    kind: _enumValue(
      RouteVerificationKind.values,
      json['kind'],
      '$path.kind',
    ),
    actorId: _string(json['actorId'], '$path.actorId'),
    geometryRevision: _int(
      json['geometryRevision'],
      '$path.geometryRevision',
    ),
    verifiedAtUtc: _dateTime(json['verifiedAtUtc'], '$path.verifiedAtUtc'),
    evidenceMediaIds: _stringListOrEmpty(json['evidenceMediaIds']),
    note: _nullableString(json['note']),
  );

  static Map<String, Object?> _verificationToJson(
    RouteVerificationRecordDraft value,
  ) => <String, Object?>{
    'id': value.id,
    'kind': value.kind.name,
    'actorId': value.actorId,
    'geometryRevision': value.geometryRevision,
    'verifiedAtUtc': value.verifiedAtUtc.toIso8601String(),
    'evidenceMediaIds': value.evidenceMediaIds,
    'note': value.note,
  };

  static RouteAsyncOperationDraft _operation(
    Map<String, Object?> json,
    String path,
  ) => RouteAsyncOperationDraft(
    operationId: _string(json['operationId'], '$path.operationId'),
    kind: _enumValue(
      RouteAsyncOperationKind.values,
      json['kind'],
      '$path.kind',
    ),
    status: _enumValue(
      RouteAsyncOperationStatus.values,
      json['status'],
      '$path.status',
    ),
    expectedGeometryRevision: _int(
      json['expectedGeometryRevision'],
      '$path.expectedGeometryRevision',
    ),
    requestFingerprint: _string(
      json['requestFingerprint'],
      '$path.requestFingerprint',
    ),
    segmentId: _nullableString(json['segmentId']),
    failureCode: _nullableString(json['failureCode']),
  );

  static Map<String, Object?> _operationToJson(
    RouteAsyncOperationDraft value,
  ) => <String, Object?>{
    'operationId': value.operationId,
    'kind': value.kind.name,
    'status': value.status.name,
    'expectedGeometryRevision': value.expectedGeometryRevision,
    'requestFingerprint': value.requestFingerprint,
    'segmentId': value.segmentId,
    'failureCode': value.failureCode,
  };

  static GeoPoint _point(Map<String, Object?> json, String path) => GeoPoint(
    latitude: _double(json['latitude'], '$path.latitude'),
    longitude: _double(json['longitude'], '$path.longitude'),
    elevationMeters: _nullableDouble(json['elevationMeters']),
  );

  static Map<String, Object?> _pointToJson(GeoPoint value) => value.toMap();

  static GeoBounds _bounds(Map<String, Object?> json, String path) => GeoBounds(
    southwest: _point(
      _map(json['southwest'], '$path.southwest'),
      '$path.southwest',
    ),
    northeast: _point(
      _map(json['northeast'], '$path.northeast'),
      '$path.northeast',
    ),
  );

  static Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map) throw RouteDraftFormatException(path);
    return Map<String, Object?>.from(value);
  }

  static List<Object?> _list(Object? value, String path) {
    if (value is! List) throw RouteDraftFormatException(path);
    return List<Object?>.from(value);
  }

  static List<Object?> _listOrEmpty(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  static List<String> _stringListOrEmpty(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const <String>[];

  static String _string(Object? value, String path) {
    if (value is! String) throw RouteDraftFormatException(path);
    return value;
  }

  static String? _nullableString(Object? value) => value?.toString();

  static int _int(Object? value, String path) {
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw RouteDraftFormatException(path);
    }
    return value.toInt();
  }

  static int _intOr(Object? value, int fallback) =>
      value is num && value.isFinite ? value.toInt() : fallback;

  static int? _nullableInt(Object? value) =>
      value is num && value.isFinite ? value.toInt() : null;

  static double _double(Object? value, String path) {
    if (value is! num || !value.isFinite) {
      throw RouteDraftFormatException(path);
    }
    return value.toDouble();
  }

  static double? _nullableDouble(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static num _num(Object? value, String path) {
    if (value is! num || !value.isFinite) {
      throw RouteDraftFormatException(path);
    }
    return value;
  }

  static bool _bool(Object? value, String path) {
    if (value is! bool) throw RouteDraftFormatException(path);
    return value;
  }

  static bool _boolOr(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static DateTime _dateTime(Object? value, String path) {
    if (value is! String) throw RouteDraftFormatException(path);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw RouteDraftFormatException(path);
    return parsed.toUtc();
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    String path,
  ) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw RouteDraftFormatException(path);
  }

  static T _enumValueOr<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return fallback;
  }

  static T? _nullableEnumValue<T extends Enum>(List<T> values, Object? value) {
    if (value == null) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }

  static Map<String, Object?> _deepCopyMap(Map<String, Object?> source) =>
      source.map(
        (key, value) => MapEntry<String, Object?>(key, _deepCopy(value)),
      );

  static Object? _deepCopy(Object? value) {
    if (value is Map) {
      return _deepCopyMap(Map<String, Object?>.from(value));
    }
    if (value is List) {
      return value.map(_deepCopy).toList(growable: false);
    }
    return value;
  }

  static Map<String, Object?> _deepMerge(
    Map<String, Object?> base,
    Map<String, Object?> overlay,
  ) => <String, Object?>{
    ..._deepCopyMap(base),
    for (final entry in overlay.entries)
      entry.key: _deepMergeValue(base[entry.key], entry.value),
  };

  static Object? _deepMergeValue(Object? base, Object? overlay) {
    if (base is Map && overlay is Map) {
      return _deepMerge(
        Map<String, Object?>.from(base),
        Map<String, Object?>.from(overlay),
      );
    }
    if (base is List && overlay is List) {
      return <Object?>[
        for (var index = 0; index < overlay.length; index += 1)
          _deepMergeValue(
            index < base.length ? base[index] : null,
            overlay[index],
          ),
      ];
    }
    return _deepCopy(overlay);
  }
}
