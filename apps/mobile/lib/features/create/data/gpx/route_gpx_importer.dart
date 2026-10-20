import 'dart:typed_data';

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
    final keys = selection.candidateKeys;
    if (keys.isEmpty || keys.toSet().length != keys.length) {
      throw const RouteGpxException('gpx_selection_invalid');
    }
    // One streaming pass: the same parser and limits as the preview.
    final pass = _inspector.inspectAndCollect(
      file: selection.file,
      bytes: bytes,
      candidateKeys: keys.toSet(),
    );
    final inspection = pass.inspection;
    final summaries = <String, RouteGpxCandidateSummary>{
      for (final candidate in inspection.candidates)
        candidate.selectionKey: candidate,
    };
    if (keys.any((key) => !summaries.containsKey(key))) {
      throw const RouteGpxException('gpx_candidate_not_found');
    }

    var duplicatesRemoved = 0;
    List<GeoPoint> deduplicated(List<GeoPoint> source) {
      final output = <GeoPoint>[];
      for (final point in source) {
        if (output.isNotEmpty && output.last == point) {
          duplicatesRemoved++;
        } else {
          output.add(point);
        }
      }
      return output;
    }

    final outputTracks = <List<List<GeoPoint>>>[];
    var directCount = 0;
    String? previousKey;
    for (final key in keys) {
      final segments = (pass.points[key] ?? const <List<GeoPoint>>[])
          .where((segment) => segment.isNotEmpty)
          .map(deduplicated)
          .toList(growable: false);
      final tracks = <List<List<GeoPoint>>>[];
      for (var index = 0; index < segments.length; index++) {
        if (index == 0) {
          tracks.add(<List<GeoPoint>>[segments[index]]);
          continue;
        }
        final resolution =
            selection.gapResolutions['$key:gap:${index - 1}:$index'];
        if (resolution == null) {
          throw const RouteGpxException('gpx_gap_decision_required');
        }
        if (resolution == RouteGpxGapResolution.direct) {
          tracks.last.add(segments[index]);
          directCount++;
        } else {
          tracks.add(<List<GeoPoint>>[segments[index]]);
        }
      }
      if (outputTracks.isEmpty || !selection.mergeTracks) {
        outputTracks.addAll(tracks);
      } else {
        final resolution =
            selection.gapResolutions['between:$previousKey:$key'];
        if (resolution == null) {
          throw const RouteGpxException('gpx_gap_decision_required');
        }
        if (resolution == RouteGpxGapResolution.direct && tracks.isNotEmpty) {
          outputTracks.last.addAll(tracks.first);
          outputTracks.addAll(tracks.skip(1));
          directCount++;
        } else {
          outputTracks.addAll(tracks);
        }
      }
      previousKey = key;
    }
    if (outputTracks.any(
      (track) => track.any((List<GeoPoint> part) => part.length < 2),
    )) {
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
    return RouteGpxImportResult(
      tracks: outputTracks.map(RouteGpxImportedTrack.new),
      waypoints: waypoints,
      sourceIssues: <RouteSourceIssueDraft>[
        if (directCount > 0)
          RouteSourceIssueDraft(
            id: 'loc_gpx_gap_review',
            code: 'gpx_direct_gap_confirmed',
            severity: RouteSourceIssueSeverity.warning,
            safeMetrics: <String, num>{'count': directCount},
          ),
        // The only normalization applied to source points, counted explicitly.
        if (duplicatesRemoved > 0)
          RouteSourceIssueDraft(
            id: 'loc_gpx_duplicates_removed',
            code: 'gpx_duplicates_removed',
            severity: RouteSourceIssueSeverity.warning,
            safeMetrics: <String, num>{'count': duplicatesRemoved},
          ),
      ],
      provenance: RouteProvenanceDraft(
        sourceId: 'gpx-${inspection.contentSha256.substring(0, 16)}',
        sourceRevision: 0,
        createdAtUtc: nowUtc,
        algorithmVersion: 'gpx-import-v2',
      ),
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
