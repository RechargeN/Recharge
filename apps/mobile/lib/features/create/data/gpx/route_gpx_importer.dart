import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/repositories/route_gpx_repository.dart';
import 'route_gpx_inspector.dart';

class RouteGpxImporter {
  const RouteGpxImporter({required RouteGpxInspector inspector})
    : _inspector = inspector;

  final RouteGpxInspector _inspector;

  RouteGpxImportResult import({
    required RouteGpxImportSelection selection,
    required Uint8List bytes,
    required DateTime nowUtc,
  }) {
    if (!nowUtc.isUtc ||
        !selection.stripPrivateMetadata ||
        !selection.stripTimestamps) {
      throw const RouteGpxException('gpx_privacy_stripping_required');
    }
    final inspection = _inspector.inspect(file: selection.file, bytes: bytes);
    final keys = selection.candidateKeys;
    if (keys.isEmpty || keys.toSet().length != keys.length) {
      throw const RouteGpxException('gpx_selection_invalid');
    }
    final summaries = <String, RouteGpxCandidateSummary>{
      for (final candidate in inspection.candidates)
        candidate.selectionKey: candidate,
    };
    if (keys.any((key) => !summaries.containsKey(key))) {
      throw const RouteGpxException('gpx_candidate_not_found');
    }

    final document = XmlDocument.parse(utf8.decode(bytes));
    final candidates = _candidateElements(document.rootElement);
    final outputTracks = <List<GeoPoint>>[];
    String? previousKey;
    for (final key in keys) {
      final segments = _segmentsFor(candidates[key]!, key);
      final normalized = _resolveInternalGaps(
        key: key,
        segments: segments,
        decisions: selection.gapResolutions,
      );
      if (outputTracks.isEmpty || !selection.mergeTracks) {
        outputTracks.addAll(normalized);
      } else {
        final resolution =
            selection.gapResolutions['between:$previousKey:$key'];
        if (resolution == null) {
          throw const RouteGpxException('gpx_gap_decision_required');
        }
        if (resolution == RouteGpxGapResolution.direct &&
            normalized.isNotEmpty) {
          outputTracks.last = _join(outputTracks.last, normalized.first);
          outputTracks.addAll(normalized.skip(1));
        } else {
          outputTracks.addAll(normalized);
        }
      }
      previousKey = key;
    }
    if (outputTracks.any((track) => track.length < 2)) {
      throw const RouteGpxException('gpx_segment_too_short');
    }

    final waypoints = <RouteGpxImportedWaypoint>[];
    for (final waypoint in inspection.waypoints) {
      final decision = !selection.importWaypoints
          ? RouteGpxWaypointDecision.skip
          : selection.waypointDecisions[waypoint.sourceIndex] ??
                RouteGpxWaypointDecision.skip;
      if (decision == RouteGpxWaypointDecision.skip) continue;
      waypoints.add(
        RouteGpxImportedWaypoint(
          position: waypoint.position,
          typeId: _waypointType(waypoint.type),
          trackState: decision == RouteGpxWaypointDecision.attachNearest
              ? RouteWaypointTrackState.unresolved
              : RouteWaypointTrackState.offTrackConfirmed,
          name: waypoint.name,
        ),
      );
    }
    final directGapCount = selection.gapResolutions.values
        .where((value) => value == RouteGpxGapResolution.direct)
        .length;
    return RouteGpxImportResult(
      tracks: outputTracks,
      waypoints: waypoints,
      sourceIssues: directGapCount == 0
          ? const <RouteSourceIssueDraft>[]
          : <RouteSourceIssueDraft>[
              RouteSourceIssueDraft(
                id: 'loc_gpx_gap_review',
                code: 'gpx_direct_gap_confirmed',
                severity: RouteSourceIssueSeverity.warning,
                safeMetrics: <String, num>{'count': directGapCount},
              ),
            ],
      provenance: RouteProvenanceDraft(
        sourceId: 'gpx-${inspection.contentSha256.substring(0, 16)}',
        sourceRevision: 0,
        createdAtUtc: nowUtc,
        algorithmVersion: 'gpx-import-v1',
      ),
    );
  }

  Map<String, XmlElement> _candidateElements(XmlElement root) {
    final result = <String, XmlElement>{};
    var trackIndex = 0;
    var routeIndex = 0;
    for (final child in root.children.whereType<XmlElement>()) {
      switch (child.name.local.toLowerCase()) {
        case 'trk':
          result['track:${trackIndex++}'] = child;
        case 'rte':
          result['route:${routeIndex++}'] = child;
      }
    }
    return result;
  }

  List<List<GeoPoint>> _segmentsFor(XmlElement candidate, String key) {
    if (key.startsWith('route:')) {
      return <List<GeoPoint>>[
        candidate.children
            .whereType<XmlElement>()
            .where((element) => element.name.local.toLowerCase() == 'rtept')
            .map(_point)
            .toList(growable: false),
      ];
    }
    return candidate.children
        .whereType<XmlElement>()
        .where((element) => element.name.local.toLowerCase() == 'trkseg')
        .map(
          (segment) => segment.children
              .whereType<XmlElement>()
              .where((element) => element.name.local.toLowerCase() == 'trkpt')
              .map(_point)
              .toList(growable: false),
        )
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  List<List<GeoPoint>> _resolveInternalGaps({
    required String key,
    required List<List<GeoPoint>> segments,
    required Map<String, RouteGpxGapResolution> decisions,
  }) {
    if (segments.isEmpty) return const <List<GeoPoint>>[];
    final output = <List<GeoPoint>>[segments.first];
    for (var index = 1; index < segments.length; index++) {
      final resolution = decisions['$key:gap:${index - 1}:$index'];
      if (resolution == null) {
        throw const RouteGpxException('gpx_gap_decision_required');
      }
      if (resolution == RouteGpxGapResolution.direct) {
        output.last = _join(output.last, segments[index]);
      } else {
        output.add(segments[index]);
      }
    }
    return output;
  }

  List<GeoPoint> _join(List<GeoPoint> first, List<GeoPoint> second) =>
      <GeoPoint>[
        ...first,
        if (first.last == second.first) ...second.skip(1) else ...second,
      ];

  GeoPoint _point(XmlElement element) {
    final latitude = double.parse(element.getAttribute('lat')!);
    final longitude = double.parse(element.getAttribute('lon')!);
    double? elevation;
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local.toLowerCase() == 'ele') {
        elevation = double.tryParse(child.innerText.trim());
        break;
      }
    }
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      elevationMeters: elevation,
    );
  }

  String _waypointType(String? source) {
    final normalized = source?.trim().toLowerCase();
    return switch (normalized) {
      'water' || 'drinking water' => 'water',
      'viewpoint' || 'view point' => 'viewpoint',
      'shelter' => 'shelter',
      'danger' || 'hazard' => 'danger',
      _ => 'other',
    };
  }
}
