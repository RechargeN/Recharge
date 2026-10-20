import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/route_sync_data.dart';
import '../../domain/repositories/route_gpx_repository.dart';

/// Builds GPX from a canonical model only (never from stored source XML).
/// Text goes through the XML builder, so names are always escaped; no
/// timestamps, bounds, IDs, notes, author or extensions are written.
class RouteGpxExporter {
  const RouteGpxExporter();

  Uint8List export(RouteGpxExportRequest request) {
    final segments = request.route.orderedSegments;
    if (segments.isEmpty ||
        segments.any((segment) => segment.geometry.points.length < 2)) {
      throw const RouteGpxException('gpx_export_geometry_invalid');
    }
    // A broken anchor chain is an explicit gap: it starts a new <trkseg>.
    final runs = <List<GeoPoint>>[];
    for (var index = 0; index < segments.length; index++) {
      final points = segments[index].geometry.points;
      final connected =
          index > 0 &&
          segments[index - 1].toAnchorId == segments[index].fromAnchorId;
      if (!connected) {
        runs.add(List<GeoPoint>.of(points));
      } else {
        runs.last.addAll(
          runs.last.last == points.first ? points.skip(1) : points,
        );
      }
    }
    return _build(
      runs: runs,
      waypoints: request.includeWaypoints
          ? request.route.waypoints
                .map(
                  (waypoint) => RouteTrimmedWaypoint(
                    position: waypoint.position,
                    typeId: waypoint.typeId,
                    title: waypoint.title,
                  ),
                )
                .toList(growable: false)
          : const <RouteTrimmedWaypoint>[],
      includeElevation: request.includeElevation,
    );
  }

  /// Export of a server-trimmed view: only its points and waypoints exist here.
  Uint8List exportTrimmed(
    RouteTrimmedView view, {
    required bool includeElevation,
    required bool includeWaypoints,
  }) {
    if (view.segments.isEmpty ||
        view.segments.any((segment) => segment.points.length < 2)) {
      throw const RouteGpxException('gpx_export_geometry_invalid');
    }
    final runs = <List<GeoPoint>>[];
    for (final segment in view.segments) {
      if (runs.isEmpty || !segment.connected) {
        runs.add(List<GeoPoint>.of(segment.points));
      } else {
        runs.last.addAll(
          runs.last.last == segment.points.first
              ? segment.points.skip(1)
              : segment.points,
        );
      }
    }
    return _build(
      runs: runs,
      waypoints: includeWaypoints
          ? view.waypoints
          : const <RouteTrimmedWaypoint>[],
      includeElevation: includeElevation,
    );
  }

  Uint8List _build({
    required List<List<GeoPoint>> runs,
    required List<RouteTrimmedWaypoint> waypoints,
    required bool includeElevation,
  }) {
    final withElevation =
        includeElevation &&
        runs.every(
          (run) => run.every((GeoPoint point) => point.elevationMeters != null),
        );
    final builder = XmlBuilder();
    builder
      ..processing('xml', 'version="1.0" encoding="UTF-8"')
      ..element(
        'gpx',
        attributes: <String, String>{
          'version': '1.1',
          'creator': 'Recharge',
          'xmlns': 'http://www.topografix.com/GPX/1/1',
        },
        nest: () {
          builder.element(
            'metadata',
            nest: () => builder.element(
              'desc',
              nest: 'Exported by Recharge. No private source metadata.',
            ),
          );
          for (final waypoint in waypoints) {
            builder.element(
              'wpt',
              attributes: <String, String>{
                'lat': _number(waypoint.position.latitude),
                'lon': _number(waypoint.position.longitude),
              },
              nest: () {
                final elevation = waypoint.position.elevationMeters;
                if (withElevation && elevation != null) {
                  builder.element('ele', nest: _number(elevation));
                }
                final title = waypoint.title?.trim();
                if (title != null && title.isNotEmpty) {
                  builder.element('name', nest: title);
                }
                builder.element('type', nest: waypoint.typeId);
              },
            );
          }
          builder.element(
            'trk',
            nest: () {
              builder.element('name', nest: 'Recharge route');
              for (final run in runs) {
                builder.element(
                  'trkseg',
                  nest: () {
                    for (final point in run) {
                      builder.element(
                        'trkpt',
                        attributes: <String, String>{
                          'lat': _number(point.latitude),
                          'lon': _number(point.longitude),
                        },
                        nest: () {
                          final elevation = point.elevationMeters;
                          if (withElevation && elevation != null) {
                            builder.element('ele', nest: _number(elevation));
                          }
                        },
                      );
                    }
                  },
                );
              }
            },
          );
        },
      );
    return Uint8List.fromList(
      utf8.encode(builder.buildDocument().toXmlString(pretty: true)),
    );
  }

  String _number(double value) {
    if (!value.isFinite) {
      throw const RouteGpxException('gpx_export_number_invalid');
    }
    return value.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
