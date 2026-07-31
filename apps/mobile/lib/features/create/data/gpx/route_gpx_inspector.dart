import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart' show XmlParserException, XmlTagException;
import 'package:xml/xml_events.dart';

import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_distance.dart';
import '../../../../core/geo/geo_point.dart';
import '../../domain/repositories/route_gpx_repository.dart';

class RouteGpxInspector {
  const RouteGpxInspector({required RouteGpxImportConfig config})
    : _config = config;

  final RouteGpxImportConfig _config;

  RouteGpxInspection inspect({
    required RouteSafeFileRef file,
    required Uint8List bytes,
  }) {
    final config = _config.validated();
    _validateFile(file, bytes, config);
    final source = _decode(bytes);
    _rejectDangerousDeclarations(source);

    final parser = _InspectionParser(file: file, config: config);
    try {
      for (final event in parseEvents(
        source,
        validateNesting: true,
        validateDocument: true,
      )) {
        parser.add(event);
      }
    } on RouteGpxException {
      rethrow;
    } on XmlParserException {
      throw const RouteGpxException('gpx_xml_malformed');
    } on XmlTagException {
      throw const RouteGpxException('gpx_xml_malformed');
    } on FormatException {
      throw const RouteGpxException('gpx_xml_malformed');
    }
    return parser.finish(contentSha256: sha256.convert(bytes).toString());
  }

  void _validateFile(
    RouteSafeFileRef file,
    Uint8List bytes,
    RouteGpxImportConfig config,
  ) {
    if (file.token.trim().isEmpty ||
        !file.displayName.toLowerCase().endsWith('.gpx')) {
      throw const RouteGpxException('gpx_file_type_unsupported');
    }
    if (file.sizeBytes != bytes.length) {
      throw const RouteGpxException('gpx_file_changed');
    }
    if (bytes.isEmpty) {
      throw const RouteGpxException('gpx_file_empty');
    }
    if (bytes.length > config.maximumFileBytes) {
      throw const RouteGpxException('gpx_file_too_large');
    }
    const allowedMediaTypes = <String>{
      '',
      'application/gpx+xml',
      'application/xml',
      'text/xml',
      'application/octet-stream',
    };
    if (!allowedMediaTypes.contains(file.mediaType.trim().toLowerCase())) {
      throw const RouteGpxException('gpx_media_type_unsupported');
    }
  }

  String _decode(Uint8List bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);
      return decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
    } on FormatException {
      throw const RouteGpxException('gpx_encoding_invalid');
    }
  }

  void _rejectDangerousDeclarations(String source) {
    final normalized = source.toUpperCase();
    if (normalized.contains('<!DOCTYPE') ||
        normalized.contains('<!ENTITY') ||
        normalized.contains('SYSTEM "') ||
        normalized.contains("SYSTEM '") ||
        normalized.contains('PUBLIC "') ||
        normalized.contains("PUBLIC '")) {
      throw const RouteGpxException('gpx_dtd_or_entity_forbidden');
    }
    if (source.contains('\u0000')) {
      throw const RouteGpxException('gpx_control_character_forbidden');
    }
  }
}

class _InspectionParser {
  _InspectionParser({required this.file, required this.config});

  final RouteSafeFileRef file;
  final RouteGpxImportConfig config;
  final List<String> _stack = <String>[];
  final List<RouteGpxCandidateSummary> _candidates =
      <RouteGpxCandidateSummary>[];
  final List<RouteGpxWaypointSummary> _waypoints =
      <RouteGpxWaypointSummary>[];
  final Set<String> _issues = <String>{};
  final Set<String> _unsupportedExtensions = <String>{};

  int _eventCount = 0;
  int _sourcePointCount = 0;
  int _sourceSegmentCount = 0;
  int _trackIndex = 0;
  int _routeIndex = 0;
  int? _extensionsDepth;
  bool _rootSeen = false;
  bool _rootClosed = false;
  bool _containsPrivateMetadata = false;
  String? _gpxVersion;
  _CandidateBuilder? _candidate;
  _PointBuilder? _point;
  int? _captureDepth;
  String? _captureName;
  StringBuffer? _captureBuffer;

  void add(XmlEvent event) {
    _eventCount++;
    if (_eventCount > config.maximumXmlEvents) {
      throw const RouteGpxException('gpx_xml_event_limit_exceeded');
    }
    if (event is XmlDoctypeEvent) {
      throw const RouteGpxException('gpx_dtd_or_entity_forbidden');
    }
    if (event is XmlProcessingEvent) {
      throw const RouteGpxException('gpx_processing_instruction_forbidden');
    }
    if (event is XmlStartElementEvent) {
      _start(event);
      if (event.isSelfClosing) {
        _end(_localName(event.name));
      }
      return;
    }
    if (event is XmlEndElementEvent) {
      _end(_localName(event.name));
      return;
    }
    if (event is XmlTextEvent) {
      _appendText(event.value);
      return;
    }
    if (event is XmlCDATAEvent) {
      _appendText(event.value);
    }
  }

  void _start(XmlStartElementEvent event) {
    final name = _localName(event.name);
    final parent = _stack.isEmpty ? null : _stack.last;
    _stack.add(name);
    if (_stack.length > config.maximumXmlDepth) {
      throw const RouteGpxException('gpx_xml_depth_limit_exceeded');
    }
    if (!_rootSeen) {
      if (name != 'gpx' || _stack.length != 1) {
        throw const RouteGpxException('gpx_root_invalid');
      }
      _rootSeen = true;
      _gpxVersion = _attribute(event, 'version');
      if (_gpxVersion != '1.0' && _gpxVersion != '1.1') {
        throw const RouteGpxException('gpx_version_unsupported');
      }
      final creator = _attribute(event, 'creator');
      if (creator != null && creator.trim().isNotEmpty) {
        _containsPrivateMetadata = true;
      }
      final namespace = _attribute(event, 'xmlns');
      if (namespace == null || namespace.trim().isEmpty) {
        _issues.add('gpx_namespace_missing');
      }
    } else if (_rootClosed) {
      throw const RouteGpxException('gpx_multiple_roots');
    }

    if (name == 'extensions') {
      _extensionsDepth = _stack.length;
      _containsPrivateMetadata = true;
    } else if (_extensionsDepth != null &&
        _stack.length == _extensionsDepth! + 1) {
      _unsupportedExtensions.add(event.name);
    }

    if (parent == 'metadata' &&
        const <String>{
          'author',
          'email',
          'link',
          'time',
          'keywords',
          'copyright',
        }.contains(name)) {
      _containsPrivateMetadata = true;
    }

    switch (name) {
      case 'trk':
        _startCandidate(RouteGpxCandidateKind.track, parent);
      case 'rte':
        _startCandidate(RouteGpxCandidateKind.route, parent);
      case 'trkseg':
        if (_candidate?.kind != RouteGpxCandidateKind.track ||
            parent != 'trk') {
          throw const RouteGpxException('gpx_track_segment_invalid');
        }
        _registerSegment();
        _candidate!.startSegment();
      case 'trkpt':
        if (_candidate?.kind != RouteGpxCandidateKind.track ||
            parent != 'trkseg') {
          throw const RouteGpxException('gpx_track_point_outside_segment');
        }
        _startPoint(event, _PointKind.track);
      case 'rtept':
        if (_candidate?.kind != RouteGpxCandidateKind.route ||
            parent != 'rte') {
          throw const RouteGpxException('gpx_route_point_outside_route');
        }
        _startPoint(event, _PointKind.route);
      case 'wpt':
        if (parent != 'gpx') {
          throw const RouteGpxException('gpx_waypoint_outside_root');
        }
        _startPoint(event, _PointKind.waypoint);
      case 'name':
      case 'type':
      case 'ele':
      case 'time':
        if (_shouldCapture(name, parent)) _beginCapture(name);
    }
  }

  void _startCandidate(RouteGpxCandidateKind kind, String? parent) {
    if (parent != 'gpx' || _candidate != null) {
      throw const RouteGpxException('gpx_candidate_nesting_invalid');
    }
    if (_trackIndex + _routeIndex >= config.maximumCandidates) {
      throw const RouteGpxException('gpx_candidate_limit_exceeded');
    }
    final index = kind == RouteGpxCandidateKind.track
        ? _trackIndex++
        : _routeIndex++;
    _candidate = _CandidateBuilder(kind: kind, sourceIndex: index);
    if (kind == RouteGpxCandidateKind.route) {
      _registerSegment();
      _candidate!.startSegment();
    }
  }

  void _registerSegment() {
    _sourceSegmentCount++;
    if (_sourceSegmentCount > config.maximumSegments) {
      throw const RouteGpxException('gpx_segment_limit_exceeded');
    }
  }

  void _startPoint(XmlStartElementEvent event, _PointKind kind) {
    if (_point != null) {
      throw const RouteGpxException('gpx_point_nesting_invalid');
    }
    if (_sourcePointCount >= config.maximumSourcePoints) {
      throw const RouteGpxException('gpx_point_limit_exceeded');
    }
    if (kind == _PointKind.waypoint &&
        _waypoints.length >= config.maximumWaypoints) {
      throw const RouteGpxException('gpx_waypoint_limit_exceeded');
    }
    final latitude = _finiteDouble(_attribute(event, 'lat'));
    final longitude = _finiteDouble(_attribute(event, 'lon'));
    final position = GeoPoint(
      latitude: latitude,
      longitude: longitude,
    );
    if (!position.isValid) {
      throw const RouteGpxException('gpx_coordinate_invalid');
    }
    _sourcePointCount++;
    _point = _PointBuilder(kind: kind, position: position);
  }

  bool _shouldCapture(String name, String? parent) {
    if (_captureName != null) return false;
    if (_point != null && const <String>{'name', 'type', 'ele', 'time'}.contains(name)) {
      return true;
    }
    return name == 'name' &&
        _candidate != null &&
        ((parent == 'trk' && _candidate!.kind == RouteGpxCandidateKind.track) ||
            (parent == 'rte' &&
                _candidate!.kind == RouteGpxCandidateKind.route));
  }

  void _beginCapture(String name) {
    _captureName = name;
    _captureDepth = _stack.length;
    _captureBuffer = StringBuffer();
  }

  void _appendText(String value) {
    final buffer = _captureBuffer;
    if (buffer == null) return;
    if (buffer.length + value.length > config.maximumTextCharacters) {
      throw const RouteGpxException('gpx_text_limit_exceeded');
    }
    buffer.write(value);
  }

  void _end(String name) {
    if (_stack.isEmpty || _stack.last != name) {
      throw const RouteGpxException('gpx_xml_malformed');
    }
    if (_captureName == name && _captureDepth == _stack.length) {
      _consumeCapture(name, _captureBuffer.toString().trim());
      _captureName = null;
      _captureDepth = null;
      _captureBuffer = null;
    }

    switch (name) {
      case 'trkpt':
      case 'rtept':
        _finishCandidatePoint();
      case 'wpt':
        _finishWaypoint();
      case 'trkseg':
        _candidate?.endSegment();
      case 'trk':
      case 'rte':
        _finishCandidate();
      case 'extensions':
        if (_extensionsDepth == _stack.length) _extensionsDepth = null;
      case 'gpx':
        _rootClosed = true;
    }
    _stack.removeLast();
  }

  void _consumeCapture(String name, String value) {
    if (_point != null) {
      switch (name) {
        case 'name':
          _point!.name = _safeText(value);
        case 'type':
          _point!.type = _safeText(value);
        case 'ele':
          if (value.isNotEmpty) {
            final elevation = _finiteDouble(value);
            _point!.position = GeoPoint(
              latitude: _point!.position.latitude,
              longitude: _point!.position.longitude,
              elevationMeters: elevation,
            );
          }
        case 'time':
          if (value.isNotEmpty) {
            _containsPrivateMetadata = true;
            _point!.hasTimestamp = true;
            _point!.timestamp = DateTime.tryParse(value)?.toUtc();
            if (_point!.timestamp == null) {
              _issues.add('gpx_timestamp_invalid');
            }
          }
      }
      return;
    }
    if (name == 'name') {
      _candidate?.name = _safeText(value);
    }
  }

  void _finishCandidatePoint() {
    final point = _point;
    final candidate = _candidate;
    if (point == null ||
        candidate == null ||
        point.kind == _PointKind.waypoint) {
      throw const RouteGpxException('gpx_point_state_invalid');
    }
    candidate.addPoint(point);
    _point = null;
  }

  void _finishWaypoint() {
    final point = _point;
    if (point == null || point.kind != _PointKind.waypoint) {
      throw const RouteGpxException('gpx_waypoint_state_invalid');
    }
    _waypoints.add(
      RouteGpxWaypointSummary(
        sourceIndex: _waypoints.length,
        position: point.position,
        name: point.name,
        type: point.type,
        hasTimestamp: point.hasTimestamp,
        extensionNames: const <String>[],
      ),
    );
    _point = null;
  }

  void _finishCandidate() {
    final candidate = _candidate;
    if (candidate == null) {
      throw const RouteGpxException('gpx_candidate_state_invalid');
    }
    if (candidate.pointCount == 0) {
      _issues.add('gpx_empty_candidate_skipped');
    } else {
      _candidates.add(candidate.build());
    }
    _candidate = null;
  }

  RouteGpxInspection finish({required String contentSha256}) {
    if (!_rootSeen || !_rootClosed || _stack.isNotEmpty) {
      throw const RouteGpxException('gpx_xml_malformed');
    }
    if (_candidates.isEmpty) {
      throw const RouteGpxException('gpx_candidate_empty');
    }
    if (_sourcePointCount > config.maximumSourcePoints) {
      throw const RouteGpxException('gpx_point_limit_exceeded');
    }
    return RouteGpxInspection(
      file: file,
      gpxVersion: _gpxVersion!,
      contentSha256: contentSha256,
      candidates: _candidates,
      waypoints: _waypoints,
      containsPrivateMetadata: _containsPrivateMetadata,
      unsupportedExtensionNames: _unsupportedExtensions.toList()..sort(),
      issueCodes: _issues.toList()..sort(),
    );
  }

  String? _attribute(XmlStartElementEvent event, String name) {
    for (final attribute in event.attributes) {
      if (_localName(attribute.name) == name) return attribute.value;
    }
    return null;
  }

  double _finiteDouble(String? value) {
    final parsed = value == null ? null : double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) {
      throw const RouteGpxException('gpx_number_invalid');
    }
    return parsed;
  }

  String? _safeText(String value) => value.isEmpty ? null : value;

  String _localName(String qualifiedName) {
    final separator = qualifiedName.indexOf(':');
    return separator < 0
        ? qualifiedName.toLowerCase()
        : qualifiedName.substring(separator + 1).toLowerCase();
  }
}

enum _PointKind { track, route, waypoint }

class _PointBuilder {
  _PointBuilder({required this.kind, required this.position});

  final _PointKind kind;
  GeoPoint position;
  String? name;
  String? type;
  bool hasTimestamp = false;
  DateTime? timestamp;
}

class _CandidateBuilder {
  _CandidateBuilder({required this.kind, required this.sourceIndex});

  final RouteGpxCandidateKind kind;
  final int sourceIndex;
  final Set<String> issueCodes = <String>{};
  final List<double> _longitudes = <double>[];
  String? name;
  int segmentCount = 0;
  int pointCount = 0;
  int gapCount = 0;
  double distanceMeters = 0;
  bool hasTimestamps = false;
  bool hasElevation = false;
  bool _segmentOpen = false;
  bool _segmentHasPoint = false;
  GeoPoint? _previous;
  DateTime? _previousTimestamp;
  DateTime? _minimumTimestamp;
  DateTime? _maximumTimestamp;
  double? _minimumLatitude;
  double? _maximumLatitude;

  void startSegment() {
    if (_segmentOpen) {
      throw const RouteGpxException('gpx_segment_nesting_invalid');
    }
    _segmentOpen = true;
    _segmentHasPoint = false;
    _previous = null;
    _previousTimestamp = null;
  }

  void endSegment() {
    if (!_segmentOpen) {
      throw const RouteGpxException('gpx_segment_state_invalid');
    }
    _segmentOpen = false;
    _previous = null;
    _previousTimestamp = null;
  }

  void addPoint(_PointBuilder point) {
    if (!_segmentOpen) {
      throw const RouteGpxException('gpx_point_outside_segment');
    }
    if (!_segmentHasPoint) {
      segmentCount++;
      gapCount = segmentCount - 1;
      _segmentHasPoint = true;
    }
    final previous = _previous;
    if (previous != null) {
      final delta = GeoDistance.haversineMeters(previous, point.position);
      distanceMeters += delta;
      if (delta == 0) issueCodes.add('gpx_consecutive_duplicate');
      final previousTime = _previousTimestamp;
      final currentTime = point.timestamp;
      if (previousTime != null && currentTime != null) {
        final seconds = currentTime.difference(previousTime).inMilliseconds /
            1000;
        if (seconds <= 0) {
          issueCodes.add('gpx_timestamp_non_monotonic');
        } else if (delta / seconds > 50) {
          issueCodes.add('gpx_speed_outlier');
        }
      }
    }
    pointCount++;
    hasElevation =
        hasElevation || point.position.elevationMeters != null;
    hasTimestamps = hasTimestamps || point.hasTimestamp;
    _previous = point.position;
    _previousTimestamp = point.timestamp;
    final timestamp = point.timestamp;
    if (timestamp != null) {
      if (_minimumTimestamp == null || timestamp.isBefore(_minimumTimestamp!)) {
        _minimumTimestamp = timestamp;
      }
      if (_maximumTimestamp == null || timestamp.isAfter(_maximumTimestamp!)) {
        _maximumTimestamp = timestamp;
      }
    }
    _minimumLatitude = _minimumLatitude == null
        ? point.position.latitude
        : (_minimumLatitude! < point.position.latitude
              ? _minimumLatitude
              : point.position.latitude);
    _maximumLatitude = _maximumLatitude == null
        ? point.position.latitude
        : (_maximumLatitude! > point.position.latitude
              ? _maximumLatitude
              : point.position.latitude);
    _longitudes.add(point.position.longitude);
  }

  RouteGpxCandidateSummary build() {
    if (pointCount == 0 ||
        segmentCount == 0 ||
        _minimumLatitude == null ||
        _maximumLatitude == null) {
      throw const RouteGpxException('gpx_candidate_empty');
    }
    return RouteGpxCandidateSummary(
      kind: kind,
      sourceIndex: sourceIndex,
      name: name,
      segmentCount: segmentCount,
      gapCount: gapCount,
      pointCount: pointCount,
      distanceMeters: distanceMeters,
      durationSeconds: _durationSeconds(),
      bounds: _buildBounds(),
      hasTimestamps: hasTimestamps,
      hasElevation: hasElevation,
      issueCodes: issueCodes.toList()..sort(),
    );
  }

  double? _durationSeconds() {
    final minimum = _minimumTimestamp;
    final maximum = _maximumTimestamp;
    if (minimum == null || maximum == null || !maximum.isAfter(minimum)) {
      return null;
    }
    return maximum.difference(minimum).inMilliseconds / 1000;
  }

  GeoBounds _buildBounds() {
    final sorted = List<double>.of(_longitudes)..sort();
    if (sorted.length == 1) {
      return GeoBounds(
        southwest: GeoPoint(
          latitude: _minimumLatitude!,
          longitude: sorted.single,
        ),
        northeast: GeoPoint(
          latitude: _maximumLatitude!,
          longitude: sorted.single,
        ),
      );
    }
    var largestGap = -1.0;
    var west = sorted.first;
    var east = sorted.last;
    for (var index = 0; index < sorted.length; index++) {
      final current = sorted[index];
      final next = index + 1 < sorted.length
          ? sorted[index + 1]
          : sorted.first + 360;
      final gap = next - current;
      if (gap > largestGap) {
        largestGap = gap;
        west = next > 180 ? next - 360 : next;
        east = current;
      }
    }
    return GeoBounds(
      southwest: GeoPoint(
        latitude: _minimumLatitude!,
        longitude: west,
      ),
      northeast: GeoPoint(
        latitude: _maximumLatitude!,
        longitude: east,
      ),
    ).validated();
  }
}
