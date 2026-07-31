import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../../../core/geo/geo_point.dart';
import '../../domain/repositories/route_gpx_repository.dart';

class RouteGpxExporter {
  const RouteGpxExporter();

  Uint8List export(RouteGpxExportRequest request) {
    final segments = request.route.orderedSegments;
    if (segments.isEmpty ||
        segments.any((segment) => segment.geometry.points.length < 2)) {
      throw const RouteGpxException('gpx_export_geometry_invalid');
    }
    final points = <GeoPoint>[];
    for (final segment in segments) {
      if (points.isNotEmpty && points.last != segment.geometry.points.first) {
        throw const RouteGpxException('gpx_export_geometry_discontinuous');
      }
      points.addAll(
        points.isNotEmpty
            ? segment.geometry.points.skip(1)
            : segment.geometry.points,
      );
    }
    final includeElevation =
        request.includeElevation &&
        points.every((point) => point.elevationMeters != null);
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
          if (request.includeWaypoints) {
            for (final waypoint in request.route.waypoints) {
              builder.element(
                'wpt',
                attributes: <String, String>{
                  'lat': _number(waypoint.position.latitude),
                  'lon': _number(waypoint.position.longitude),
                },
                nest: () {
                  final elevation = waypoint.position.elevationMeters;
                  if (includeElevation && elevation != null) {
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
          }
          builder.element(
            'trk',
            nest: () {
              builder.element('name', nest: 'Recharge route');
              builder.element(
                'trkseg',
                nest: () {
                  for (final point in points) {
                    builder.element(
                      'trkpt',
                      attributes: <String, String>{
                        'lat': _number(point.latitude),
                        'lon': _number(point.longitude),
                      },
                      nest: () {
                        final elevation = point.elevationMeters;
                        if (includeElevation && elevation != null) {
                          builder.element('ele', nest: _number(elevation));
                        }
                      },
                    );
                  }
                },
              );
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
