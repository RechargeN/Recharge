import 'dart:convert';

import '../../../../shared/primitives/geo/geo_point.dart';
import '../../../../shared/primitives/geo/geometry_encoding.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/route_sync_data.dart';

class RouteCanonicalFailure implements Exception {
  const RouteCanonicalFailure(this.code);
  final String code;
  @override
  String toString() => 'RouteCanonicalFailure($code)';
}

/// J1 canonical Route (`wgs84-e7-dm-v1`), the only shape that leaves the
/// device. Quantization to 1e-7° and 0.1 m is the one transformation applied
/// here; decoding and re-encoding a canonical Route is an identity.
abstract final class RouteCanonicalCodec {
  static const String coordinatePolicy = 'wgs84-e7-dm-v1';
  static const int routeJsonBytes = 204800;
  static const int maximumPoints = 10000;
  static const int _elevationAbsent = 1048576;
  static const GeometryEncodingPolicy _policy = GeometryEncodingPolicy(
    precision: 7,
  );
  static final RegExp _token = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');
  static final RegExp _entityId = RegExp(
    r'^([0-9A-HJKMNP-TV-Z]{26}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$',
  );
  static const Set<RouteSegmentSource> _storable = <RouteSegmentSource>{
    RouteSegmentSource.importedGpx,
    RouteSegmentSource.recordedGps,
    RouteSegmentSource.freehand,
    RouteSegmentSource.intentionalDirect,
    RouteSegmentSource.fallbackDirect,
  };

  static bool isEntityId(String value) => _entityId.hasMatch(value);
  static int e7(double degrees) => (degrees * 1e7).round();
  static int? dm(double? meters) =>
      meters == null ? null : (meters * 10).round();

  /// Encodes [route]. [idFor] maps every local `loc_*` ID to its permanent ID;
  /// other IDs must already be permanent. Fails before anything is queued.
  static Map<String, Object?> encode(
    RouteDraftData route, {
    required String title,
    required String Function(String localId) idFor,
  }) {
    String id(String value) {
      final mapped = value.startsWith('loc_') ? idFor(value) : value;
      if (!isEntityId(mapped)) {
        throw const RouteCanonicalFailure('route_ids_invalid');
      }
      return mapped;
    }

    var points = 0;
    final segments = route.orderedSegments
        .map((RouteSegmentDraft segment) {
          if (!_storable.contains(segment.source)) {
            // Provider geometry has no accepted storage license (BCK-11 §22).
            throw const RouteCanonicalFailure('license_blocked');
          }
          if (!_token.hasMatch(segment.provenance.sourceId)) {
            throw const RouteCanonicalFailure('request_invalid');
          }
          points += segment.geometry.points.length;
          if (points > maximumPoints) {
            throw const RouteCanonicalFailure('point_limit_exceeded');
          }
          final parent = segment.provenance.parentSegmentId;
          return <String, Object?>{
            'segmentId': id(segment.id),
            'order': segment.order,
            'fromAnchorId': id(segment.fromAnchorId),
            'toAnchorId': id(segment.toAnchorId),
            'sourceKind': segment.source.name,
            'derivation': segment.derivation.name,
            'sourceId': segment.provenance.sourceId,
            'parentSegmentId': parent == null ? null : id(parent),
            'polyline': GeometryEncoding.encode(
              segment.geometry.points,
              policy: _policy,
            ),
            'elevation': _encodeElevation(segment.geometry.points),
          };
        })
        .toList(growable: false);
    final dto = <String, Object?>{
      'schemaVersion': 1,
      'coordinatePolicy': coordinatePolicy,
      'title': title,
      'shape': route.shape.name,
      'turningAnchorId': route.turningAnchorId == null
          ? null
          : id(route.turningAnchorId!),
      'profile': <String, Object?>{
        'id': route.profile.id,
        'version': route.profile.version,
      },
      'anchors': route.anchors
          .map(
            (RouteAnchorDraft anchor) => <String, Object?>{
              'anchorId': id(anchor.id),
              'latE7': e7(anchor.position.latitude),
              'lonE7': e7(anchor.position.longitude),
            },
          )
          .toList(growable: false),
      'segments': segments,
      'waypoints': route.waypoints
          .map(
            (RouteWaypointDraft waypoint) => <String, Object?>{
              'waypointId': id(waypoint.id),
              'segmentId': waypoint.segmentId == null
                  ? null
                  : id(waypoint.segmentId!),
              'anchorId': waypoint.anchorId == null
                  ? null
                  : id(waypoint.anchorId!),
              'latE7': e7(waypoint.position.latitude),
              'lonE7': e7(waypoint.position.longitude),
              'eleDm': dm(waypoint.position.elevationMeters),
              'typeId': waypoint.typeId,
              'trackState': waypoint.trackState.name,
              'title': waypoint.title,
              'description': waypoint.description,
              'note': waypoint.note,
              'safetyNote': waypoint.safetyNote,
            },
          )
          .toList(growable: false),
    };
    if (utf8.encode(jsonEncode(dto)).length > routeJsonBytes) {
      throw const RouteCanonicalFailure('payload_too_large');
    }
    return dto;
  }

  /// Replaces the geometry of [template] with a canonical server Route.
  /// Derived metrics are recalculated by the caller's restore path.
  static RouteDraftData decode(
    Map<String, Object?> dto, {
    required RouteDraftData template,
    required DateTime updatedAtUtc,
  }) {
    try {
      if (dto['coordinatePolicy'] != coordinatePolicy) {
        throw const RouteCanonicalFailure('answer_invalid');
      }
      final anchors = (dto['anchors']! as List).cast<Map>().map(
        (Map a) => RouteAnchorDraft(
          id: a['anchorId']! as String,
          position: GeoPoint(
            latitude: (a['latE7']! as int) / 1e7,
            longitude: (a['lonE7']! as int) / 1e7,
          ).validated(),
        ),
      );
      var budget = maximumPoints;
      final segments = (dto['segments']! as List)
          .cast<Map>()
          .map((Map s) {
            final points = decodeSegment(
              s['polyline']! as String,
              s['elevation'] as String?,
              budget,
            );
            budget -= points.length;
            return RouteSegmentDraft(
              id: s['segmentId']! as String,
              fromAnchorId: s['fromAnchorId']! as String,
              toAnchorId: s['toAnchorId']! as String,
              order: s['order']! as int,
              source: RouteSegmentSource.values.byName(
                s['sourceKind']! as String,
              ),
              derivation: RouteSegmentDerivation.values.byName(
                s['derivation']! as String,
              ),
              geometry: RouteGeometryDraft.fromPoints(
                points,
                encodingPolicy: template.encodingPolicy,
              ),
              provenance: RouteProvenanceDraft(
                sourceId: s['sourceId']! as String,
                sourceRevision: 0,
                createdAtUtc: updatedAtUtc.toUtc(),
                parentSegmentId: s['parentSegmentId'] as String?,
              ),
              geometryRevision: template.geometryRevision,
            );
          })
          .toList(growable: false);
      final waypoints = (dto['waypoints']! as List).cast<Map>().map(
        (Map w) => RouteWaypointDraft(
          id: w['waypointId']! as String,
          segmentId: w['segmentId'] as String?,
          anchorId: w['anchorId'] as String?,
          position: GeoPoint(
            latitude: (w['latE7']! as int) / 1e7,
            longitude: (w['lonE7']! as int) / 1e7,
            elevationMeters: (w['eleDm'] as int?) == null
                ? null
                : (w['eleDm']! as int) / 10,
          ).validated(),
          typeId: w['typeId']! as String,
          trackState: RouteWaypointTrackState.values.byName(
            w['trackState']! as String,
          ),
          title: w['title'] as String?,
          description: w['description'] as String?,
          note: w['note'] as String?,
          safetyNote: w['safetyNote'] as String?,
        ),
      );
      final profile = dto['profile']! as Map;
      final sources = segments.map((RouteSegmentDraft s) => s.source).toSet();
      return template.copyWith(
        creationMethod: sources.contains(RouteSegmentSource.importedGpx)
            ? RouteCreationMethod.importedGpx
            : sources.contains(RouteSegmentSource.recordedGps)
            ? RouteCreationMethod.recordedGps
            : template.creationMethod,
        shape: RouteShape.values.byName(dto['shape']! as String),
        turningAnchorId: dto['turningAnchorId'] as String?,
        clearTurningAnchorId: dto['turningAnchorId'] == null,
        profile: RouteProfileRef(
          id: profile['id']! as String,
          version: profile['version']! as int,
        ),
        anchors: anchors,
        segments: segments,
        waypoints: waypoints,
        sourceIssues: const <RouteSourceIssueDraft>[],
        operations: const <RouteAsyncOperationDraft>[],
      );
    } on RouteCanonicalFailure {
      rethrow;
    } on Object {
      throw const RouteCanonicalFailure('answer_invalid');
    }
  }

  static List<GeoPoint> decodeSegment(
    String polyline,
    String? elevation,
    int budget,
  ) {
    final coordinates = GeometryEncoding.decode(polyline, policy: _policy);
    if (coordinates.length < 2 || coordinates.length > budget) {
      throw const RouteCanonicalFailure('answer_invalid');
    }
    if (elevation == null) return coordinates;
    final values = <int>[];
    var cursor = 0;
    while (cursor < elevation.length) {
      final (value, next) = _decodeSigned(elevation, cursor);
      values.add(value);
      cursor = next;
    }
    if (values.length != coordinates.length) {
      throw const RouteCanonicalFailure('answer_invalid');
    }
    return <GeoPoint>[
      for (var i = 0; i < coordinates.length; i++)
        GeoPoint(
          latitude: coordinates[i].latitude,
          longitude: coordinates[i].longitude,
          elevationMeters: values[i] == _elevationAbsent
              ? null
              : _elevationMeters(values[i]),
        ),
    ];
  }

  static double _elevationMeters(int decimetres) {
    if (decimetres < -5000 || decimetres > 90000) {
      throw const RouteCanonicalFailure('answer_invalid');
    }
    return decimetres / 10;
  }

  static String? _encodeElevation(List<GeoPoint> points) {
    if (points.every((GeoPoint p) => p.elevationMeters == null)) return null;
    final output = StringBuffer();
    for (final point in points) {
      final value = dm(point.elevationMeters);
      if (value != null && (value < -5000 || value > 90000)) {
        throw const RouteCanonicalFailure('invalid_geometry');
      }
      final signed = value ?? _elevationAbsent;
      var rest = signed < 0 ? ~(signed << 1) : signed << 1;
      while (rest >= 0x20) {
        output.writeCharCode((0x20 | (rest & 0x1f)) + 63);
        rest >>= 5;
      }
      output.writeCharCode(rest + 63);
    }
    return output.toString();
  }

  static (int, int) _decodeSigned(String text, int start) {
    var cursor = start, result = 0, shift = 0;
    while (true) {
      if (cursor >= text.length || shift > 30) {
        throw const RouteCanonicalFailure('answer_invalid');
      }
      final chunk = text.codeUnitAt(cursor++) - 63;
      if (chunk < 0 || chunk > 63) {
        throw const RouteCanonicalFailure('answer_invalid');
      }
      result |= (chunk & 0x1f) << shift;
      if (chunk < 0x20) break;
      shift += 5;
    }
    return ((result & 1) == 1 ? ~(result >> 1) : result >> 1, cursor);
  }

  static RouteSyncSummary summary(Map<String, Object?> json) {
    double? optional(String key) => (json[key] as num?)?.toDouble();
    return RouteSyncSummary(
      pointCount: json['pointCount']! as int,
      segmentCount: json['segmentCount']! as int,
      gapCount: json['gapCount']! as int,
      distanceMeters: (json['distanceMeters']! as num).toDouble(),
      ascentMeters: optional('ascentMeters'),
      descentMeters: optional('descentMeters'),
      minimumElevationMeters: optional('minElevationMeters'),
      maximumElevationMeters: optional('maxElevationMeters'),
    );
  }

  /// Strict decoding of the server trimmed view; anything else is refused.
  static RouteTrimmedView trimmedView(Map<String, Object?> json) {
    try {
      const keys = <String>{
        'routeId',
        'revision',
        'policy',
        'startMeters',
        'endMeters',
        'segments',
        'waypoints',
        'summary',
        'warnings',
        'variantHash',
      };
      if (json.keys.toSet().difference(keys).isNotEmpty ||
          json['policy'] != 'endpoint-radius-v1') {
        throw const RouteCanonicalFailure('answer_invalid');
      }
      var budget = maximumPoints;
      final segments = (json['segments']! as List)
          .cast<Map>()
          .map((Map s) {
            final points = decodeSegment(
              s['polyline']! as String,
              s['elevation'] as String?,
              budget,
            );
            budget -= points.length;
            return RouteTrimmedSegment(
              points: points,
              connected: s['connected']! as bool,
            );
          })
          .toList(growable: false);
      final warnings = json['warnings']! as Map;
      return RouteTrimmedView(
        routeId: json['routeId']! as String,
        revision: json['revision']! as int,
        trim: RoutePrivacyTrim(
          startMeters: json['startMeters']! as int,
          endMeters: json['endMeters']! as int,
        ),
        variantHash: json['variantHash']! as String,
        segments: segments,
        waypoints: (json['waypoints']! as List).cast<Map>().map(
          (Map w) => RouteTrimmedWaypoint(
            position: GeoPoint(
              latitude: (w['latE7']! as int) / 1e7,
              longitude: (w['lonE7']! as int) / 1e7,
              elevationMeters: (w['eleDm'] as int?) == null
                  ? null
                  : (w['eleDm']! as int) / 10,
            ).validated(),
            typeId: w['typeId']! as String,
            title: w['title'] as String?,
          ),
        ),
        summary: summary(Map<String, Object?>.from(json['summary']! as Map)),
        reenteredStart: warnings['reenteredStart']! as bool,
        reenteredEnd: warnings['reenteredEnd']! as bool,
      );
    } on RouteCanonicalFailure {
      rethrow;
    } on Object {
      throw const RouteCanonicalFailure('answer_invalid');
    }
  }
}
